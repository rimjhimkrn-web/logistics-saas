-- Persist quote expiry when an acceptance is attempted after its validity window.
-- Do not raise after the UPDATE: an exception would roll the UPDATE back.
DO $migration$
DECLARE
  v_oid oid;
  v_definition text;
  v_old text := $old$RAISE EXCEPTION 'Quote has expired';$old$;
  v_new text := $new$v_quote.status := 'expired';
v_quote.updated_at := now();
RETURN v_quote;$new$;
BEGIN
  SELECT p.oid INTO v_oid
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid=p.pronamespace
  WHERE n.nspname='public'
    AND p.proname='krim_accept_global_quote'
    AND pg_get_function_identity_arguments(p.oid)='p_quote_id bigint';
  IF v_oid IS NULL THEN
    RAISE EXCEPTION 'Expected global quote acceptance function was not found';
  END IF;
  v_definition := pg_get_functiondef(v_oid);
  IF position(v_new IN v_definition)>0 THEN
    NULL;
  ELSIF position(v_old IN v_definition)>0 THEN
    v_definition := replace(v_definition,v_old,v_new);
    EXECUTE v_definition;
  ELSE
    RAISE EXCEPTION 'Expected quote expiry exception was not found; migration aborted safely';
  END IF;
END
$migration$;
