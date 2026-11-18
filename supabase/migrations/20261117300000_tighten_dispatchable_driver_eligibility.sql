CREATE OR REPLACE FUNCTION public.krim_list_dispatchable_drivers(p_partner_assignment_id bigint)
RETURNS TABLE(user_id uuid, email text, full_name text, organization_id bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE v_org bigint; v_shipment bigint; v_user uuid:=auth.uid();
BEGIN
 IF v_user IS NULL THEN RAISE EXCEPTION USING errcode='28000',message='Authentication required'; END IF;
 SELECT a.partner_organization_id,a.shipment_id INTO v_org,v_shipment
 FROM public.krim_shipment_partner_assignments a
 WHERE a.id=p_partner_assignment_id AND a.status IN ('accepted','active');
 IF v_org IS NULL THEN RAISE EXCEPTION USING errcode='22023',message='Accepted partner assignment not found'; END IF;
 IF NOT public.krim_has_permission(v_user,v_org,'shipment.dispatch') THEN
  RAISE EXCEPTION USING errcode='42501',message='Dispatch permission required'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.krim_organizations o WHERE o.id=v_org AND o.status='active'
  AND o.partner_account_mode='registered_business' AND o.partner_verification_status IN ('verified','approved')
  AND o.partner_lifecycle_status IN ('active','verified')
  AND o.partner_compliance_status IN ('clear','compliant','approved','verified','not_required','not_applicable'))
  OR private.krim_partner_capability_covers_shipment(v_org,v_shipment) IS NOT TRUE THEN
  RAISE EXCEPTION USING errcode='42501',message='Partner eligibility or route capability is not valid'; END IF;
 RETURN QUERY
 SELECT m.user_id,u.email::text,
  coalesce(nullif(btrim(p.full_name),''),nullif(btrim(u.raw_user_meta_data->>'full_name'),''),'Driver')::text,m.organization_id
 FROM public.krim_organization_members m
 JOIN public.krim_organizations o ON o.id=m.organization_id AND o.status='active'
 JOIN auth.users u ON u.id=m.user_id
 LEFT JOIN public.krim_driver_profiles p ON p.user_id=m.user_id AND p.organization_id=m.organization_id
 WHERE m.organization_id=v_org AND lower(m.role)='driver' AND lower(m.status)='active'
 AND NOT EXISTS(SELECT 1 FROM public.krim_driver_assignments da
  WHERE (da.user_id=m.user_id OR da.vehicle_id IN(SELECT b.vehicle_id FROM public.krim_vehicle_driver_bindings b
   WHERE b.driver_user_id=m.user_id AND b.organization_id=v_org AND b.status='active'))
  AND da.status IN('assigned','accepted','pickup_complete','in_transit','exception'))
 AND EXISTS(SELECT 1 FROM public.krim_driver_profiles dp WHERE dp.user_id=m.user_id AND dp.organization_id=v_org
  AND dp.verification_status IN('verified','approved') AND nullif(btrim(dp.licence_number),'') IS NOT NULL
  AND dp.licence_expiry_date>current_date
  AND EXISTS(SELECT 1 FROM public.krim_driver_verification_documents d WHERE d.profile_id=dp.id AND d.document_type='licence_front' AND d.review_status='accepted')
  AND EXISTS(SELECT 1 FROM public.krim_driver_verification_documents d WHERE d.profile_id=dp.id AND d.document_type='licence_back' AND d.review_status='accepted')
  AND EXISTS(SELECT 1 FROM public.krim_driver_verification_documents d WHERE d.profile_id=dp.id AND d.document_type='identity_document' AND d.review_status='accepted'))
 AND EXISTS(SELECT 1 FROM public.krim_vehicles v JOIN public.krim_vehicle_driver_bindings b
  ON b.vehicle_id=v.id AND b.driver_user_id=m.user_id AND b.organization_id=v_org AND b.status='active'
  WHERE v.organization_id=v_org AND v.verification_status='verified' AND v.operational_status='active'
  AND EXISTS(SELECT 1 FROM public.krim_vehicle_document_requirements r WHERE r.registration_country_code=v.registration_country_code
   AND lower(r.vehicle_category)=lower(v.vehicle_category) AND r.is_required=true)
  AND NOT EXISTS(SELECT 1 FROM public.krim_vehicle_document_requirements r
   WHERE r.registration_country_code=v.registration_country_code AND lower(r.vehicle_category)=lower(v.vehicle_category)
   AND r.is_required=true AND NOT EXISTS(SELECT 1 FROM public.krim_vehicle_documents vd
    WHERE vd.vehicle_id=v.id AND vd.document_type=r.document_type AND vd.review_status='approved'
    AND (vd.expires_at IS NULL OR vd.expires_at>=current_date))))
 ORDER BY coalesce(nullif(btrim(p.full_name),''),nullif(btrim(u.raw_user_meta_data->>'full_name'),''),u.email),u.email;
END;$function$;
REVOKE ALL ON FUNCTION public.krim_list_dispatchable_drivers(bigint) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.krim_list_dispatchable_drivers(bigint) TO authenticated;
