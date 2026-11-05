-- Narrow broad organization-membership SELECT policies to the relevant domain permission.
-- Existing role-specific customs, operations, finance and partner-assignment policies remain intact.

DROP POLICY IF EXISTS "KRIM exceptions organization access" ON public.krim_exceptions;
CREATE POLICY "KRIM exceptions permission-scoped organization access"
ON public.krim_exceptions
FOR SELECT TO authenticated
USING (
  private.krim_has_permission((SELECT auth.uid()), organization_id, 'shipment.view')
  OR private.krim_has_permission((SELECT auth.uid()), organization_id, 'compliance.view')
);

DROP POLICY IF EXISTS "KRIM invoices organization access" ON public.krim_invoices;
CREATE POLICY "KRIM invoices finance permission access"
ON public.krim_invoices
FOR SELECT TO authenticated
USING (
  (organization_id IS NOT NULL AND private.krim_has_permission((SELECT auth.uid()), organization_id, 'finance.view'))
  OR (customer_organization_id IS NOT NULL AND private.krim_has_permission((SELECT auth.uid()), customer_organization_id, 'finance.view'))
  OR (supplier_organization_id IS NOT NULL AND private.krim_has_permission((SELECT auth.uid()), supplier_organization_id, 'finance.view'))
  OR (partner_organization_id IS NOT NULL AND private.krim_has_permission((SELECT auth.uid()), partner_organization_id, 'finance.view'))
);

DROP POLICY IF EXISTS "KRIM settlements organization access" ON public.krim_settlements;
CREATE POLICY "KRIM settlements finance permission access"
ON public.krim_settlements
FOR SELECT TO authenticated
USING (
  (organization_id IS NOT NULL AND private.krim_has_permission((SELECT auth.uid()), organization_id, 'finance.view'))
  OR (partner_organization_id IS NOT NULL AND private.krim_has_permission((SELECT auth.uid()), partner_organization_id, 'finance.view'))
);

DROP POLICY IF EXISTS "KRIM shipment alerts organization access" ON public.krim_shipment_alerts;
CREATE POLICY "KRIM shipment alerts customer permission access"
ON public.krim_shipment_alerts
FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.krim_shipments s
    WHERE s.id = krim_shipment_alerts.shipment_id
      AND private.krim_has_permission((SELECT auth.uid()), s.customer_organization_id, 'shipment.view')
  )
);

DROP POLICY IF EXISTS "KRIM shipment customs organization access" ON public.krim_shipment_customs;
CREATE POLICY "KRIM shipment customs customer permission access"
ON public.krim_shipment_customs
FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.krim_shipments s
    WHERE s.id = krim_shipment_customs.shipment_id
      AND private.krim_has_permission((SELECT auth.uid()), s.customer_organization_id, 'shipment.view')
  )
);

DROP POLICY IF EXISTS "KRIM shipment milestones organization access" ON public.krim_shipment_milestones;
CREATE POLICY "KRIM shipment milestones customer permission access"
ON public.krim_shipment_milestones
FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.krim_shipments s
    WHERE s.id = krim_shipment_milestones.shipment_id
      AND private.krim_has_permission((SELECT auth.uid()), s.customer_organization_id, 'shipment.view')
  )
);
