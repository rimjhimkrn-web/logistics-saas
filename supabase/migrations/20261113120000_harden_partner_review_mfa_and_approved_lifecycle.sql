-- Harden partner governance RPCs at the database boundary.
-- Verification queue/review must require AAL2 even when called directly,
-- not only through the MFA-gated administrator UI.
-- Approved business verification and approved compliance review both use
-- partner_lifecycle_status='approved'; capability review must accept that state.

DO $migration$
DECLARE
  v_sig text;
  v_def text;
  v_anchor text := $anchor$  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION USING errcode='28000', message='Authentication required';
  END IF;$anchor$;
  v_guard text := $guard$  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION USING errcode='28000', message='Authentication required';
  END IF;
  IF coalesce(auth.jwt()->>'aal','aal1') <> 'aal2' THEN
    RAISE EXCEPTION USING errcode='42501', message='Multi-factor authentication required';
  END IF;$guard$;
BEGIN
  FOREACH v_sig IN ARRAY ARRAY[
    'public.krim_admin_list_partner_verification_cases()',
    'public.krim_admin_review_partner_verification(bigint,text,text)'
  ] LOOP
    SELECT pg_get_functiondef(v_sig::regprocedure) INTO v_def;
    IF position('Multi-factor authentication required' IN v_def)>0 THEN
      CONTINUE;
    END IF;
    IF position(v_anchor IN v_def)=0 THEN
      RAISE EXCEPTION 'Expected authentication guard not found in %; refusing unsafe patch',v_sig;
    END IF;
    v_def:=replace(v_def,v_anchor,v_guard);
    EXECUTE v_def;
  END LOOP;
END
$migration$;

DO $migration$
DECLARE
  v_def text;
  v_old text := $old$v_org_lifecycle<>'active'$old$;
  v_new text := $new$v_org_lifecycle NOT IN ('active','approved')$new$;
BEGIN
  SELECT pg_get_functiondef('public.krim_admin_review_partner_capability(bigint,text,text)'::regprocedure)
    INTO v_def;
  IF position(v_new IN v_def)>0 THEN RETURN; END IF;
  IF position(v_old IN v_def)=0 THEN
    RAISE EXCEPTION 'Expected capability lifecycle guard not found; refusing unsafe patch';
  END IF;
  EXECUTE replace(v_def,v_old,v_new);
END
$migration$;

-- Private business/compliance evidence previews are also AAL2-only for admins.
DROP POLICY IF EXISTS krim_partner_verification_admin_read ON storage.objects;
CREATE POLICY krim_partner_verification_admin_read
ON storage.objects FOR SELECT TO authenticated
USING (
  bucket_id='krim-partner-verification'
  AND coalesce((SELECT auth.jwt()->>'aal'),'aal1')='aal2'
  AND private.krim_has_permission((SELECT auth.uid()),1::bigint,'admin.platform')
);
