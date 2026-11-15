-- Read-only evaluation gate for shipment leg-plan activation.
-- This RPC does not mutate plans, shipment legs, partner assignments or capacity.

CREATE OR REPLACE FUNCTION public.krim_evaluate_shipment_leg_plan(p_plan_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_user uuid := auth.uid();
  v_plan public.krim_shipment_leg_plans%ROWTYPE;
  v_shipment public.krim_shipments%ROWTYPE;
  v_item public.krim_shipment_leg_plan_items%ROWTYPE;
  v_count integer := 0;
  v_existing_count integer := 0;
  v_prev_destination bigint;
  v_first_origin bigint;
  v_last_destination bigint;
  v_prev_arrival timestamptz;
  v_issues jsonb := '[]'::jsonb;
  v_first_item public.krim_shipment_leg_plan_items%ROWTYPE;
  v_leg public.krim_shipment_legs%ROWTYPE;
  v_active_other integer := 0;
BEGIN
  IF v_user IS NULL THEN
    RAISE EXCEPTION USING ERRCODE='28000', MESSAGE='Authentication required';
  END IF;
  SELECT * INTO v_plan FROM public.krim_shipment_leg_plans WHERE id=p_plan_id;
  IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='P0002', MESSAGE='Shipment leg plan not found'; END IF;
  SELECT * INTO v_shipment FROM public.krim_shipments WHERE id=v_plan.shipment_id;
  IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='P0002', MESSAGE='Shipment not found'; END IF;
  IF v_shipment.customer_organization_id IS NULL
     OR NOT public.krim_has_permission(v_user,v_shipment.customer_organization_id,'shipment.update') THEN
    RAISE EXCEPTION USING ERRCODE='42501', MESSAGE='Shipment update permission is required for the owning customer organization';
  END IF;

  IF v_plan.status NOT IN ('draft','ready') THEN
    v_issues := v_issues || pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
      'code','plan_not_evaluable','message','Only draft or ready plans can be evaluated'));
  END IF;
  IF v_shipment.status NOT IN ('draft','quoted','confirmed') THEN
    v_issues := v_issues || pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
      'code','shipment_execution_started','message','Shipment is no longer in a pre-execution state'));
  END IF;

  SELECT count(*)::integer INTO v_count
  FROM public.krim_shipment_leg_plan_items WHERE plan_id=v_plan.id;
  IF v_count<1 OR v_count>20 OR v_count<>v_plan.total_legs THEN
    v_issues := v_issues || pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
      'code','leg_count_mismatch','message','Plan item count must exactly match the declared total between 1 and 20',
      'expected',v_plan.total_legs,'actual',v_count));
  END IF;

  FOR v_item IN SELECT * FROM public.krim_shipment_leg_plan_items
    WHERE plan_id=v_plan.id ORDER BY leg_sequence
  LOOP
    IF v_item.leg_sequence<1 OR v_item.leg_sequence<>
       (SELECT count(*) FROM public.krim_shipment_leg_plan_items x
        WHERE x.plan_id=v_plan.id AND x.leg_sequence<=v_item.leg_sequence) THEN
      v_issues := v_issues || pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
        'code','sequence_gap','message','Leg sequences must be contiguous starting at one',
        'leg_sequence',v_item.leg_sequence));
    END IF;
    IF v_item.origin_location_id IS NULL OR v_item.destination_location_id IS NULL
       OR v_item.transport_mode_id IS NULL THEN
      v_issues := v_issues || pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
        'code','missing_leg_routing','message','Every leg requires origin, destination and transport mode',
        'leg_sequence',v_item.leg_sequence));
      CONTINUE;
    END IF;
    IF v_item.origin_location_id=v_item.destination_location_id THEN
      v_issues := v_issues || pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
        'code','same_leg_endpoints','message','A leg cannot have identical origin and destination',
        'leg_sequence',v_item.leg_sequence));
    END IF;
    IF NOT EXISTS (SELECT 1 FROM public.krim_locations l
      WHERE l.id=v_item.origin_location_id AND l.is_active IS TRUE)
       OR NOT EXISTS (SELECT 1 FROM public.krim_locations l
      WHERE l.id=v_item.destination_location_id AND l.is_active IS TRUE) THEN
      v_issues := v_issues || pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
        'code','inactive_location','message','Every leg must use active locations',
        'leg_sequence',v_item.leg_sequence));
    END IF;
    IF NOT EXISTS (SELECT 1 FROM public.krim_transport_modes tm
      WHERE tm.id=v_item.transport_mode_id AND tm.is_active IS TRUE) THEN
      v_issues := v_issues || pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
        'code','inactive_transport_mode','message','Every leg must use an active transport mode',
        'leg_sequence',v_item.leg_sequence));
    END IF;
    IF v_item.leg_sequence=1 THEN
      v_first_item:=v_item;
      v_first_origin:=v_item.origin_location_id;
    END IF;
    IF v_prev_destination IS NOT NULL AND v_item.origin_location_id IS DISTINCT FROM v_prev_destination THEN
      v_issues := v_issues || pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
        'code','route_disconnected','message','Each leg origin must match the previous leg destination',
        'leg_sequence',v_item.leg_sequence));
    END IF;
    v_prev_destination:=v_item.destination_location_id;
    v_last_destination:=v_item.destination_location_id;
    IF v_item.planned_departure_at IS NOT NULL AND v_item.planned_arrival_at IS NOT NULL
       AND v_item.planned_arrival_at<=v_item.planned_departure_at THEN
      v_issues := v_issues || pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
        'code','invalid_leg_time_window','message','Planned arrival must be later than departure',
        'leg_sequence',v_item.leg_sequence));
    END IF;
    IF v_item.planned_departure_at IS NOT NULL AND v_prev_arrival IS NOT NULL
       AND v_item.planned_departure_at<v_prev_arrival THEN
      v_issues := v_issues || pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
        'code','overlapping_leg_time_window','message','A leg cannot depart before the previous leg planned arrival',
        'leg_sequence',v_item.leg_sequence));
    END IF;
    v_prev_arrival:=v_item.planned_arrival_at;
    IF (v_item.required_capacity IS NOT NULL AND
        (v_item.required_capacity<=0 OR v_item.capacity_unit IS NULL))
       OR (v_item.required_capacity IS NULL AND v_item.capacity_unit IS NOT NULL) THEN
      v_issues := v_issues || pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
        'code','invalid_capacity_requirement','message','Capacity and unit must be supplied together with a positive capacity',
        'leg_sequence',v_item.leg_sequence));
    END IF;
  END LOOP;

  IF v_first_origin IS DISTINCT FROM v_shipment.origin_location_id THEN
    v_issues := v_issues || pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
      'code','shipment_origin_mismatch','message','First plan leg must start at the shipment origin'));
  END IF;
  IF v_last_destination IS DISTINCT FROM v_shipment.destination_location_id THEN
    v_issues := v_issues || pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
      'code','shipment_destination_mismatch','message','Final plan leg must end at the shipment destination'));
  END IF;

  SELECT count(*)::integer INTO v_active_other
  FROM public.krim_shipment_leg_plans p
  WHERE p.shipment_id=v_plan.shipment_id AND p.id<>v_plan.id AND p.status='active';
  IF v_active_other>0 THEN
    v_issues := v_issues || pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
      'code','another_active_plan','message','Another route plan is already active for this shipment'));
  END IF;

  SELECT count(*)::integer INTO v_existing_count
  FROM public.krim_shipment_legs WHERE shipment_id=v_plan.shipment_id;
  IF v_existing_count>0 THEN
    SELECT * INTO v_leg FROM public.krim_shipment_legs
    WHERE shipment_id=v_plan.shipment_id ORDER BY leg_sequence LIMIT 1;
    IF v_existing_count<>1 OR v_leg.leg_sequence<>1 OR v_leg.status<>'planned'
       OR v_leg.assignment_status<>'unassigned' OR v_leg.partner_organization_id IS NOT NULL
       OR v_leg.leg_plan_item_id IS NOT NULL
       OR v_leg.origin_location_id IS DISTINCT FROM v_first_item.origin_location_id
       OR v_leg.destination_location_id IS DISTINCT FROM v_first_item.destination_location_id
       OR v_leg.transport_mode_id IS DISTINCT FROM v_first_item.transport_mode_id THEN
      v_issues := v_issues || pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
        'code','existing_leg_conflict','message','Existing shipment leg records are not an exact, unassigned match for the first plan item; activation is blocked to preserve history'));
    END IF;
  END IF;

  RETURN pg_catalog.jsonb_build_object(
    'ready',pg_catalog.jsonb_array_length(v_issues)=0,
    'plan_id',v_plan.id,'shipment_id',v_plan.shipment_id,
    'plan_version',v_plan.plan_version,'expected_legs',v_plan.total_legs,
    'existing_legs',v_existing_count,'issues',v_issues,'evaluated_at',pg_catalog.now());
END;
$function$;

REVOKE ALL ON FUNCTION public.krim_evaluate_shipment_leg_plan(bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.krim_evaluate_shipment_leg_plan(bigint) TO authenticated;
