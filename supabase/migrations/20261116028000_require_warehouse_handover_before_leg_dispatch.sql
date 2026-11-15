-- Require completed warehouse handover, picked stock and live private proof
-- before a leg dispatch authorization can be created or remain current.
CREATE OR REPLACE FUNCTION private.krim_dispatch_handover_is_current(
 p_shipment_id bigint,
 p_shipment_leg_id bigint,
 p_partner_organization_id bigint
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
 SELECT EXISTS (
  SELECT 1
  FROM public.krim_warehouse_tasks ht
  WHERE ht.task_type='dispatch_handover'
   AND ht.status='completed'
   AND ht.organization_id=p_partner_organization_id
   AND ht.shipment_id=p_shipment_id
   AND ht.shipment_leg_id=p_shipment_leg_id
   AND EXISTS (
    SELECT 1 FROM public.krim_warehouse_shipment_allocations a
    WHERE a.organization_id=ht.organization_id AND a.facility_id=ht.facility_id
     AND a.shipment_id=ht.shipment_id AND a.shipment_leg_id=ht.shipment_leg_id
     AND a.status='picked'
   )
   AND NOT EXISTS (
    SELECT 1 FROM public.krim_warehouse_shipment_allocations a
    WHERE a.organization_id=ht.organization_id AND a.facility_id=ht.facility_id
     AND a.shipment_id=ht.shipment_id AND a.shipment_leg_id=ht.shipment_leg_id
     AND a.status='reserved'
   )
   AND EXISTS (
    SELECT 1
    FROM public.krim_warehouse_evidence e
    JOIN storage.objects o ON o.bucket_id=e.bucket_id AND o.name=e.storage_path AND o.owner=e.created_by
    WHERE e.task_id=ht.id AND e.organization_id=ht.organization_id AND e.facility_id=ht.facility_id
     AND e.evidence_type='dispatch_proof' AND e.bucket_id='krim-warehouse-evidence'
     AND split_part(e.storage_path,'/',1)=e.organization_id::text
     AND split_part(e.storage_path,'/',2)=e.created_by::text
     AND cardinality(string_to_array(e.storage_path,'/'))=3
     AND coalesce(o.metadata->>'mimetype','') IN ('image/jpeg','image/png','application/pdf')
     AND pg_catalog.pg_input_is_valid(o.metadata->>'size','bigint')
     AND (o.metadata->>'size')::bigint BETWEEN 1 AND 10485760
   )
 );
$function$;

CREATE OR REPLACE FUNCTION private.krim_guard_dispatch_authorization_handover()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
 IF NEW.status='authorized'
  AND NOT private.krim_dispatch_handover_is_current(
   NEW.shipment_id,NEW.shipment_leg_id,NEW.partner_organization_id
  ) THEN
  RAISE EXCEPTION 'Leg dispatch authorization requires a completed exact-leg warehouse handover, picked stock allocations and current private dispatch proof'
   USING errcode='23514';
 END IF;
 RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION private.krim_dispatch_handover_is_current(bigint,bigint,bigint) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.krim_guard_dispatch_authorization_handover() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_krim_dispatch_authorization_requires_warehouse_handover
ON public.krim_shipment_leg_dispatch_authorizations;

CREATE TRIGGER trg_krim_dispatch_authorization_requires_warehouse_handover
BEFORE INSERT OR UPDATE OF status
ON public.krim_shipment_leg_dispatch_authorizations
FOR EACH ROW
EXECUTE FUNCTION private.krim_guard_dispatch_authorization_handover();

CREATE OR REPLACE FUNCTION private.krim_leg_dispatch_authorization_is_current(
 p_shipment_id bigint,
 p_shipment_leg_id bigint,
 p_partner_assignment_id bigint,
 p_partner_organization_id bigint
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
 SELECT EXISTS(
  SELECT 1
  FROM public.krim_shipment_leg_dispatch_authorizations da
  JOIN public.krim_shipment_legs l ON l.id=da.shipment_leg_id AND l.shipment_id=da.shipment_id
  JOIN public.krim_shipment_leg_plans p ON p.shipment_id=da.shipment_id AND p.status='active' AND p.total_legs>1
  JOIN public.krim_shipment_leg_plan_items i ON i.id=l.leg_plan_item_id AND i.plan_id=p.id
   AND i.leg_sequence=l.leg_sequence AND i.origin_location_id=l.origin_location_id
   AND i.destination_location_id=l.destination_location_id AND i.transport_mode_id=l.transport_mode_id
   AND i.partner_organization_id=da.partner_organization_id AND i.assignment_id=da.partner_assignment_id
  JOIN public.krim_shipment_partner_assignments pa ON pa.id=da.partner_assignment_id
   AND pa.shipment_id=da.shipment_id AND pa.shipment_leg_id=da.shipment_leg_id
   AND pa.partner_organization_id=da.partner_organization_id AND pa.status IN ('accepted','active')
  JOIN public.krim_organizations o ON o.id=da.partner_organization_id
   AND o.status='active' AND o.partner_account_mode='registered_business'
   AND o.partner_verification_status IN ('verified','approved')
   AND o.partner_lifecycle_status IN ('active','verified')
   AND o.partner_compliance_status IN ('clear','compliant','approved','verified','not_required','not_applicable')
  JOIN public.krim_capacity_leg_bindings cb ON cb.id=da.capacity_binding_id
   AND cb.shipment_id=da.shipment_id AND cb.shipment_leg_id=da.shipment_leg_id AND cb.status='confirmed'
  JOIN public.krim_capacity_reservations cr ON cr.id=da.reservation_id AND cr.id=cb.reservation_id
   AND cr.shipment_id=da.shipment_id AND cr.shipment_leg_id=da.shipment_leg_id
   AND cr.organization_id=da.partner_organization_id AND cr.status='confirmed'
  WHERE da.shipment_id=p_shipment_id AND da.shipment_leg_id=p_shipment_leg_id
   AND da.partner_assignment_id=p_partner_assignment_id AND da.partner_organization_id=p_partner_organization_id
   AND da.status='authorized'
   AND private.krim_partner_compliance_is_current(o.id) IS TRUE
   AND private.krim_partner_capability_covers_shipment_leg(o.id,l.id) IS TRUE
   AND private.krim_dispatch_handover_is_current(da.shipment_id,da.shipment_leg_id,da.partner_organization_id) IS TRUE
   AND (l.leg_sequence=1 OR EXISTS(
    SELECT 1 FROM public.krim_shipment_leg_custody_transfers ct
    JOIN public.krim_shipment_legs prev ON prev.id=ct.from_leg_id
    WHERE ct.shipment_id=l.shipment_id AND ct.to_leg_id=l.id
     AND ct.status='accepted' AND prev.leg_sequence=l.leg_sequence-1
     AND ct.receiving_organization_id=da.partner_organization_id
   ))
 );
$function$;
