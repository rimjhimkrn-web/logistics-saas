-- Secure customer-authorized creation of immutable shipment route-plan drafts.
-- Activation is intentionally separate: no shipment legs are mutated by this RPC.

ALTER TABLE public.krim_shipment_leg_plans
  ADD COLUMN IF NOT EXISTS request_idempotency_key text,
  ADD COLUMN IF NOT EXISTS request_fingerprint text;

CREATE UNIQUE INDEX IF NOT EXISTS uq_krim_leg_plan_request_key
  ON public.krim_shipment_leg_plans (shipment_id, request_idempotency_key)
  WHERE request_idempotency_key IS NOT NULL;

CREATE OR REPLACE FUNCTION public.krim_create_shipment_leg_plan(
  p_shipment_id bigint,
  p_legs jsonb,
  p_idempotency_key text,
  p_constraints jsonb DEFAULT '{}'::jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_user uuid := auth.uid();
  v_shipment public.krim_shipments%ROWTYPE;
  v_plan public.krim_shipment_leg_plans%ROWTYPE;
  v_item jsonb;
  v_fingerprint text;
  v_count integer;
  v_seq integer := 0;
  v_origin bigint;
  v_destination bigint;
  v_mode bigint;
  v_prev_destination bigint;
  v_first_origin bigint;
  v_last_destination bigint;
  v_departure timestamptz;
  v_arrival timestamptz;
  v_capacity numeric;
  v_capacity_unit text;
  v_service_level text;
  v_requirements jsonb;
  v_version integer;
  v_item_snapshot jsonb := '[]'::jsonb;
BEGIN
  IF v_user IS NULL THEN
    RAISE EXCEPTION USING ERRCODE='28000', MESSAGE='Authentication required';
  END IF;
  IF p_shipment_id IS NULL OR p_legs IS NULL OR pg_catalog.jsonb_typeof(p_legs)<>'array'
     OR pg_catalog.jsonb_array_length(p_legs)<1 OR pg_catalog.jsonb_array_length(p_legs)>20 THEN
    RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='Provide between 1 and 20 shipment legs';
  END IF;
  IF NULLIF(pg_catalog.btrim(p_idempotency_key),'') IS NULL
     OR pg_catalog.length(p_idempotency_key)>160 THEN
    RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='A valid idempotency key (maximum 160 characters) is required';
  END IF;
  IF p_constraints IS NULL OR pg_catalog.jsonb_typeof(p_constraints)<>'object' THEN
    RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='Plan constraints must be a JSON object';
  END IF;

  SELECT * INTO v_shipment FROM public.krim_shipments
  WHERE id=p_shipment_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='P0002', MESSAGE='Shipment not found'; END IF;
  IF v_shipment.customer_organization_id IS NULL
     OR NOT public.krim_has_permission(v_user,v_shipment.customer_organization_id,'shipment.update') THEN
    RAISE EXCEPTION USING ERRCODE='42501', MESSAGE='Shipment update permission is required for the owning customer organization';
  END IF;
  IF v_shipment.status NOT IN ('draft','quoted','confirmed') THEN
    RAISE EXCEPTION USING ERRCODE='55000', MESSAGE='A route plan can only be created before shipment execution begins';
  END IF;

  v_fingerprint := pg_catalog.encode(
    extensions.digest(
      pg_catalog.convert_to(pg_catalog.jsonb_build_object('legs',p_legs,'constraints',p_constraints)::text,'UTF8'),
      'sha256'
    ),'hex'
  );

  SELECT * INTO v_plan FROM public.krim_shipment_leg_plans
  WHERE shipment_id=p_shipment_id AND request_idempotency_key=p_idempotency_key
  FOR UPDATE;
  IF FOUND THEN
    IF v_plan.request_fingerprint IS DISTINCT FROM v_fingerprint THEN
      RAISE EXCEPTION USING ERRCODE='23505', MESSAGE='Idempotency key was already used with a different route plan';
    END IF;
    RETURN pg_catalog.jsonb_build_object('created',true,'idempotent',true,'plan_id',v_plan.id,
      'shipment_id',v_plan.shipment_id,'plan_version',v_plan.plan_version,
      'status',v_plan.status,'total_legs',v_plan.total_legs);
  END IF;

  v_count := pg_catalog.jsonb_array_length(p_legs);
  FOR v_item IN SELECT value FROM pg_catalog.jsonb_array_elements(p_legs)
  LOOP
    v_seq := v_seq+1;
    IF pg_catalog.jsonb_typeof(v_item)<>'object'
       OR NOT (v_item ? 'origin_location_id')
       OR NOT (v_item ? 'destination_location_id')
       OR NOT (v_item ? 'transport_mode_id') THEN
      RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='Every leg requires origin_location_id, destination_location_id and transport_mode_id';
    END IF;
    IF NOT pg_catalog.pg_input_is_valid(v_item->>'origin_location_id','bigint')
       OR NOT pg_catalog.pg_input_is_valid(v_item->>'destination_location_id','bigint')
       OR NOT pg_catalog.pg_input_is_valid(v_item->>'transport_mode_id','bigint') THEN
      RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='Location and transport mode identifiers must be valid integers';
    END IF;
    v_origin := (v_item->>'origin_location_id')::bigint;
    v_destination := (v_item->>'destination_location_id')::bigint;
    v_mode := (v_item->>'transport_mode_id')::bigint;
    IF v_origin=v_destination THEN RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='A shipment leg cannot start and end at the same location'; END IF;
    IF NOT EXISTS (SELECT 1 FROM public.krim_locations l WHERE l.id=v_origin AND l.is_active IS TRUE)
       OR NOT EXISTS (SELECT 1 FROM public.krim_locations l WHERE l.id=v_destination AND l.is_active IS TRUE) THEN
      RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='Every leg must use active origin and destination locations';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM public.krim_transport_modes tm WHERE tm.id=v_mode AND tm.is_active IS TRUE) THEN
      RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='Every leg must use an active transport mode';
    END IF;
    IF v_seq=1 THEN v_first_origin:=v_origin;
    ELSIF v_origin IS DISTINCT FROM v_prev_destination THEN
      RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='Route is disconnected: each leg origin must match the previous leg destination';
    END IF;
    v_prev_destination:=v_destination;
    v_last_destination:=v_destination;

    v_departure:=NULL; v_arrival:=NULL;
    IF NULLIF(v_item->>'planned_departure_at','') IS NOT NULL THEN
      IF NOT pg_catalog.pg_input_is_valid(v_item->>'planned_departure_at','timestamptz') THEN
        RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='Invalid planned_departure_at timestamp';
      END IF;
      v_departure:=(v_item->>'planned_departure_at')::timestamptz;
    END IF;
    IF NULLIF(v_item->>'planned_arrival_at','') IS NOT NULL THEN
      IF NOT pg_catalog.pg_input_is_valid(v_item->>'planned_arrival_at','timestamptz') THEN
        RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='Invalid planned_arrival_at timestamp';
      END IF;
      v_arrival:=(v_item->>'planned_arrival_at')::timestamptz;
    END IF;
    IF v_departure IS NOT NULL AND v_arrival IS NOT NULL AND v_arrival<=v_departure THEN
      RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='Each planned arrival must be later than its planned departure';
    END IF;
    IF v_seq>1 AND v_departure IS NOT NULL AND EXISTS (
      SELECT 1 FROM pg_catalog.jsonb_array_elements(p_legs) WITH ORDINALITY x(value,ord)
      WHERE ord=v_seq-1 AND NULLIF(value->>'planned_arrival_at','') IS NOT NULL
        AND pg_catalog.pg_input_is_valid(value->>'planned_arrival_at','timestamptz')
        AND v_departure<(value->>'planned_arrival_at')::timestamptz
    ) THEN
      RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='A leg cannot depart before the previous leg planned arrival';
    END IF;

    v_capacity:=NULL;
    IF NULLIF(v_item->>'required_capacity','') IS NOT NULL THEN
      IF NOT pg_catalog.pg_input_is_valid(v_item->>'required_capacity','numeric') THEN
        RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='required_capacity must be numeric';
      END IF;
      v_capacity:=(v_item->>'required_capacity')::numeric;
      IF v_capacity<=0 OR v_capacity::text IN ('NaN','Infinity','-Infinity') THEN
        RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='required_capacity must be finite and positive';
      END IF;
    END IF;
    v_capacity_unit:=NULLIF(pg_catalog.btrim(v_item->>'capacity_unit'),'');
    IF (v_capacity IS NULL)<>(v_capacity_unit IS NULL) THEN
      RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='required_capacity and capacity_unit must be supplied together';
    END IF;
    v_service_level:=NULLIF(pg_catalog.btrim(v_item->>'service_level'),'');
    IF pg_catalog.length(coalesce(v_service_level,''))>80 THEN
      RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='service_level is too long';
    END IF;
    v_requirements:=coalesce(v_item->'requirements','{}'::jsonb);
    IF pg_catalog.jsonb_typeof(v_requirements)<>'object' THEN
      RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='Leg requirements must be a JSON object';
    END IF;
    v_item_snapshot:=v_item_snapshot||pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object('leg_sequence',v_seq,'origin_location_id',v_origin,
        'destination_location_id',v_destination,'transport_mode_id',v_mode,
        'planned_departure_at',v_departure,'planned_arrival_at',v_arrival,
        'required_capacity',v_capacity,'capacity_unit',v_capacity_unit,
        'service_level',v_service_level,'requirements',v_requirements));
  END LOOP;

  IF v_shipment.origin_location_id IS NOT NULL AND v_first_origin<>v_shipment.origin_location_id THEN
    RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='The first leg origin must match the shipment origin';
  END IF;
  IF v_shipment.destination_location_id IS NOT NULL AND v_last_destination<>v_shipment.destination_location_id THEN
    RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='The final leg destination must match the shipment destination';
  END IF;

  SELECT coalesce(max(plan_version),0)+1 INTO v_version
  FROM public.krim_shipment_leg_plans WHERE shipment_id=p_shipment_id;

  INSERT INTO public.krim_shipment_leg_plans
    (shipment_id,plan_version,status,source_type,total_legs,planning_snapshot,
     constraints_snapshot,created_by,request_idempotency_key,request_fingerprint)
  VALUES
    (p_shipment_id,v_version,'draft','customer',v_count,v_item_snapshot,
     p_constraints,v_user,p_idempotency_key,v_fingerprint)
  RETURNING * INTO v_plan;

  v_seq:=0;
  FOR v_item IN SELECT value FROM pg_catalog.jsonb_array_elements(p_legs)
  LOOP
    v_seq:=v_seq+1;
    INSERT INTO public.krim_shipment_leg_plan_items
      (plan_id,leg_sequence,origin_location_id,destination_location_id,transport_mode_id,
       service_level,planned_departure_at,planned_arrival_at,required_capacity,capacity_unit,status,requirements)
    VALUES
      (v_plan.id,v_seq,(v_item->>'origin_location_id')::bigint,
       (v_item->>'destination_location_id')::bigint,(v_item->>'transport_mode_id')::bigint,
       NULLIF(pg_catalog.btrim(v_item->>'service_level'),''),
       NULLIF(v_item->>'planned_departure_at','')::timestamptz,
       NULLIF(v_item->>'planned_arrival_at','')::timestamptz,
       NULLIF(v_item->>'required_capacity','')::numeric,
       NULLIF(pg_catalog.btrim(v_item->>'capacity_unit'),''),'planned',
       coalesce(v_item->'requirements','{}'::jsonb));
  END LOOP;

  INSERT INTO public.krim_shipment_leg_plan_events
    (plan_id,event_type,previous_status,new_status,actor_user_id,payload,event_time,created_at)
  VALUES
    (v_plan.id,'plan_created',NULL,'draft',v_user,
     pg_catalog.jsonb_build_object('shipment_id',p_shipment_id,'plan_version',v_version,
       'total_legs',v_count,'request_fingerprint',v_fingerprint),pg_catalog.now(),pg_catalog.now());

  RETURN pg_catalog.jsonb_build_object('created',true,'idempotent',false,'plan_id',v_plan.id,
    'shipment_id',p_shipment_id,'plan_version',v_version,'status','draft','total_legs',v_count);
END;
$function$;

REVOKE ALL ON FUNCTION public.krim_create_shipment_leg_plan(bigint,jsonb,text,jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.krim_create_shipment_leg_plan(bigint,jsonb,text,jsonb) TO authenticated;
