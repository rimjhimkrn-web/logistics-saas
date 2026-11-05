-- Step 1: expose open commercial opportunities only to registered businesses
-- with a currently verified capability that covers the specific shipment.
DROP POLICY IF EXISTS "KRIM verified partners can view open opportunities"
  ON public.krim_partner_opportunities;

CREATE POLICY "KRIM verified capable businesses can view open opportunities"
  ON public.krim_partner_opportunities
  FOR SELECT TO authenticated
  USING (
    status = 'open'
    AND EXISTS (
      SELECT 1
      FROM public.krim_organization_members m
      JOIN public.krim_organizations o ON o.id = m.organization_id
      WHERE m.user_id = (SELECT auth.uid())
        AND m.status = 'active'
        AND o.organization_type IN ('partner', 'carrier', 'forwarder')
        AND o.status = 'active'
        AND o.partner_account_mode = 'registered_business'
        AND o.partner_verification_status IN ('verified', 'approved')
        AND o.partner_lifecycle_status IN ('active', 'verified')
        AND o.partner_compliance_status IN
          ('clear', 'compliant', 'approved', 'verified', 'not_required', 'not_applicable')
        AND EXISTS (
          SELECT 1
          FROM public.krim_partner_capabilities pc
          WHERE pc.organization_id = o.id
            AND pc.active IS TRUE
            AND pc.verification_status = 'verified'
            AND (pc.effective_from IS NULL OR pc.effective_from <= now())
            AND (pc.effective_until IS NULL OR pc.effective_until > now())
        )
        AND private.krim_partner_capability_covers_shipment(
          o.id, krim_partner_opportunities.shipment_id
        )
    )
  );

DROP POLICY IF EXISTS "KRIM verified partners can view open opportunity shipments"
  ON public.krim_shipments;

CREATE POLICY "KRIM verified capable businesses can view open opportunity shipments"
  ON public.krim_shipments
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.krim_partner_opportunities po
      JOIN public.krim_organization_members m
        ON m.user_id = (SELECT auth.uid())
       AND m.status = 'active'
      JOIN public.krim_organizations o ON o.id = m.organization_id
      WHERE po.shipment_id = krim_shipments.id
        AND po.status = 'open'
        AND o.organization_type IN ('partner', 'carrier', 'forwarder')
        AND o.status = 'active'
        AND o.partner_account_mode = 'registered_business'
        AND o.partner_verification_status IN ('verified', 'approved')
        AND o.partner_lifecycle_status IN ('active', 'verified')
        AND o.partner_compliance_status IN
          ('clear', 'compliant', 'approved', 'verified', 'not_required', 'not_applicable')
        AND EXISTS (
          SELECT 1
          FROM public.krim_partner_capabilities pc
          WHERE pc.organization_id = o.id
            AND pc.active IS TRUE
            AND pc.verification_status = 'verified'
            AND (pc.effective_from IS NULL OR pc.effective_from <= now())
            AND (pc.effective_until IS NULL OR pc.effective_until > now())
        )
        AND private.krim_partner_capability_covers_shipment(
          o.id, krim_shipments.id
        )
    )
  );
