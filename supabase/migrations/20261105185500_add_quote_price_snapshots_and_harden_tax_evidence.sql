ALTER TABLE public.krim_quotes ADD COLUMN IF NOT EXISTS pricing_snapshot jsonb NOT NULL DEFAULT '{}'::jsonb;
ALTER TABLE public.krim_quotes DROP CONSTRAINT IF EXISTS krim_quotes_pricing_snapshot_object;
ALTER TABLE public.krim_quotes ADD CONSTRAINT krim_quotes_pricing_snapshot_object CHECK (jsonb_typeof(pricing_snapshot)='object');

CREATE OR REPLACE FUNCTION public.krim_admin_record_global_rate_card_evidence(p_rate_card_id bigint, p_provider_organization_id bigint, p_provider_buy_rate numeric, p_platform_fee numeric, p_cost_evidence_reference text, p_cost_evidence_date date, p_tax_treatment text, p_tax_review_reference text)
 RETURNS krim_pricing_rate_cards
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'private', 'pg_temp'
AS $function$
DECLARE
 v_rate public.krim_pricing_rate_cards%rowtype;
 v_mode_id bigint;
 v_org public.krim_organizations%rowtype;
 v_exponent integer;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION USING errcode='28000',message='Authentication required'; END IF;
 IF NOT private.krim_has_permission(auth.uid(),1::bigint,'admin.platform') THEN RAISE EXCEPTION USING errcode='42501',message='Platform administrator permission required'; END IF;
 IF p_rate_card_id IS NULL OR p_provider_organization_id IS NULL OR p_provider_buy_rate IS NULL OR p_provider_buy_rate<=0
    OR p_platform_fee IS NULL OR p_platform_fee<0 OR p_cost_evidence_date IS NULL OR p_cost_evidence_date>current_date
    OR length(btrim(coalesce(p_cost_evidence_reference,'')))<8 OR length(btrim(coalesce(p_tax_review_reference,'')))<8
    OR p_tax_treatment IS NULL OR p_tax_treatment NOT IN ('included_in_rate','not_applicable') THEN
   RAISE EXCEPTION USING errcode='22023',message='Complete the dated carrier cost evidence, platform fee, and qualified tax-treatment review';
 END IF;
 SELECT * INTO v_rate FROM public.krim_pricing_rate_cards WHERE id=p_rate_card_id AND organization_id IS NULL FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION USING errcode='P0002',message='Global draft rate card not found'; END IF;
 IF v_rate.status NOT IN ('draft','suspended') THEN RAISE EXCEPTION USING errcode='22023',message='Commercial evidence can only be recorded against a draft or suspended rate card'; END IF;
 SELECT * INTO v_org FROM public.krim_organizations WHERE id=p_provider_organization_id;
 IF NOT FOUND OR v_org.status<>'active' OR v_org.organization_type NOT IN ('partner','carrier','forwarder')
    OR v_org.partner_account_mode<>'registered_business'
    OR v_org.partner_verification_status NOT IN ('verified','approved')
    OR v_org.partner_lifecycle_status NOT IN ('active','verified')
    OR v_org.partner_compliance_status NOT IN ('clear','compliant','approved','verified','not_required','not_applicable') THEN
   RAISE EXCEPTION USING errcode='42501',message='Provider must be an active, verified registered business with cleared compliance';
 END IF;
 SELECT id INTO v_mode_id FROM public.krim_transport_modes WHERE code=v_rate.transport_mode_code AND is_active IS TRUE;
 IF v_mode_id IS NULL THEN RAISE EXCEPTION USING errcode='22023',message='Transport mode is not active in KRIM configuration'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.krim_partner_capabilities pc WHERE pc.organization_id=p_provider_organization_id
   AND pc.coverage_country_id=v_rate.origin_country_id AND pc.transport_mode_id=v_mode_id
   AND pc.active IS TRUE AND pc.verification_status='verified'
   AND (pc.effective_from IS NULL OR pc.effective_from<=now()) AND (pc.effective_until IS NULL OR pc.effective_until>now()))
 OR NOT EXISTS(SELECT 1 FROM public.krim_partner_capabilities pc WHERE pc.organization_id=p_provider_organization_id
   AND pc.coverage_country_id=v_rate.destination_country_id AND pc.transport_mode_id=v_mode_id
   AND pc.active IS TRUE AND pc.verification_status='verified'
   AND (pc.effective_from IS NULL OR pc.effective_from<=now()) AND (pc.effective_until IS NULL OR pc.effective_until>now())) THEN
   RAISE EXCEPTION USING errcode='42501',message='Provider must hold verified active capabilities for the rate card transport mode in both countries';
 END IF;
 IF NOT EXISTS(SELECT 1 FROM public.krim_currencies WHERE code=v_rate.currency_code AND is_active IS TRUE) THEN
   RAISE EXCEPTION USING errcode='22023',message='Rate card currency is not active';
 END IF;
 v_exponent:=private.krim_currency_minor_unit_exponent(v_rate.currency_code);
 IF round(p_provider_buy_rate+p_platform_fee,v_exponent)<>round(v_rate.base_amount,v_exponent) THEN
   RAISE EXCEPTION USING errcode='22023',message='Provider buy rate plus KRIM platform fee must reconcile exactly to the customer rate card amount';
 END IF;
 UPDATE public.krim_pricing_rate_cards
 SET metadata=(coalesce(metadata,'{}'::jsonb)-'commercial_approval') ||
   jsonb_build_object('commercial_evidence',jsonb_build_object(
    'provider_organization_id',p_provider_organization_id,
    'provider_buy_rate',p_provider_buy_rate,
    'platform_fee',p_platform_fee,
    'currency_code',v_rate.currency_code,
    'cost_evidence_reference',btrim(p_cost_evidence_reference),
    'cost_evidence_date',p_cost_evidence_date,
    'tax_treatment',p_tax_treatment,
    'tax_review_reference',btrim(p_tax_review_reference),
    'recorded_by',auth.uid(),'recorded_at',now()
   )),updated_at=now()
 WHERE id=v_rate.id RETURNING * INTO v_rate;
 INSERT INTO public.krim_audit_events(actor_user_id,event_type,entity_type,entity_id,source,metadata,previous_state,new_state)
 VALUES(auth.uid(),'global_rate_card.commercial_evidence_recorded','krim_pricing_rate_cards',v_rate.id::text,'rate_governance',
   jsonb_build_object('provider_organization_id',p_provider_organization_id,'currency_code',v_rate.currency_code,
   'cost_evidence_date',p_cost_evidence_date,'tax_treatment',p_tax_treatment),NULL,to_jsonb(v_rate));
 RETURN v_rate;
END;
$function$


CREATE OR REPLACE FUNCTION public.krim_admin_approve_global_rate_card(p_rate_card_id bigint, p_approval_reference text)
 RETURNS krim_pricing_rate_cards
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'private', 'pg_temp'
AS $function$
DECLARE
 v_rate public.krim_pricing_rate_cards%rowtype;
 v_evidence jsonb;
 v_market_id bigint;
 v_gate jsonb;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION USING errcode='28000',message='Authentication required'; END IF;
 IF NOT private.krim_has_permission(auth.uid(),1::bigint,'admin.platform') THEN RAISE EXCEPTION USING errcode='42501',message='Platform administrator permission required'; END IF;
 IF p_rate_card_id IS NULL OR length(btrim(coalesce(p_approval_reference,'')))<8 THEN
   RAISE EXCEPTION USING errcode='22023',message='A valid rate card and documented approval reference are required';
 END IF;
 SELECT * INTO v_rate FROM public.krim_pricing_rate_cards WHERE id=p_rate_card_id AND organization_id IS NULL FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION USING errcode='P0002',message='Global rate card not found'; END IF;
 IF v_rate.status NOT IN ('draft','suspended') THEN RAISE EXCEPTION USING errcode='22023',message='Only a draft or suspended rate card can be approved'; END IF;
 v_evidence:=v_rate.metadata->'commercial_evidence';
 IF v_evidence IS NULL OR (v_evidence->>'provider_organization_id') IS NULL
   OR (v_evidence->>'provider_buy_rate')::numeric<=0
   OR (v_evidence->>'platform_fee')::numeric<0
   OR nullif(btrim(v_evidence->>'cost_evidence_reference'),'') IS NULL
   OR nullif(btrim(v_evidence->>'tax_review_reference'),'') IS NULL
   OR v_evidence->>'tax_treatment' IS NULL OR v_evidence->>'tax_treatment' NOT IN ('included_in_rate','not_applicable') THEN
   RAISE EXCEPTION USING errcode='22023',message='Complete verified provider cost and tax-treatment evidence before approval';
 END IF;
 FOR v_market_id IN
   SELECT id FROM public.krim_markets WHERE country_id IN (v_rate.origin_country_id,v_rate.destination_country_id)
     AND is_active IS TRUE AND status='active'
 LOOP
   v_gate:=public.krim_internal_market_activation_gate(v_market_id);
   IF coalesce(v_gate->>'eligible','false')<>'true' THEN
     RAISE EXCEPTION USING errcode='42501',message='Rate approval blocked: both route markets must pass the complete operational and compliance activation gate';
   END IF;
 END LOOP;
 IF (SELECT count(*) FROM public.krim_markets WHERE country_id IN (v_rate.origin_country_id,v_rate.destination_country_id)
       AND is_active IS TRUE AND status='active')<>2 THEN
   RAISE EXCEPTION USING errcode='42501',message='Both origin and destination countries must have an active KRIM market';
 END IF;
 UPDATE public.krim_pricing_rate_cards
 SET metadata=coalesce(metadata,'{}'::jsonb)||jsonb_build_object('commercial_approval',
   jsonb_build_object('approval_reference',btrim(p_approval_reference),'approved_by',auth.uid(),'approved_at',now())),
   updated_at=now()
 WHERE id=v_rate.id RETURNING * INTO v_rate;
 INSERT INTO public.krim_audit_events(actor_user_id,event_type,entity_type,entity_id,source,metadata,previous_state,new_state)
 VALUES(auth.uid(),'global_rate_card.commercially_approved','krim_pricing_rate_cards',v_rate.id::text,'rate_governance',
   jsonb_build_object('approval_reference',btrim(p_approval_reference)),NULL,to_jsonb(v_rate));
 RETURN v_rate;
END;
$function$


CREATE OR REPLACE FUNCTION public.krim_admin_set_global_rate_card_status(p_rate_card_id bigint, p_status text)
 RETURNS krim_pricing_rate_cards
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'private', 'pg_temp'
AS $function$
DECLARE
 v_rate public.krim_pricing_rate_cards%rowtype;
 v_old_state jsonb;
 v_evidence jsonb;
 v_approval jsonb;
 v_mode_id bigint;
 v_market_id bigint;
 v_gate jsonb;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION USING errcode='28000',message='Authentication required'; END IF;
 IF NOT private.krim_has_permission(auth.uid(),1::bigint,'admin.platform') THEN RAISE EXCEPTION USING errcode='42501',message='Platform administrator permission required'; END IF;
 IF p_rate_card_id IS NULL OR p_rate_card_id<=0 OR p_status IS NULL OR p_status NOT IN ('active','suspended','expired') THEN
   RAISE EXCEPTION USING errcode='22023',message='Invalid rate card or target status';
 END IF;
 SELECT * INTO v_rate FROM public.krim_pricing_rate_cards WHERE id=p_rate_card_id AND organization_id IS NULL FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION USING errcode='P0002',message='Global rate card not found'; END IF;
 v_old_state:=to_jsonb(v_rate);
 IF p_status='active' THEN
   IF v_rate.base_amount<=0 OR v_rate.minimum_charge<0 OR v_rate.status='expired'
     OR v_rate.effective_from>now() OR (v_rate.effective_until IS NOT NULL AND v_rate.effective_until<=now()) THEN
     RAISE EXCEPTION USING errcode='22023',message='Rate card must have a positive amount and be within its effective date window before activation';
   END IF;
   v_evidence:=v_rate.metadata->'commercial_evidence';
   v_approval:=v_rate.metadata->'commercial_approval';
   IF v_evidence IS NULL OR v_approval IS NULL
     OR nullif(btrim(v_evidence->>'cost_evidence_reference'),'') IS NULL
     OR nullif(btrim(v_evidence->>'tax_review_reference'),'') IS NULL
     OR v_evidence->>'tax_treatment' IS NULL OR v_evidence->>'tax_treatment' NOT IN ('included_in_rate','not_applicable')
     OR (v_evidence->>'provider_buy_rate') IS NULL OR (v_evidence->>'platform_fee') IS NULL
     OR nullif(btrim(v_approval->>'approval_reference'),'') IS NULL
     OR (v_approval->>'approved_by') IS NULL OR (v_approval->>'approved_at') IS NULL THEN
     RAISE EXCEPTION USING errcode='42501',message='Activation requires documented carrier cost evidence, qualified tax review and explicit commercial approval';
   END IF;
   IF round((v_evidence->>'provider_buy_rate')::numeric+(v_evidence->>'platform_fee')::numeric,
       private.krim_currency_minor_unit_exponent(v_rate.currency_code))
      <>round(v_rate.base_amount,private.krim_currency_minor_unit_exponent(v_rate.currency_code)) THEN
     RAISE EXCEPTION USING errcode='22023',message='Commercial cost and platform fee no longer reconcile to the approved customer rate';
   END IF;
   IF (v_evidence->>'tax_treatment') NOT IN ('included_in_rate','not_applicable') THEN
     RAISE EXCEPTION USING errcode='42501',message='Tax treatment must be explicitly reviewed as included in rate or not applicable';
   END IF;
   IF (v_approval->>'approved_by')::uuid IS NULL OR (v_approval->>'approved_at')::timestamptz IS NULL
      OR (v_approval->>'approved_at')::timestamptz>now() THEN
     RAISE EXCEPTION USING errcode='22023',message='Commercial approval evidence is invalid';
   END IF;
   SELECT id INTO v_mode_id FROM public.krim_transport_modes WHERE code=v_rate.transport_mode_code AND is_active IS TRUE;
   IF v_mode_id IS NULL OR NOT EXISTS(SELECT 1 FROM public.krim_organizations o
     WHERE o.id=(v_evidence->>'provider_organization_id')::bigint AND o.status='active'
       AND o.organization_type IN ('partner','carrier','forwarder') AND o.partner_account_mode='registered_business'
       AND o.partner_verification_status IN ('verified','approved')
       AND o.partner_lifecycle_status IN ('active','verified')
       AND o.partner_compliance_status IN ('clear','compliant','approved','verified','not_required','not_applicable')) THEN
     RAISE EXCEPTION USING errcode='42501',message='The documented provider must remain an active, verified registered business with cleared compliance';
   END IF;
   IF NOT EXISTS(SELECT 1 FROM public.krim_partner_capabilities pc WHERE pc.organization_id=(v_evidence->>'provider_organization_id')::bigint
       AND pc.coverage_country_id=v_rate.origin_country_id AND pc.transport_mode_id=v_mode_id AND pc.active IS TRUE
       AND pc.verification_status='verified' AND (pc.effective_from IS NULL OR pc.effective_from<=now())
       AND (pc.effective_until IS NULL OR pc.effective_until>now()))
     OR NOT EXISTS(SELECT 1 FROM public.krim_partner_capabilities pc WHERE pc.organization_id=(v_evidence->>'provider_organization_id')::bigint
       AND pc.coverage_country_id=v_rate.destination_country_id AND pc.transport_mode_id=v_mode_id AND pc.active IS TRUE
       AND pc.verification_status='verified' AND (pc.effective_from IS NULL OR pc.effective_from<=now())
       AND (pc.effective_until IS NULL OR pc.effective_until>now())) THEN
     RAISE EXCEPTION USING errcode='42501',message='Verified provider capability must cover both countries and the selected transport mode';
   END IF;
   FOR v_market_id IN SELECT id FROM public.krim_markets WHERE country_id IN (v_rate.origin_country_id,v_rate.destination_country_id)
     AND is_active IS TRUE AND status='active'
   LOOP
     v_gate:=public.krim_internal_market_activation_gate(v_market_id);
     IF coalesce(v_gate->>'eligible','false')<>'true' THEN
       RAISE EXCEPTION USING errcode='42501',message='Rate activation blocked: origin and destination market readiness gates must both pass';
     END IF;
   END LOOP;
   IF (SELECT count(*) FROM public.krim_markets WHERE country_id IN (v_rate.origin_country_id,v_rate.destination_country_id)
       AND is_active IS TRUE AND status='active')<>2 THEN
     RAISE EXCEPTION USING errcode='42501',message='Both route markets must be active before a commercial rate can be activated';
   END IF;
   PERFORM pg_advisory_xact_lock(hashtextextended(concat_ws(':',v_rate.origin_country_id,v_rate.destination_country_id,
     v_rate.transport_mode_code,coalesce(v_rate.service_tier,'general'),v_rate.priority),0));
   IF EXISTS(SELECT 1 FROM public.krim_pricing_rate_cards x WHERE x.id<>v_rate.id AND x.organization_id IS NULL AND x.status='active'
      AND x.origin_country_id=v_rate.origin_country_id AND x.destination_country_id=v_rate.destination_country_id
      AND x.transport_mode_code=v_rate.transport_mode_code AND coalesce(x.service_tier,'general')=coalesce(v_rate.service_tier,'general')
      AND x.priority=v_rate.priority AND (x.effective_until IS NULL OR x.effective_until>now())
      AND (v_rate.effective_until IS NULL OR v_rate.effective_until>now())) THEN
     RAISE EXCEPTION USING errcode='23505',message='Another active rate card has the same route, service tier and priority. Suspend it or choose a different priority';
   END IF;
 END IF;
 UPDATE public.krim_pricing_rate_cards SET status=p_status,updated_at=now() WHERE id=v_rate.id RETURNING * INTO v_rate;
 INSERT INTO public.krim_audit_events(actor_user_id,event_type,entity_type,entity_id,source,metadata,previous_state,new_state)
 VALUES(auth.uid(),'global_rate_card.status_changed','krim_pricing_rate_cards',v_rate.id::text,'rate_card',
   jsonb_build_object('previous_status',v_old_state->>'status','new_status',p_status),v_old_state,to_jsonb(v_rate));
 RETURN v_rate;
END;
$function$


CREATE OR REPLACE FUNCTION public.krim_create_tariff_quote(p_shipment_id bigint, p_service_tier text, p_valid_until timestamp with time zone DEFAULT (now() + '7 days'::interval))
 RETURNS krim_quotes
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'private', 'pg_temp'
AS $function$
DECLARE
 v_user_id uuid:=auth.uid();
 v_shipment public.krim_shipments%rowtype;
 v_origin_country_id bigint;
 v_destination_country_id bigint;
 v_mode_code text;
 v_rate public.krim_pricing_rate_cards%rowtype;
 v_amount numeric;
 v_quote public.krim_quotes%rowtype;
BEGIN
 IF v_user_id IS NULL THEN RAISE EXCEPTION USING errcode='28000',message='Authentication required'; END IF;
 IF p_shipment_id IS NULL OR p_shipment_id<=0 THEN RAISE EXCEPTION USING errcode='22023',message='A valid shipment is required'; END IF;
 IF p_service_tier IS NULL OR p_service_tier NOT IN ('surface_express','air_priority','heavy_haul') THEN
   RAISE EXCEPTION USING errcode='22023',message='Unsupported service tier';
 END IF;
 IF p_valid_until IS NULL OR p_valid_until<=now() OR p_valid_until>now()+interval '30 days' THEN
   RAISE EXCEPTION USING errcode='22023',message='Quote validity must be between now and 30 days';
 END IF;
 SELECT * INTO v_shipment FROM public.krim_shipments WHERE id=p_shipment_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION USING errcode='P0002',message='Shipment not found'; END IF;
 IF v_shipment.customer_organization_id IS NULL OR NOT public.krim_has_organization_access(v_user_id,v_shipment.customer_organization_id) THEN
   RAISE EXCEPTION USING errcode='42501',message='Shipment is not accessible to this organization';
 END IF;
 IF NOT public.krim_has_permission(v_user_id,v_shipment.customer_organization_id,'quote.create') THEN
   RAISE EXCEPTION USING errcode='42501',message='Permission denied: quote.create';
 END IF;
 IF v_shipment.status NOT IN ('draft','quoted') OR v_shipment.total_weight_kg IS NULL OR v_shipment.total_weight_kg<=0 THEN
   RAISE EXCEPTION USING errcode='22023',message='Only draft or quoted shipments with positive weight can be quoted';
 END IF;
 SELECT o.country_id,d.country_id INTO v_origin_country_id,v_destination_country_id
 FROM public.krim_locations o JOIN public.krim_locations d ON d.id=v_shipment.destination_location_id
 JOIN public.krim_countries oc ON oc.id=o.country_id AND oc.is_active IS TRUE
 JOIN public.krim_countries dc ON dc.id=d.country_id AND dc.is_active IS TRUE
 JOIN public.krim_markets om ON om.id=o.market_id AND om.country_id=oc.id AND om.is_active IS TRUE AND om.status='active'
 JOIN public.krim_markets dm ON dm.id=d.market_id AND dm.country_id=dc.id AND dm.is_active IS TRUE AND dm.status='active'
 JOIN public.krim_market_settings oms ON oms.market_id=om.id AND oms.setting_key='market_activation' AND oms.is_active IS TRUE AND oms.setting_value->>'status'='active'
 JOIN public.krim_market_settings dms ON dms.market_id=dm.id AND dms.setting_key='market_activation' AND dms.is_active IS TRUE AND dms.setting_value->>'status'='active'
 WHERE o.id=v_shipment.origin_location_id AND o.is_active IS TRUE AND d.is_active IS TRUE;
 IF v_origin_country_id IS NULL OR v_destination_country_id IS NULL THEN
   RAISE EXCEPTION USING errcode='22023',message='Quote blocked: both origin and destination must belong to explicitly activated KRIM markets';
 END IF;
 IF coalesce((public.krim_internal_market_activation_gate((SELECT market_id FROM public.krim_locations WHERE id=v_shipment.origin_location_id))->>'eligible'),'false')<>'true'
   OR coalesce((public.krim_internal_market_activation_gate((SELECT market_id FROM public.krim_locations WHERE id=v_shipment.destination_location_id))->>'eligible'),'false')<>'true' THEN
   RAISE EXCEPTION USING errcode='42501',message='Quote blocked: market readiness and compliance gates have not passed';
 END IF;
 IF nullif(btrim(v_shipment.requested_transport_mode),'') IS NULL THEN
   RAISE EXCEPTION USING errcode='22023',message='Tariff quote blocked: shipment has no recorded transport mode';
 END IF;
 v_mode_code:=CASE v_shipment.requested_transport_mode WHEN 'road' THEN 'ROAD' WHEN 'rail' THEN 'RAIL'
   WHEN 'ocean' THEN 'OCEAN' WHEN 'air' THEN 'AIR' WHEN 'multimodal' THEN 'MULTIMODAL'
   WHEN 'warehouse_transfer' THEN 'WAREHOUSE' WHEN 'specialist' THEN 'SPECIALIST' ELSE NULL END;
 SELECT r.* INTO v_rate FROM public.krim_pricing_rate_cards r
 WHERE r.organization_id IS NULL AND r.origin_country_id=v_origin_country_id AND r.destination_country_id=v_destination_country_id
   AND r.transport_mode_code=v_mode_code AND (r.service_tier=p_service_tier OR r.service_tier IS NULL)
   AND r.status='active' AND r.effective_from<=now() AND (r.effective_until IS NULL OR r.effective_until>now())
   AND r.metadata ? 'commercial_evidence' AND r.metadata ? 'commercial_approval'
   AND r.metadata #>> '{commercial_evidence,tax_treatment}' IN ('included_in_rate','not_applicable')
 ORDER BY CASE WHEN r.service_tier=p_service_tier THEN 0 ELSE 1 END,r.priority ASC,r.updated_at DESC,r.id DESC
 LIMIT 1 FOR SHARE;
 IF NOT FOUND THEN RAISE EXCEPTION USING errcode='P0001',message='Tariff quote unavailable: no active, evidence-backed, commercially approved rate card matches this route and service tier'; END IF;
 v_amount:=CASE v_rate.rate_type WHEN 'flat' THEN v_rate.base_amount WHEN 'per_kg' THEN v_rate.base_amount*v_shipment.total_weight_kg ELSE NULL END;
 IF v_amount IS NULL OR v_amount<=0 THEN RAISE EXCEPTION USING errcode='22023',message='The matching rate card produced an invalid quote amount'; END IF;
 v_amount:=round(greatest(v_amount,v_rate.minimum_charge),private.krim_currency_minor_unit_exponent(v_rate.currency_code));
 IF v_amount<=0 THEN RAISE EXCEPTION USING errcode='22023',message='The calculated tariff must be greater than zero'; END IF;
 SELECT * INTO v_quote FROM public.krim_quotes WHERE shipment_id=p_shipment_id
   AND customer_organization_id=v_shipment.customer_organization_id AND partner_quote_id IS NULL
   AND status='sent' AND valid_until>now() ORDER BY id DESC LIMIT 1 FOR UPDATE;
 IF FOUND THEN RETURN v_quote; END IF;
 INSERT INTO public.krim_quotes(shipment_id,customer_organization_id,amount,currency_code,valid_until,status,pricing_snapshot)
 VALUES(p_shipment_id,v_shipment.customer_organization_id,v_amount,v_rate.currency_code,p_valid_until,'sent',
   jsonb_build_object('source','approved_global_rate_card','rate_card_id',v_rate.id,
     'service_tier',p_service_tier,'transport_mode_code',v_mode_code,'rate_type',v_rate.rate_type,
     'rate_basis_amount',v_rate.base_amount,'minimum_charge',v_rate.minimum_charge,
     'shipment_weight_kg',v_shipment.total_weight_kg,'quoted_amount',v_amount,
     'currency_code',v_rate.currency_code,'tax_treatment',v_rate.metadata #>> '{commercial_evidence,tax_treatment}',
     'rate_effective_from',v_rate.effective_from,'rate_effective_until',v_rate.effective_until,
     'quote_created_at',now()))
 RETURNING * INTO v_quote;
 IF v_shipment.status='draft' THEN
   PERFORM public.krim_transition_shipment(p_shipment_id,'quoted','Tariff quote created from an evidence-backed approved global rate card',
     jsonb_build_object('quote_id',v_quote.id,'rate_card_id',v_rate.id,'service_tier',p_service_tier,
       'transport_mode_code',v_mode_code,'currency_code',v_rate.currency_code,'amount',v_quote.amount,
       'tax_treatment',v_rate.metadata #>> '{commercial_evidence,tax_treatment}'));
 END IF;
 RETURN v_quote;
END;
$function$

