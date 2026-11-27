-- Phase 00: dispatch authorization currentness must include live road-driver and vehicle readiness.
DO $migration$
DECLARE
  v_definition text;
  v_old text := $old$      AND (l.leg_sequence=1 OR EXISTS(
        SELECT 1 FROM public.krim_shipment_leg_custody_transfers ct
        JOIN public.krim_shipment_legs prev ON prev.id=ct.from_leg_id
        WHERE ct.shipment_id=l.shipment_id AND ct.to_leg_id=l.id AND ct.status='accepted'
          AND prev.leg_sequence=l.leg_sequence-1 AND ct.receiving_organization_id=da.partner_organization_id
      ))$old$;
  v_new text := $new$      AND (l.leg_sequence=1 OR EXISTS(
        SELECT 1 FROM public.krim_shipment_leg_custody_transfers ct
        JOIN public.krim_shipment_legs prev ON prev.id=ct.from_leg_id
        WHERE ct.shipment_id=l.shipment_id AND ct.to_leg_id=l.id AND ct.status='accepted'
          AND prev.leg_sequence=l.leg_sequence-1 AND ct.receiving_organization_id=da.partner_organization_id
      ))
      AND (upper(tm.code)<>'ROAD' OR EXISTS(
        SELECT 1
        FROM public.krim_driver_assignments driver_assignment
        JOIN public.krim_driver_profiles dp ON dp.user_id=driver_assignment.user_id
          AND dp.organization_id=driver_assignment.organization_id
        JOIN public.krim_vehicles vehicle ON vehicle.id=driver_assignment.vehicle_id
          AND vehicle.organization_id=driver_assignment.organization_id
        JOIN public.krim_vehicle_driver_bindings vb ON vb.driver_user_id=driver_assignment.user_id
          AND vb.vehicle_id=driver_assignment.vehicle_id
          AND vb.organization_id=driver_assignment.organization_id AND vb.status='active'
        JOIN public.krim_organization_members member ON member.user_id=driver_assignment.user_id
          AND member.organization_id=driver_assignment.organization_id
          AND lower(member.role)='driver' AND lower(member.status)='active'
        WHERE driver_assignment.partner_assignment_id=da.partner_assignment_id
          AND driver_assignment.shipment_id=da.shipment_id
          AND driver_assignment.shipment_leg_id=da.shipment_leg_id
          AND driver_assignment.organization_id=da.partner_organization_id
          AND driver_assignment.status='accepted'
          AND driver_assignment.accepted_by=driver_assignment.user_id
          AND driver_assignment.accepted_at IS NOT NULL
          AND dp.verification_status IN ('verified','approved')
          AND nullif(btrim(dp.licence_number),'') IS NOT NULL
          AND dp.licence_expiry_date>=current_date
          AND vehicle.verification_status='verified'
          AND vehicle.operational_status='active'
          AND EXISTS(SELECT 1 FROM public.krim_driver_verification_documents doc
            WHERE doc.profile_id=dp.id AND doc.document_type='licence_front' AND doc.review_status='accepted')
          AND EXISTS(SELECT 1 FROM public.krim_driver_verification_documents doc
            WHERE doc.profile_id=dp.id AND doc.document_type='licence_back' AND doc.review_status='accepted')
          AND EXISTS(SELECT 1 FROM public.krim_driver_verification_documents doc
            WHERE doc.profile_id=dp.id AND doc.document_type='identity_document' AND doc.review_status='accepted')
          AND NOT EXISTS(
            SELECT 1 FROM public.krim_vehicle_document_requirements req
            WHERE req.registration_country_code=vehicle.registration_country_code
              AND lower(req.vehicle_category)=lower(vehicle.vehicle_category)
              AND req.is_required
              AND NOT EXISTS(SELECT 1 FROM public.krim_vehicle_documents vd
                WHERE vd.vehicle_id=vehicle.id AND vd.document_type=req.document_type
                  AND vd.review_status='approved'
                  AND (vd.expires_at IS NULL OR vd.expires_at>=current_date))
          )
      ))$new$;
BEGIN
  SELECT pg_get_functiondef('private.krim_leg_dispatch_authorization_is_current(bigint,bigint,bigint,bigint)'::regprocedure)
    INTO v_definition;
  IF position(v_old IN v_definition)=0 THEN
    RAISE EXCEPTION 'Expected authorization-currentness predicate not found; no change applied';
  END IF;
  v_definition := replace(v_definition,v_old,v_new);
  EXECUTE v_definition;
END
$migration$;