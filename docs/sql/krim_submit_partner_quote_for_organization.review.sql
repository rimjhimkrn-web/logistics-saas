-- KRIM partner quote submission scoped to an explicitly selected partner organization.
-- REVIEW-ONLY: do not execute against production until reviewed and tested with authenticated
-- positive/negative fixtures. This file is a proposed migration payload, not an applied migration.
--
-- Contract differences from krim_submit_partner_quote:
--   * requires p_partner_organization_id; never chooses the user's earliest organization
--   * validates active membership + quote.create permission for that exact organization
--   * retains server-side verification, compliance, currency, opportunity-lock and route checks
--   * updates/reuses a quote only for the same opportunity + selected organization
--
-- Apply only through a reviewed Supabase migration after staging tests and security review.

CREATE OR REPLACE FUNCTION public.krim_submit_partner_quote_for_organization(
  p_opportunity_id bigint,
  p_partner_organization_id bigint,
  p_amount numeric,
  p_currency_code text DEFAULT 'INR',
  p_valid_until timestamptz DEFAULT NULL,
  p_notes text DEFAULT NULL
)
RETURNS public.krim_partner_quotes
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, auth, private
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_organization public.krim_organizations%ROWTYPE;
  v_opportunity public.krim_partner_opportunities%ROWTYPE;
  v_quote public.krim_partner_quotes%ROWTYPE;
  v_currency_code text := upper(nullif(btrim(p_currency_code), ''));
  v_valid_until timestamptz;
  v_quote_number text;
  v_notes text := nullif(btrim(p_notes), '');
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION USING errcode = '28000', message = 'Authentication required';
  END IF;

  IF p_opportunity_id IS NULL OR p_opportunity_id <= 0
     OR p_partner_organization_id IS NULL OR p_partner_organization_id <= 0 THEN
    RAISE EXCEPTION USING errcode = '22023',
      message = 'A valid opportunity and partner organization are required';
  END IF;

  IF p_amount IS NULL OR p_amount <= 0 OR p_amount > 1000000000000 THEN
    RAISE EXCEPTION USING errcode = '22023',
      message = 'Bid amount must be greater than zero and within the supported range';
  END IF;

  IF v_currency_code IS NULL OR v_currency_code !~ '^[A-Z]{3}$' THEN
    RAISE EXCEPTION USING errcode = '22023',
      message = 'A valid three-letter currency code is required';
  END IF;

  IF v_notes IS NOT NULL AND char_length(v_notes) > 1000 THEN
    RAISE EXCEPTION USING errcode = '22023',
      message = 'Bid notes must be 1,000 characters or fewer';
  END IF;

  -- Resolve and authorize only the organization explicitly selected by the client.
  SELECT o.* INTO v_organization
  FROM public.krim_organizations o
  JOIN public.krim_organization_members m
    ON m.organization_id = o.id
   AND m.user_id = v_user_id
   AND m.status = 'active'
  WHERE o.id = p_partner_organization_id
    AND o.organization_type IN ('partner', 'carrier', 'forwarder')
    AND o.status = 'active'
    AND o.partner_account_mode = 'registered_business'
    AND o.partner_verification_status = 'verified'
    AND o.partner_lifecycle_status IN ('approved', 'active')
    AND o.partner_compliance_status = 'compliant'
    AND EXISTS (
      SELECT 1
      FROM public.krim_partner_capabilities pc
      WHERE pc.organization_id = o.id
        AND pc.active IS TRUE
        AND pc.verification_status = 'verified'
        AND (pc.effective_from IS NULL OR pc.effective_from <= now())
        AND (pc.effective_until IS NULL OR pc.effective_until > now())
    );

  IF NOT FOUND THEN
    RAISE EXCEPTION USING errcode = '42501',
      message = 'Selected organization is not an active, verified partner organization with current compliance and an approved capability';
  END IF;

  IF NOT private.krim_has_permission(v_user_id, p_partner_organization_id, 'quote.create') THEN
    RAISE EXCEPTION USING errcode = '42501',
      message = 'Permission denied: selected organization requires quote.create';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.krim_currencies c
    WHERE c.code = v_currency_code AND c.is_active IS TRUE
  ) THEN
    RAISE EXCEPTION USING errcode = '22023',
      message = 'Currency is not active in KRIM configuration';
  END IF;

  -- Serialize submissions for an opportunity and prevent stale/late awards.
  SELECT * INTO v_opportunity
  FROM public.krim_partner_opportunities
  WHERE id = p_opportunity_id
    AND status = 'open'
    AND (response_deadline IS NULL OR response_deadline > now())
    AND awarded_partner_organization_id IS NULL
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION USING errcode = 'P0002',
      message = 'Opportunity is no longer open for bids';
  END IF;

  IF NOT private.krim_partner_capability_covers_shipment(
    p_partner_organization_id, v_opportunity.shipment_id
  ) THEN
    RAISE EXCEPTION USING errcode = '42501',
      message = 'Selected partner capability does not cover the shipment transport mode, both route countries, region or weight limit';
  END IF;

  IF v_opportunity.customer_organization_id = p_partner_organization_id THEN
    RAISE EXCEPTION USING errcode = '42501',
      message = 'A customer organization cannot bid on its own shipment';
  END IF;

  v_valid_until := COALESCE(
    p_valid_until, v_opportunity.response_deadline, now() + interval '7 days'
  );
  IF v_opportunity.response_deadline IS NOT NULL
     AND v_valid_until > v_opportunity.response_deadline THEN
    v_valid_until := v_opportunity.response_deadline;
  END IF;
  IF v_valid_until <= now() THEN
    RAISE EXCEPTION USING errcode = '22023',
      message = 'Bid validity must be in the future';
  END IF;

  SELECT * INTO v_quote
  FROM public.krim_partner_quotes
  WHERE opportunity_id = p_opportunity_id
    AND partner_organization_id = p_partner_organization_id
    AND status IN ('submitted', 'under_review', 'shortlisted')
  ORDER BY created_at DESC
  LIMIT 1
  FOR UPDATE;

  IF v_quote.id IS NOT NULL THEN
    UPDATE public.krim_partner_quotes
    SET amount = p_amount,
        currency_code = v_currency_code,
        valid_until = v_valid_until,
        status = 'submitted',
        submitted_at = now(),
        notes = v_notes,
        pricing_snapshot = jsonb_build_object(
          'amount', p_amount,
          'currency_code', v_currency_code,
          'method', 'partner_submitted_bid',
          'opportunity_number', v_opportunity.opportunity_number,
          'submitted_at', now()
        ),
        metadata = COALESCE(metadata, '{}'::jsonb) ||
          jsonb_build_object(
            'source', 'partner_load_marketplace',
            'last_updated_by', v_user_id,
            'partner_organization_id', p_partner_organization_id
          ),
        updated_at = now()
    WHERE id = v_quote.id
    RETURNING * INTO v_quote;
  ELSE
    v_quote_number := 'KPQ-' || to_char(now(), 'YYYYMMDD') || '-' ||
      upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8));

    INSERT INTO public.krim_partner_quotes (
      opportunity_id, shipment_id, partner_organization_id, quote_number,
      amount, currency_code, valid_until, status, submitted_at, notes,
      pricing_snapshot, metadata
    ) VALUES (
      v_opportunity.id, v_opportunity.shipment_id, p_partner_organization_id,
      v_quote_number, p_amount, v_currency_code, v_valid_until, 'submitted',
      now(), v_notes,
      jsonb_build_object(
        'amount', p_amount,
        'currency_code', v_currency_code,
        'method', 'partner_submitted_bid',
        'opportunity_number', v_opportunity.opportunity_number,
        'submitted_at', now()
      ),
      jsonb_build_object(
        'source', 'partner_load_marketplace',
        'submitted_by', v_user_id,
        'partner_organization_id', p_partner_organization_id
      )
    )
    RETURNING * INTO v_quote;
  END IF;

  INSERT INTO public.krim_audit_events (
    actor_user_id, organization_id, event_type, entity_type, entity_id, source, metadata
  ) VALUES (
    v_user_id, p_partner_organization_id, 'partner.quote.submitted',
    'partner_quote', v_quote.id::text, 'partner_load_marketplace',
    jsonb_build_object(
      'opportunity_id', v_opportunity.id,
      'shipment_id', v_opportunity.shipment_id,
      'currency_code', v_currency_code,
      'partner_organization_id', p_partner_organization_id
    )
  );

  RETURN v_quote;
END;
$function$;

-- A SECURITY DEFINER RPC must not be executable by anon/PUBLIC.
REVOKE ALL ON FUNCTION public.krim_submit_partner_quote_for_organization(
  bigint, bigint, numeric, text, timestamptz, text
) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.krim_submit_partner_quote_for_organization(
  bigint, bigint, numeric, text, timestamptz, text
) TO authenticated;

-- Required staging test matrix before the app is allowed to call this RPC:
-- 1. Signed-out call -> SQLSTATE 28000.
-- 2. User not a member of selected org -> 42501.
-- 3. User belongs to org A and B; explicitly select B -> returned quote belongs to B.
-- 4. User belongs to org A and B; select B without quote.create in B -> 42501.
-- 5. Unverified/suspended/noncompliant org -> 42501.
-- 6. Inactive, expired, wrong-mode, wrong-country, wrong-region or overweight capability -> 42501.
-- 7. Customer org bidding on its own shipment -> 42501.
-- 8. Closed/awarded/expired opportunity -> P0002.
-- 9. Invalid amount/currency/notes/validity -> 22023.
-- 10. Repeated submission for same org/opportunity updates only that org's active quote.
-- 11. Two different eligible organizations can each create their own quote for one opportunity.
-- 12. Audit event organization_id and quote.partner_organization_id equal the explicit selection.
-- 13. Confirm anon cannot execute; authenticated can execute; no PUBLIC execute remains.
-- 14. Confirm existing legacy RPC remains unchanged until all clients are migrated.
