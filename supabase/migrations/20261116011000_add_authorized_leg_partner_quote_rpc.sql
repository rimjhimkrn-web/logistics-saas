CREATE OR REPLACE FUNCTION public.krim_submit_leg_partner_quote(
  p_opportunity_id bigint,
  p_amount numeric,
  p_currency_code text DEFAULT 'INR',
  p_valid_until timestamptz DEFAULT NULL,
  p_notes text DEFAULT NULL
)
RETURNS public.krim_partner_quotes
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_user uuid := auth.uid();
  v_partner_ids bigint[];
  v_partner_id bigint;
  v_opportunity public.krim_partner_opportunities%rowtype;
  v_shipment public.krim_shipments%rowtype;
  v_leg public.krim_shipment_legs%rowtype;
  v_plan public.krim_shipment_leg_plans%rowtype;
  v_item public.krim_shipment_leg_plan_items%rowtype;
  v_quote public.krim_partner_quotes%rowtype;
  v_currency text := upper(nullif(btrim(p_currency_code),''));
  v_notes text := nullif(btrim(p_notes),'');
  v_valid_until timestamptz;
  v_quote_number text;
BEGIN
  IF v_user IS NULL THEN RAISE EXCEPTION USING ERRCODE='28000', MESSAGE='Authentication required'; END IF;
  IF p_opportunity_id IS NULL OR p_opportunity_id<=0 THEN RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='A valid leg opportunity is required'; END IF;
  IF p_amount IS NULL OR p_amount<=0 OR p_amount>1000000000000 OR p_amount::text IN ('NaN','Infinity','-Infinity') THEN
    RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='Quote amount must be finite, positive and within the supported range';
  END IF;
  IF v_currency IS NULL OR v_currency !~ '^[A-Z]{3}$' THEN RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='A valid three-letter currency code is required'; END IF;
  IF v_notes IS NOT NULL AND char_length(v_notes)>1000 THEN RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='Quote notes must be 1,000 characters or fewer'; END IF;

  SELECT array_agg(DISTINCT o.id ORDER BY o.id) INTO v_partner_ids
  FROM public.krim_organization_members m
  JOIN public.krim_organizations o ON o.id=m.organization_id
  WHERE m.user_id=v_user AND m.status='active' AND o.status='active'
    AND lower(coalesce(o.organization_type_code,o.organization_type)) IN ('partner','carrier','forwarder','logistics_provider')
    AND o.partner_account_mode='registered_business'
    AND o.partner_verification_status IN ('verified','approved')
    AND o.partner_lifecycle_status IN ('active','verified')
    AND o.partner_compliance_status IN ('clear','compliant','approved','verified','not_required','not_applicable')
    AND EXISTS (SELECT 1 FROM public.krim_partner_capabilities pc
      WHERE pc.organization_id=o.id AND pc.active IS TRUE AND pc.verification_status='verified'
        AND (pc.effective_from IS NULL OR pc.effective_from<=now())
        AND (pc.effective_until IS NULL OR pc.effective_until>now()));
  IF coalesce(cardinality(v_partner_ids),0)=0 THEN
    RAISE EXCEPTION USING ERRCODE='42501', MESSAGE='Only verified registered-business partners with current approved capability may submit leg quotes';
  ELSIF cardinality(v_partner_ids)>1 THEN
    RAISE EXCEPTION USING ERRCODE='42501', MESSAGE='This account is linked to multiple eligible partner organisations; select one through KRIM support before quoting';
  END IF;
  v_partner_id:=v_partner_ids[1];
  IF NOT private.krim_has_permission(v_user,v_partner_id,'quote.create') THEN
    RAISE EXCEPTION USING ERRCODE='42501', MESSAGE='Permission denied: quote.create';
  END IF;
  IF NOT private.krim_partner_compliance_is_current(v_partner_id) THEN
    RAISE EXCEPTION USING ERRCODE='42501', MESSAGE='Partner compliance evidence is not current';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.krim_currencies c WHERE c.code=v_currency AND c.is_active IS TRUE) THEN
    RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='Currency is not active in KRIM configuration';
  END IF;

  SELECT * INTO v_opportunity FROM public.krim_partner_opportunities
  WHERE id=p_opportunity_id AND shipment_leg_id IS NOT NULL AND status='open'
    AND (response_deadline IS NULL OR response_deadline>now())
    AND awarded_partner_organization_id IS NULL FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='P0002', MESSAGE='Open leg opportunity not found or response deadline has passed'; END IF;
  IF v_opportunity.customer_organization_id=v_partner_id THEN
    RAISE EXCEPTION USING ERRCODE='42501', MESSAGE='A customer organisation cannot quote on its own shipment';
  END IF;
  SELECT * INTO v_shipment FROM public.krim_shipments WHERE id=v_opportunity.shipment_id FOR UPDATE;
  IF NOT FOUND OR v_shipment.customer_organization_id IS DISTINCT FROM v_opportunity.customer_organization_id THEN
    RAISE EXCEPTION USING ERRCODE='23503', MESSAGE='Opportunity shipment and customer organisation do not match';
  END IF;
  IF v_shipment.status NOT IN ('draft','quoted','confirmed') THEN RAISE EXCEPTION USING ERRCODE='55000', MESSAGE='Leg quote submission is blocked after shipment execution begins'; END IF;
  SELECT * INTO v_leg FROM public.krim_shipment_legs WHERE id=v_opportunity.shipment_leg_id AND shipment_id=v_shipment.id FOR UPDATE;
  IF NOT FOUND OR v_leg.leg_plan_item_id IS NULL THEN RAISE EXCEPTION USING ERRCODE='23503', MESSAGE='Opportunity is not bound to a plan-linked shipment leg'; END IF;
  SELECT p.* INTO v_plan FROM public.krim_shipment_leg_plans p
  JOIN public.krim_shipment_leg_plan_items pi ON pi.plan_id=p.id
  WHERE p.shipment_id=v_shipment.id AND p.status='active' AND pi.id=v_leg.leg_plan_item_id
  ORDER BY p.plan_version DESC LIMIT 1 FOR UPDATE OF p;
  IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='55000', MESSAGE='Leg does not belong to the active route plan'; END IF;
  SELECT * INTO v_item FROM public.krim_shipment_leg_plan_items WHERE id=v_leg.leg_plan_item_id AND plan_id=v_plan.id FOR KEY SHARE;
  IF NOT FOUND OR v_item.leg_sequence<>v_leg.leg_sequence
     OR v_item.origin_location_id IS DISTINCT FROM v_leg.origin_location_id
     OR v_item.destination_location_id IS DISTINCT FROM v_leg.destination_location_id
     OR v_item.transport_mode_id IS DISTINCT FROM v_leg.transport_mode_id THEN
    RAISE EXCEPTION USING ERRCODE='23514', MESSAGE='Shipment leg no longer matches the active route-plan item';
  END IF;
  IF v_item.requirements IS DISTINCT FROM '{}'::jsonb THEN
    RAISE EXCEPTION USING ERRCODE='55000', MESSAGE='This leg has special cargo requirements that need a verified requirement-to-capability review before partner quoting';
  END IF;
  IF NOT private.krim_partner_capability_covers_shipment_leg(v_partner_id,v_leg.id) THEN
    RAISE EXCEPTION USING ERRCODE='42501', MESSAGE='Verified partner capability does not cover this exact leg mode, route countries and shipment weight';
  END IF;
  v_valid_until:=coalesce(p_valid_until,v_opportunity.response_deadline,now()+interval '7 days');
  IF v_opportunity.response_deadline IS NOT NULL AND v_valid_until>v_opportunity.response_deadline THEN v_valid_until:=v_opportunity.response_deadline; END IF;
  IF v_valid_until<=now() THEN RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='Quote validity must be in the future and within the opportunity deadline'; END IF;

  SELECT * INTO v_quote FROM public.krim_partner_quotes
  WHERE opportunity_id=v_opportunity.id AND partner_organization_id=v_partner_id
    AND shipment_leg_id=v_leg.id AND status IN ('submitted','under_review','shortlisted')
  ORDER BY created_at DESC LIMIT 1 FOR UPDATE;
  IF FOUND THEN
    UPDATE public.krim_partner_quotes SET amount=p_amount,currency_code=v_currency,valid_until=v_valid_until,
      status='submitted',submitted_at=now(),notes=v_notes,
      pricing_snapshot=jsonb_build_object('amount',p_amount,'currency_code',v_currency,'method','partner_leg_submitted_bid',
        'opportunity_number',v_opportunity.opportunity_number,'shipment_leg_id',v_leg.id,'submitted_at',now()),
      metadata=coalesce(metadata,'{}'::jsonb)||jsonb_build_object('source','partner_leg_marketplace','last_updated_by',v_user),
      updated_at=now() WHERE id=v_quote.id RETURNING * INTO v_quote;
  ELSE
    v_quote_number:='KPLQ-'||to_char(now(),'YYYYMMDD')||'-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,8));
    INSERT INTO public.krim_partner_quotes(opportunity_id,shipment_id,partner_organization_id,quote_number,amount,currency_code,
      valid_until,status,submitted_at,notes,pricing_snapshot,metadata,shipment_leg_id)
    VALUES(v_opportunity.id,v_shipment.id,v_partner_id,v_quote_number,p_amount,v_currency,v_valid_until,'submitted',now(),v_notes,
      jsonb_build_object('amount',p_amount,'currency_code',v_currency,'method','partner_leg_submitted_bid',
        'opportunity_number',v_opportunity.opportunity_number,'shipment_leg_id',v_leg.id,'submitted_at',now()),
      jsonb_build_object('source','partner_leg_marketplace','submitted_by',v_user),v_leg.id)
    RETURNING * INTO v_quote;
  END IF;
  INSERT INTO public.krim_audit_events(actor_user_id,organization_id,event_type,entity_type,entity_id,source,metadata)
  VALUES(v_user,v_partner_id,'partner.leg_quote.submitted','partner_quote',v_quote.id::text,'partner_leg_marketplace',
    jsonb_build_object('opportunity_id',v_opportunity.id,'shipment_id',v_shipment.id,'shipment_leg_id',v_leg.id,'currency_code',v_currency));
  RETURN v_quote;
END;
$function$;
REVOKE ALL ON FUNCTION public.krim_submit_leg_partner_quote(bigint,numeric,text,timestamptz,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.krim_submit_leg_partner_quote(bigint,numeric,text,timestamptz,text) TO authenticated;
