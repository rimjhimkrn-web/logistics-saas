-- Revalidate partner commercial eligibility at the exact moment a customer
-- accepts a quote. An assignment accepted earlier must not remain sufficient
-- after the partner organisation is suspended or its capability is withdrawn.
-- Apply only after migration-history reconciliation and staging tests.

DO $migration$
DECLARE
  v_def text;
  v_old_decl text := $old$v_partner_quote public.krim_partner_quotes%ROWTYPE;$old$;
  v_new_decl text := $new$v_partner_quote public.krim_partner_quotes%ROWTYPE;$new$;
  v_old_guard text := $old$  IF NOT FOUND THEN
    RAISE EXCEPTION 'Linked partner offer is missing, expired or not eligible';
  END IF;$old$;
  v_new_guard text := $new$  IF NOT FOUND THEN
    RAISE EXCEPTION 'Linked partner offer is missing, expired or not eligible';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.krim_organizations o
    WHERE o.id = v_partner_quote.partner_organization_id
      AND o.status = 'active'
      AND o.partner_account_mode = 'registered_business'
      AND o.partner_lifecycle_status IN ('approved', 'active')
      AND o.partner_verification_status = 'verified'
      AND o.partner_compliance_status = 'compliant'
      AND private.krim_partner_capability_covers_shipment(
        v_partner_quote.partner_organization_id,
        v_shipment.id
      )
  ) THEN
    RAISE EXCEPTION 'Partner organisation or verified capability is no longer commercially eligible';
  END IF;$new$;
BEGIN
  SELECT pg_get_functiondef(
    'public.krim_accept_global_quote(bigint)'::regprocedure
  ) INTO v_def;

  IF position('Partner organisation or verified capability is no longer commercially eligible' IN v_def) > 0 THEN
    RETURN;
  END IF;

  IF position(v_old_decl IN v_def) = 0 THEN
    RAISE EXCEPTION 'Expected partner quote declaration not found; refusing unsafe patch';
  END IF;
  IF position(v_old_guard IN v_def) = 0 THEN
    RAISE EXCEPTION 'Expected linked partner quote guard not found; refusing unsafe patch';
  END IF;

  v_def := replace(v_def, v_old_decl, v_new_decl);
  v_def := replace(v_def, v_old_guard, v_new_guard);
  EXECUTE v_def;
END
$migration$;
