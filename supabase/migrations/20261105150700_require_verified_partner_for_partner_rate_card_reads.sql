-- Partner-owned commercial rate cards and their charge lines are visible
-- only to active members of an active, verified, compliant registered business.
-- Customer-bound cards remain organization-scoped. Unscoped customer tariffs
-- remain limited to effective cards and shipment.create permission.

DROP POLICY IF EXISTS "KRIM rate cards organization access" ON public.krim_rate_cards;
CREATE POLICY "KRIM rate cards organization access"
ON public.krim_rate_cards
FOR SELECT TO authenticated
USING (
  (
    organization_id IS NOT NULL
    AND private.krim_has_organization_access((SELECT auth.uid()), organization_id)
    AND EXISTS (
      SELECT 1 FROM public.krim_organizations owner_org
      WHERE owner_org.id = organization_id
        AND (
          lower(coalesce(owner_org.organization_type_code,owner_org.organization_type,'')) NOT IN
            ('partner','carrier','forwarder','logistics_provider','warehouse','warehouse_operator')
          OR (
            lower(coalesce(owner_org.status,''))='active'
            AND lower(coalesce(owner_org.partner_account_mode,''))='registered_business'
            AND lower(coalesce(owner_org.partner_verification_status,'')) IN ('verified','approved')
            AND lower(coalesce(owner_org.partner_lifecycle_status,'')) IN ('active','verified')
            AND lower(coalesce(owner_org.partner_compliance_status,'')) IN ('clear','compliant','approved','verified','not_required','not_applicable')
          )
        )
    )
  )
  OR (
    customer_organization_id IS NOT NULL
    AND private.krim_has_organization_access((SELECT auth.uid()), customer_organization_id)
  )
  OR (
    partner_organization_id IS NOT NULL
    AND private.krim_has_organization_access((SELECT auth.uid()), partner_organization_id)
    AND EXISTS (
      SELECT 1 FROM public.krim_organizations partner_org
      WHERE partner_org.id = partner_organization_id
        AND lower(coalesce(partner_org.status,''))='active'
        AND lower(coalesce(partner_org.organization_type_code,partner_org.organization_type,'')) IN
          ('partner','carrier','forwarder','logistics_provider','warehouse','warehouse_operator')
        AND lower(coalesce(partner_org.partner_account_mode,''))='registered_business'
        AND lower(coalesce(partner_org.partner_verification_status,'')) IN ('verified','approved')
        AND lower(coalesce(partner_org.partner_lifecycle_status,'')) IN ('active','verified')
        AND lower(coalesce(partner_org.partner_compliance_status,'')) IN ('clear','compliant','approved','verified','not_required','not_applicable')
    )
  )
  OR (
    organization_id IS NULL AND customer_organization_id IS NULL AND partner_organization_id IS NULL
    AND status='active' AND rate_type IN ('customer','tariff')
    AND (valid_from IS NULL OR valid_from<=now())
    AND (valid_until IS NULL OR valid_until>now())
    AND EXISTS (
      SELECT 1 FROM public.krim_organization_members m
      WHERE m.user_id=(SELECT auth.uid()) AND lower(m.status)='active'
        AND private.krim_has_permission((SELECT auth.uid()),m.organization_id,'shipment.create')
    )
  )
);

DROP POLICY IF EXISTS "KRIM rate lines via card access" ON public.krim_rate_lines;
CREATE POLICY "KRIM rate lines via card access"
ON public.krim_rate_lines
FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.krim_rate_cards rc
    WHERE rc.id=krim_rate_lines.rate_card_id
      AND (
        (
          rc.organization_id IS NOT NULL
          AND private.krim_has_organization_access((SELECT auth.uid()),rc.organization_id)
          AND EXISTS (
            SELECT 1 FROM public.krim_organizations owner_org
            WHERE owner_org.id=rc.organization_id
              AND (
                lower(coalesce(owner_org.organization_type_code,owner_org.organization_type,'')) NOT IN
                  ('partner','carrier','forwarder','logistics_provider','warehouse','warehouse_operator')
                OR (
                  lower(coalesce(owner_org.status,''))='active'
                  AND lower(coalesce(owner_org.partner_account_mode,''))='registered_business'
                  AND lower(coalesce(owner_org.partner_verification_status,'')) IN ('verified','approved')
                  AND lower(coalesce(owner_org.partner_lifecycle_status,'')) IN ('active','verified')
                  AND lower(coalesce(owner_org.partner_compliance_status,'')) IN ('clear','compliant','approved','verified','not_required','not_applicable')
                )
              )
          )
        )
        OR (rc.customer_organization_id IS NOT NULL AND private.krim_has_organization_access((SELECT auth.uid()),rc.customer_organization_id))
        OR (
          rc.partner_organization_id IS NOT NULL
          AND private.krim_has_organization_access((SELECT auth.uid()),rc.partner_organization_id)
          AND EXISTS (
            SELECT 1 FROM public.krim_organizations partner_org
            WHERE partner_org.id=rc.partner_organization_id
              AND lower(coalesce(partner_org.status,''))='active'
              AND lower(coalesce(partner_org.organization_type_code,partner_org.organization_type,'')) IN
                ('partner','carrier','forwarder','logistics_provider','warehouse','warehouse_operator')
              AND lower(coalesce(partner_org.partner_account_mode,''))='registered_business'
              AND lower(coalesce(partner_org.partner_verification_status,'')) IN ('verified','approved')
              AND lower(coalesce(partner_org.partner_lifecycle_status,'')) IN ('active','verified')
              AND lower(coalesce(partner_org.partner_compliance_status,'')) IN ('clear','compliant','approved','verified','not_required','not_applicable')
          )
        )
        OR (
          rc.organization_id IS NULL AND rc.customer_organization_id IS NULL AND rc.partner_organization_id IS NULL
          AND rc.status='active' AND rc.rate_type IN ('customer','tariff')
          AND (rc.valid_from IS NULL OR rc.valid_from<=now())
          AND (rc.valid_until IS NULL OR rc.valid_until>now())
          AND EXISTS (
            SELECT 1 FROM public.krim_organization_members m
            WHERE m.user_id=(SELECT auth.uid()) AND lower(m.status)='active'
              AND private.krim_has_permission((SELECT auth.uid()),m.organization_id,'shipment.create')
          )
        )
      )
  )
);
