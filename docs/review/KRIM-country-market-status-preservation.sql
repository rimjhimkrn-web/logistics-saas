-- REVIEW DRAFT ONLY — NOT APPLIED TO PRODUCTION
-- KRIM Global Logistics OS
-- Purpose: prevent customer-selected geographic places from enabling a country.
-- Global coverage principle:
--   * Country/location master data can represent a global destination.
--   * Country/market operational availability must be explicitly managed by KRIM.
--   * A booking request must not mutate the market launch switch.
--
-- Preconditions before deployment:
-- 1. Review country/market semantics with the platform administrator.
-- 2. Apply to an isolated staging project first.
-- 3. Test active country remains active after booking.
-- 4. Test inactive country remains inactive after booking.
-- 5. Test a new country record is created inactive and a location request does not enable a market.
-- 6. Test organization isolation, function grants, idempotency and rollback.
-- 7. Re-run Supabase security/performance advisors and inspect all dependent overloads.
--
-- This function replacement deliberately preserves existing function signature,
-- SECURITY DEFINER setting, pinned search_path and authorization checks.
-- It does NOT by itself enforce service availability for a requested route.
-- Quote/bid creation must independently verify serviceable lanes, approved tariffs,
-- and eligible partners before promising or dispatching service.

BEGIN;

CREATE OR REPLACE FUNCTION public.krim_create_global_shipment_from_places(p_customer_organization_id bigint, p_origin_place jsonb, p_destination_place jsonb, p_goods_description text, p_total_weight_kg numeric)
 RETURNS krim_shipments
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'private', 'pg_temp'
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_origin_country_id bigint;
  v_destination_country_id bigint;
  v_origin_location_id bigint;
  v_destination_location_id bigint;
  v_origin_country_code text;
  v_destination_country_code text;
  v_origin_country_name text;
  v_destination_country_name text;
  v_origin_city text;
  v_destination_city text;
  v_origin_region text;
  v_destination_region text;
  v_origin_lat numeric;
  v_origin_lon numeric;
  v_destination_lat numeric;
  v_destination_lon numeric;
  v_shipment public.krim_shipments%ROWTYPE;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION USING errcode='28000', message='Authentication required';
  END IF;
  IF p_customer_organization_id IS NULL
     OR NOT private.krim_has_organization_access(v_user_id,p_customer_organization_id) THEN
    RAISE EXCEPTION USING errcode='42501', message='Organization access denied';
  END IF;
  IF NOT private.krim_has_permission(v_user_id,p_customer_organization_id,'shipment.create') THEN
    RAISE EXCEPTION USING errcode='42501', message='Permission denied: shipment.create';
  END IF;
  IF p_goods_description IS NULL OR length(btrim(p_goods_description))=0 OR length(p_goods_description)>500 THEN
    RAISE EXCEPTION USING errcode='22023', message='Goods description is required and must be 500 characters or fewer';
  END IF;
  IF p_total_weight_kg IS NULL OR p_total_weight_kg<=0 OR p_total_weight_kg>100000000 THEN
    RAISE EXCEPTION USING errcode='22023', message='Shipment weight must be greater than zero and within the supported range';
  END IF;
  IF p_origin_place IS NULL OR p_destination_place IS NULL THEN
    RAISE EXCEPTION USING errcode='22023', message='Choose both locations from global search results';
  END IF;

  v_origin_city := left(btrim(coalesce(p_origin_place->>'city',p_origin_place->>'name','')),160);
  v_destination_city := left(btrim(coalesce(p_destination_place->>'city',p_destination_place->>'name','')),160);
  v_origin_region := left(btrim(coalesce(p_origin_place->>'state','')),160);
  v_destination_region := left(btrim(coalesce(p_destination_place->>'state','')),160);
  v_origin_country_code := upper(btrim(coalesce(p_origin_place->>'country_code','')));
  v_destination_country_code := upper(btrim(coalesce(p_destination_place->>'country_code','')));
  v_origin_country_name := left(btrim(coalesce(p_origin_place->>'country','')),160);
  v_destination_country_name := left(btrim(coalesce(p_destination_place->>'country','')),160);

  IF v_origin_city='' OR v_destination_city='' OR v_origin_country_name='' OR v_destination_country_name=''
     OR v_origin_country_code !~ '^[A-Z]{2}$' OR v_destination_country_code !~ '^[A-Z]{2}$' THEN
    RAISE EXCEPTION USING errcode='22023', message='Choose valid named places with country information from global search results';
  END IF;

  BEGIN
    v_origin_lat := (p_origin_place->>'latitude')::numeric;
    v_origin_lon := (p_origin_place->>'longitude')::numeric;
    v_destination_lat := (p_destination_place->>'latitude')::numeric;
    v_destination_lon := (p_destination_place->>'longitude')::numeric;
  EXCEPTION WHEN OTHERS THEN
    RAISE EXCEPTION USING errcode='22023', message='Selected locations must include valid map coordinates';
  END;
  IF v_origin_lat IS NULL OR v_destination_lat IS NULL OR v_origin_lon IS NULL OR v_destination_lon IS NULL
     OR v_origin_lat NOT BETWEEN -90 AND 90 OR v_destination_lat NOT BETWEEN -90 AND 90
     OR v_origin_lon NOT BETWEEN -180 AND 180 OR v_destination_lon NOT BETWEEN -180 AND 180 THEN
    RAISE EXCEPTION USING errcode='22023', message='Selected location coordinates are outside the valid range';
  END IF;
  IF v_origin_lat=v_destination_lat AND v_origin_lon=v_destination_lon THEN
    RAISE EXCEPTION USING errcode='22023', message='Origin and destination must be different places';
  END IF;

  INSERT INTO public.krim_countries(code,name,iso2_code,is_active)
  -- New place submissions add a country master record without enabling market operations.
  VALUES (v_origin_country_code,v_origin_country_name,v_origin_country_code,false)
  -- A user-submitted location must never change an existing country's activation status.
  ON CONFLICT (code) DO UPDATE SET code=EXCLUDED.code
  RETURNING id INTO v_origin_country_id;
  INSERT INTO public.krim_countries(code,name,iso2_code,is_active)
  -- New place submissions add a country master record without enabling market operations.
  VALUES (v_destination_country_code,v_destination_country_name,v_destination_country_code,false)
  -- A user-submitted location must never change an existing country's activation status.
  ON CONFLICT (code) DO UPDATE SET code=EXCLUDED.code
  RETURNING id INTO v_destination_country_id;

  SELECT id INTO v_origin_location_id
  FROM public.krim_locations
  WHERE country_id=v_origin_country_id AND lower(coalesce(city,''))=lower(v_origin_city)
    AND lower(coalesce(state_region,''))=lower(v_origin_region) AND is_active=true
  ORDER BY id LIMIT 1;
  IF v_origin_location_id IS NULL THEN
    INSERT INTO public.krim_locations(country_id,city,state_region,latitude,longitude,location_code,location_type,is_active)
    VALUES (v_origin_country_id,v_origin_city,nullif(v_origin_region,''),v_origin_lat,v_origin_lon,
      left(v_origin_country_code || '-' || regexp_replace(upper(v_origin_city),'[^A-Z0-9]+','-','g'),80),
      'customer_requested',true)
    RETURNING id INTO v_origin_location_id;
  END IF;

  SELECT id INTO v_destination_location_id
  FROM public.krim_locations
  WHERE country_id=v_destination_country_id AND lower(coalesce(city,''))=lower(v_destination_city)
    AND lower(coalesce(state_region,''))=lower(v_destination_region) AND is_active=true
  ORDER BY id LIMIT 1;
  IF v_destination_location_id IS NULL THEN
    INSERT INTO public.krim_locations(country_id,city,state_region,latitude,longitude,location_code,location_type,is_active)
    VALUES (v_destination_country_id,v_destination_city,nullif(v_destination_region,''),v_destination_lat,v_destination_lon,
      left(v_destination_country_code || '-' || regexp_replace(upper(v_destination_city),'[^A-Z0-9]+','-','g'),80),
      'customer_requested',true)
    RETURNING id INTO v_destination_location_id;
  END IF;

  RETURN public.krim_create_global_shipment(
    p_customer_organization_id,
    v_origin_location_id,
    v_destination_location_id,
    p_goods_description,
    p_total_weight_kg
  );
END;
$function$
;

COMMIT;

-- Post-deployment verification (run separately, using a controlled staging fixture):
-- SELECT code, name, is_active FROM public.krim_countries WHERE code IN ('<active-fixture>','<inactive-fixture>');
-- Confirm no customer booking can flip is_active from false to true.
