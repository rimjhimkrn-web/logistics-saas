-- Preserve the active-organization check for operations readers while
-- aligning partner shipment visibility with current verified capability scope.
DROP POLICY IF EXISTS "KRIM shipments scoped read" ON public.krim_shipments;

CREATE POLICY "KRIM shipments scoped read"
ON public.krim_shipments
FOR SELECT
TO authenticated
USING (
  private.krim_user_has_active_partner_assignment(id)
  OR (
    customer_organization_id IS NOT NULL
    AND private.krim_has_organization_access((SELECT auth.uid()), customer_organization_id)
  )
  OR EXISTS (
    SELECT 1
    FROM public.krim_organization_members m
    JOIN public.krim_organizations o ON o.id = m.organization_id
    WHERE m.user_id = (SELECT auth.uid())
      AND m.status = 'active'
      AND o.status = 'active'
      AND lower(coalesce(o.organization_type_code, o.organization_type, '')) = 'operations'
      AND public.krim_has_permission((SELECT auth.uid()), m.organization_id, 'shipment.view')
  )
  OR EXISTS (
    SELECT 1
    FROM public.krim_partner_opportunities po
    JOIN public.krim_organization_members m
      ON m.user_id = (SELECT auth.uid())
     AND m.status = 'active'
    JOIN public.krim_organizations o
      ON o.id = m.organization_id
    WHERE po.shipment_id = public.krim_shipments.id
      AND po.customer_organization_id IS DISTINCT FROM o.id
      AND po.status = 'open'
      AND lower(coalesce(o.organization_type_code, o.organization_type, ''))
        IN ('partner','carrier','forwarder','logistics_provider')
      AND o.status = 'active'
      AND o.partner_account_mode = 'registered_business'
      AND o.partner_verification_status = 'verified'
      AND o.partner_lifecycle_status IN ('approved','active')
      AND o.partner_compliance_status = 'compliant'
      AND private.krim_partner_compliance_is_current(o.id)
      AND private.krim_partner_capability_covers_shipment(o.id, public.krim_shipments.id)
  )
);
