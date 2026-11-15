CREATE UNIQUE INDEX IF NOT EXISTS uq_krim_active_partner_assignment_per_leg
ON public.krim_shipment_partner_assignments (shipment_leg_id)
WHERE shipment_leg_id IS NOT NULL AND status IN ('offered','accepted','active','completed');

CREATE OR REPLACE FUNCTION public.krim_award_leg_partner_quote(p_partner_quote_id bigint)
RETURNS public.krim_shipment_partner_assignments
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_user uuid := auth.uid();
  v_quote public.krim_partner_quotes%rowtype;
  v_opportunity public.krim_partner_opportunities%rowtype;
  v_shipment public.krim_shipments%rowtype;
  v_leg public.krim_shipment_legs%rowtype;
  v_plan public.krim_shipment_leg_plans%rowtype;
  v_item public.krim_shipment_leg_plan_items%rowtype;
  v_assignment public.krim_shipment_partner_assignments%rowtype;
  v_number text;
BEGIN
  IF v_user IS NULL THEN RAISE EXCEPTION USING ERRCODE='28000', MESSAGE='Authentication required'; END IF;
  IF p_partner_quote_id IS NULL OR p_partner_quote_id<=0 THEN RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='A valid partner quote is required'; END IF;
  SELECT * INTO v_quote FROM public.krim_partner_quotes WHERE id=p_partner_quote_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='P0002', MESSAGE='Partner quote not found'; END IF;
  IF v_quote.shipment_leg_id IS NULL THEN RAISE EXCEPTION USING ERRCODE='55000', MESSAGE='This RPC accepts only leg-scoped partner quotes'; END IF;
  SELECT * INTO v_opportunity FROM public.krim_partner_opportunities WHERE id=v_quote.opportunity_id FOR UPDATE;
  IF NOT FOUND OR v_opportunity.shipment_id<>v_quote.shipment_id OR v_opportunity.shipment_leg_id IS DISTINCT FROM v_quote.shipment_leg_id THEN
    RAISE EXCEPTION USING ERRCODE='23514', MESSAGE='Quote, opportunity, shipment and exact leg scope do not match';
  END IF;
  IF NOT private.krim_has_organization_access(v_user,v_opportunity.customer_organization_id)
     OR NOT private.krim_has_permission(v_user,v_opportunity.customer_organization_id,'quote.update')
     OR NOT private.krim_has_permission(v_user,v_opportunity.customer_organization_id,'shipment.update') THEN
    RAISE EXCEPTION USING ERRCODE='42501', MESSAGE='Customer organisation access plus quote.update and shipment.update permissions are required';
  END IF;
  IF v_opportunity.status<>'open' OR v_opportunity.awarded_partner_organization_id IS NOT NULL
     OR (v_opportunity.response_deadline IS NOT NULL AND v_opportunity.response_deadline<=now()) THEN
    RAISE EXCEPTION USING ERRCODE='55000', MESSAGE='Leg opportunity is no longer open for award';
  END IF;
  IF v_quote.status NOT IN ('submitted','under_review','shortlisted') OR (v_quote.valid_until IS NOT NULL AND v_quote.valid_until<=now()) THEN
    RAISE EXCEPTION USING ERRCODE='55000', MESSAGE='Partner quote is not eligible for award';
  END IF;
  IF EXISTS (SELECT 1 FROM public.krim_organizations o WHERE o.id=v_quote.partner_organization_id AND o.partner_account_mode='development_test') THEN
    RAISE EXCEPTION USING ERRCODE='42501', MESSAGE='Development/test partners cannot receive commercial assignments';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.krim_organizations o WHERE o.id=v_quote.partner_organization_id AND o.status='active'
    AND lower(coalesce(o.organization_type_code,o.organization_type)) IN ('partner','carrier','forwarder','logistics_provider')
    AND o.partner_account_mode='registered_business' AND o.partner_verification_status IN ('verified','approved')
    AND o.partner_lifecycle_status IN ('active','verified')
    AND o.partner_compliance_status IN ('clear','compliant','approved','verified','not_required','not_applicable')) THEN
    RAISE EXCEPTION USING ERRCODE='42501', MESSAGE='Quoted partner is no longer eligible for commercial assignment';
  END IF;
  IF NOT private.krim_partner_compliance_is_current(v_quote.partner_organization_id)
     OR NOT private.krim_partner_capability_covers_shipment_leg(v_quote.partner_organization_id,v_quote.shipment_leg_id) THEN
    RAISE EXCEPTION USING ERRCODE='42501', MESSAGE='Partner compliance or exact-leg capability is no longer current';
  END IF;
  SELECT * INTO v_shipment FROM public.krim_shipments WHERE id=v_quote.shipment_id FOR UPDATE;
  IF NOT FOUND OR v_shipment.customer_organization_id IS DISTINCT FROM v_opportunity.customer_organization_id THEN
    RAISE EXCEPTION USING ERRCODE='23503', MESSAGE='Shipment does not belong to the opportunity customer';
  END IF;
  IF v_shipment.status NOT IN ('draft','quoted','confirmed') THEN RAISE EXCEPTION USING ERRCODE='55000', MESSAGE='Partner award is blocked after shipment execution begins'; END IF;
  SELECT * INTO v_leg FROM public.krim_shipment_legs WHERE id=v_quote.shipment_leg_id AND shipment_id=v_shipment.id FOR UPDATE;
  IF NOT FOUND OR v_leg.leg_plan_item_id IS NULL THEN RAISE EXCEPTION USING ERRCODE='23503', MESSAGE='Award target is not a plan-linked leg of this shipment'; END IF;
  SELECT p.* INTO v_plan FROM public.krim_shipment_leg_plans p
  JOIN public.krim_shipment_leg_plan_items pi ON pi.plan_id=p.id
  WHERE p.shipment_id=v_shipment.id AND p.status='active' AND pi.id=v_leg.leg_plan_item_id
  ORDER BY p.plan_version DESC LIMIT 1 FOR UPDATE OF p;
  IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='55000', MESSAGE='Target leg is not in an active route plan'; END IF;
  SELECT * INTO v_item FROM public.krim_shipment_leg_plan_items WHERE id=v_leg.leg_plan_item_id AND plan_id=v_plan.id FOR KEY SHARE;
  IF NOT FOUND OR v_item.leg_sequence<>v_leg.leg_sequence
     OR v_item.origin_location_id IS DISTINCT FROM v_leg.origin_location_id
     OR v_item.destination_location_id IS DISTINCT FROM v_leg.destination_location_id
     OR v_item.transport_mode_id IS DISTINCT FROM v_leg.transport_mode_id
     OR v_item.requirements IS DISTINCT FROM '{}'::jsonb THEN
    RAISE EXCEPTION USING ERRCODE='23514', MESSAGE='Target leg no longer satisfies the verified plan and cargo-requirement gate';
  END IF;
  IF v_leg.status NOT IN ('planned','unassigned') AND v_leg.assignment_status NOT IN ('planned','unassigned','pending') THEN
    RAISE EXCEPTION USING ERRCODE='55000', MESSAGE='Target leg is no longer available for assignment';
  END IF;
  SELECT * INTO v_assignment FROM public.krim_shipment_partner_assignments WHERE partner_quote_id=v_quote.id ORDER BY created_at DESC LIMIT 1 FOR UPDATE;
  IF FOUND THEN RETURN v_assignment; END IF;
  IF EXISTS (SELECT 1 FROM public.krim_shipment_partner_assignments a WHERE a.shipment_leg_id=v_leg.id AND a.status IN ('offered','accepted','active','completed')) THEN
    RAISE EXCEPTION USING ERRCODE='23505', MESSAGE='This leg already has an active or completed partner assignment';
  END IF;
  UPDATE public.krim_partner_quotes SET status='accepted',accepted_at=now(),updated_at=now() WHERE id=v_quote.id RETURNING * INTO v_quote;
  UPDATE public.krim_partner_quotes SET status='rejected',rejected_at=now(),updated_at=now()
    WHERE opportunity_id=v_opportunity.id AND shipment_leg_id=v_leg.id AND id<>v_quote.id AND status IN ('submitted','under_review','shortlisted');
  UPDATE public.krim_partner_opportunities SET status='awarded',awarded_partner_organization_id=v_quote.partner_organization_id,awarded_at=now(),updated_at=now()
    WHERE id=v_opportunity.id;
  v_number:='KPA-'||to_char(now(),'YYYYMMDD')||'-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,8));
  INSERT INTO public.krim_shipment_partner_assignments(shipment_id,shipment_leg_id,partner_organization_id,partner_quote_id,
    assignment_number,status,offered_at,response_deadline,assigned_by,metadata)
  VALUES(v_shipment.id,v_leg.id,v_quote.partner_organization_id,v_quote.id,v_number,'offered',now(),now()+interval '24 hours',v_user,
    jsonb_build_object('source','customer_leg_partner_quote_award','opportunity_id',v_opportunity.id,'route_plan_id',v_plan.id,'route_plan_item_id',v_item.id))
  RETURNING * INTO v_assignment;
  INSERT INTO public.krim_audit_events(actor_user_id,organization_id,event_type,entity_type,entity_id,source,metadata)
  VALUES(v_user,v_opportunity.customer_organization_id,'partner.leg_quote.awarded','partner_quote',v_quote.id::text,'customer_leg_quote_award',
    jsonb_build_object('opportunity_id',v_opportunity.id,'assignment_id',v_assignment.id,'shipment_id',v_shipment.id,
      'shipment_leg_id',v_leg.id,'partner_organization_id',v_quote.partner_organization_id));
  RETURN v_assignment;
END;
$function$;
REVOKE ALL ON FUNCTION public.krim_award_leg_partner_quote(bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.krim_award_leg_partner_quote(bigint) TO authenticated;
