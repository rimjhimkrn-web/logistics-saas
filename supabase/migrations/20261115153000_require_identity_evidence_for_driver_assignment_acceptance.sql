DO $$
DECLARE
  v_def text;
  v_old text := $needle$AND d.document_type='licence_back' AND d.review_status='accepted') THEN RAISE EXCEPTION USING errcode='42501',message='Verified driver profile and independently accepted front/back licence evidence are required';END IF;$needle$;
  v_new text := $replacement$AND d.document_type='licence_back' AND d.review_status='accepted') OR NOT EXISTS(SELECT 1 FROM public.krim_driver_verification_documents d JOIN public.krim_driver_profiles dp ON dp.id=d.profile_id WHERE dp.user_id=v_user AND dp.organization_id=v_assignment.organization_id AND d.document_type='identity_document' AND d.review_status='accepted') THEN RAISE EXCEPTION USING errcode='42501',message='Verified driver profile and independently accepted front/back licence plus identity evidence are required';END IF;$replacement$;
BEGIN
  v_def := pg_get_functiondef('public.krim_driver_accept_assignment(uuid)'::regprocedure);
  IF strpos(v_def, v_old) = 0 THEN
    RAISE EXCEPTION 'Expected assignment evidence guard not found; no function change applied';
  END IF;
  EXECUTE replace(v_def, v_old, v_new);
END;
$$;