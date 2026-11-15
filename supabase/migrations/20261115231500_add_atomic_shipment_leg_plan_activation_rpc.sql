-- Atomic, idempotent materialization of a validated shipment leg plan.
-- Does not assign partners, reserve capacity, dispatch, or advance shipment status.

CREATE UNIQUE INDEX IF NOT EXISTS uq_krim_leg_activation_request_key
  ON public.krim_shipment_leg_activations (shipment_id,idempotency_key)
  WHERE idempotency_key IS NOT NULL;

CREATE OR REPLACE FUNCTION public.krim_activate_shipment_leg_plan(
  p_plan_id bigint,
  p_idempotency_key text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_user uuid := auth.uid();
  v_shipment_id bigint;
  v_shipment public.krim_shipments%ROWTYPE;
  v_plan public.krim_shipment_leg_plans%ROWTYPE;
  v_activation public.krim_shipment_leg_activations%ROWTYPE;
  v_existing_activation public.krim_shipment_leg_activations%ROWTYPE;
  v_item public.krim_shipment_leg_plan_items%ROWTYPE;
  v_evaluation jsonb;
  v_existing_leg_id bigint;
  v_leg_id bigint;
  v_created integer := 0;
  v_mapping jsonb := '[]'::jsonb;
  v_activation_number text;
BEGIN
  IF v_user IS NULL THEN
    RAISE EXCEPTION USING ERRCODE='28000', MESSAGE='Authentication required';
  END IF;
  IF p_plan_id IS NULL OR NULLIF(pg_catalog.btrim(p_idempotency_key),'') IS NULL
     OR pg_catalog.length(p_idempotency_key)>160 THEN
    RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='A plan ID and valid idempotency key (maximum 160 characters) are required';
  END IF;

  SELECT shipment_id INTO v_shipment_id
  FROM public.krim_shipment_leg_plans WHERE id=p_plan_id;
  IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='P0002', MESSAGE='Shipment leg plan not found'; END IF;

  SELECT * INTO v_shipment
  FROM public.krim_shipments WHERE id=v_shipment_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='P0002', MESSAGE='Shipment not found'; END IF;
  IF v_shipment.customer_organization_id IS NULL
     OR NOT public.krim_has_permission(v_user,v_shipment.customer_organization_id,'shipment.update') THEN
    RAISE EXCEPTION USING ERRCODE='42501', MESSAGE='Shipment update permission is required for the owning customer organization';
  END IF;

  SELECT * INTO v_plan
  FROM public.krim_shipment_leg_plans WHERE id=p_plan_id FOR UPDATE;
  IF NOT FOUND OR v_plan.shipment_id<>v_shipment_id THEN
    RAISE EXCEPTION USING ERRCODE='P0002', MESSAGE='Shipment leg plan not found';
  END IF;

  SELECT * INTO v_existing_activation
  FROM public.krim_shipment_leg_activations
  WHERE shipment_id=v_shipment_id AND idempotency_key=p_idempotency_key
  FOR UPDATE;
  IF FOUND THEN
    IF v_existing_activation.leg_plan_id<>p_plan_id THEN
      RAISE EXCEPTION USING ERRCODE='23505', MESSAGE='Activation idempotency key was already used for a different plan';
    END IF;
    IF v_existing_activation.status<>'completed' THEN
      RAISE EXCEPTION USING ERRCODE='55000', MESSAGE='A prior activation is not complete; manual reconciliation is required';
    END IF;
    RETURN pg_catalog.jsonb_build_object(
      'activated',true,'idempotent',true,'activation_id',v_existing_activation.id,
      'activation_number',v_existing_activation.activation_number,'plan_id',p_plan_id,
      'shipment_id',v_shipment_id,'legs_expected',v_existing_activation.legs_expected,
      'legs_created',v_existing_activation.legs_created,'status',v_existing_activation.status);
  END IF;

  SELECT * INTO v_existing_activation
  FROM public.krim_shipment_leg_activations
  WHERE leg_plan_id=p_plan_id FOR UPDATE;
  IF FOUND THEN
    RAISE EXCEPTION USING ERRCODE='23505', MESSAGE='This route plan already has an activation record';
  END IF;

  v_evaluation := public.krim_evaluate_shipment_leg_plan(p_plan_id);
  IF coalesce((v_evaluation->>'ready')::boolean,false) IS NOT TRUE THEN
    RETURN pg_catalog.jsonb_build_object(
      'activated',false,'idempotent',false,'plan_id',p_plan_id,
      'shipment_id',v_shipment_id,'evaluation',v_evaluation);
  END IF;

  SELECT id INTO v_existing_leg_id
  FROM public.krim_shipment_legs
  WHERE shipment_id=v_shipment_id
  ORDER BY leg_sequence LIMIT 1 FOR UPDATE;

  v_activation_number := 'KRIM-LPA-PENDING-'||pg_catalog.gen_random_uuid()::text;
  INSERT INTO public.krim_shipment_leg_activations
    (shipment_id,leg_plan_id,activation_number,status,requested_by,idempotency_key,
     plan_version,legs_expected,legs_created,input_snapshot,result_snapshot,started_at)
  VALUES
    (v_shipment_id,p_plan_id,v_activation_number,'running',v_user,p_idempotency_key,
     v_plan.plan_version,v_plan.total_legs,0,
     pg_catalog.jsonb_build_object('planning_snapshot',v_plan.planning_snapshot,
       'constraints_snapshot',v_plan.constraints_snapshot,
       'request_fingerprint',v_plan.request_fingerprint),
     '{}'::jsonb,pg_catalog.now())
  RETURNING * INTO v_activation;

  INSERT INTO public.krim_shipment_leg_activation_events
    (activation_id,event_type,previous_status,new_status,actor_user_id,event_time,payload,created_at)
  VALUES
    (v_activation.id,'activation_started',NULL,'running',v_user,pg_catalog.now(),
     pg_catalog.jsonb_build_object('plan_id',p_plan_id,'shipment_id',v_shipment_id,
       'expected_legs',v_plan.total_legs),pg_catalog.now());

  FOR v_item IN SELECT * FROM public.krim_shipment_leg_plan_items
    WHERE plan_id=p_plan_id ORDER BY leg_sequence
  LOOP
    IF v_existing_leg_id IS NOT NULL AND v_item.leg_sequence=1 THEN
      UPDATE public.krim_shipment_legs
      SET leg_plan_item_id=v_item.id,updated_at=pg_catalog.now()
      WHERE id=v_existing_leg_id AND shipment_id=v_shipment_id
        AND leg_plan_item_id IS NULL
      RETURNING id INTO v_leg_id;
      IF v_leg_id IS NULL THEN
        RAISE EXCEPTION USING ERRCODE='55000', MESSAGE='Existing first leg changed during activation; transaction aborted';
      END IF;
    ELSE
      INSERT INTO public.krim_shipment_legs
        (shipment_id,leg_sequence,origin_location_id,destination_location_id,
         transport_mode_id,status,assignment_status,planned_departure,planned_arrival,
         leg_plan_item_id,updated_at)
      VALUES
        (v_shipment_id,v_item.leg_sequence,v_item.origin_location_id,
         v_item.destination_location_id,v_item.transport_mode_id,
         'planned','unassigned',v_item.planned_departure_at,v_item.planned_arrival_at,
         v_item.id,pg_catalog.now())
      RETURNING id INTO v_leg_id;
    END IF;
    v_created:=v_created+1;
    v_mapping:=v_mapping||pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object('plan_item_id',v_item.id,
        'leg_sequence',v_item.leg_sequence,'shipment_leg_id',v_leg_id));
  END LOOP;

  IF v_created<>v_plan.total_legs THEN
    RAISE EXCEPTION USING ERRCODE='55000', MESSAGE='Activation leg count mismatch; transaction aborted';
  END IF;

  UPDATE public.krim_shipment_leg_activations
  SET status='completed',legs_created=v_created,
      activation_number='KRIM-LPA-'||id::text,
      result_snapshot=pg_catalog.jsonb_build_object('legs',v_mapping,
        'expected_legs',v_plan.total_legs,'created_legs',v_created),
      completed_at=pg_catalog.now(),updated_at=pg_catalog.now()
  WHERE id=v_activation.id
  RETURNING * INTO v_activation;

  UPDATE public.krim_shipment_leg_plans
  SET status='active',activated_at=coalesce(activated_at,pg_catalog.now())
  WHERE id=p_plan_id AND status IN ('draft','ready');
  IF NOT FOUND THEN
    RAISE EXCEPTION USING ERRCODE='55000', MESSAGE='Plan status changed during activation; transaction aborted';
  END IF;

  INSERT INTO public.krim_shipment_leg_plan_events
    (plan_id,event_type,previous_status,new_status,actor_user_id,payload,event_time,created_at)
  VALUES
    (p_plan_id,'plan_activated',v_plan.status,'active',v_user,
     pg_catalog.jsonb_build_object('activation_id',v_activation.id,
       'activation_number',v_activation.activation_number,
       'legs_expected',v_plan.total_legs,'legs_created',v_created,
       'leg_mapping',v_mapping),pg_catalog.now(),pg_catalog.now());

  INSERT INTO public.krim_shipment_leg_activation_events
    (activation_id,event_type,previous_status,new_status,actor_user_id,event_time,payload,created_at)
  VALUES
    (v_activation.id,'activation_completed','running','completed',v_user,pg_catalog.now(),
     pg_catalog.jsonb_build_object('legs_expected',v_plan.total_legs,
       'legs_created',v_created,'leg_mapping',v_mapping),pg_catalog.now());

  RETURN pg_catalog.jsonb_build_object(
    'activated',true,'idempotent',false,'activation_id',v_activation.id,
    'activation_number',v_activation.activation_number,'plan_id',p_plan_id,
    'shipment_id',v_shipment_id,'legs_expected',v_plan.total_legs,
    'legs_created',v_created,'status','completed','legs',v_mapping);
END;
$function$;

REVOKE ALL ON FUNCTION public.krim_activate_shipment_leg_plan(bigint,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.krim_activate_shipment_leg_plan(bigint,text) TO authenticated;
