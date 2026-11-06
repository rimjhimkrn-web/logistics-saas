-- Until an explicit shipment-to-customs-broker assignment model is in place,
-- customs organizations must not receive cross-customer shipment customs records.
DROP POLICY IF EXISTS "KRIM shipment customs scoped read" ON public.krim_shipment_customs;
CREATE POLICY "KRIM shipment customs customer scoped read"
ON public.krim_shipment_customs
FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.krim_shipments s
    WHERE s.id = krim_shipment_customs.shipment_id
      AND private.krim_has_permission(auth.uid(), s.customer_organization_id, 'shipment.view')
  )
);

-- Remove the unscoped customs-organization branch. Customs staff gain exception
-- visibility only after the platform establishes a shipment-specific broker link.
DROP POLICY IF EXISTS "KRIM exceptions scoped read" ON public.krim_exceptions;
CREATE POLICY "KRIM exceptions scoped read"
ON public.krim_exceptions
FOR SELECT TO authenticated
USING (
  private.krim_has_permission(auth.uid(), organization_id, 'shipment.view')
  OR private.krim_has_permission(auth.uid(), organization_id, 'compliance.view')
  OR EXISTS (
    SELECT 1
    FROM public.krim_organization_members m
    JOIN public.krim_organizations o ON o.id = m.organization_id
    WHERE m.user_id = auth.uid()
      AND m.status = 'active'
      AND o.status = 'active'
      AND lower(coalesce(o.organization_type, '')) = 'operations'
      AND public.krim_has_permission(auth.uid(), m.organization_id, 'shipment.view')
  )
);
