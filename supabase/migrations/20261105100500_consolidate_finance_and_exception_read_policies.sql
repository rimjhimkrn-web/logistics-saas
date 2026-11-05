DROP POLICY IF EXISTS "KRIM customs managers can view exceptions" ON public.krim_exceptions;
DROP POLICY IF EXISTS "KRIM exceptions permission-scoped organization access" ON public.krim_exceptions;
DROP POLICY IF EXISTS "KRIM operations managers can view exceptions" ON public.krim_exceptions;
CREATE POLICY "KRIM exceptions scoped read"
ON public.krim_exceptions FOR SELECT TO authenticated
USING (
  private.krim_has_permission((SELECT auth.uid()), organization_id, 'shipment.view')
  OR private.krim_has_permission((SELECT auth.uid()), organization_id, 'compliance.view')
  OR EXISTS (
    SELECT 1 FROM public.krim_organization_members m
    JOIN public.krim_organizations o ON o.id=m.organization_id
    WHERE m.user_id=(SELECT auth.uid()) AND m.status='active' AND o.status='active'
      AND lower(coalesce(o.organization_type,''))='customs'
      AND public.krim_has_permission((SELECT auth.uid()),m.organization_id,'compliance.view')
  )
  OR EXISTS (
    SELECT 1 FROM public.krim_organization_members m
    JOIN public.krim_organizations o ON o.id=m.organization_id
    WHERE m.user_id=(SELECT auth.uid()) AND m.status='active' AND o.status='active'
      AND lower(coalesce(o.organization_type,''))='operations'
      AND public.krim_has_permission((SELECT auth.uid()),m.organization_id,'shipment.view')
  )
);

DROP POLICY IF EXISTS "KRIM finance managers can view invoices" ON public.krim_invoices;
DROP POLICY IF EXISTS "KRIM invoices finance permission access" ON public.krim_invoices;
CREATE POLICY "KRIM invoices scoped read"
ON public.krim_invoices FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.krim_organization_members m
    JOIN public.krim_organizations o ON o.id=m.organization_id
    WHERE m.user_id=(SELECT auth.uid()) AND m.status='active' AND o.status='active'
      AND lower(coalesce(o.organization_type,''))='finance'
      AND public.krim_has_permission((SELECT auth.uid()),m.organization_id,'finance.view')
  )
  OR (organization_id IS NOT NULL AND private.krim_has_permission((SELECT auth.uid()),organization_id,'finance.view'))
  OR (customer_organization_id IS NOT NULL AND private.krim_has_permission((SELECT auth.uid()),customer_organization_id,'finance.view'))
  OR (supplier_organization_id IS NOT NULL AND private.krim_has_permission((SELECT auth.uid()),supplier_organization_id,'finance.view'))
  OR (partner_organization_id IS NOT NULL AND private.krim_has_permission((SELECT auth.uid()),partner_organization_id,'finance.view'))
);

DROP POLICY IF EXISTS "KRIM finance managers can view settlements" ON public.krim_settlements;
DROP POLICY IF EXISTS "KRIM settlements finance permission access" ON public.krim_settlements;
CREATE POLICY "KRIM settlements scoped read"
ON public.krim_settlements FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.krim_organization_members m
    JOIN public.krim_organizations o ON o.id=m.organization_id
    WHERE m.user_id=(SELECT auth.uid()) AND m.status='active' AND o.status='active'
      AND lower(coalesce(o.organization_type,''))='finance'
      AND public.krim_has_permission((SELECT auth.uid()),m.organization_id,'finance.view')
  )
  OR (organization_id IS NOT NULL AND private.krim_has_permission((SELECT auth.uid()),organization_id,'finance.view'))
  OR (partner_organization_id IS NOT NULL AND private.krim_has_permission((SELECT auth.uid()),partner_organization_id,'finance.view'))
);
