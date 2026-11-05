-- Scope unassigned/global rate cards to effective customer-facing tariffs.
-- Organization-bound cards remain visible only to active members of the
-- customer, partner, or owning organization. Rate lines inherit card visibility.

DROP POLICY IF EXISTS "KRIM rate cards organization access" ON public.krim_rate_cards;
CREATE POLICY "KRIM rate cards organization access"
ON public.krim_rate_cards
FOR SELECT
TO authenticated
USING (
  (
    organization_id IS NOT NULL
    AND private.krim_has_organization_access((SELECT auth.uid()), organization_id)
  )
  OR (
    customer_organization_id IS NOT NULL
    AND private.krim_has_organization_access((SELECT auth.uid()), customer_organization_id)
  )
  OR (
    partner_organization_id IS NOT NULL
    AND private.krim_has_organization_access((SELECT auth.uid()), partner_organization_id)
  )
  OR (
    organization_id IS NULL
    AND customer_organization_id IS NULL
    AND partner_organization_id IS NULL
    AND status = 'active'
    AND rate_type IN ('customer','tariff')
    AND (valid_from IS NULL OR valid_from <= now())
    AND (valid_until IS NULL OR valid_until > now())
  )
);

DROP POLICY IF EXISTS "KRIM rate lines via card access" ON public.krim_rate_lines;
CREATE POLICY "KRIM rate lines via card access"
ON public.krim_rate_lines
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.krim_rate_cards rc
    WHERE rc.id = krim_rate_lines.rate_card_id
      AND (
        (
          rc.organization_id IS NOT NULL
          AND private.krim_has_organization_access((SELECT auth.uid()), rc.organization_id)
        )
        OR (
          rc.customer_organization_id IS NOT NULL
          AND private.krim_has_organization_access((SELECT auth.uid()), rc.customer_organization_id)
        )
        OR (
          rc.partner_organization_id IS NOT NULL
          AND private.krim_has_organization_access((SELECT auth.uid()), rc.partner_organization_id)
        )
        OR (
          rc.organization_id IS NULL
          AND rc.customer_organization_id IS NULL
          AND rc.partner_organization_id IS NULL
          AND rc.status = 'active'
          AND rc.rate_type IN ('customer','tariff')
          AND (rc.valid_from IS NULL OR rc.valid_from <= now())
          AND (rc.valid_until IS NULL OR rc.valid_until > now())
        )
      )
  )
);
