-- Allow driver acceptance for later legs while a multi-leg shipment is already in transit.
-- Still requires exact leg binding, active plan, assigned leg, partner acceptance,
-- verified driver/licence/evidence, active vehicle binding and current vehicle documents.
CREATE OR REPLACE FUNCTION public.krim_driver_accept_assignment(p_assignment_id uuid)
 RETURNS public.krim_driver_assignments
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE v_user uuid:=auth.uid();v_assignment public.krim_driver_assignments%ROWTYPE;v_partner public.krim_shipment_partner_assignments%ROWTYPE;v_shipment public.krim_shipments%ROWTYPE;v_leg public.krim_shipment_legs%ROWTYPE;v_vehicle public.krim_vehicles%ROWTYPE;v_capacity_kg numeric;
BEGIN
 IF v_user IS NULL THEN RAISE EXCEPTION USING errcode='28000',message='Authentication required';END IF;
 SELECT * INTO v_assignment FROM public.krim_driver_assignments WHERE id=p_assignment_id AND user_id=v_user FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION USING errcode='42501',message='Driver assignment not found for this account';END IF;
 IF NOT EXISTS(SELECT 1 FROM public.krim_organization_members m WHERE m.user_id=v_user AND m.organization_id=v_assignment.organization_id AND lower(m.role)='driver' AND lower(m.status)='active') THEN RAISE EXCEPTION USING errcode='42501',message='Active driver membership is required';END IF;
 IF NOT EXISTS(SELECT 1 FROM public.krim_driver_profiles dp WHERE dp.user_id=v_user AND dp.organization_id=v_assignment.organization_id AND dp.verification_status IN('verified','approved') AND nullif(btrim(dp.licence_number),'') IS NOT NULL AND dp.licence_expiry_date IS NOT NULL AND dp.licence_expiry_date>current_date) OR NOT EXISTS(SELECT 1 FROM public.krim_driver_verification_documents d JOIN public.krim_driver_profiles dp ON dp.id=d.profile_id WHERE dp.user_id=v_user AND dp.organization_id=v_assignment.organization_id AND d.document_type='licence_front' AND d.review_status='accepted') OR NOT EXISTS(SELECT 1 FROM public.krim_driver_verification_documents d JOIN public.krim_driver_profiles dp ON dp.id=d.profile_id WHERE dp.user_id=v_user AND dp.organization_id=v_assignment.organization_id AND d.document_type='licence_back' AND d.review_status='accepted') OR NOT EXISTS(SELECT 1 FROM public.krim_driver_verification_documents d JOIN public.krim_driver_profiles dp ON dp.id=d.profile_id WHERE dp.user_id=v_user AND dp.organization_id=v_assignment.organization_id AND d.document_type='identity_document' AND d.review_status='accepted') THEN RAISE EXCEPTION USING errcode='42501',message='Verified driver profile and independently accepted front/back licence plus identity evidence are required';END IF;
 IF v_assignment.vehicle_id IS NULL THEN RAISE EXCEPTION USING errcode='55000',message='This assignment has no linked verified vehicle; operations must correct the assignment before acceptance';END IF;
 SELECT v.* INTO v_vehicle FROM public.krim_vehicles v JOIN public.krim_vehicle_driver_bindings b ON b.vehicle_id=v.id AND b.driver_user_id=v_user AND b.organization_id=v_assignment.organization_id AND b.status='active' WHERE v.id=v_assignment.vehicle_id AND v.organization_id=v_assignment.organization_id AND v.verification_status='verified' AND v.operational_status='active' FOR UPDATE OF v;
 IF NOT FOUND THEN RAISE EXCEPTION USING errcode='55000',message='The assigned vehicle is no longer verified, active or bound to this driver';END IF;
 IF NOT EXISTS(SELECT 1 FROM public.krim_vehicle_document_requirements r WHERE r.registration_country_code=v_vehicle.registration_country_code AND lower(r.vehicle_category)=lower(v_vehicle.vehicle_category) AND r.is_required=true) OR EXISTS(SELECT 1 FROM public.krim_vehicle_document_requirements r WHERE r.registration_country_code=v_vehicle.registration_country_code AND lower(r.vehicle_category)=lower(v_vehicle.vehicle_category) AND r.is_required=true AND NOT EXISTS(SELECT 1 FROM public.krim_vehicle_documents vd WHERE vd.vehicle_id=v_vehicle.id AND vd.document_type=r.document_type AND vd.review_status='approved' AND (vd.expires_at IS NULL OR vd.expires_at>=current_date))) THEN RAISE EXCEPTION USING errcode='55000',message='Vehicle mandatory evidence is missing, unapproved or expired';END IF;
 IF v_assignment.status='accepted' THEN IF v_assignment.accepted_by IS DISTINCT FROM v_user OR v_assignment.accepted_at IS NULL THEN RAISE EXCEPTION USING errcode='23514',message='Accepted assignment metadata is inconsistent; contact operations';END IF;RETURN v_assignment;END IF;
 IF v_assignment.status<>'assigned' THEN RAISE EXCEPTION USING errcode='55000',message='Only a pending driver assignment can be accepted';END IF;
 SELECT * INTO v_partner FROM public.krim_shipment_partner_assignments WHERE id=v_assignment.partner_assignment_id AND shipment_id=v_assignment.shipment_id AND shipment_leg_id=v_assignment.shipment_leg_id AND partner_organization_id=v_assignment.organization_id AND status IN('accepted','active') FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION USING errcode='23514',message='Accepted partner assignment does not match this driver assignment';END IF;
 SELECT * INTO v_shipment FROM public.krim_shipments WHERE id=v_assignment.shipment_id FOR UPDATE;
 IF NOT FOUND OR NOT (
   v_shipment.status='assigned'
   OR (
     v_shipment.status='in_transit'
     AND EXISTS (
       SELECT 1
       FROM public.krim_shipment_legs l
       JOIN public.krim_shipment_leg_plans p
         ON p.shipment_id=l.shipment_id
        AND p.status='active'
        AND p.total_legs>1
       WHERE l.id=v_assignment.shipment_leg_id
         AND l.shipment_id=v_assignment.shipment_id
         AND l.leg_plan_item_id IS NOT NULL
     )
   )
 ) THEN RAISE EXCEPTION USING errcode='55000',message='Shipment must be assigned, or an active multi-leg shipment already in transit, before this exact leg driver assignment can be accepted';END IF;
 IF v_shipment.total_weight_kg IS NULL OR v_shipment.total_weight_kg<=0 OR v_vehicle.payload_capacity IS NULL OR v_vehicle.payload_unit IS NULL THEN RAISE EXCEPTION USING errcode='55000',message='Shipment weight and verified vehicle payload capacity must be present';END IF;
 CASE lower(btrim(v_vehicle.payload_unit))
  WHEN 'kg' THEN v_capacity_kg:=v_vehicle.payload_capacity;
  WHEN 'kilogram' THEN v_capacity_kg:=v_vehicle.payload_capacity;
  WHEN 'kilograms' THEN v_capacity_kg:=v_vehicle.payload_capacity;
  WHEN 't' THEN v_capacity_kg:=v_vehicle.payload_capacity*1000;
  WHEN 'ton' THEN v_capacity_kg:=v_vehicle.payload_capacity*1000;
  WHEN 'tonne' THEN v_capacity_kg:=v_vehicle.payload_capacity*1000;
  WHEN 'tonnes' THEN v_capacity_kg:=v_vehicle.payload_capacity*1000;
  WHEN 'mt' THEN v_capacity_kg:=v_vehicle.payload_capacity*1000;
  ELSE RAISE EXCEPTION USING errcode='22023',message='Vehicle payload unit is not recognised';
 END CASE;
 IF v_shipment.total_weight_kg>v_capacity_kg THEN RAISE EXCEPTION USING errcode='22023',message='Shipment exceeds the verified vehicle payload capacity';END IF;
 SELECT * INTO v_leg FROM public.krim_shipment_legs WHERE id=v_assignment.shipment_leg_id AND shipment_id=v_assignment.shipment_id AND partner_organization_id=v_assignment.organization_id AND status='assigned' FOR UPDATE;
 IF NOT FOUND OR (SELECT code FROM public.krim_transport_modes WHERE id=v_leg.transport_mode_id)<>'ROAD' THEN RAISE EXCEPTION USING errcode='23514',message='Shipment leg is no longer assigned to this partner or is not a road leg';END IF;
 IF NOT EXISTS (
  SELECT 1 FROM public.krim_partner_capabilities pc
  JOIN public.krim_organizations o ON o.id=pc.organization_id
  JOIN public.krim_partner_service_areas a ON a.organization_id=pc.organization_id
  JOIN public.krim_locations origin ON origin.id=v_leg.origin_location_id
  WHERE pc.organization_id=v_assignment.organization_id
    AND pc.transport_mode_id=v_leg.transport_mode_id
    AND pc.coverage_country_id=origin.country_id
    AND pc.service_type IN ('transport','first_mile','last_mile')
    AND pc.active=true AND pc.verification_status IN ('verified','approved')
    AND (pc.effective_from IS NULL OR pc.effective_from<=now())
    AND (pc.effective_until IS NULL OR pc.effective_until>now())
    AND o.status='active' AND private.krim_partner_compliance_is_current(o.id)
    AND a.country_id=origin.country_id AND a.service_type=pc.service_type
    AND (a.transport_mode_id IS NULL OR a.transport_mode_id=v_leg.transport_mode_id)
    AND a.status='active' AND a.metadata->>'workflow_status'='approved'
    AND a.effective_from<=now() AND (a.effective_until IS NULL OR a.effective_until>now())
    AND ((a.coverage_type='country' AND a.country_id=origin.country_id)
      OR (a.coverage_type='market' AND a.market_id=origin.market_id)
      OR (a.coverage_type='location' AND a.location_id=origin.id))
 ) THEN RAISE EXCEPTION USING errcode='42501',message='Driver dispatch blocked: partner has no active approved service area and matching verified road-service capability for this pickup location'; END IF;
 UPDATE public.krim_driver_assignments SET status='accepted',accepted_at=now(),accepted_by=v_user,updated_at=now() WHERE id=v_assignment.id RETURNING * INTO v_assignment;RETURN v_assignment;
END;$function$;
