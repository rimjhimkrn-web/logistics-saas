-- PROPOSED ONLY — do not apply until the staging positive/negative tenant tests pass.
-- Restores the exact browser permission required by public/partner/submit-quote.html.
-- The function body was reviewed in both environments on 2026-11-24.
-- Staging additionally enforces private.krim_partner_compliance_is_current().
-- This migration changes EXECUTE ACL only; it does not alter function logic or data.

DO $guard$
DECLARE
  v_oid oid;
  v_definition text;
BEGIN
  SELECT p.oid, pg_get_functiondef(p.oid)
    INTO v_oid, v_definition
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
    AND p.proname = 'krim_submit_partner_quote'
    AND pg_get_function_identity_arguments(p.oid) =
      'p_opportunity_id bigint, p_amount numeric, p_currency_code text, p_valid_until timestamp with time zone, p_notes text';

  IF v_oid IS NULL THEN
    RAISE EXCEPTION 'Expected public.krim_submit_partner_quote(bigint,numeric,text,timestamptz,text) overload not found';
  END IF;

  IF NOT (SELECT prosecdef FROM pg_proc WHERE oid = v_oid) THEN
    RAISE EXCEPTION 'Unexpected security mode: quote submission function is not SECURITY DEFINER';
  END IF;

  IF v_definition NOT LIKE '%auth.uid()%'
     OR v_definition NOT LIKE '%private.krim_has_permission%'
     OR v_definition NOT LIKE '%quote.create%'
     OR v_definition NOT LIKE '%private.krim_partner_compliance_is_current%'
     OR v_definition NOT LIKE '%private.krim_partner_capability_covers_shipment%'
     OR v_definition NOT LIKE '%registered_business%'
     OR v_definition NOT LIKE '%partner_verification_status%'
     OR v_definition NOT LIKE '%FOR UPDATE%'
  THEN
    RAISE EXCEPTION 'Function authorization/tenant guard fingerprint differs from the reviewed staging definition; refusing ACL change';
  END IF;
END;
$guard$;

REVOKE ALL ON FUNCTION public.krim_submit_partner_quote(bigint,numeric,text,timestamp with time zone,text)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.krim_submit_partner_quote(bigint,numeric,text,timestamp with time zone,text)
  TO authenticated;

DO $verify$
DECLARE
  v_oid oid := 'public.krim_submit_partner_quote(bigint,numeric,text,timestamp with time zone,text)'::regprocedure;
BEGIN
  IF NOT has_function_privilege('authenticated', v_oid, 'EXECUTE') THEN
    RAISE EXCEPTION 'authenticated EXECUTE was not granted';
  END IF;
  IF has_function_privilege('anon', v_oid, 'EXECUTE') THEN
    RAISE EXCEPTION 'anon must not have EXECUTE';
  END IF;
  IF EXISTS (
    SELECT 1
    FROM pg_proc p, LATERAL aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
    WHERE p.oid = v_oid AND a.grantee = 0 AND a.privilege_type = 'EXECUTE'
  ) THEN
    RAISE EXCEPTION 'PUBLIC must not have EXECUTE';
  END IF;
END;
$verify$;
