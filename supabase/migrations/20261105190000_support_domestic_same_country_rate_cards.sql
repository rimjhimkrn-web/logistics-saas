-- Step 3 correction: allow same-country domestic commercial lanes.
-- A domestic lane requires one distinct country/market gate; a cross-border
-- lane requires two. This migration changes no existing rate-card data.
--
-- NOTE: This file is committed as a pending migration candidate. It was not
-- applied to production because the Supabase migration action was safety-blocked.

DO $migration$
DECLARE
  v_definition text;
  v_oid oid;
BEGIN
  v_oid := to_regprocedure('public.krim_admin_create_global_rate_card(bigint,bigint,text,text,text,numeric,text,numeric,timestamp with time zone,timestamp with time zone,integer)');
  IF v_oid IS NULL THEN RAISE EXCEPTION 'Expected global rate-card creation function is missing'; END IF;
  v_definition := pg_get_functiondef(v_oid);
  IF position(' OR p_origin_country_id=p_destination_country_id' in v_definition)=0 THEN
    RAISE EXCEPTION 'Could not locate the domestic-lane restriction in rate-card creation function; no change applied';
  END IF;
  v_definition := replace(v_definition,' OR p_origin_country_id=p_destination_country_id','');
  EXECUTE v_definition;
END
$migration$;

DO $migration$
DECLARE
  v_definition text;
  v_oid oid;
BEGIN
  v_oid := to_regprocedure('public.krim_admin_approve_global_rate_card(bigint,text)');
  IF v_oid IS NULL THEN RAISE EXCEPTION 'Expected global rate-card approval function is missing'; END IF;
  v_definition := pg_get_functiondef(v_oid);
  IF position(')<>2 THEN' in v_definition)=0 THEN
    RAISE EXCEPTION 'Could not locate the two-market restriction in rate-card approval function; no change applied';
  END IF;
  v_definition := replace(v_definition,
    ')<>2 THEN',
    ')<>(SELECT count(DISTINCT country_id) FROM (VALUES (v_rate.origin_country_id),(v_rate.destination_country_id)) AS required(country_id)) THEN');
  EXECUTE v_definition;
END
$migration$;

DO $migration$
DECLARE
  v_definition text;
  v_oid oid;
BEGIN
  v_oid := to_regprocedure('public.krim_admin_set_global_rate_card_status(bigint,text)');
  IF v_oid IS NULL THEN RAISE EXCEPTION 'Expected global rate-card status function is missing'; END IF;
  v_definition := pg_get_functiondef(v_oid);
  IF position(')<>2 THEN' in v_definition)=0 THEN
    RAISE EXCEPTION 'Could not locate the two-market restriction in rate-card status function; no change applied';
  END IF;
  v_definition := replace(v_definition,
    ')<>2 THEN',
    ')<>(SELECT count(DISTINCT country_id) FROM (VALUES (v_rate.origin_country_id),(v_rate.destination_country_id)) AS required(country_id)) THEN');
  EXECUTE v_definition;
END
$migration$;
