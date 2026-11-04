-- Require an MFA-verified administrator for partner verification queue access,
-- organisation-level review decisions and private verification document reads.
DO $migration$
DECLARE
 v_def text;
 v_old_list text := $old$  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION USING errcode='28000', message='Authentication required';
  END IF;
  IF NOT private.krim_has_permission(auth.uid(), 1::bigint, 'admin.platform') THEN$old$;
 v_old_review text := $old$  IF v_user_id IS NULL THEN
    RAISE EXCEPTION USING errcode='28000', message='Authentication required';
  END IF;
  IF NOT private.krim_has_permission(v_user_id, 1::bigint, 'admin.platform') THEN$old$;
 v_new_list text := $new$  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION USING errcode='28000', message='Authentication required';
  END IF;
  IF coalesce(auth.jwt()->>'aal','aal1') <> 'aal2' THEN
    RAISE EXCEPTION USING errcode='42501', message='Multi-factor authentication required';
  END IF;
  IF NOT private.krim_has_permission(auth.uid(), 1::bigint, 'admin.platform') THEN$new$;
 v_new_review text := $new$  IF v_user_id IS NULL THEN
    RAISE EXCEPTION USING errcode='28000', message='Authentication required';
  END IF;
  IF coalesce(auth.jwt()->>'aal','aal1') <> 'aal2' THEN
    RAISE EXCEPTION USING errcode='42501', message='Multi-factor authentication required';
  END IF;
  IF NOT private.krim_has_permission(v_user_id, 1::bigint, 'admin.platform') THEN$new$;
BEGIN
 SELECT pg_get_functiondef('public.krim_admin_list_partner_verification_cases()'::regprocedure) INTO v_def;
 IF position(v_new_list in v_def)=0 THEN
  IF position(v_old_list in v_def)=0 THEN RAISE EXCEPTION 'Verification list authorization anchor not found'; END IF;
  EXECUTE replace(v_def,v_old_list,v_new_list);
 END IF;
 SELECT pg_get_functiondef('public.krim_admin_review_partner_verification(bigint,text,text)'::regprocedure) INTO v_def;
 IF position(v_new_review in v_def)=0 THEN
  IF position(v_old_review in v_def)=0 THEN RAISE EXCEPTION 'Verification review authorization anchor not found'; END IF;
  EXECUTE replace(v_def,v_old_review,v_new_review);
 END IF;
 DROP POLICY IF EXISTS krim_partner_verification_admin_read ON storage.objects;
 CREATE POLICY krim_partner_verification_admin_read ON storage.objects FOR SELECT TO authenticated
 USING (bucket_id='krim-partner-verification'
 AND coalesce(auth.jwt()->>'aal','aal1')='aal2'
 AND private.krim_has_permission((SELECT auth.uid()),1::bigint,'admin.platform'));
END
$migration$;