-- Implement deterministic tariff quoting from approved active global rate cards.
-- No rate card is seeded or activated here; commercial rates must be approved separately.

CREATE OR REPLACE FUNCTION public.krim_create_tariff_quote(
  p_shipment_id bigint,
  p_service_tier text,
  p_valid_until timestamptz DEFAULT (now() + interval '7 days')
)
RETURNS public.krim_quotes
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
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
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION USING errcode = '28000', message = 'Authentication required';
  END IF;

  IF p_shipment_id IS NULL OR p_shipment_id <= 0 THEN
    RAISE EXCEPTION USING errcode = '22023', message = 'A valid shipment is required';
  END IF;

  IF p_service_tier IS NULL OR p_service_tier NOT IN ('surface_express', 'air_priority', 'heavy_haul') THEN
    RAISE EXCEPTION USING errcode = '22023', message = 'Unsupported service tier';
  END IF;

  IF p_valid_until IS NULL OR p_valid_until <= now() OR p_valid_until > now() + interval '30 days' THEN
    RAISE EXCEPTION USING errcode = '22023', message = 'Quote validity must be between now and 30 days';
  END IF;

  SELECT * INTO v_shipment
  FROM public.krim_shipments
  WHERE id = p_shipment_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION USING errcode = 'P0002', message = 'Shipment not found';
  END IF;

  IF v_shipment.customer_organization_id IS NULL
     OR NOT public.krim_has_organization_access(v_user_id, v_shipment.customer_organization_id) THEN
    RAISE EXCEPTION USING errcode = '42501', message = 'Shipment is not accessible to this organization';
  END IF;

  IF NOT public.krim_has_permission(v_user_id, v_shipment.customer_organization_id, 'quote.create') THEN
    RAISE EXCEPTION USING errcode = '42501', message = 'Permission denied: quote.create';
  END IF;

  IF v_shipment.status NOT IN ('draft', 'quoted') THEN
    RAISE EXCEPTION USING errcode = '22023', message = 'Only draft or quoted shipments can be quoted';
  END IF;

  IF v_shipment.total_weight_kg IS NULL OR v_shipment.total_weight_kg <= 0 THEN
    RAISE EXCEPTION USING errcode = '22023', message = 'Shipment weight must be greater than zero';
  END IF;

  SELECT o.country_id, d.country_id
    INTO v_origin_country_id, v_destination_country_id
  FROM public.krim_locations o
  JOIN public.krim_locations d ON d.id = v_shipment.destination_location_id
  WHERE o.id = v_shipment.origin_location_id
    AND o.is_active IS TRUE
    AND d.is_active IS TRUE;

  IF v_origin_country_id IS NULL OR v_destination_country_id IS NULL THEN
    RAISE EXCEPTION USING errcode = '22023', message = 'Active origin and destination locations with country mappings are required';
  END IF;

  v_mode_code := CASE p_service_tier
    WHEN 'surface_express' THEN 'ROAD'
    WHEN 'air_priority' THEN 'AIR'
    WHEN 'heavy_haul' THEN 'ROAD'
  END;

  -- Global platform rates are separate from carrier-specific partner bids.
  SELECT * INTO v_rate
  FROM public.krim_pricing_rate_cards r
  WHERE r.organization_id IS NULL
    AND r.origin_country_id = v_origin_country_id
    AND r.destination_country_id = v_destination_country_id
    AND r.transport_mode_code = v_mode_code
    AND r.status = 'active'
    AND r.effective_from <= now()
    AND (r.effective_until IS NULL OR r.effective_until > now())
  ORDER BY r.priority ASC, r.updated_at DESC, r.id DESC
  LIMIT 1
  FOR SHARE;

  IF NOT FOUND THEN
    RAISE EXCEPTION USING errcode = 'P0001',
      message = 'Tariff quote unavailable: no approved active global rate card matches this route and service tier.';
  END IF;

  v_amount := CASE v_rate.rate_type
    WHEN 'flat' THEN v_rate.base_amount
    WHEN 'per_kg' THEN v_rate.base_amount * v_shipment.total_weight_kg
    ELSE NULL
  END;

  IF v_amount IS NULL OR v_amount <= 0 THEN
    RAISE EXCEPTION USING errcode = '22023', message = 'The matching rate card produced an invalid quote amount';
  END IF;

  v_amount := GREATEST(v_amount, v_rate.minimum_charge);

  IF v_amount <= 0 THEN
    RAISE EXCEPTION USING errcode = '22023', message = 'The calculated tariff must be greater than zero';
  END IF;

  -- Avoid duplicate unexpired platform tariff quotations.
  SELECT * INTO v_quote
  FROM public.krim_quotes
  WHERE shipment_id = p_shipment_id
    AND customer_organization_id = v_shipment.customer_organization_id
    AND partner_quote_id IS NULL
    AND status = 'sent'
    AND valid_until > now()
  ORDER BY id DESC
  LIMIT 1
  FOR UPDATE;

  IF FOUND THEN
    RETURN v_quote;
  END IF;

  INSERT INTO public.krim_quotes (
    shipment_id, customer_organization_id, amount, currency_code, valid_until, status
  )
  VALUES (
    p_shipment_id, v_shipment.customer_organization_id,
    round(v_amount, 2), v_rate.currency_code, p_valid_until, 'sent'
  )
  RETURNING * INTO v_quote;

  IF v_shipment.status = 'draft' THEN
    PERFORM public.krim_transition_shipment(
      p_shipment_id,
      'quoted',
      'Tariff quote created from an active global rate card',
      jsonb_build_object(
        'quote_id', v_quote.id,
        'rate_card_id', v_rate.id,
        'service_tier', p_service_tier,
        'transport_mode_code', v_mode_code,
        'currency_code', v_rate.currency_code,
        'amount', v_quote.amount
      )
    );
  END IF;

  RETURN v_quote;
END;
$function$;
