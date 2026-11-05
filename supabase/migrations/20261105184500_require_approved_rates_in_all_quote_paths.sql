-- Ensure every pricing path consumes only commercially evidenced and approved cards.
-- Quote orchestration also fails closed when either market is not activated.

CREATE OR REPLACE FUNCTION public.krim_internal_calculate_quote_pricing(p_orchestration_run_id bigint)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public','private','pg_temp'
AS $function$
DECLARE
 v_run public.krim_quote_orchestration_runs%rowtype;
 v_origin_country bigint;
 v_destination_country bigint;
 v_origin_market bigint;
 v_destination_market bigint;
 v_origin_gate jsonb;
 v_destination_gate jsonb;
 v_rate public.krim_pricing_rate_cards%rowtype;
 v_weight numeric;
 v_subtotal numeric;
 v_currency text;
 v_calc_id bigint;
 v_calc_number text;
 v_tier text;
 v_tax_treatment text;
BEGIN
 SELECT * INTO v_run FROM public.krim_quote_orchestration_runs WHERE id=p_orchestration_run_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Quote orchestration run not found'; END IF;
 IF v_run.status NOT IN ('queued','running') THEN
   RETURN jsonb_build_object('status',v_run.status,'run_id',p_orchestration_run_id);
 END IF;
 v_weight:=nullif((v_run.input_snapshot->>'cargo_weight')::numeric,0);
 v_tier:=nullif(v_run.input_snapshot->>'service_tier','');
 IF v_weight IS NULL OR v_weight<=0 THEN
   UPDATE public.krim_quote_orchestration_runs SET status='failed',stage='pricing',
     result_summary=jsonb_build_object('reason','valid_cargo_weight_required'),completed_at=now()
   WHERE id=p_orchestration_run_id;
   RETURN jsonb_build_object('status','failed','reason','valid_cargo_weight_required');
 END IF;
 SELECT l.country_id,l.market_id INTO v_origin_country,v_origin_market
 FROM public.krim_locations l WHERE l.id=(v_run.input_snapshot->>'origin_location_id')::bigint AND l.is_active IS TRUE;
 SELECT l.country_id,l.market_id INTO v_destination_country,v_destination_market
 FROM public.krim_locations l WHERE l.id=(v_run.input_snapshot->>'destination_location_id')::bigint AND l.is_active IS TRUE;
 IF v_origin_country IS NULL OR v_destination_country IS NULL OR v_origin_market IS NULL OR v_destination_market IS NULL THEN
   UPDATE public.krim_quote_orchestration_runs SET status='queued',stage='pricing',
     result_summary=jsonb_build_object('status','awaiting_market_activation','reason','active_locations_and_market_mappings_required')
   WHERE id=p_orchestration_run_id;
   RETURN jsonb_build_object('status','awaiting_market_activation','run_id',p_orchestration_run_id);
 END IF;
 v_origin_gate:=public.krim_internal_market_activation_gate(v_origin_market);
 v_destination_gate:=public.krim_internal_market_activation_gate(v_destination_market);
 IF coalesce(v_origin_gate->>'eligible','false')<>'true' OR coalesce(v_destination_gate->>'eligible','false')<>'true'
   OR NOT EXISTS(SELECT 1 FROM public.krim_market_settings s WHERE s.market_id=v_origin_market
       AND s.setting_key='market_activation' AND s.is_active IS TRUE AND s.setting_value->>'status'='active')
   OR NOT EXISTS(SELECT 1 FROM public.krim_market_settings s WHERE s.market_id=v_destination_market
       AND s.setting_key='market_activation' AND s.is_active IS TRUE AND s.setting_value->>'status'='active') THEN
   UPDATE public.krim_quote_orchestration_runs SET status='queued',stage='pricing',
     result_summary=jsonb_build_object('status','awaiting_market_activation',
       'origin_market_gate',v_origin_gate,'destination_market_gate',v_destination_gate)
   WHERE id=p_orchestration_run_id;
   RETURN jsonb_build_object('status','awaiting_market_activation','run_id',p_orchestration_run_id);
 END IF;
 SELECT * INTO v_rate FROM public.krim_pricing_rate_cards r
 WHERE r.organization_id IS NULL
   AND r.transport_mode_code=upper(v_run.input_snapshot->>'transport_mode_code')
   AND (r.service_tier=v_tier OR r.service_tier IS NULL)
   AND r.status='active' AND r.effective_from<=now() AND (r.effective_until IS NULL OR r.effective_until>now())
   AND r.origin_country_id=v_origin_country AND r.destination_country_id=v_destination_country
   AND r.metadata ? 'commercial_evidence' AND r.metadata ? 'commercial_approval'
   AND r.metadata #>> '{commercial_evidence,tax_treatment}' IN ('included_in_rate','not_applicable')
 ORDER BY CASE WHEN r.service_tier=v_tier THEN 0 ELSE 1 END,r.priority,r.effective_from DESC,r.id DESC
 LIMIT 1 FOR SHARE;
 IF NOT FOUND THEN
   UPDATE public.krim_quote_orchestration_runs SET status='queued',stage='pricing',
     result_summary=jsonb_build_object('status','awaiting_rate','reason','no_active_commercially_approved_rate_card')
   WHERE id=p_orchestration_run_id;
   RETURN jsonb_build_object('status','awaiting_rate','run_id',p_orchestration_run_id,
     'reason','no_active_commercially_approved_rate_card');
 END IF;
 v_subtotal:=CASE WHEN v_rate.rate_type='per_kg'
   THEN greatest(v_rate.base_amount*v_weight,v_rate.minimum_charge)
   WHEN v_rate.rate_type='flat' THEN greatest(v_rate.base_amount,v_rate.minimum_charge)
   ELSE NULL END;
 IF v_subtotal IS NULL OR v_subtotal<=0 THEN
   UPDATE public.krim_quote_orchestration_runs SET status='failed',stage='pricing',
     result_summary=jsonb_build_object('reason','invalid_rate_calculation'),completed_at=now()
   WHERE id=p_orchestration_run_id;
   RETURN jsonb_build_object('status','failed','reason','invalid_rate_calculation');
 END IF;
 v_currency:=upper(v_rate.currency_code);
 v_subtotal:=round(v_subtotal,private.krim_currency_minor_unit_exponent(v_currency));
 v_tax_treatment:=v_rate.metadata #>> '{commercial_evidence,tax_treatment}';
 v_calc_number:='PCR-'||to_char(clock_timestamp(),'YYYYMMDDHH24MISSMS')||'-'||upper(substr(md5(p_orchestration_run_id::text||clock_timestamp()::text),1,8));
 INSERT INTO public.krim_pricing_calculation_runs(
   organization_id,customer_organization_id,status,input_snapshot,rate_selection,charge_breakdown,tax_breakdown,fx_snapshot,
   subtotal,tax_total,total,currency_code,calculated_at
 ) VALUES(
   (v_run.input_snapshot->>'customer_organization_id')::bigint,
   (v_run.input_snapshot->>'customer_organization_id')::bigint,
   'calculated',v_run.input_snapshot,
   jsonb_build_array(jsonb_build_object('rate_card_id',v_rate.id,'rate_type',v_rate.rate_type,
     'base_amount',v_rate.base_amount,'minimum_charge',v_rate.minimum_charge,'currency_code',v_currency,'service_tier',v_rate.service_tier)),
   jsonb_build_array(jsonb_build_object('component','transport_base','amount',v_subtotal,'currency_code',v_currency)),
   jsonb_build_array(jsonb_build_object('tax_treatment',v_tax_treatment,'additional_tax_added',0,
     'tax_included_in_rate',v_tax_treatment='included_in_rate')),
   '{}'::jsonb,v_subtotal,0,v_subtotal,v_currency,now()
 ) RETURNING id INTO v_calc_id;
 UPDATE public.krim_quote_orchestration_runs SET status='completed',stage='pricing',
   result_summary=jsonb_build_object('status','calculated','pricing_calculation_run_id',v_calc_id,
     'subtotal',v_subtotal,'tax_total',0,'total',v_subtotal,'currency_code',v_currency,
     'rate_card_id',v_rate.id,'tax_treatment',v_tax_treatment),completed_at=now()
 WHERE id=p_orchestration_run_id;
 RETURN jsonb_build_object('status','calculated','run_id',p_orchestration_run_id,
   'pricing_calculation_run_id',v_calc_id,'total',v_subtotal,'currency_code',v_currency,
   'tax_treatment',v_tax_treatment);
END;
$function$;

CREATE OR REPLACE FUNCTION public.krim_create_tariff_quote(
 p_shipment_id bigint,p_service_tier text,p_valid_until timestamp with time zone DEFAULT (now()+interval '7 days')
) RETURNS public.krim_quotes
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public','private','pg_temp'
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
 INSERT INTO public.krim_quotes(shipment_id,customer_organization_id,amount,currency_code,valid_until,status)
 VALUES(p_shipment_id,v_shipment.customer_organization_id,v_amount,v_rate.currency_code,p_valid_until,'sent')
 RETURNING * INTO v_quote;
 IF v_shipment.status='draft' THEN
   PERFORM public.krim_transition_shipment(p_shipment_id,'quoted','Tariff quote created from an evidence-backed approved global rate card',
     jsonb_build_object('quote_id',v_quote.id,'rate_card_id',v_rate.id,'service_tier',p_service_tier,
       'transport_mode_code',v_mode_code,'currency_code',v_rate.currency_code,'amount',v_quote.amount,
       'tax_treatment',v_rate.metadata #>> '{commercial_evidence,tax_treatment}'));
 END IF;
 RETURN v_quote;
END;
$function$;

REVOKE ALL ON FUNCTION public.krim_internal_calculate_quote_pricing(bigint) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.krim_create_tariff_quote(bigint,text,timestamp with time zone) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.krim_create_tariff_quote(bigint,text,timestamp with time zone) TO authenticated;
