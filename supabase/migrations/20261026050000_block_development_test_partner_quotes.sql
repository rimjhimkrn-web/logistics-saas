-- Keep the live database guard reproducible in repository migration history.
-- Idempotent: safely skips if the guard is already present.
DO $migration$
DECLARE
  v_definition text;
  v_updated text;
  v_signature oid;
BEGIN
  SELECT p.oid INTO v_signature
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
    AND p.proname = 'krim_submit_partner_quote'
    AND pg_get_function_identity_arguments(p.oid) =
      'p_opportunity_id bigint, p_amount numeric, p_currency_code text, p_valid_until timestamp with time zone, p_notes text';

  IF v_signature IS NULL THEN
    RAISE EXCEPTION 'Expected public.krim_submit_partner_quote function was not found';
  END IF;

  v_definition := pg_get_functiondef(v_signature);
  IF position('development_test' IN v_definition) > 0 THEN
    RAISE NOTICE 'Development/test partner bid guard already present; no change needed';
    RETURN;
  END IF;

  v_updated := replace(
    v_definition,
    E'    AND o.status = ''active''\n    AND o.partner_verification_status',
    E'    AND o.status = ''active''\n    AND COALESCE(o.partner_account_mode, '''') <> ''development_test''\n    AND o.partner_verification_status'
  );

  IF v_updated = v_definition THEN
    RAISE EXCEPTION 'Could not safely locate partner eligibility check; function was not changed';
  END IF;

  EXECUTE v_updated;
END
$migration$;
