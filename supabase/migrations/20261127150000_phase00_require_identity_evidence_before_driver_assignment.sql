-- Phase 00: require identity evidence before a driver can be assigned to a road leg.
DO $migration$
DECLARE
  v_definition text;
  v_old text := $old$IF NOT FOUND OR NOT EXISTS(SELECT 1 FROM public.krim_driver_verification_documents d WHERE d.profile_id=v_profile.id AND d.document_type='licence_front' AND d.review_status='accepted') OR NOT EXISTS(SELECT 1 FROM public.krim_driver_verification_documents d WHERE d.profile_id=v_profile.id AND d.document_type='licence_back' AND d.review_status='accepted') THEN RAISE EXCEPTION USING errcode='42501',message='Driver must have active membership, verified profile and independently accepted front/back licence evidence';END IF;$old$;
  v_new text := $new$IF NOT FOUND OR NOT EXISTS(SELECT 1 FROM public.krim_driver_verification_documents d WHERE d.profile_id=v_profile.id AND d.document_type='licence_front' AND d.review_status='accepted') OR NOT EXISTS(SELECT 1 FROM public.krim_driver_verification_documents d WHERE d.profile_id=v_profile.id AND d.document_type='licence_back' AND d.review_status='accepted') OR NOT EXISTS(SELECT 1 FROM public.krim_driver_verification_documents d WHERE d.profile_id=v_profile.id AND d.document_type='identity_document' AND d.review_status='accepted') THEN RAISE EXCEPTION USING errcode='42501',message='Driver must have active membership, verified profile and independently accepted front/back licence plus identity evidence';END IF;$new$;
BEGIN
  SELECT pg_get_functiondef('public.krim_assign_driver_to_partner_shipment(bigint,uuid)'::regprocedure)
    INTO v_definition;
  IF position(v_old IN v_definition)=0 THEN
    RAISE EXCEPTION 'Expected driver assignment evidence gate not found; no change applied';
  END IF;
  v_definition := replace(v_definition,v_old,v_new);
  EXECUTE v_definition;
END
$migration$;