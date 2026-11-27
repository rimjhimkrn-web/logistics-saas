-- Phase 00: align driver-picker eligibility with the authoritative vehicle bind gate.
CREATE OR REPLACE FUNCTION public.krim_vehicle_driver_eligible_drivers(p_organization_id bigint)
RETURNS TABLE(driver_user_id uuid, driver_profile_id uuid, full_name text, licence_number text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE v_user uuid:=auth.uid();
BEGIN
 IF v_user IS NULL OR NOT public.krim_has_permission(v_user,p_organization_id,'shipment.dispatch') THEN
  RAISE EXCEPTION USING errcode='42501',message='Dispatch permission required';
 END IF;
 RETURN QUERY
 SELECT dp.user_id,dp.id,dp.full_name,dp.licence_number
 FROM public.krim_driver_profiles dp
 JOIN public.krim_organization_members m
   ON m.user_id=dp.user_id AND m.organization_id=dp.organization_id
  AND lower(m.role)='driver' AND lower(m.status)='active'
 WHERE dp.organization_id=p_organization_id
  AND dp.verification_status IN('verified','approved')
  AND nullif(btrim(dp.licence_number),'') IS NOT NULL
  AND dp.licence_expiry_date IS NOT NULL
  AND dp.licence_expiry_date>current_date
  AND EXISTS(SELECT 1 FROM public.krim_driver_verification_documents d
    WHERE d.profile_id=dp.id AND d.document_type='licence_front' AND d.review_status='accepted')
  AND EXISTS(SELECT 1 FROM public.krim_driver_verification_documents d
    WHERE d.profile_id=dp.id AND d.document_type='licence_back' AND d.review_status='accepted')
  AND EXISTS(SELECT 1 FROM public.krim_driver_verification_documents d
    WHERE d.profile_id=dp.id AND d.document_type='identity_document' AND d.review_status='accepted')
  AND NOT EXISTS(SELECT 1 FROM public.krim_vehicle_driver_bindings b
    WHERE b.driver_user_id=dp.user_id AND b.status='active')
 ORDER BY dp.full_name;
END;
$function$;