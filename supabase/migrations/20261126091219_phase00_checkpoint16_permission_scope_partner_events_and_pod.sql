-- Phase 00 / Checkpoint 16
-- Scope partner execution events and POD reads to explicit organization permissions.
-- Partner organizations retain access to their own PODs for operational review,
-- but only members with document.view may read them. Customer organizations
-- see verified PODs only and must hold document.view. Execution events require
-- tracking.view on the relevant partner or customer organization.

DROP POLICY IF EXISTS "KRIM partner execution events organization access"
ON public.krim_partner_execution_events;

CREATE POLICY "KRIM partner execution events permission scoped"
ON public.krim_partner_execution_events
FOR SELECT TO authenticated
USING (
  (
    private.krim_has_organization_access((SELECT auth.uid()), partner_organization_id)
    AND private.krim_has_permission((SELECT auth.uid()), partner_organization_id, 'tracking.view')
  )
  OR
  (
    EXISTS (
      SELECT 1
      FROM public.krim_shipments s
      WHERE s.id = krim_partner_execution_events.shipment_id
        AND s.customer_organization_id IS NOT NULL
        AND private.krim_has_organization_access((SELECT auth.uid()), s.customer_organization_id)
        AND private.krim_has_permission((SELECT auth.uid()), s.customer_organization_id, 'tracking.view')
    )
  )
);

DROP POLICY IF EXISTS "KRIM POD stakeholder read"
ON public.krim_pod_records;

CREATE POLICY "KRIM POD stakeholder permission scoped"
ON public.krim_pod_records
FOR SELECT TO authenticated
USING (
  (
    status = 'verified'
    AND verified_at IS NOT NULL
    AND EXISTS (
      SELECT 1
      FROM public.krim_shipments s
      WHERE s.id = krim_pod_records.shipment_id
        AND s.customer_organization_id IS NOT NULL
        AND private.krim_has_organization_access((SELECT auth.uid()), s.customer_organization_id)
        AND private.krim_has_permission((SELECT auth.uid()), s.customer_organization_id, 'document.view')
    )
  )
  OR
  (
    private.krim_has_organization_access((SELECT auth.uid()), partner_organization_id)
    AND private.krim_has_permission((SELECT auth.uid()), partner_organization_id, 'document.view')
  )
);
