-- KRIM partner verification authorization hardening
-- Applied to Supabase project ebltviniygljwwseplph on 2026-11-04.
-- Ensure only an active registered-business partner can submit business
-- verification, including direct RPC calls to either onboarding function.
-- Ensure even a platform administrator cannot commercially approve a
-- development-test or individual-interest account.

DO $krim$
DECLARE
  v_oid oid;
  v_def text;
  v_new text;
  v_anchor text;
  v_replacement text;
BEGIN
  SELECT p.oid INTO v_oid
  FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
  WHERE n.nspname='public'
    AND p.proname='krim_submit_partner_onboarding_global_multi_v1';
  IF v_oid IS NULL THEN RAISE EXCEPTION 'Multi-category partner onboarding function not found'; END IF;

  v_def := pg_get_functiondef(v_oid);
  v_anchor := $a$ IF auth.uid() IS NULL THEN
   RAISE EXCEPTION USING errcode='28000', message='Authentication required';
 END IF;$a$;
  v_replacement := $b$ IF auth.uid() IS NULL THEN
   RAISE EXCEPTION USING errcode='28000', message='Authentication required';
 END IF;

 IF p_document_paths IS NULL OR cardinality(p_document_paths) < 1
    OR p_document_paths[1] !~* ('^[0-9]+/' || auth.uid()::text || '/[^/]+\.(pdf|png|jpe?g)$') THEN
   RAISE EXCEPTION USING errcode='22023', message='A valid registration document path for your account is required';
 END IF;

 IF NOT EXISTS (
   SELECT 1
   FROM public.krim_organization_members m
   JOIN public.krim_organizations o ON o.id=m.organization_id
   WHERE m.user_id=auth.uid()
     AND m.status='active'
     AND m.organization_id=split_part(p_document_paths[1], '/', 1)::bigint
     AND lower(coalesce(o.organization_type_code,o.organization_type)) IN ('partner','carrier','warehouse','forwarder')
     AND o.status='active'
     AND o.partner_account_mode='registered_business'
 ) THEN
   RAISE EXCEPTION USING errcode='42501', message='Registered-business partner mode and an active matching organization membership are required before submitting verification';
 END IF;$b$;
  IF position(v_anchor in v_def)=0 THEN
    RAISE EXCEPTION 'Expected multi-category authentication guard not found';
  END IF;
  v_new := replace(v_def,v_anchor,v_replacement);
  IF v_new=v_def THEN RAISE EXCEPTION 'Multi-category guard was not inserted'; END IF;
  EXECUTE v_new;

  SELECT p.oid INTO v_oid
  FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
  WHERE n.nspname='public'
    AND p.proname='krim_submit_partner_onboarding_global_v2';
  IF v_oid IS NULL THEN RAISE EXCEPTION 'Lower-level partner onboarding function not found'; END IF;

  v_def := pg_get_functiondef(v_oid);
  v_anchor := $c$      AND o.organization_type IN ('partner','carrier','warehouse','forwarder')
      AND o.status='active'
$c$;
  v_replacement := $d$      AND o.organization_type IN ('partner','carrier','warehouse','forwarder')
      AND o.status='active'
      AND o.partner_account_mode='registered_business'
$d$;
  IF position(v_anchor in v_def)=0 THEN
    RAISE EXCEPTION 'Expected lower-level organization authorization predicate not found';
  END IF;
  v_new := replace(v_def,v_anchor,v_replacement);
  IF v_new=v_def THEN RAISE EXCEPTION 'Lower-level guard was not inserted'; END IF;
  EXECUTE v_new;
END
$krim$;

DO $krim$
DECLARE
  v_oid oid;
  v_def text;
  v_new text;
  v_anchor text;
  v_replacement text;
BEGIN
  SELECT p.oid INTO v_oid
  FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
  WHERE n.nspname='public'
    AND p.proname='krim_admin_review_partner_verification';
  IF v_oid IS NULL THEN RAISE EXCEPTION 'Partner verification review function not found'; END IF;

  v_def := pg_get_functiondef(v_oid);
  v_anchor := $a$  IF v_decision='approved' THEN
    IF v_org_type NOT IN ('partner','carrier','warehouse','forwarder') OR v_org_status <> 'active' THEN$a$;
  v_replacement := $b$  IF v_decision='approved' THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.krim_organizations o
      WHERE o.id=v_org_id AND o.partner_account_mode='registered_business'
    ) THEN
      RAISE EXCEPTION USING errcode='23514', message='Only a registered-business partner account can be approved for commercial access';
    END IF;
    IF v_org_type NOT IN ('partner','carrier','warehouse','forwarder') OR v_org_status <> 'active' THEN$b$;
  IF position(v_anchor in v_def)=0 THEN
    RAISE EXCEPTION 'Expected partner verification approval guard not found';
  END IF;
  v_new := replace(v_def,v_anchor,v_replacement);
  IF v_new=v_def THEN RAISE EXCEPTION 'Registered-business approval guard was not inserted'; END IF;
  EXECUTE v_new;
END
$krim$;
