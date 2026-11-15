CREATE OR REPLACE FUNCTION public.krim_create_leg_partner_opportunity(
  p_shipment_id bigint,
  p_shipment_leg_id bigint,
  p_response_deadline timestamptz DEFAULT NULL
)
RETURNS public.krim_partner_opportunities
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_user uuid := auth.uid();
  v_shipment public.krim_shipments%rowtype;
  v_leg public.krim_shipment_legs%rowtype;
  v_plan public.krim_shipment_leg_plans%rowtype;
  v_item public.krim_shipment_leg_plan_items%rowtype;
  v_existing public.krim_partner_opportunities%rowtype;
  v_result public.krim_partner_opportunities%rowtype;
  v_deadline timestamptz;
  v_number text;
  v_lane text;
BEGIN
  IF v_user IS NULL THEN RAISE EXCEPTION USING ERRCODE='28000', MESSAGE='Authentication required'; END IF;
  IF p_shipment_id IS NULL OR p_shipment_id<=0 OR p_shipment_leg_id IS NULL OR p_shipment_leg_id<=0 THEN
    RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='A valid shipment and shipment leg are required';
  END IF;
  SELECT * INTO v_shipment FROM public.krim_shipments WHERE id=p_shipment_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='P0002', MESSAGE='Shipment not found'; END IF;
  IF v_shipment.customer_organization_id IS NULL
     OR NOT private.krim_has_organization_access(v_user,v_shipment.customer_organization_id)
     OR NOT private.krim_has_permission(v_user,v_shipment.customer_organization_id,'quote.create')
     OR NOT private.krim_has_permission(v_user,v_shipment.customer_organization_id,'shipment.update') THEN
    RAISE EXCEPTION USING ERRCODE='42501', MESSAGE='Customer organisation access and quote.create plus shipment.update permissions are required';
  END IF;
  IF v_shipment.status NOT IN ('draft','quoted','confirmed') THEN
    RAISE EXCEPTION USING ERRCODE='55000', MESSAGE='Leg sourcing is available only before shipment execution';
  END IF;
  SELECT * INTO v_leg FROM public.krim_shipment_legs
  WHERE id=p_shipment_leg_id AND shipment_id=p_shipment_id FOR UPDATE;
  IF NOT FOUND OR v_leg.leg_plan_item_id IS NULL THEN
    RAISE EXCEPTION USING ERRCODE='23503', MESSAGE='Shipment leg is not linked to this shipment route plan';
  END IF;
  IF v_leg.status NOT IN ('planned','unassigned') AND v_leg.assignment_status NOT IN ('planned','unassigned','pending') THEN
    RAISE EXCEPTION USING ERRCODE='55000', MESSAGE='Only an unassigned planned leg can be sourced';
  END IF;
  SELECT p.* INTO v_plan FROM public.krim_shipment_leg_plans p
  JOIN public.krim_shipment_leg_plan_items pi ON pi.plan_id=p.id
  WHERE p.shipment_id=p_shipment_id AND p.status='active' AND pi.id=v_leg.leg_plan_item_id
  ORDER BY p.plan_version DESC LIMIT 1 FOR UPDATE OF p;
  IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='55000', MESSAGE='Leg does not belong to an active route plan'; END IF;
  SELECT * INTO v_item FROM public.krim_shipment_leg_plan_items
  WHERE id=v_leg.leg_plan_item_id AND plan_id=v_plan.id FOR KEY SHARE;
  IF NOT FOUND OR v_item.leg_sequence<>v_leg.leg_sequence
     OR v_item.origin_location_id IS DISTINCT FROM v_leg.origin_location_id
     OR v_item.destination_location_id IS DISTINCT FROM v_leg.destination_location_id
     OR v_item.transport_mode_id IS DISTINCT FROM v_leg.transport_mode_id THEN
    RAISE EXCEPTION USING ERRCODE='23514', MESSAGE='Shipment leg no longer matches its immutable route-plan item';
  END IF;
  v_deadline:=coalesce(p_response_deadline,now()+interval '72 hours');
  IF v_deadline<now()+interval '1 hour' OR v_deadline>now()+interval '30 days' THEN
    RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='Response deadline must be between one hour and 30 days from now';
  END IF;
  SELECT * INTO v_existing FROM public.krim_partner_opportunities
  WHERE shipment_id=p_shipment_id AND shipment_leg_id=p_shipment_leg_id
    AND status='open' AND (response_deadline IS NULL OR response_deadline>now())
  ORDER BY created_at DESC LIMIT 1 FOR UPDATE;
  IF FOUND THEN RETURN v_existing; END IF;
  SELECT concat_ws(' → ',coalesce(o.city,o.location_code,'Origin'),coalesce(d.city,d.location_code,'Destination'))
  INTO v_lane FROM public.krim_locations o
  JOIN public.krim_locations d ON d.id=v_leg.destination_location_id
  WHERE o.id=v_leg.origin_location_id;
  v_number:='KPL-'||to_char(now(),'YYYYMMDD')||'-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,8));
  INSERT INTO public.krim_partner_opportunities(
    shipment_id,customer_organization_id,opportunity_number,status,requested_at,
    response_deadline,service_lane,metadata,shipment_leg_id
  ) VALUES (
    p_shipment_id,v_shipment.customer_organization_id,v_number,'open',now(),v_deadline,v_lane,
    jsonb_build_object('source','customer_leg_sourcing','shipment_leg_id',p_shipment_leg_id,
      'leg_sequence',v_leg.leg_sequence,'transport_mode_id',v_leg.transport_mode_id,
      'route_plan_id',v_plan.id,'route_plan_item_id',v_item.id,'requested_by',v_user),
    p_shipment_leg_id
  ) RETURNING * INTO v_result;
  INSERT INTO public.krim_audit_events(actor_user_id,organization_id,event_type,entity_type,entity_id,source,metadata)
  VALUES(v_user,v_shipment.customer_organization_id,'partner.leg_opportunity.created',
    'partner_opportunity',v_result.id::text,'customer_leg_sourcing',
    jsonb_build_object('shipment_id',p_shipment_id,'shipment_leg_id',p_shipment_leg_id,
      'route_plan_id',v_plan.id,'response_deadline',v_deadline));
  RETURN v_result;
END;
$function$;
REVOKE ALL ON FUNCTION public.krim_create_leg_partner_opportunity(bigint,bigint,timestamptz) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.krim_create_leg_partner_opportunity(bigint,bigint,timestamptz) TO authenticated;
