-- Evaluate verified partner capability against one exact shipment leg.
-- This avoids incorrectly requiring a leg-only carrier to cover the full shipment
-- origin/destination and the shipment's legacy single transport mode.
CREATE OR REPLACE FUNCTION private.krim_partner_capability_covers_shipment_leg(
  p_organization_id bigint,
  p_shipment_leg_id bigint
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
  SELECT EXISTS (
    SELECT 1
    FROM public.krim_shipment_legs l
    JOIN public.krim_shipments s ON s.id=l.shipment_id
    JOIN public.krim_locations origin
      ON origin.id=l.origin_location_id AND origin.is_active IS TRUE
    JOIN public.krim_locations destination
      ON destination.id=l.destination_location_id AND destination.is_active IS TRUE
    JOIN public.krim_countries origin_country
      ON origin_country.id=origin.country_id AND origin_country.is_active IS TRUE
    JOIN public.krim_countries destination_country
      ON destination_country.id=destination.country_id AND destination_country.is_active IS TRUE
    JOIN public.krim_transport_modes mode
      ON mode.id=l.transport_mode_id AND mode.is_active IS TRUE
    WHERE l.id=p_shipment_leg_id
      AND p_organization_id IS NOT NULL
      AND s.total_weight_kg IS NOT NULL
      AND s.total_weight_kg>0
      AND EXISTS (
        SELECT 1 FROM public.krim_partner_capabilities pc
        WHERE pc.organization_id=p_organization_id
          AND pc.transport_mode_id=mode.id
          AND pc.coverage_country_id=origin.country_id
          AND pc.active IS TRUE
          AND pc.verification_status='verified'
          AND (pc.effective_from IS NULL OR pc.effective_from<=pg_catalog.now())
          AND (pc.effective_until IS NULL OR pc.effective_until>pg_catalog.now())
          AND (pc.max_weight_kg IS NULL OR pc.max_weight_kg>=s.total_weight_kg)
          AND (nullif(pg_catalog.btrim(pc.coverage_region),'') IS NULL
            OR pg_catalog.lower(pg_catalog.btrim(pc.coverage_region)) IN (
              pg_catalog.lower(origin_country.name),
              pg_catalog.lower(coalesce(origin.state_region,'')),
              pg_catalog.lower(coalesce(origin.region,''))
            ))
      )
      AND EXISTS (
        SELECT 1 FROM public.krim_partner_capabilities pc
        WHERE pc.organization_id=p_organization_id
          AND pc.transport_mode_id=mode.id
          AND pc.coverage_country_id=destination.country_id
          AND pc.active IS TRUE
          AND pc.verification_status='verified'
          AND (pc.effective_from IS NULL OR pc.effective_from<=pg_catalog.now())
          AND (pc.effective_until IS NULL OR pc.effective_until>pg_catalog.now())
          AND (pc.max_weight_kg IS NULL OR pc.max_weight_kg>=s.total_weight_kg)
          AND (nullif(pg_catalog.btrim(pc.coverage_region),'') IS NULL
            OR pg_catalog.lower(pg_catalog.btrim(pc.coverage_region)) IN (
              pg_catalog.lower(destination_country.name),
              pg_catalog.lower(coalesce(destination.state_region,'')),
              pg_catalog.lower(coalesce(destination.region,''))
            ))
      )
  );
$function$;

REVOKE ALL ON FUNCTION private.krim_partner_capability_covers_shipment_leg(bigint,bigint) FROM PUBLIC, anon, authenticated;
