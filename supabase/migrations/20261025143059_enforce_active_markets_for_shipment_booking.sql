-- Require both shipment endpoints to belong to an explicitly activated operational market.
-- Catalogue presence alone must not enable bookings in a country that KRIM has not activated.
CREATE OR REPLACE FUNCTION public.krim_create_global_shipment_from_places(
  p_customer_organization_id bigint,
  p_origin_place jsonb,
  p_destination_place jsonb,
  p_goods_description text,
  p_total_weight_kg numeric,
  p_transport_mode text,
  p_route_type text
)
RETURNS public.krim_shipments
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'private', 'pg_temp'
AS $function$
DECLARE
  v_shipment public.krim_shipments%ROWTYPE;
  v_origin_code text;
  v_destination_code text;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION USING errcode='28000', message='Authentication required';
  END IF;

  IF p_route_type IS NULL OR p_route_type NOT IN (
    'door_to_door','airport_to_airport','port_to_port','terminal_to_terminal',
    'warehouse_to_warehouse','domestic','cross_border','first_last_mile',
    'multimodal_end_to_end'
  ) THEN
    RAISE EXCEPTION USING errcode='22023', message='Choose a supported route type';
  END IF;

  v_origin_code := upper(btrim(coalesce(p_origin_place->>'country_code','')));
  v_destination_code := upper(btrim(coalesce(p_destination_place->>'country_code','')));

  IF v_origin_code !~ '^[A-Z]{2}$' OR v_destination_code !~ '^[A-Z]{2}$' THEN
    RAISE EXCEPTION USING errcode='22023', message='Both selected places must include valid country codes';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.krim_markets m
    JOIN public.krim_countries c ON c.id = m.country_id
    JOIN public.krim_market_settings s
      ON s.market_id = m.id
     AND s.setting_key = 'market_activation'
     AND s.is_active = true
     AND s.setting_value->>'status' = 'active'
    WHERE upper(m.code) = v_origin_code
      AND m.is_active = true
      AND m.status = 'active'
      AND c.is_active = true
  ) THEN
    RAISE EXCEPTION USING errcode='22023',
      message='Origin country is not enabled for operational bookings in KRIM';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.krim_markets m
    JOIN public.krim_countries c ON c.id = m.country_id
    JOIN public.krim_market_settings s
      ON s.market_id = m.id
     AND s.setting_key = 'market_activation'
     AND s.is_active = true
     AND s.setting_value->>'status' = 'active'
    WHERE upper(m.code) = v_destination_code
      AND m.is_active = true
      AND m.status = 'active'
      AND c.is_active = true
  ) THEN
    RAISE EXCEPTION USING errcode='22023',
      message='Destination country is not enabled for operational bookings in KRIM';
  END IF;

  IF p_route_type = 'domestic' AND v_origin_code <> v_destination_code THEN
    RAISE EXCEPTION USING errcode='22023',
      message='Domestic route type requires origin and destination in the same country';
  END IF;

  IF p_route_type = 'cross_border' AND v_origin_code = v_destination_code THEN
    RAISE EXCEPTION USING errcode='22023',
      message='Cross-border route type requires origin and destination in different countries';
  END IF;

  v_shipment := public.krim_create_global_shipment_from_places(
    p_customer_organization_id,
    p_origin_place,
    p_destination_place,
    p_goods_description,
    p_total_weight_kg,
    p_transport_mode
  );

  UPDATE public.krim_shipments
  SET requested_route_type = p_route_type
  WHERE id = v_shipment.id
  RETURNING * INTO v_shipment;

  RETURN v_shipment;
END;
$function$;
