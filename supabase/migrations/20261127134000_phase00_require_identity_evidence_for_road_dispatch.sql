-- Phase 00: align road dispatch driver eligibility with the full driver acceptance evidence gate.
DO $migration$
DECLARE
  v_definition text;
  v_old text := $$and dp.verification_status in ('verified','approved') and dp.licence_expiry_date>=current_date
   and v.verification_status='verified' and v.operational_status='active'
   and exists(select 1 from public.krim_driver_verification_documents d where d.profile_id=dp.id and d.document_type='licence_front' and d.review_status='accepted')
   and exists(select 1 from public.krim_driver_verification_documents d where d.profile_id=dp.id and d.document_type='licence_back' and d.review_status='accepted')
   and not exists(select 1 from public.krim_vehicle_document_requirements req where req.registration_country_code=v.registration_country_code and lower(req.vehicle_category)=lower(v.vehicle_category) and req.is_required and not exists(select 1 from public.krim_vehicle_documents vd where vd.vehicle_id=v.id and vd.document_type=req.document_type and vd.review_status='approved' and (vd.expires_at is null or vd.expires_at>=current_date)))$$;
  v_new text := $$and dp.verification_status in ('verified','approved')
   and nullif(btrim(dp.licence_number),'') is not null
   and dp.licence_expiry_date>=current_date
   and v.verification_status='verified' and v.operational_status='active'
   and exists(select 1 from public.krim_driver_verification_documents d where d.profile_id=dp.id and d.document_type='licence_front' and d.review_status='accepted')
   and exists(select 1 from public.krim_driver_verification_documents d where d.profile_id=dp.id and d.document_type='licence_back' and d.review_status='accepted')
   and exists(select 1 from public.krim_driver_verification_documents d where d.profile_id=dp.id and d.document_type='identity_document' and d.review_status='accepted')
   and not exists(select 1 from public.krim_vehicle_document_requirements req where req.registration_country_code=v.registration_country_code and lower(req.vehicle_category)=lower(v.vehicle_category) and req.is_required and not exists(select 1 from public.krim_vehicle_documents vd where vd.vehicle_id=v.id and vd.document_type=req.document_type and vd.review_status='approved' and (vd.expires_at is null or vd.expires_at>=current_date)))$$;
BEGIN
  SELECT pg_get_functiondef('public.krim_authorize_leg_dispatch(bigint,text)'::regprocedure) INTO v_definition;
  IF position(v_old IN v_definition)=0 THEN
    RAISE EXCEPTION 'Expected road-driver eligibility block not found; no change applied';
  END IF;
  v_definition := replace(v_definition,v_old,v_new);
  EXECUTE v_definition;
END
$migration$;