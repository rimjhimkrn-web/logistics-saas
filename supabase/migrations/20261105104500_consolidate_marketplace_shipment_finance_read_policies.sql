DROP POLICY IF EXISTS "KRIM partner opportunities organization access" ON public.krim_partner_opportunities;
DROP POLICY IF EXISTS "KRIM verified partners can view open opportunities" ON public.krim_partner_opportunities;
CREATE POLICY "KRIM partner opportunities scoped read"
ON public.krim_partner_opportunities FOR SELECT TO authenticated
USING (
  private.krim_has_organization_access((SELECT auth.uid()), customer_organization_id)
  OR (awarded_partner_organization_id IS NOT NULL AND private.krim_has_organization_access((SELECT auth.uid()), awarded_partner_organization_id))
  OR private.krim_has_permission((SELECT auth.uid()), 1::bigint, 'admin.platform')
  OR (
    status='open'
    AND EXISTS (
      SELECT 1 FROM public.krim_organization_members m
      JOIN public.krim_organizations o ON o.id=m.organization_id
      WHERE m.user_id=(SELECT auth.uid()) AND m.status='active'
        AND o.organization_type=ANY(ARRAY['partner','carrier','forwarder'])
        AND o.status='active' AND o.partner_account_mode='registered_business'
        AND o.partner_verification_status=ANY(ARRAY['verified','approved'])
        AND o.partner_lifecycle_status=ANY(ARRAY['active','verified'])
        AND o.partner_compliance_status=ANY(ARRAY['clear','compliant','approved','verified','not_required','not_applicable'])
        AND EXISTS (
          SELECT 1 FROM public.krim_partner_capabilities pc
          WHERE pc.organization_id=o.id AND pc.active IS TRUE
            AND pc.verification_status='verified'
            AND (pc.effective_from IS NULL OR pc.effective_from<=now())
            AND (pc.effective_until IS NULL OR pc.effective_until>now())
        )
        AND private.krim_partner_capability_covers_shipment(o.id,krim_partner_opportunities.shipment_id)
    )
  )
);

DROP POLICY IF EXISTS "KRIM assigned partners can view assigned shipments" ON public.krim_shipments;
DROP POLICY IF EXISTS "KRIM operations managers can view shipments" ON public.krim_shipments;
DROP POLICY IF EXISTS "KRIM shipments organization access" ON public.krim_shipments;
DROP POLICY IF EXISTS "KRIM verified partners can view open opportunity shipments" ON public.krim_shipments;
CREATE POLICY "KRIM shipments scoped read"
ON public.krim_shipments FOR SELECT TO authenticated
USING (
  private.krim_user_has_active_partner_assignment(id)
  OR (
    customer_organization_id IS NOT NULL
    AND private.krim_has_organization_access((SELECT auth.uid()),customer_organization_id)
  )
  OR EXISTS (
    SELECT 1 FROM public.krim_organization_members m
    JOIN public.krim_organizations o ON o.id=m.organization_id
    WHERE m.user_id=(SELECT auth.uid()) AND m.status='active' AND o.status='active'
      AND lower(coalesce(o.organization_type,''))='operations'
      AND public.krim_has_permission((SELECT auth.uid()),m.organization_id,'shipment.view')
  )
  OR EXISTS (
    SELECT 1
    FROM public.krim_partner_opportunities po
    JOIN public.krim_organization_members m ON m.user_id=(SELECT auth.uid()) AND m.status='active'
    JOIN public.krim_organizations o ON o.id=m.organization_id
    WHERE po.shipment_id=krim_shipments.id AND po.status='open'
      AND o.organization_type=ANY(ARRAY['partner','carrier','forwarder'])
      AND o.status='active' AND o.partner_account_mode='registered_business'
      AND o.partner_verification_status=ANY(ARRAY['verified','approved'])
      AND o.partner_lifecycle_status=ANY(ARRAY['active','verified'])
      AND o.partner_compliance_status=ANY(ARRAY['clear','compliant','approved','verified','not_required','not_applicable'])
      AND EXISTS (
        SELECT 1 FROM public.krim_partner_capabilities pc
        WHERE pc.organization_id=o.id AND pc.active IS TRUE
          AND pc.verification_status='verified'
          AND (pc.effective_from IS NULL OR pc.effective_from<=now())
          AND (pc.effective_until IS NULL OR pc.effective_until>now())
      )
      AND private.krim_partner_capability_covers_shipment(o.id,krim_shipments.id)
  )
);

DROP POLICY IF EXISTS "Customers can view their own payment orders" ON public.payment_orders;
DROP POLICY IF EXISTS "KRIM finance managers can view payment orders" ON public.payment_orders;
CREATE POLICY "KRIM payment orders scoped read"
ON public.payment_orders FOR SELECT TO authenticated
USING (
  customer_id=(SELECT auth.uid())
  OR EXISTS (
    SELECT 1 FROM public.krim_organization_members m
    JOIN public.krim_organizations o ON o.id=m.organization_id
    WHERE m.user_id=(SELECT auth.uid()) AND m.status='active' AND o.status='active'
      AND lower(coalesce(o.organization_type,''))='finance'
      AND public.krim_has_permission((SELECT auth.uid()),m.organization_id,'finance.view')
  )
);

DROP POLICY IF EXISTS "Allow authorized read on revenue_ledger" ON public.revenue_ledger;
DROP POLICY IF EXISTS "KRIM finance managers can view revenue ledger" ON public.revenue_ledger;
CREATE POLICY "KRIM revenue ledger scoped read"
ON public.revenue_ledger FOR SELECT TO authenticated
USING (
  (customer_organization_id IS NOT NULL AND private.krim_has_organization_access((SELECT auth.uid()),customer_organization_id))
  OR EXISTS (
    SELECT 1 FROM public.krim_organization_members m
    JOIN public.krim_organizations o ON o.id=m.organization_id
    WHERE m.user_id=(SELECT auth.uid()) AND m.status='active' AND o.status='active'
      AND lower(coalesce(o.organization_type,''))='finance'
      AND public.krim_has_permission((SELECT auth.uid()),m.organization_id,'finance.view')
  )
);
