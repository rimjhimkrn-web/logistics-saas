-- Require explicit market activation for tariff quotes, matching the booking guard.
-- Country/location presence and krim_markets.status alone do not mean a market is commercially launched.
CREATE OR REPLACE FUNCTION public.krim_create_tariff_quote(
  p_shipment_id bigint,
  p_service_tier text,
  p_valid_until timestamp with time zone DEFAULT (now() + interval '7 days')
)
RETURNS public.krim_quotes
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'private', 'pg_temp'
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_shipment public.krim_shipments%rowtype;
  v_origin_country_id bigint;
  v_destination_country_id bigint;
  v_mode_code text;
  v_rate public.krim_pricing_rate_cards%rowtype;
  v_amount numeric;
  v_quote public.krim_quotes%rowtype;
BEGIN
  IF v_user_id IS NULL THEN RAISE EXCEPTION USING errcode='28000', message='Authentication required'; END IF;
  IF p_shipment_id IS NULL OR p_shipment_id<=0 THEN RAISE EXCEPTION USING errcode='22023', message='A valid shipment is required'; END IF;
  IF p_service_tier IS NULL OR p_service_tier NOT IN ('surface_express','air_priority','heavy_haul') THEN RAISE EXCEPTION USING errcode='22023', message='Unsupported service tier'; END IF;
  IF p_valid_until IS NULL OR p_valid_until<=now() OR p_valid_until>now()+interval '30 days' THEN RAISE EXCEPTION USING errcode='22023', message='Quote validity must be between now and 30 days'; END IF;

  SELECT * INTO v_shipment FROM public.krim_shipments WHERE id=p_shipment_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION USING errcode='P0002', message='Shipment not found'; END IF;
  IF v_shipment.customer_organization_id IS NULL OR NOT public.krim_has_organization_access(v_user_id,v_shipment.customer_organization_id) THEN
    RAISE EXCEPTION USING errcode='42501', message='Shipment is not accessible to this organization';
  END IF;
  IF NOT public.krim_has_permission(v_user_id,v_shipment.customer_organization_id,'quote.create') THEN RAISE EXCEPTION USING errcode='42501', message='Permission denied: quote.create'; END IF;
  IF v_shipment.status NOT IN ('draft','quoted') THEN RAISE EXCEPTION USING errcode='22023', message='Only draft or quoted shipments can be quoted'; END IF;
  IF v_shipment.total_weight_kg IS NULL OR v_shipment.total_weight_kg<=0 THEN RAISE EXCEPTION USING errcode='22023', message='Shipment weight must be greater than zero'; END IF;

  SELECT o.country_id,d.country_id INTO v_origin_country_id,v_destination_country_id
  FROM public.krim_locations o
  JOIN public.krim_locations d ON d.id=v_shipment.destination_location_id
  JOIN public.krim_countries oc ON oc.id=o.country_id AND oc.is_active IS TRUE
  JOIN public.krim_countries dc ON dc.id=d.country_id AND dc.is_active IS TRUE
  JOIN public.krim_markets om ON om.id=o.market_id AND om.country_id=oc.id AND om.is_active IS TRUE AND om.status='active'
  JOIN public.krim_markets dm ON dm.id=d.market_id AND dm.country_id=dc.id AND dm.is_active IS TRUE AND dm.status='active'
  JOIN public.krim_market_settings oms ON oms.market_id=om.id AND oms.setting_key='market_activation' AND oms.is_active IS TRUE AND oms.setting_value->>'status'='active'
  JOIN public.krim_market_settings dms ON dms.market_id=dm.id AND dms.setting_key='market_activation' AND dms.is_active IS TRUE AND dms.setting_value->>'status'='active'
  WHERE o.id=v_shipment.origin_location_id AND o.is_active IS TRUE AND d.is_active IS TRUE;
  IF v_origin_country_id IS NULL OR v_destination_country_id IS NULL THEN
    RAISE EXCEPTION USING errcode='22023', message='Quote blocked: origin and destination must belong to explicitly activated KRIM markets. A listed country or location alone does not establish commercial availability.';
  END IF;

  IF NULLIF(btrim(v_shipment.requested_transport_mode), '') IS NULL THEN
    RAISE EXCEPTION USING errcode='22023', message='Tariff quote blocked: shipment has no recorded transport mode.';
  END IF;

  v_mode_code:=CASE v_shipment.requested_transport_mode
    WHEN 'road' THEN 'ROAD'
    WHEN 'rail' THEN 'RAIL'
    WHEN 'ocean' THEN 'OCEAN'
    WHEN 'air' THEN 'AIR'
    WHEN 'multimodal' THEN 'MULTIMODAL'
    WHEN 'warehouse_transfer' THEN 'WAREHOUSE'
    WHEN 'specialist' THEN 'SPECIALIST'
    ELSE NULL
  END;

  SELECT r.* INTO v_rate FROM public.krim_pricing_rate_cards r
  WHERE r.organization_id IS NULL AND r.origin_country_id=v_origin_country_id AND r.destination_country_id=v_destination_country_id
    AND r.transport_mode_code=v_mode_code AND (r.service_tier=p_service_tier OR r.service_tier IS NULL)
    AND r.status='active' AND r.effective_from<=now() AND (r.effective_until IS NULL OR r.effective_until>now())
  ORDER BY CASE WHEN r.service_tier=p_service_tier THEN 0 ELSE 1 END,r.priority ASC,r.updated_at DESC,r.id DESC
  LIMIT 1 FOR SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION USING errcode='P0001', message='Tariff quote unavailable: no approved active global rate card matches this route and service tier.'; END IF;

  v_amount:=CASE v_rate.rate_type WHEN 'flat' THEN v_rate.base_amount WHEN 'per_kg' THEN v_rate.base_amount*v_shipment.total_weight_kg ELSE NULL END;
  IF v_amount IS NULL OR v_amount<=0 THEN RAISE EXCEPTION USING errcode='22023', message='The matching rate card produced an invalid quote amount'; END IF;
  v_amount:=GREATEST(v_amount,v_rate.minimum_charge);
  IF v_amount<=0 THEN RAISE EXCEPTION USING errcode='22023', message='The calculated tariff must be greater than zero'; END IF;

  SELECT * INTO v_quote FROM public.krim_quotes
  WHERE shipment_id=p_shipment_id AND customer_organization_id=v_shipment.customer_organization_id
    AND partner_quote_id IS NULL AND status='sent' AND valid_until>now()
  ORDER BY id DESC LIMIT 1 FOR UPDATE;
  IF FOUND THEN RETURN v_quote; END IF;

  INSERT INTO public.krim_quotes(shipment_id,customer_organization_id,amount,currency_code,valid_until,status)
  VALUES(p_shipment_id,v_shipment.customer_organization_id,round(v_amount,private.krim_currency_minor_unit_exponent(v_rate.currency_code)),v_rate.currency_code,p_valid_until,'sent')
  RETURNING * INTO v_quote;

  IF v_shipment.status='draft' THEN
    PERFORM public.krim_transition_shipment(p_shipment_id,'quoted','Tariff quote created from an active global rate card',
      jsonb_build_object('quote_id',v_quote.id,'rate_card_id',v_rate.id,'service_tier',p_service_tier,'transport_mode_code',v_mode_code,'requested_transport_mode',v_shipment.requested_transport_mode,'requested_route_type',v_shipment.requested_route_type,'origin_place_label',v_shipment.origin_place_label,'destination_place_label',v_shipment.destination_place_label,'currency_code',v_rate.currency_code,'amount',v_quote.amount));
  END IF;
  RETURN v_quote;
END;
$function$;
