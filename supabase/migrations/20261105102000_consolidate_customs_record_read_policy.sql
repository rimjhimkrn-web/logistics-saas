DROP POLICY IF EXISTS "KRIM customs managers can view customs records" ON public.krim_shipment_customs;
DROP POLICY IF EXISTS "KRIM shipment customs customer permission access" ON public.krim_shipment_customs;
CREATE POLICY "KRIM shipment customs scoped read"
ON public.krim_shipment_customs FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.krim_organization_members m
    JOIN public.krim_organizations o ON o.id=m.organization_id
    WHERE m.user_id=(SELECT auth.uid()) AND m.status='active' AND o.status='active'
      AND lower(coalesce(o.organization_type,''))='customs'
      AND public.krim_has_permission((SELECT auth.uid()),m.organization_id,'compliance.view')
  )
  OR EXISTS (
    SELECT 1 FROM public.krim_shipments s
    WHERE s.id=krim_shipment_customs.shipment_id
      AND private.krim_has_permission((SELECT auth.uid()),s.customer_organization_id,'shipment.view')
  )
);
