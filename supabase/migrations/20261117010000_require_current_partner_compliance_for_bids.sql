-- Require a current, approved compliance review at the moment a partner submits or updates a bid.
-- This closes the gap between broad organization status flags and the authoritative review-validity check.
CREATE OR REPLACE FUNCTION public.krim_submit_partner_quote(
  p_opportunity_id bigint,
  p_amount numeric,
  p_currency_code text DEFAULT 'INR'::text,
  p_valid_until timestamp with time zone DEFAULT NULL::timestamp with time zone,
  p_notes text DEFAULT NULL::text
)
RETURNS public.krim_partner_quotes
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_partner_organization_id bigint;
  v_partner_organization_ids bigint[];
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
  IF p_opportunity_id IS NULL OR p_opportunity_id <= 0 THEN
    RAISE EXCEPTION USING errcode = '22023', message = 'A valid opportunity is required';
  END IF;
  IF p_amount IS NULL OR p_amount <= 0 OR p_amount > 1000000000000 THEN
    RAISE EXCEPTION USING errcode = '22023', message = 'Bid amount must be greater than zero and within the supported range';
  END IF;
  IF v_currency_code IS NULL OR v_currency_code !~ '^[A-Z]{3}$' THEN
    RAISE EXCEPTION USING errcode = '22023', message = 'A valid three-letter currency code is required';
  END IF;
  IF v_notes IS NOT NULL AND char_length(v_notes) > 1000 THEN
    RAISE EXCEPTION USING errcode = '22023', message = 'Bid notes must be 1,000 characters or fewer';
  END IF;

  SELECT array_agg(DISTINCT o.id ORDER BY o.id)
    INTO v_partner_organization_ids
  FROM public.krim_organization_members m
  JOIN public.krim_organizations o ON o.id = m.organization_id
  WHERE m.user_id = v_user_id
    AND m.status = 'active'
    AND lower(coalesce(o.organization_type_code, o.organization_type)) IN ('partner', 'carrier', 'forwarder', 'logistics_provider')
    AND o.status = 'active'
    AND o.partner_account_mode = 'registered_business'
    AND EXISTS (
      SELECT 1 FROM public.krim_partner_capabilities pc
      WHERE pc.organization_id = o.id
        AND pc.active IS TRUE
        AND pc.verification_status = 'verified'
        AND (pc.effective_from IS NULL OR pc.effective_from <= now())
        AND (pc.effective_until IS NULL OR pc.effective_until > now())
    )
    AND o.partner_verification_status IN ('verified', 'approved')
    AND o.partner_lifecycle_status IN ('active', 'verified')
    AND o.partner_compliance_status IN ('clear', 'compliant', 'approved', 'verified', 'not_required', 'not_applicable')
    AND private.krim_partner_compliance_is_current(o.id);

  IF coalesce(cardinality(v_partner_organization_ids), 0) = 0 THEN
    RAISE EXCEPTION USING errcode = '42501', message = 'Only verified registered-business organisations with an active approved capability and current compliance approval may submit partner bids';
  ELSIF cardinality(v_partner_organization_ids) > 1 THEN
    RAISE EXCEPTION USING errcode = '42501', message = 'Multiple eligible partner organisations are linked to this account. Contact KRIM support to select the correct organisation before bidding';
  END IF;
  v_partner_organization_id := v_partner_organization_ids[1];

  IF NOT private.krim_has_permission(v_user_id, v_partner_organization_id, 'quote.create') THEN
    RAISE EXCEPTION USING errcode = '42501', message = 'Permission denied: partner quote submission requires quote.create';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.krim_currencies c WHERE c.code = v_currency_code AND c.is_active = true) THEN
    RAISE EXCEPTION USING errcode = '22023', message = 'Currency is not active in KRIM configuration';
  END IF;

  SELECT * INTO v_opportunity
  FROM public.krim_partner_opportunities
  WHERE id = p_opportunity_id
    AND status = 'open'
    AND (response_deadline IS NULL OR response_deadline > now())
    AND awarded_partner_organization_id IS NULL
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION USING errcode = 'P0002', message = 'Opportunity is no longer open for bids';
  END IF;
  IF EXISTS (
    SELECT 1 FROM public.krim_shipment_leg_plans p
    WHERE p.shipment_id=v_opportunity.shipment_id AND p.status='active' AND p.total_legs>1
  ) THEN
    RAISE EXCEPTION USING errcode='55000',
      message='This shipment has an active multi-leg plan. Shipment-wide partner quotes are disabled until leg-specific sourcing is available';
  END IF;

  IF NOT private.krim_partner_capability_covers_shipment(v_partner_organization_id,v_opportunity.shipment_id) THEN
    RAISE EXCEPTION USING errcode = '42501', message = 'Partner capability does not cover the shipment transport mode, both route countries, region or weight limit';
  END IF;
  IF v_opportunity.customer_organization_id = v_partner_organization_id THEN
    RAISE EXCEPTION USING errcode = '42501', message = 'A customer organization cannot bid on its own shipment';
  END IF;

  v_valid_until := COALESCE(p_valid_until, v_opportunity.response_deadline, now() + interval '7 days');
  IF v_opportunity.response_deadline IS NOT NULL AND v_valid_until > v_opportunity.response_deadline THEN
    v_valid_until := v_opportunity.response_deadline;
  END IF;
  IF v_valid_until <= now() THEN
    RAISE EXCEPTION USING errcode = '22023', message = 'Bid validity must be in the future';
  END IF;

  SELECT * INTO v_quote
  FROM public.krim_partner_quotes
  WHERE opportunity_id = p_opportunity_id
    AND partner_organization_id = v_partner_organization_id
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
        metadata = COALESCE(metadata, '{}'::jsonb) || jsonb_build_object('source', 'partner_load_marketplace', 'last_updated_by', v_user_id),
        updated_at = now()
    WHERE id = v_quote.id
    RETURNING * INTO v_quote;
  ELSE
    v_quote_number := 'KPQ-' || to_char(now(), 'YYYYMMDD') || '-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8));
    INSERT INTO public.krim_partner_quotes (
      opportunity_id, shipment_id, partner_organization_id, quote_number,
      amount, currency_code, valid_until, status, submitted_at, notes,
      pricing_snapshot, metadata
    ) VALUES (
      v_opportunity.id, v_opportunity.shipment_id, v_partner_organization_id, v_quote_number,
      p_amount, v_currency_code, v_valid_until, 'submitted', now(), v_notes,
      jsonb_build_object(
        'amount', p_amount,
        'currency_code', v_currency_code,
        'method', 'partner_submitted_bid',
        'opportunity_number', v_opportunity.opportunity_number,
        'submitted_at', now()
      ),
      jsonb_build_object('source', 'partner_load_marketplace', 'submitted_by', v_user_id)
    )
    RETURNING * INTO v_quote;
  END IF;

  INSERT INTO public.krim_audit_events (
    actor_user_id, organization_id, event_type, entity_type, entity_id, source, metadata
  ) VALUES (
    v_user_id, v_partner_organization_id, 'partner.quote.submitted',
    'partner_quote', v_quote.id::text, 'partner_load_marketplace',
    jsonb_build_object('opportunity_id', v_opportunity.id, 'shipment_id', v_opportunity.shipment_id, 'currency_code', v_currency_code)
  );

  RETURN v_quote;
END;
$function$;
