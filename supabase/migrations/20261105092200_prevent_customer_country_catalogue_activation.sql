-- Prevent customer-submitted place data from activating country catalogue records.
-- Country catalogue activation is an administrative market-readiness action, never a shipment side effect.
DO $migration$
DECLARE
  v_oid oid;
  v_definition text;
  v_old text := $old$
  INSERT INTO public.krim_countries(code,name,iso2_code,is_active)
  VALUES (v_origin_country_code,v_origin_country_name,v_origin_country_code,true)
  ON CONFLICT (code) DO UPDATE SET is_active=true
  RETURNING id INTO v_origin_country_id;
  INSERT INTO public.krim_countries(code,name,iso2_code,is_active)
  VALUES (v_destination_country_code,v_destination_country_name,v_destination_country_code,true)
  ON CONFLICT (code) DO UPDATE SET is_active=true
  RETURNING id INTO v_destination_country_id;
$old$;
  v_new text := $new$
  SELECT id INTO v_origin_country_id
  FROM public.krim_countries
  WHERE code=v_origin_country_code;
  IF v_origin_country_id IS NULL THEN
    RAISE EXCEPTION USING errcode='22023',
      message='Origin country is not present in the KRIM country catalogue';
  END IF;

  SELECT id INTO v_destination_country_id
  FROM public.krim_countries
  WHERE code=v_destination_country_code;
  IF v_destination_country_id IS NULL THEN
    RAISE EXCEPTION USING errcode='22023',
      message='Destination country is not present in the KRIM country catalogue';
  END IF;
$new$;
BEGIN
  SELECT p.oid INTO v_oid
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid=p.pronamespace
  WHERE n.nspname='public'
    AND p.proname='krim_create_global_shipment_from_places'
    AND pg_get_function_identity_arguments(p.oid)=
      'p_customer_organization_id bigint, p_origin_place jsonb, p_destination_place jsonb, p_goods_description text, p_total_weight_kg numeric';

  IF v_oid IS NULL THEN
    RAISE EXCEPTION 'Expected five-argument shipment creation function was not found';
  END IF;

  v_definition := pg_get_functiondef(v_oid);
  IF position(v_old IN v_definition)=0 THEN
    RAISE EXCEPTION 'Expected country activation block did not match; migration aborted safely';
  END IF;

  v_definition := replace(v_definition,v_old,v_new);
  EXECUTE v_definition;
END
$migration$;
