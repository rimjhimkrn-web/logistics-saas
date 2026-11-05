-- KRIM Driver–Vehicle Compatibility and Shipment Assignment Gate
ALTER TABLE public.krim_driver_assignments ADD COLUMN IF NOT EXISTS vehicle_id uuid REFERENCES public.krim_vehicles(id) ON DELETE RESTRICT;
CREATE INDEX IF NOT EXISTS krim_driver_assignments_vehicle_status_idx ON public.krim_driver_assignments(vehicle_id,status) WHERE vehicle_id IS NOT NULL;
CREATE TABLE IF NOT EXISTS public.krim_vehicle_driver_bindings (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), organization_id bigint NOT NULL REFERENCES public.krim_organizations(id) ON DELETE CASCADE,
 vehicle_id uuid NOT NULL REFERENCES public.krim_vehicles(id) ON DELETE RESTRICT, driver_profile_id uuid NOT NULL REFERENCES public.krim_driver_profiles(id) ON DELETE RESTRICT,
 driver_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT, status text NOT NULL DEFAULT 'active' CHECK(status IN('active','revoked')),
 created_by uuid NOT NULL REFERENCES auth.users(id), created_at timestamptz NOT NULL DEFAULT now(), revoked_by uuid REFERENCES auth.users(id), revoked_at timestamptz,
 CHECK((status='active' AND revoked_at IS NULL AND revoked_by IS NULL) OR (status='revoked' AND revoked_at IS NOT NULL AND revoked_by IS NOT NULL))
);
CREATE UNIQUE INDEX IF NOT EXISTS krim_vehicle_driver_one_active_vehicle_idx ON public.krim_vehicle_driver_bindings(vehicle_id) WHERE status='active';
CREATE UNIQUE INDEX IF NOT EXISTS krim_vehicle_driver_one_active_driver_idx ON public.krim_vehicle_driver_bindings(driver_user_id) WHERE status='active';
CREATE INDEX IF NOT EXISTS krim_vehicle_driver_org_status_idx ON public.krim_vehicle_driver_bindings(organization_id,status,created_at DESC);
ALTER TABLE public.krim_vehicle_driver_bindings ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.krim_vehicle_driver_bindings FROM PUBLIC,anon,authenticated;
DO $$ BEGIN IF NOT EXISTS(SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='krim_vehicle_driver_bindings' AND policyname='krim_vehicle_driver_bindings_deny_direct_api') THEN CREATE POLICY krim_vehicle_driver_bindings_deny_direct_api ON public.krim_vehicle_driver_bindings FOR ALL TO anon,authenticated USING(false) WITH CHECK(false); END IF; END $$;
CREATE OR REPLACE FUNCTION public.krim_assign_driver_to_partner_shipment(p_partner_assignment_id bigint, p_driver_user_id uuid)
 RETURNS krim_driver_assignments
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE v_user uuid:=auth.uid();v_pa public.krim_shipment_partner_assignments%ROWTYPE;v_ship public.krim_shipments%ROWTYPE;v_leg public.krim_shipment_legs%ROWTYPE;v_driver_org bigint;v_profile public.krim_driver_profiles%ROWTYPE;v_vehicle public.krim_vehicles%ROWTYPE;v_pickup text;v_delivery text;v_assignment public.krim_driver_assignments%ROWTYPE;v_capacity_kg numeric;
BEGIN
 IF v_user IS NULL THEN RAISE EXCEPTION USING errcode='28000',message='Authentication required';END IF;
 SELECT * INTO v_pa FROM public.krim_shipment_partner_assignments WHERE id=p_partner_assignment_id AND status='accepted' FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION USING errcode='22023',message='Only an accepted partner assignment can receive a driver';END IF;
 IF NOT public.krim_has_permission(v_user,v_pa.partner_organization_id,'shipment.dispatch') THEN RAISE EXCEPTION USING errcode='42501',message='Dispatch permission required for this partner organization';END IF;
 SELECT * INTO v_ship FROM public.krim_shipments WHERE id=v_pa.shipment_id FOR UPDATE;
 IF NOT FOUND OR v_ship.status<>'assigned' THEN RAISE EXCEPTION USING errcode='22023',message='Shipment must exist and be in assigned status before driver assignment';END IF;
 SELECT * INTO v_leg FROM public.krim_shipment_legs WHERE id=v_pa.shipment_leg_id AND shipment_id=v_pa.shipment_id FOR UPDATE;
 IF NOT FOUND OR v_leg.status<>'assigned' OR v_leg.partner_organization_id IS DISTINCT FROM v_pa.partner_organization_id THEN RAISE EXCEPTION USING errcode='22023',message='Partner assignment must match an assigned leg owned by the same partner';END IF;
 IF (SELECT code FROM public.krim_transport_modes WHERE id=v_leg.transport_mode_id)<>'ROAD' THEN RAISE EXCEPTION USING errcode='55000',message='A registered road vehicle can only serve a ROAD shipment leg';END IF;
 IF NOT EXISTS(SELECT 1 FROM public.krim_organizations o WHERE o.id=v_pa.partner_organization_id AND o.status='active' AND o.partner_account_mode='registered_business' AND o.partner_verification_status IN('verified','approved') AND o.partner_lifecycle_status IN('active','verified') AND o.partner_compliance_status IN('clear','compliant','approved','verified','not_required','not_applicable')) OR private.krim_partner_capability_covers_shipment(v_pa.partner_organization_id,v_ship.id) IS NOT TRUE THEN RAISE EXCEPTION USING errcode='42501',message='Partner verification, compliance or route capability is not valid';END IF;
 SELECT dp.* INTO v_profile FROM public.krim_driver_profiles dp JOIN public.krim_organization_members m ON m.user_id=dp.user_id AND m.organization_id=dp.organization_id WHERE dp.user_id=p_driver_user_id AND dp.organization_id=v_pa.partner_organization_id AND dp.verification_status IN('verified','approved') AND nullif(btrim(dp.licence_number),'') IS NOT NULL AND lower(m.role)='driver' AND lower(m.status)='active' FOR UPDATE OF dp;
 IF NOT FOUND OR NOT EXISTS(SELECT 1 FROM public.krim_driver_verification_documents d WHERE d.profile_id=v_profile.id AND d.document_type='licence_front' AND d.review_status='accepted') OR NOT EXISTS(SELECT 1 FROM public.krim_driver_verification_documents d WHERE d.profile_id=v_profile.id AND d.document_type='licence_back' AND d.review_status='accepted') THEN RAISE EXCEPTION USING errcode='42501',message='Driver must have active membership, verified profile and independently accepted front/back licence evidence';END IF;
 SELECT v.* INTO v_vehicle FROM public.krim_vehicles v JOIN public.krim_vehicle_driver_bindings b ON b.vehicle_id=v.id AND b.organization_id=v_pa.partner_organization_id AND b.driver_user_id=p_driver_user_id AND b.status='active' WHERE v.organization_id=v_pa.partner_organization_id AND v.verification_status='verified' AND v.operational_status='active' FOR UPDATE OF v;
 IF NOT FOUND THEN RAISE EXCEPTION USING errcode='42501',message='Driver must have an active binding to a verified, operational vehicle in this partner organisation';END IF;
 IF NOT EXISTS(SELECT 1 FROM public.krim_vehicle_document_requirements r WHERE r.registration_country_code=v_vehicle.registration_country_code AND lower(r.vehicle_category)=lower(v_vehicle.vehicle_category) AND r.is_required=true) OR EXISTS(SELECT 1 FROM public.krim_vehicle_document_requirements r WHERE r.registration_country_code=v_vehicle.registration_country_code AND lower(r.vehicle_category)=lower(v_vehicle.vehicle_category) AND r.is_required=true AND NOT EXISTS(SELECT 1 FROM public.krim_vehicle_documents vd WHERE vd.vehicle_id=v_vehicle.id AND vd.document_type=r.document_type AND vd.review_status='approved' AND (vd.expires_at IS NULL OR vd.expires_at>=current_date))) THEN RAISE EXCEPTION USING errcode='55000',message='Vehicle mandatory evidence is missing, unapproved or expired';END IF;
 IF v_ship.total_weight_kg IS NULL OR v_ship.total_weight_kg<=0 OR v_vehicle.payload_capacity IS NULL OR v_vehicle.payload_unit IS NULL THEN RAISE EXCEPTION USING errcode='55000',message='Shipment weight and verified vehicle payload capacity are required before dispatch assignment';END IF;
 CASE lower(btrim(v_vehicle.payload_unit))
  WHEN 'kg' THEN v_capacity_kg:=v_vehicle.payload_capacity;
  WHEN 'kilogram' THEN v_capacity_kg:=v_vehicle.payload_capacity;
  WHEN 'kilograms' THEN v_capacity_kg:=v_vehicle.payload_capacity;
  WHEN 't' THEN v_capacity_kg:=v_vehicle.payload_capacity*1000;
  WHEN 'ton' THEN v_capacity_kg:=v_vehicle.payload_capacity*1000;
  WHEN 'tonne' THEN v_capacity_kg:=v_vehicle.payload_capacity*1000;
  WHEN 'tonnes' THEN v_capacity_kg:=v_vehicle.payload_capacity*1000;
  WHEN 'mt' THEN v_capacity_kg:=v_vehicle.payload_capacity*1000;
  ELSE RAISE EXCEPTION USING errcode='22023',message='Vehicle payload unit is not recognised; update the verified vehicle record to kg or tonnes';
 END CASE;
 IF v_ship.total_weight_kg>v_capacity_kg THEN RAISE EXCEPTION USING errcode='22023',message='Shipment exceeds the verified payload capacity of the assigned vehicle';END IF;
 SELECT concat_ws(', ',nullif(l.city,''),nullif(l.state_region,''),nullif(l.location_code,'')) INTO v_pickup FROM public.krim_locations l WHERE l.id=v_leg.origin_location_id;
 SELECT concat_ws(', ',nullif(l.city,''),nullif(l.state_region,''),nullif(l.location_code,'')) INTO v_delivery FROM public.krim_locations l WHERE l.id=v_leg.destination_location_id;
 v_pickup:=coalesce(nullif(v_pickup,''),'Pickup location pending');v_delivery:=coalesce(nullif(v_delivery,''),'Delivery location pending');v_driver_org:=v_pa.partner_organization_id;
 SELECT * INTO v_assignment FROM public.krim_driver_assignments WHERE partner_assignment_id=p_partner_assignment_id FOR UPDATE;
 IF FOUND THEN
  IF v_assignment.user_id<>p_driver_user_id OR v_assignment.vehicle_id IS DISTINCT FROM v_vehicle.id THEN RAISE EXCEPTION USING errcode='23505',message='This shipment leg is already assigned to another driver or vehicle';END IF;
  IF v_assignment.shipment_id IS DISTINCT FROM v_ship.id OR v_assignment.shipment_leg_id IS DISTINCT FROM v_leg.id OR v_assignment.organization_id IS DISTINCT FROM v_pa.partner_organization_id THEN RAISE EXCEPTION USING errcode='23514',message='Existing driver assignment linkage is inconsistent and requires review';END IF;
  RETURN v_assignment;
 END IF;
 IF EXISTS(SELECT 1 FROM public.krim_driver_assignments da WHERE (da.user_id=p_driver_user_id OR da.vehicle_id=v_vehicle.id) AND da.status IN('assigned','accepted','pickup_complete','in_transit','exception')) THEN RAISE EXCEPTION USING errcode='55000',message='Driver or vehicle already has an open shipment assignment';END IF;
 INSERT INTO public.krim_driver_assignments(user_id,organization_id,shipment_id,shipment_leg_id,partner_assignment_id,vehicle_id,status,pickup_location,delivery_location,created_by)
 VALUES(p_driver_user_id,v_driver_org,v_ship.id,v_leg.id,p_partner_assignment_id,v_vehicle.id,'assigned',v_pickup,v_delivery,v_user) RETURNING * INTO v_assignment;
 INSERT INTO public.krim_audit_events(actor_user_id,organization_id,event_type,entity_type,entity_id,source,metadata,new_state) VALUES(v_user,v_driver_org,'shipment.driver_vehicle.assigned','driver_assignment',v_assignment.id::text,'dispatch-compatibility',jsonb_build_object('shipment_id',v_ship.id,'shipment_leg_id',v_leg.id,'driver_user_id',p_driver_user_id,'vehicle_id',v_vehicle.id),jsonb_build_object('status','assigned','vehicle_id',v_vehicle.id));
 RETURN v_assignment;
END;$function$
;

CREATE OR REPLACE FUNCTION public.krim_driver_accept_assignment(p_assignment_id uuid)
 RETURNS krim_driver_assignments
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
 IF NOT EXISTS(SELECT 1 FROM public.krim_driver_profiles dp WHERE dp.user_id=v_user AND dp.organization_id=v_assignment.organization_id AND dp.verification_status IN('verified','approved') AND nullif(btrim(dp.licence_number),'') IS NOT NULL) OR NOT EXISTS(SELECT 1 FROM public.krim_driver_verification_documents d JOIN public.krim_driver_profiles dp ON dp.id=d.profile_id WHERE dp.user_id=v_user AND dp.organization_id=v_assignment.organization_id AND d.document_type='licence_front' AND d.review_status='accepted') OR NOT EXISTS(SELECT 1 FROM public.krim_driver_verification_documents d JOIN public.krim_driver_profiles dp ON dp.id=d.profile_id WHERE dp.user_id=v_user AND dp.organization_id=v_assignment.organization_id AND d.document_type='licence_back' AND d.review_status='accepted') THEN RAISE EXCEPTION USING errcode='42501',message='Verified driver profile and independently accepted front/back licence evidence are required';END IF;
 IF v_assignment.vehicle_id IS NULL THEN RAISE EXCEPTION USING errcode='55000',message='This assignment has no linked verified vehicle; operations must correct the assignment before acceptance';END IF;
 SELECT v.* INTO v_vehicle FROM public.krim_vehicles v JOIN public.krim_vehicle_driver_bindings b ON b.vehicle_id=v.id AND b.driver_user_id=v_user AND b.organization_id=v_assignment.organization_id AND b.status='active' WHERE v.id=v_assignment.vehicle_id AND v.organization_id=v_assignment.organization_id AND v.verification_status='verified' AND v.operational_status='active' FOR UPDATE OF v;
 IF NOT FOUND THEN RAISE EXCEPTION USING errcode='55000',message='The assigned vehicle is no longer verified, active or bound to this driver';END IF;
 IF NOT EXISTS(SELECT 1 FROM public.krim_vehicle_document_requirements r WHERE r.registration_country_code=v_vehicle.registration_country_code AND lower(r.vehicle_category)=lower(v_vehicle.vehicle_category) AND r.is_required=true) OR EXISTS(SELECT 1 FROM public.krim_vehicle_document_requirements r WHERE r.registration_country_code=v_vehicle.registration_country_code AND lower(r.vehicle_category)=lower(v_vehicle.vehicle_category) AND r.is_required=true AND NOT EXISTS(SELECT 1 FROM public.krim_vehicle_documents vd WHERE vd.vehicle_id=v_vehicle.id AND vd.document_type=r.document_type AND vd.review_status='approved' AND (vd.expires_at IS NULL OR vd.expires_at>=current_date))) THEN RAISE EXCEPTION USING errcode='55000',message='Vehicle mandatory evidence is missing, unapproved or expired';END IF;
 IF v_assignment.status='accepted' THEN IF v_assignment.accepted_by IS DISTINCT FROM v_user OR v_assignment.accepted_at IS NULL THEN RAISE EXCEPTION USING errcode='23514',message='Accepted assignment metadata is inconsistent; contact operations';END IF;RETURN v_assignment;END IF;
 IF v_assignment.status<>'assigned' THEN RAISE EXCEPTION USING errcode='55000',message='Only a pending driver assignment can be accepted';END IF;
 SELECT * INTO v_partner FROM public.krim_shipment_partner_assignments WHERE id=v_assignment.partner_assignment_id AND shipment_id=v_assignment.shipment_id AND shipment_leg_id=v_assignment.shipment_leg_id AND partner_organization_id=v_assignment.organization_id AND status IN('accepted','active') FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION USING errcode='23514',message='Accepted partner assignment does not match this driver assignment';END IF;
 SELECT * INTO v_shipment FROM public.krim_shipments WHERE id=v_assignment.shipment_id FOR UPDATE;
 IF NOT FOUND OR v_shipment.status<>'assigned' THEN RAISE EXCEPTION USING errcode='55000',message='Shipment is not in an assignable state';END IF;
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
 UPDATE public.krim_driver_assignments SET status='accepted',accepted_at=now(),accepted_by=v_user,updated_at=now() WHERE id=v_assignment.id RETURNING * INTO v_assignment;RETURN v_assignment;
END;$function$
;

CREATE OR REPLACE FUNCTION public.krim_vehicle_driver_bind(p_organization_id bigint, p_vehicle_id uuid, p_driver_user_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE v_user uuid:=auth.uid();v_profile public.krim_driver_profiles%ROWTYPE;v_vehicle public.krim_vehicles%ROWTYPE;v_binding uuid;
BEGIN
 IF v_user IS NULL OR NOT public.krim_has_permission(v_user,p_organization_id,'shipment.dispatch') THEN RAISE EXCEPTION USING errcode='42501',message='Dispatch permission required';END IF;
 SELECT * INTO v_vehicle FROM public.krim_vehicles WHERE id=p_vehicle_id AND organization_id=p_organization_id FOR UPDATE;
 IF NOT FOUND OR v_vehicle.verification_status<>'verified' OR v_vehicle.operational_status<>'active' THEN RAISE EXCEPTION USING errcode='42501',message='Vehicle must be verified, active and owned by this partner organisation';END IF;
 IF v_vehicle.payload_capacity IS NULL OR v_vehicle.payload_capacity<=0 OR lower(btrim(coalesce(v_vehicle.payload_unit,''))) NOT IN('kg','kilogram','kilograms','t','ton','tonne','tonnes','mt') THEN RAISE EXCEPTION USING errcode='55000',message='A positive vehicle payload and recognised kg/tonne unit are required';END IF;
 IF NOT EXISTS(SELECT 1 FROM public.krim_vehicle_document_requirements r WHERE r.registration_country_code=v_vehicle.registration_country_code AND lower(r.vehicle_category)=lower(v_vehicle.vehicle_category) AND r.is_required=true) OR EXISTS(SELECT 1 FROM public.krim_vehicle_document_requirements r WHERE r.registration_country_code=v_vehicle.registration_country_code AND lower(r.vehicle_category)=lower(v_vehicle.vehicle_category) AND r.is_required=true AND NOT EXISTS(SELECT 1 FROM public.krim_vehicle_documents d WHERE d.vehicle_id=v_vehicle.id AND d.document_type=r.document_type AND d.review_status='approved' AND (d.expires_at IS NULL OR d.expires_at>=current_date))) THEN RAISE EXCEPTION USING errcode='55000',message='Vehicle mandatory documents are missing, unapproved or expired';END IF;
 SELECT dp.* INTO v_profile FROM public.krim_driver_profiles dp JOIN public.krim_organization_members m ON m.user_id=dp.user_id AND m.organization_id=dp.organization_id WHERE dp.user_id=p_driver_user_id AND dp.organization_id=p_organization_id AND dp.verification_status IN('verified','approved') AND nullif(btrim(dp.licence_number),'') IS NOT NULL AND lower(m.role)='driver' AND lower(m.status)='active' FOR UPDATE OF dp;
 IF NOT FOUND THEN RAISE EXCEPTION USING errcode='42501',message='Driver must have an active driver membership and verified licence profile in this organisation';END IF;
 IF NOT EXISTS(SELECT 1 FROM public.krim_driver_verification_documents d WHERE d.profile_id=v_profile.id AND d.document_type='licence_front' AND d.review_status='accepted') OR NOT EXISTS(SELECT 1 FROM public.krim_driver_verification_documents d WHERE d.profile_id=v_profile.id AND d.document_type='licence_back' AND d.review_status='accepted') THEN RAISE EXCEPTION USING errcode='42501',message='Both front and back of the driving licence must be independently accepted';END IF;
 IF EXISTS(SELECT 1 FROM public.krim_vehicle_driver_bindings WHERE status='active' AND (vehicle_id=p_vehicle_id OR driver_user_id=p_driver_user_id)) THEN RAISE EXCEPTION USING errcode='23505',message='Vehicle or driver already has an active binding; revoke the existing binding first';END IF;
 INSERT INTO public.krim_vehicle_driver_bindings(organization_id,vehicle_id,driver_profile_id,driver_user_id,status,created_by) VALUES(p_organization_id,p_vehicle_id,v_profile.id,p_driver_user_id,'active',v_user) RETURNING id INTO v_binding;
 INSERT INTO public.krim_audit_events(actor_user_id,organization_id,event_type,entity_type,entity_id,source,metadata,new_state) VALUES(v_user,p_organization_id,'vehicle.driver.bound','vehicle_driver_binding',v_binding::text,'fleet-compatibility',jsonb_build_object('vehicle_id',p_vehicle_id,'driver_user_id',p_driver_user_id),jsonb_build_object('status','active'));
 RETURN v_binding;
END;$function$
;

CREATE OR REPLACE FUNCTION public.krim_vehicle_driver_binding_list(p_organization_id bigint)
 RETURNS TABLE(binding_id uuid, vehicle_id uuid, registration_number text, driver_user_id uuid, driver_name text, status text, created_at timestamp with time zone)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE v_user uuid:=auth.uid();
BEGIN
 IF v_user IS NULL OR NOT public.krim_has_permission(v_user,p_organization_id,'shipment.dispatch') THEN RAISE EXCEPTION USING errcode='42501',message='Dispatch permission required';END IF;
 RETURN QUERY SELECT b.id,b.vehicle_id,v.registration_number,b.driver_user_id,dp.full_name,b.status,b.created_at
 FROM public.krim_vehicle_driver_bindings b JOIN public.krim_vehicles v ON v.id=b.vehicle_id
 JOIN public.krim_driver_profiles dp ON dp.id=b.driver_profile_id
 WHERE b.organization_id=p_organization_id ORDER BY b.created_at DESC;
END;$function$
;

CREATE OR REPLACE FUNCTION public.krim_vehicle_driver_eligible_drivers(p_organization_id bigint)
 RETURNS TABLE(driver_user_id uuid, driver_profile_id uuid, full_name text, licence_number text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE v_user uuid:=auth.uid();
BEGIN
 IF v_user IS NULL OR NOT public.krim_has_permission(v_user,p_organization_id,'shipment.dispatch') THEN RAISE EXCEPTION USING errcode='42501',message='Dispatch permission required';END IF;
 RETURN QUERY SELECT dp.user_id,dp.id,dp.full_name,dp.licence_number
 FROM public.krim_driver_profiles dp
 JOIN public.krim_organization_members m ON m.user_id=dp.user_id AND m.organization_id=dp.organization_id AND lower(m.role)='driver' AND lower(m.status)='active'
 WHERE dp.organization_id=p_organization_id AND dp.verification_status IN('verified','approved')
 AND nullif(btrim(dp.licence_number),'') IS NOT NULL
 AND EXISTS(SELECT 1 FROM public.krim_driver_verification_documents d WHERE d.profile_id=dp.id AND d.document_type='licence_front' AND d.review_status='accepted')
 AND EXISTS(SELECT 1 FROM public.krim_driver_verification_documents d WHERE d.profile_id=dp.id AND d.document_type='licence_back' AND d.review_status='accepted')
 AND NOT EXISTS(SELECT 1 FROM public.krim_vehicle_driver_bindings b WHERE b.driver_user_id=dp.user_id AND b.status='active')
 ORDER BY dp.full_name;
END;$function$
;

CREATE OR REPLACE FUNCTION public.krim_vehicle_driver_eligible_vehicles(p_organization_id bigint)
 RETURNS TABLE(vehicle_id uuid, registration_number text, registration_country_code text, vehicle_category text, vehicle_type text, payload_capacity numeric, payload_unit text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE v_user uuid:=auth.uid();
BEGIN
 IF v_user IS NULL OR NOT public.krim_has_permission(v_user,p_organization_id,'shipment.dispatch') THEN RAISE EXCEPTION USING errcode='42501',message='Dispatch permission required';END IF;
 RETURN QUERY SELECT v.id,v.registration_number,v.registration_country_code,v.vehicle_category,v.vehicle_type,v.payload_capacity,v.payload_unit
 FROM public.krim_vehicles v WHERE v.organization_id=p_organization_id AND v.verification_status='verified' AND v.operational_status='active'
 AND v.payload_capacity IS NOT NULL AND v.payload_capacity>0 AND lower(btrim(coalesce(v.payload_unit,''))) IN('kg','kilogram','kilograms','t','ton','tonne','tonnes','mt')
 AND EXISTS(SELECT 1 FROM public.krim_vehicle_document_requirements r WHERE r.registration_country_code=v.registration_country_code AND lower(r.vehicle_category)=lower(v.vehicle_category) AND r.is_required=true)
 AND NOT EXISTS(SELECT 1 FROM public.krim_vehicle_document_requirements r WHERE r.registration_country_code=v.registration_country_code AND lower(r.vehicle_category)=lower(v.vehicle_category) AND r.is_required=true AND NOT EXISTS(SELECT 1 FROM public.krim_vehicle_documents d WHERE d.vehicle_id=v.id AND d.document_type=r.document_type AND d.review_status='approved' AND (d.expires_at IS NULL OR d.expires_at>=current_date)))
 AND NOT EXISTS(SELECT 1 FROM public.krim_vehicle_driver_bindings b WHERE b.vehicle_id=v.id AND b.status='active')
 ORDER BY v.registration_number;
END;$function$
;

CREATE OR REPLACE FUNCTION public.krim_vehicle_driver_unbind(p_binding_id uuid, p_reason text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE v_user uuid:=auth.uid();v_binding public.krim_vehicle_driver_bindings%ROWTYPE;
BEGIN
 IF v_user IS NULL THEN RAISE EXCEPTION USING errcode='28000',message='Authentication required';END IF;
 SELECT * INTO v_binding FROM public.krim_vehicle_driver_bindings WHERE id=p_binding_id AND status='active' FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION USING errcode='P0002',message='Active vehicle-driver binding not found';END IF;
 IF NOT public.krim_has_permission(v_user,v_binding.organization_id,'shipment.dispatch') THEN RAISE EXCEPTION USING errcode='42501',message='Dispatch permission required';END IF;
 IF length(btrim(coalesce(p_reason,'')))<5 THEN RAISE EXCEPTION USING errcode='22023',message='A reason of at least five characters is required';END IF;
 IF EXISTS(SELECT 1 FROM public.krim_driver_assignments da WHERE da.vehicle_id=v_binding.vehicle_id AND da.user_id=v_binding.driver_user_id AND da.status IN('assigned','accepted','pickup_complete','in_transit','exception')) THEN RAISE EXCEPTION USING errcode='55000',message='Cannot unbind while the driver has an open or active shipment assignment';END IF;
 UPDATE public.krim_vehicle_driver_bindings SET status='revoked',revoked_by=v_user,revoked_at=now() WHERE id=p_binding_id;
 INSERT INTO public.krim_audit_events(actor_user_id,organization_id,event_type,entity_type,entity_id,source,metadata,previous_state,new_state)
 VALUES(v_user,v_binding.organization_id,'vehicle.driver.unbound','vehicle_driver_binding',v_binding.id::text,'fleet-compatibility',jsonb_build_object('reason',btrim(p_reason)),jsonb_build_object('status','active'),jsonb_build_object('status','revoked','revoked_at',now()));
 RETURN 'revoked';
END;$function$
;
REVOKE ALL ON FUNCTION public.krim_vehicle_driver_eligible_drivers(bigint) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.krim_vehicle_driver_eligible_vehicles(bigint) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.krim_vehicle_driver_binding_list(bigint) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.krim_vehicle_driver_bind(bigint,uuid,uuid) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.krim_vehicle_driver_unbind(uuid,text) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.krim_assign_driver_to_partner_shipment(bigint,uuid) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.krim_driver_accept_assignment(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.krim_vehicle_driver_eligible_drivers(bigint),public.krim_vehicle_driver_eligible_vehicles(bigint),public.krim_vehicle_driver_binding_list(bigint),public.krim_vehicle_driver_bind(bigint,uuid,uuid),public.krim_vehicle_driver_unbind(uuid,text),public.krim_assign_driver_to_partner_shipment(bigint,uuid),public.krim_driver_accept_assignment(uuid) TO authenticated;
