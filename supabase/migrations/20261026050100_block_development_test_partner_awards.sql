-- Prevent development/test partner organizations from being awarded live freight.
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
    AND p.proname = 'krim_award_partner_quote'
    AND pg_get_function_identity_arguments(p.oid) = 'p_partner_quote_id bigint';

  IF v_signature IS NULL THEN
    RAISE EXCEPTION 'Expected public.krim_award_partner_quote function was not found';
  END IF;

  v_definition := pg_get_functiondef(v_signature);
  IF position('Development/test partners cannot be awarded commercial shipments' IN v_definition) > 0 THEN
    RAISE NOTICE 'Development/test partner award guard already present; no change needed';
    RETURN;
  END IF;

  v_updated := replace(
    v_definition,
    E'  SELECT * INTO v_assignment\n  FROM public.krim_shipment_partner_assignments',
    E'  IF EXISTS (\n    SELECT 1 FROM public.krim_organizations o\n    WHERE o.id = v_quote.partner_organization_id\n      AND COALESCE(o.partner_account_mode, '''') = ''development_test''\n  ) THEN\n    RAISE EXCEPTION USING errcode=''42501'', message=''Development/test partners cannot be awarded commercial shipments'';\n  END IF;\n\n  SELECT * INTO v_assignment\n  FROM public.krim_shipment_partner_assignments'
  );

  IF v_updated = v_definition THEN
    RAISE EXCEPTION 'Could not safely locate assignment lookup; function was not changed';
  END IF;

  EXECUTE v_updated;
END
$migration$;
