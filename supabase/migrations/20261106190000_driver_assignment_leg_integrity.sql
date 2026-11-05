ALTER TABLE public.krim_driver_assignments
 ADD COLUMN IF NOT EXISTS shipment_leg_id bigint;
UPDATE public.krim_driver_assignments da SET shipment_leg_id=pa.shipment_leg_id
 FROM public.krim_shipment_partner_assignments pa
 WHERE da.partner_assignment_id=pa.id AND da.shipment_id=pa.shipment_id AND da.shipment_leg_id IS NULL;
DO $$
BEGIN
 IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='krim_driver_assignments_leg_shipment_fk') THEN
  ALTER TABLE public.krim_driver_assignments ADD CONSTRAINT krim_driver_assignments_leg_shipment_fk
   FOREIGN KEY (shipment_leg_id,shipment_id) REFERENCES public.krim_shipment_legs(id,shipment_id);
 END IF;
END $$;
CREATE INDEX IF NOT EXISTS krim_driver_assignments_leg_idx ON public.krim_driver_assignments(shipment_leg_id) WHERE shipment_leg_id IS NOT NULL;

CREATE OR REPLACE FUNCTION public.krim_assign_driver_to_partner_shipment(p_partner_assignment_id bigint,p_driver_user_id uuid)
RETURNS public.krim_driver_assignments LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
 v_user uuid:=auth.uid(); v_pa public.krim_shipment_partner_assignments%ROWTYPE;
 v_ship public.krim_shipments%ROWTYPE; v_leg public.krim_shipment_legs%ROWTYPE;
 v_driver_org bigint; v_pickup text; v_delivery text; v_assignment public.krim_driver_assignments%ROWTYPE;
BEGIN
 IF v_user IS NULL THEN RAISE EXCEPTION USING errcode='28000',message='Authentication required'; END IF;
 SELECT * INTO v_pa FROM public.krim_shipment_partner_assignments WHERE id=p_partner_assignment_id AND status='accepted' FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION USING errcode='22023',message='Only an accepted partner assignment can receive a driver'; END IF;
 IF NOT public.krim_has_permission(v_user,v_pa.partner_organization_id,'shipment.dispatch') THEN
  RAISE EXCEPTION USING errcode='42501',message='Dispatch permission required for this partner organization'; END IF;
 SELECT * INTO v_ship FROM public.krim_shipments WHERE id=v_pa.shipment_id FOR UPDATE;
 IF NOT FOUND OR v_ship.status<>'assigned' THEN RAISE EXCEPTION USING errcode='22023',message='Shipment must exist and be in assigned status before driver assignment'; END IF;
 SELECT * INTO v_leg FROM public.krim_shipment_legs WHERE id=v_pa.shipment_leg_id AND shipment_id=v_pa.shipment_id FOR UPDATE;
 IF NOT FOUND OR v_leg.status<>'assigned' OR v_leg.partner_organization_id IS DISTINCT FROM v_pa.partner_organization_id THEN
  RAISE EXCEPTION USING errcode='22023',message='Partner assignment must match an assigned leg owned by the same partner'; END IF;
 IF NOT EXISTS (SELECT 1 FROM public.krim_organizations o WHERE o.id=v_pa.partner_organization_id AND o.status='active'
  AND o.partner_account_mode='registered_business' AND o.partner_verification_status IN ('verified','approved')
  AND o.partner_lifecycle_status IN ('active','verified')
  AND o.partner_compliance_status IN ('clear','compliant','approved','verified','not_required','not_applicable'))
  OR private.krim_partner_capability_covers_shipment(v_pa.partner_organization_id,v_ship.id) IS NOT TRUE THEN
  RAISE EXCEPTION USING errcode='42501',message='Partner verification, compliance or route capability is not valid'; END IF;
 SELECT m.organization_id INTO v_driver_org FROM public.krim_organization_members m
 JOIN public.krim_organizations o ON o.id=m.organization_id AND lower(o.status)='active'
 WHERE m.user_id=p_driver_user_id AND m.organization_id=v_pa.partner_organization_id AND lower(m.role)='driver'
 AND lower(m.status)='active' LIMIT 1;
 IF v_driver_org IS NULL OR NOT EXISTS (SELECT 1 FROM public.krim_driver_profiles dp WHERE dp.user_id=p_driver_user_id
  AND dp.organization_id=v_pa.partner_organization_id AND dp.verification_status IN ('verified','approved')
  AND nullif(btrim(dp.licence_number),'') IS NOT NULL) THEN
  RAISE EXCEPTION USING errcode='42501',message='Driver must have active partner membership and verified licence'; END IF;
 SELECT concat_ws(', ',nullif(l.city,''),nullif(l.state_region,''),nullif(l.location_code,'')) INTO v_pickup
 FROM public.krim_locations l WHERE l.id=v_leg.origin_location_id;
 SELECT concat_ws(', ',nullif(l.city,''),nullif(l.state_region,''),nullif(l.location_code,'')) INTO v_delivery
 FROM public.krim_locations l WHERE l.id=v_leg.destination_location_id;
 v_pickup:=coalesce(nullif(v_pickup,''),'Pickup location pending'); v_delivery:=coalesce(nullif(v_delivery,''),'Delivery location pending');
 SELECT * INTO v_assignment FROM public.krim_driver_assignments WHERE partner_assignment_id=p_partner_assignment_id FOR UPDATE;
 IF FOUND THEN
  IF v_assignment.user_id<>p_driver_user_id THEN RAISE EXCEPTION USING errcode='23505',message='This partner shipment leg is already assigned to another driver'; END IF;
  IF v_assignment.shipment_id IS DISTINCT FROM v_ship.id OR v_assignment.shipment_leg_id IS DISTINCT FROM v_leg.id
   OR v_assignment.organization_id IS DISTINCT FROM v_pa.partner_organization_id THEN
   RAISE EXCEPTION USING errcode='23514',message='Existing driver assignment linkage is inconsistent and requires review'; END IF;
  RETURN v_assignment;
 END IF;
 INSERT INTO public.krim_driver_assignments(user_id,organization_id,shipment_id,shipment_leg_id,partner_assignment_id,status,pickup_location,delivery_location,created_by)
 VALUES(p_driver_user_id,v_driver_org,v_ship.id,v_leg.id,p_partner_assignment_id,'assigned',v_pickup,v_delivery,v_user)
 RETURNING * INTO v_assignment;
 RETURN v_assignment;
END;
$function$;
REVOKE ALL ON FUNCTION public.krim_assign_driver_to_partner_shipment(bigint,uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.krim_assign_driver_to_partner_shipment(bigint,uuid) TO authenticated;