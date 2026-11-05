CREATE OR REPLACE FUNCTION public.krim_operations_dispatch_readiness()
 RETURNS TABLE(assignment_id bigint, shipment_id bigint, shipment_number text, shipment_status text, shipment_leg_id bigint, leg_sequence integer, leg_status text, assignment_status text, partner_organization_id bigint, handover_complete boolean, eligible_driver_count integer, readiness_status text, blockers text[])
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
WITH scoped AS (
 SELECT a.id assignment_id,a.shipment_id,s.shipment_number,s.status shipment_status,a.shipment_leg_id,l.leg_sequence,l.status leg_status,l.assignment_status,a.partner_organization_id,a.status partner_assignment_status,
 o.status org_status,o.partner_account_mode,o.partner_verification_status,o.partner_lifecycle_status,o.partner_compliance_status,
 (SELECT code FROM public.krim_transport_modes tm WHERE tm.id=l.transport_mode_id) mode_code,
 s.total_weight_kg
 FROM public.krim_shipment_partner_assignments a
 JOIN public.krim_shipments s ON s.id=a.shipment_id
 JOIN public.krim_shipment_legs l ON l.id=a.shipment_leg_id AND l.shipment_id=a.shipment_id
 JOIN public.krim_organizations o ON o.id=a.partner_organization_id
 WHERE a.status IN('accepted','active') AND auth.uid() IS NOT NULL
 AND public.krim_has_permission(auth.uid(),a.partner_organization_id,'shipment.dispatch')
), checks AS (
 SELECT x.*,
 EXISTS(SELECT 1 FROM public.krim_warehouse_tasks h WHERE h.organization_id=x.partner_organization_id AND h.shipment_id=x.shipment_id AND h.shipment_leg_id=x.shipment_leg_id AND h.task_type='dispatch_handover' AND h.status='completed') handover_ok,
 (SELECT count(DISTINCT dp.user_id)::integer
  FROM public.krim_driver_profiles dp
  JOIN public.krim_organization_members m ON m.user_id=dp.user_id AND m.organization_id=dp.organization_id AND lower(m.role)='driver' AND lower(m.status)='active'
  JOIN public.krim_vehicle_driver_bindings b ON b.driver_user_id=dp.user_id AND b.organization_id=x.partner_organization_id AND b.status='active'
  JOIN public.krim_vehicles v ON v.id=b.vehicle_id AND v.organization_id=x.partner_organization_id AND v.verification_status='verified' AND v.operational_status='active'
  WHERE dp.organization_id=x.partner_organization_id AND dp.verification_status IN('verified','approved') AND nullif(btrim(dp.licence_number),'') IS NOT NULL
  AND EXISTS(SELECT 1 FROM public.krim_driver_verification_documents d WHERE d.profile_id=dp.id AND d.document_type='licence_front' AND d.review_status='accepted')
  AND EXISTS(SELECT 1 FROM public.krim_driver_verification_documents d WHERE d.profile_id=dp.id AND d.document_type='licence_back' AND d.review_status='accepted')
  AND x.mode_code='ROAD' AND x.total_weight_kg>0 AND v.payload_capacity>0
  AND lower(btrim(coalesce(v.payload_unit,''))) IN('kg','kilogram','kilograms','t','ton','tonne','tonnes','mt')
  AND v.payload_capacity * CASE WHEN lower(btrim(v.payload_unit)) IN('t','ton','tonne','tonnes','mt') THEN 1000 ELSE 1 END >= x.total_weight_kg
  AND EXISTS(SELECT 1 FROM public.krim_vehicle_document_requirements r WHERE r.registration_country_code=v.registration_country_code AND lower(r.vehicle_category)=lower(v.vehicle_category) AND r.is_required=true)
  AND NOT EXISTS(SELECT 1 FROM public.krim_vehicle_document_requirements r WHERE r.registration_country_code=v.registration_country_code AND lower(r.vehicle_category)=lower(v.vehicle_category) AND r.is_required=true AND NOT EXISTS(SELECT 1 FROM public.krim_vehicle_documents vd WHERE vd.vehicle_id=v.id AND vd.document_type=r.document_type AND vd.review_status='approved' AND (vd.expires_at IS NULL OR vd.expires_at>=current_date)))
  AND NOT EXISTS(SELECT 1 FROM public.krim_driver_assignments da WHERE da.user_id=dp.user_id AND da.status IN('assigned','accepted','pickup_complete','in_transit','exception'))
 ) compatible_drivers
 FROM scoped x
), results AS (
 SELECT c.*,array_remove(ARRAY[
  CASE WHEN c.shipment_status<>'assigned' THEN 'Shipment is not in assigned status' END,
  CASE WHEN c.leg_status<>'assigned' OR c.assignment_status NOT IN('accepted','active') THEN 'Shipment leg assignment is not active' END,
  CASE WHEN c.org_status<>'active' OR c.partner_account_mode<>'registered_business' OR c.partner_verification_status NOT IN('verified','approved') OR c.partner_lifecycle_status NOT IN('active','verified') OR c.partner_compliance_status NOT IN('clear','compliant','approved','verified','not_required','not_applicable') THEN 'Partner verification or compliance is incomplete' END,
  CASE WHEN NOT c.handover_ok THEN 'Completed warehouse dispatch handover is missing' END,
  CASE WHEN c.mode_code<>'ROAD' THEN 'This driver and road-vehicle workflow only supports ROAD legs' END,
  CASE WHEN c.total_weight_kg IS NULL OR c.total_weight_kg<=0 THEN 'Shipment weight is missing or invalid' END,
  CASE WHEN c.compatible_drivers=0 THEN 'No verified, available driver with an eligible vehicle and sufficient payload is available' END,
  CASE WHEN private.krim_partner_capability_covers_shipment(c.partner_organization_id,c.shipment_id) IS NOT TRUE THEN 'Verified route capability does not cover this shipment' END
 ],NULL) blockers FROM checks c
)
SELECT r.assignment_id,r.shipment_id,r.shipment_number,r.shipment_status,r.shipment_leg_id,r.leg_sequence,r.leg_status,r.partner_assignment_status,r.partner_organization_id,r.handover_ok,r.compatible_drivers,
 CASE WHEN cardinality(r.blockers)=0 THEN 'ready_for_authorized_review' ELSE 'blocked' END,r.blockers
FROM results r ORDER BY r.shipment_id,r.leg_sequence,r.assignment_id;
$function$
;
