-- Corrects function qualification: COALESCE is a PostgreSQL special expression,
-- not a pg_catalog-qualified callable routine. Keep all other identifiers schema-qualified.
DO $$
DECLARE
  v_definition text;
  v_signature regprocedure;
BEGIN
  FOREACH v_signature IN ARRAY ARRAY[
    'public.krim_internal_submit_delivery_pod(bigint,text,text,text,jsonb)'::regprocedure,
    'public.krim_internal_verify_delivery_pod(bigint,uuid,text,text)'::regprocedure,
    'public.krim_driver_submit_delivery_pod(uuid,text,text,text)'::regprocedure
  ]
  LOOP
    SELECT pg_get_functiondef(v_signature) INTO v_definition;
    v_definition := replace(v_definition, 'pg_catalog.coalesce', 'coalesce');
    EXECUTE v_definition;
  END LOOP;
END;
$$;
