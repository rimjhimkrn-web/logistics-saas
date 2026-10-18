-- Prevent customer quotes from being generated using hardcoded, unapproved rates.
-- Re-enable tariff quoting only after approved rate-card matching and pricing calculations
-- have been implemented and tested against the configured KRIM rate-card schema.

CREATE OR REPLACE FUNCTION public.krim_create_tariff_quote(
  p_shipment_id bigint,
  p_service_tier text,
  p_valid_until timestamp with time zone DEFAULT (now() + interval '7 days')
)
RETURNS public.krim_quotes
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_shipment public.krim_shipments%rowtype;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  SELECT *
    INTO v_shipment
    FROM public.krim_shipments
   WHERE id = p_shipment_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Shipment not found';
  END IF;

  IF v_shipment.customer_organization_id IS NULL THEN
    RAISE EXCEPTION 'Shipment has no customer organization';
  END IF;

  IF NOT public.krim_has_organization_access(auth.uid(), v_shipment.customer_organization_id) THEN
    RAISE EXCEPTION 'Organization access denied';
  END IF;

  IF NOT public.krim_has_permission(auth.uid(), v_shipment.customer_organization_id, 'quote.create') THEN
    RAISE EXCEPTION 'Permission denied: quote.create';
  END IF;

  IF v_shipment.total_weight_kg IS NULL OR v_shipment.total_weight_kg <= 0 THEN
    RAISE EXCEPTION 'Shipment weight must be greater than zero';
  END IF;

  IF p_service_tier IS NULL OR p_service_tier NOT IN ('surface_express', 'air_priority', 'heavy_haul') THEN
    RAISE EXCEPTION 'Unsupported service tier';
  END IF;

  IF p_valid_until IS NULL OR p_valid_until <= now() THEN
    RAISE EXCEPTION 'Quote validity must be in the future';
  END IF;

  RAISE EXCEPTION 'Tariff quote unavailable: no approved active rate card is configured. Ask an authorized pricing administrator to configure and approve a rate card before quoting.';
END;
$function$;
