-- KRIM partner/customer quote lifecycle consistency and customer-safe partner identity.
-- Provider acceptance is recorded while the shipment remains quoted. Customer acceptance
-- then confirms the quote and atomically finalizes the accepted partner assignment.
-- Customer-facing offer reads are scoped to the customer's own shipment and expose only
-- partner identity and current eligibility fields needed to make a commercial decision.

CREATE OR REPLACE FUNCTION public.krim_set_partner_account_mode(p_mode text, p_profile jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_user_id uuid := auth.uid();
  v_org_id bigint;
  v_verification text;
  v_lifecycle text;
  v_profile jsonb := coalesce(p_profile, '{}'::jsonb);
  v_display_name text;
  v_country_code text;
  v_city text;
  v_service_category text;
  v_metadata_patch jsonb;
  v_partner_org_count integer;
begin
  if v_user_id is null then
    raise exception using errcode = '28000', message = 'Authentication required';
  end if;
  if p_mode is null or p_mode not in ('development_test', 'individual_interest', 'registered_business') then
    raise exception using errcode = '22023', message = 'Unsupported account mode';
  end if;
  if jsonb_typeof(v_profile) <> 'object' then
    raise exception using errcode = '22023', message = 'Profile must be a JSON object';
  end if;

  select count(*)::integer
    into v_partner_org_count
  from public.krim_organization_members m
  join public.krim_organizations o on o.id = m.organization_id
  where m.user_id = v_user_id
    and m.status = 'active'
    and o.status = 'active'
    and lower(coalesce(o.organization_type_code, o.organization_type)) in
      ('partner','carrier','forwarder','logistics_provider','warehouse','warehouse_operator');

  if v_partner_org_count = 0 then
    raise exception using errcode = '42501', message = 'An active partner organization is required';
  elsif v_partner_org_count > 1 then
    raise exception using errcode = '42501', message = 'Multiple active partner organizations are linked to this account. Contact KRIM support to select the correct organization.';
  end if;

  select o.id,
         coalesce(o.partner_verification_status, 'not_started'),
         coalesce(o.partner_lifecycle_status, 'registered')
    into v_org_id, v_verification, v_lifecycle
  from public.krim_organization_members m
  join public.krim_organizations o on o.id = m.organization_id
  where m.user_id = v_user_id
    and m.status = 'active'
    and o.status = 'active'
    and lower(coalesce(o.organization_type_code, o.organization_type)) in
      ('partner','carrier','forwarder','logistics_provider','warehouse','warehouse_operator')
  for update of o;

  if v_org_id is null then
    raise exception using errcode = '42501', message = 'An active partner organization is required';
  end if;
  if v_verification in ('verified','approved') or v_lifecycle in ('approved','active') then
    raise exception using errcode = '42501', message = 'An approved partner organization cannot be switched into a non-commercial mode';
  end if;

  if p_mode = 'individual_interest' then
    v_display_name := nullif(btrim(v_profile->>'display_name'), '');
    v_country_code := upper(nullif(btrim(v_profile->>'country_code'), ''));
    v_city := nullif(btrim(v_profile->>'city'), '');
    v_service_category := nullif(btrim(v_profile->>'service_category'), '');

    if v_display_name is null or char_length(v_display_name) < 2 or char_length(v_display_name) > 120 then
      raise exception using errcode = '22023', message = 'Enter your name (2–120 characters)';
    end if;
    if v_country_code is null or v_country_code !~ '^[A-Z]{2}$' then
      raise exception using errcode = '22023', message = 'Choose a valid two-letter country code';
    end if;
    if v_city is null or char_length(v_city) < 2 or char_length(v_city) > 120 then
      raise exception using errcode = '22023', message = 'Enter your operating city (2–120 characters)';
    end if;
    if v_service_category is null or v_service_category not in ('road_transport','freight_forwarding','warehouse','customs_support','other') then
      raise exception using errcode = '22023', message = 'Choose a supported independent-partner service category';
    end if;

    v_metadata_patch := jsonb_build_object(
      'account_mode', p_mode,
      'account_mode_updated_at', now(),
      'individual_profile', jsonb_build_object(
        'display_name', v_display_name,
        'country_code', v_country_code,
        'city', v_city,
        'service_category', v_service_category,
        'submitted_at', now(),
        'review_status', 'interest_recorded'
      )
    );
  elsif p_mode = 'development_test' then
    v_metadata_patch := jsonb_build_object(
      'account_mode', p_mode,
      'account_mode_updated_at', now(),
      'development_test', jsonb_build_object(
        'enabled', true,
        'commercial_access', false,
        'sample_data_only', true,
        'enabled_at', now()
      )
    );
  else
    v_metadata_patch := jsonb_build_object(
      'account_mode', p_mode,
      'account_mode_updated_at', now()
    );
  end if;

  update public.krim_organizations
  set partner_account_mode = p_mode,
      partner_metadata = (coalesce(partner_metadata, '{}'::jsonb) - 'individual_profile' - 'development_test') || v_metadata_patch,
      updated_at = now()
  where id = v_org_id;

  insert into public.krim_audit_events
    (actor_user_id, organization_id, event_type, entity_type, entity_id, source, metadata, new_state)
  values
    (v_user_id, v_org_id, 'partner.account_mode.selected', 'organization', v_org_id::text,
     'partner_onboarding',
     jsonb_build_object('account_mode', p_mode, 'commercial_access', false),
     jsonb_build_object('account_mode', p_mode, 'commercial_access', false));

  return jsonb_build_object(
    'organization_id', v_org_id,
    'account_mode', p_mode,
    'commercial_access', false,
    'message', case
      when p_mode = 'development_test' then 'Development/test mode enabled. Live commercial operations remain locked.'
      when p_mode = 'individual_interest' then 'Independent partner interest saved. Identity and applicable operating requirements remain pending.'
      else 'Registered business pathway selected. Verification remains pending until genuine documents are submitted and reviewed.'
    end
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.krim_award_partner_quote(p_partner_quote_id bigint)
 RETURNS krim_shipment_partner_assignments
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_quote public.krim_partner_quotes%ROWTYPE;
  v_opportunity public.krim_partner_opportunities%ROWTYPE;
  v_shipment public.krim_shipments%ROWTYPE;
  v_assignment public.krim_shipment_partner_assignments%ROWTYPE;
  v_assignment_number text;
  v_leg_id bigint;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION USING errcode='28000', message='Authentication required';
  END IF;
  IF p_partner_quote_id IS NULL OR p_partner_quote_id <= 0 THEN
    RAISE EXCEPTION USING errcode='22023', message='A valid partner quote is required';
  END IF;

  SELECT * INTO v_quote
  FROM public.krim_partner_quotes
  WHERE id=p_partner_quote_id
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION USING errcode='P0002', message='Partner quote not found';
  END IF;

  SELECT * INTO v_opportunity
  FROM public.krim_partner_opportunities
  WHERE id=v_quote.opportunity_id
  FOR UPDATE;
  IF NOT FOUND OR NOT private.krim_has_organization_access(v_user_id,v_opportunity.customer_organization_id) THEN
    RAISE EXCEPTION USING errcode='42501', message='Opportunity is not accessible to this organization';
  END IF;
  IF NOT private.krim_has_permission(v_user_id,v_opportunity.customer_organization_id,'quote.update')
     OR NOT private.krim_has_permission(v_user_id,v_opportunity.customer_organization_id,'shipment.update') THEN
    RAISE EXCEPTION USING errcode='42501', message='Permission denied: quote award requires quote.update and shipment.update';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.krim_organizations o
    WHERE o.id = v_quote.partner_organization_id
      AND COALESCE(o.partner_account_mode, '') = 'development_test'
  ) THEN
    RAISE EXCEPTION USING errcode='42501', message='Development/test partners cannot be awarded commercial shipments';
  END IF;

  SELECT * INTO v_assignment
  FROM public.krim_shipment_partner_assignments
  WHERE partner_quote_id=p_partner_quote_id
  ORDER BY created_at DESC
  LIMIT 1
  FOR UPDATE;
  IF v_assignment.id IS NOT NULL THEN
    RETURN v_assignment;
  END IF;

  IF v_opportunity.status <> 'open'
     OR v_opportunity.awarded_partner_organization_id IS NOT NULL
     OR (v_opportunity.response_deadline IS NOT NULL AND v_opportunity.response_deadline <= now()) THEN
    RAISE EXCEPTION USING errcode='22023', message='Opportunity is no longer open for award';
  END IF;
  IF v_quote.status NOT IN ('submitted','under_review','shortlisted')
     OR (v_quote.valid_until IS NOT NULL AND v_quote.valid_until <= now()) THEN
    RAISE EXCEPTION USING errcode='22023', message='Partner quote is not eligible for award';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.krim_organizations o
    WHERE o.id=v_quote.partner_organization_id
      AND o.status='active'
      AND lower(coalesce(o.organization_type_code, o.organization_type)) IN ('partner','carrier','forwarder','logistics_provider')
      AND o.partner_account_mode = 'registered_business'
      AND EXISTS (
        SELECT 1 FROM public.krim_partner_capabilities pc
        WHERE pc.organization_id=o.id AND pc.active IS TRUE
          AND pc.verification_status='verified'
          AND (pc.effective_from IS NULL OR pc.effective_from<=now())
          AND (pc.effective_until IS NULL OR pc.effective_until>now())
      )
      AND o.partner_verification_status IN ('verified','approved')
      AND o.partner_lifecycle_status IN ('active','verified')
      AND o.partner_compliance_status IN ('clear','compliant','approved','verified','not_required','not_applicable')
  ) THEN
    RAISE EXCEPTION USING errcode='42501', message='The bidding partner is no longer eligible for assignment';
  END IF;

  SELECT * INTO v_shipment FROM public.krim_shipments WHERE id=v_quote.shipment_id FOR UPDATE;
  IF NOT FOUND OR v_shipment.customer_organization_id <> v_opportunity.customer_organization_id THEN
    RAISE EXCEPTION USING errcode='23503', message='Partner quote shipment does not match the opportunity';
  END IF;
  IF NOT private.krim_partner_capability_covers_shipment(v_quote.partner_organization_id,v_shipment.id) THEN
    RAISE EXCEPTION USING errcode='42501', message='Partner capability no longer covers the shipment route, transport mode or weight';
  END IF;

  SELECT id INTO v_leg_id
  FROM public.krim_shipment_legs
  WHERE shipment_id=v_shipment.id
  ORDER BY leg_sequence ASC
  LIMIT 1;

  UPDATE public.krim_partner_quotes
  SET status='accepted', accepted_at=now(), updated_at=now()
  WHERE id=v_quote.id;

  UPDATE public.krim_partner_quotes
  SET status='rejected', rejected_at=now(), updated_at=now()
  WHERE opportunity_id=v_opportunity.id
    AND id<>v_quote.id
    AND status IN ('submitted','under_review','shortlisted');

  UPDATE public.krim_partner_opportunities
  SET status='awarded',
      awarded_partner_organization_id=v_quote.partner_organization_id,
      awarded_at=now(),
      updated_at=now()
  WHERE id=v_opportunity.id;

  v_assignment_number := 'KPA-' || to_char(now(),'YYYYMMDD') || '-' || upper(substr(replace(gen_random_uuid()::text,'-',''),1,8));
  INSERT INTO public.krim_shipment_partner_assignments (
    shipment_id, shipment_leg_id, partner_organization_id, partner_quote_id,
    assignment_number, status, offered_at, response_deadline, assigned_by, metadata
  ) VALUES (
    v_shipment.id, v_leg_id, v_quote.partner_organization_id, v_quote.id,
    v_assignment_number, 'offered', now(), now()+interval '24 hours', v_user_id,
    jsonb_build_object('source','customer_partner_quote_award','opportunity_id',v_opportunity.id)
  )
  RETURNING * INTO v_assignment;

  -- Keep the shipment quoted until the customer accepts the prepared quote.
  INSERT INTO public.krim_audit_events (
    actor_user_id, organization_id, event_type, entity_type, entity_id, source, metadata
  ) VALUES (
    v_user_id, v_opportunity.customer_organization_id, 'partner.quote.awarded',
    'partner_quote', v_quote.id::text, 'customer_quote_award',
    jsonb_build_object('opportunity_id',v_opportunity.id,'assignment_id',v_assignment.id,'partner_organization_id',v_quote.partner_organization_id)
  );

  RETURN v_assignment;
END;
$function$;

CREATE OR REPLACE FUNCTION public.krim_submit_partner_quote(p_opportunity_id bigint, p_amount numeric, p_currency_code text DEFAULT 'INR'::text, p_valid_until timestamp with time zone DEFAULT NULL::timestamp with time zone, p_notes text DEFAULT NULL::text)
 RETURNS krim_partner_quotes
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'auth', 'private'
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
    AND o.partner_compliance_status IN ('clear', 'compliant', 'approved', 'verified', 'not_required', 'not_applicable');

  IF coalesce(cardinality(v_partner_organization_ids), 0) = 0 THEN
    RAISE EXCEPTION USING errcode = '42501', message = 'Only verified registered-business organisations with an active approved capability may submit partner bids';
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

CREATE OR REPLACE FUNCTION public.krim_award_partner_quote_for_checkout(p_partner_quote_id bigint, p_valid_until timestamp with time zone DEFAULT (now() + '7 days'::interval))
 RETURNS krim_quotes
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_partner_quote public.krim_partner_quotes%ROWTYPE;
  v_opportunity public.krim_partner_opportunities%ROWTYPE;
  v_shipment public.krim_shipments%ROWTYPE;
  v_assignment public.krim_shipment_partner_assignments%ROWTYPE;
  v_customer_quote public.krim_quotes%ROWTYPE;
  v_existing_quote public.krim_quotes%ROWTYPE;
  v_version_id bigint;
  v_version_number integer;
  v_valid_until timestamptz := p_valid_until;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION USING errcode='28000', message='Authentication required';
  END IF;
  IF p_partner_quote_id IS NULL OR p_partner_quote_id <= 0 THEN
    RAISE EXCEPTION USING errcode='22023', message='A valid partner quote is required';
  END IF;

  SELECT * INTO v_partner_quote
  FROM public.krim_partner_quotes
  WHERE id = p_partner_quote_id
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION USING errcode='P0002', message='Partner quote not found';
  END IF;

  SELECT * INTO v_opportunity
  FROM public.krim_partner_opportunities
  WHERE id = v_partner_quote.opportunity_id
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION USING errcode='P0002', message='Partner opportunity not found';
  END IF;

  IF NOT private.krim_has_organization_access(v_user_id, v_opportunity.customer_organization_id) THEN
    RAISE EXCEPTION USING errcode='42501', message='Opportunity is not accessible to this customer organization';
  END IF;
  IF NOT private.krim_has_permission(v_user_id, v_opportunity.customer_organization_id, 'quote.update')
     OR NOT private.krim_has_permission(v_user_id, v_opportunity.customer_organization_id, 'shipment.update') THEN
    RAISE EXCEPTION USING errcode='42501', message='Permission denied: quote award requires quote.update and shipment.update';
  END IF;

  SELECT * INTO v_existing_quote
  FROM public.krim_quotes
  WHERE partner_quote_id = p_partner_quote_id
  FOR UPDATE;
  IF FOUND THEN
    SELECT * INTO v_assignment
    FROM public.krim_shipment_partner_assignments
    WHERE partner_quote_id = p_partner_quote_id
    ORDER BY created_at DESC
    LIMIT 1
    FOR UPDATE;
    IF v_existing_quote.status IN ('sent','accepted') AND v_assignment.status IN ('offered','accepted','active') THEN
      RETURN v_existing_quote;
    END IF;
    RAISE EXCEPTION USING errcode='22023', message='This partner quote has already been awarded and is no longer eligible; choose an available offer';
  END IF;

  IF v_opportunity.status <> 'open'
     OR (v_opportunity.response_deadline IS NOT NULL AND v_opportunity.response_deadline <= now()) THEN
    RAISE EXCEPTION USING errcode='22023', message='Partner opportunity is no longer open';
  END IF;
  IF v_partner_quote.status NOT IN ('submitted','under_review','shortlisted')
     OR (v_partner_quote.valid_until IS NOT NULL AND v_partner_quote.valid_until <= now()) THEN
    RAISE EXCEPTION USING errcode='22023', message='Partner quote is not eligible for award';
  END IF;
  IF v_partner_quote.amount <= 0 THEN
    RAISE EXCEPTION USING errcode='22023', message='Partner quote amount must be greater than zero';
  END IF;
  IF v_valid_until IS NULL OR v_valid_until <= now() + interval '1 hour'
     OR v_valid_until > now() + interval '30 days' THEN
    RAISE EXCEPTION USING errcode='22023', message='Customer quote validity must be between one hour and 30 days';
  END IF;
  IF v_partner_quote.valid_until IS NOT NULL THEN
    v_valid_until := LEAST(v_valid_until, v_partner_quote.valid_until);
  END IF;
  IF v_valid_until <= now() + interval '1 hour' THEN
    RAISE EXCEPTION USING errcode='22023', message='Partner quote expires too soon to create a customer quote';
  END IF;

  SELECT * INTO v_shipment
  FROM public.krim_shipments
  WHERE id = v_partner_quote.shipment_id
  FOR UPDATE;
  IF NOT FOUND OR v_shipment.customer_organization_id <> v_opportunity.customer_organization_id
     OR v_opportunity.shipment_id <> v_shipment.id THEN
    RAISE EXCEPTION USING errcode='42501', message='Partner quote does not match the authorized customer shipment';
  END IF;
  IF v_shipment.status NOT IN ('quoted','confirmed') THEN
    RAISE EXCEPTION USING errcode='22023', message='Shipment is not in an awardable state';
  END IF;
  IF v_shipment.status = 'confirmed' AND NOT EXISTS (
    SELECT 1 FROM public.krim_shipment_partner_assignments a
    WHERE a.shipment_id = v_shipment.id AND a.status = 'rejected'
  ) THEN
    RAISE EXCEPTION USING errcode='22023', message='Shipment is already confirmed; a new award is allowed only after a previous partner assignment was rejected';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.krim_quotes q
    WHERE q.shipment_id = v_shipment.id
      AND q.status IN ('draft','sent','accepted')
  ) THEN
    RAISE EXCEPTION USING errcode='23505', message='An active customer quote already exists for this shipment; resolve it before awarding a partner quote';
  END IF;

  v_assignment := public.krim_award_partner_quote(p_partner_quote_id);

  INSERT INTO public.krim_quotes (
    shipment_id, customer_organization_id, amount, currency_code,
    valid_until, status, partner_quote_id
  ) VALUES (
    v_shipment.id, v_opportunity.customer_organization_id, v_partner_quote.amount,
    v_partner_quote.currency_code, v_valid_until, 'sent', v_partner_quote.id
  )
  RETURNING * INTO v_customer_quote;

  SELECT COALESCE(MAX(version_number), 0) + 1
  INTO v_version_number
  FROM public.krim_quote_versions
  WHERE quote_id = v_customer_quote.id;

  INSERT INTO public.krim_quote_versions (
    quote_id, version_number, status, currency_code, subtotal, tax_amount,
    total_amount, valid_from, valid_until, customer_terms, pricing_snapshot, created_by
  ) VALUES (
    v_customer_quote.id, v_version_number, 'sent', v_partner_quote.currency_code,
    v_partner_quote.amount, 0, v_partner_quote.amount, now(), v_valid_until,
    jsonb_build_object(
      'price_basis', 'partner_submitted_quote_total',
      'applicable_charges_included_in_partner_total', true,
      'tax_breakdown_status', 'not_separately_calculated',
      'payment_terms', 'payment arranged directly with provider after final quote acceptance and assignment confirmation',
      'production_tax_invoice_ready', false
    ),
    jsonb_build_object(
      'source', 'selected_partner_quote',
      'partner_quote_id', v_partner_quote.id,
      'partner_quote_number', v_partner_quote.quote_number,
      'partner_organization_id', v_partner_quote.partner_organization_id,
      'opportunity_id', v_opportunity.id,
      'assignment_id', v_assignment.id,
      'total_customer_payable', v_partner_quote.amount,
      'currency_code', v_partner_quote.currency_code,
      'tax_breakdown_status', 'not_separately_calculated',
      'finance_reconciliation_required', true
    ),
    v_user_id
  )
  RETURNING id INTO v_version_id;

  INSERT INTO public.krim_quote_events (
    quote_id, version_id, event_type, previous_status, new_status,
    actor_user_id, event_time, payload
  ) VALUES (
    v_customer_quote.id, v_version_id, 'quote.sent_after_partner_selection',
    NULL, 'sent', v_user_id, now(),
    jsonb_build_object(
      'partner_quote_id', v_partner_quote.id,
      'assignment_id', v_assignment.id,
      'opportunity_id', v_opportunity.id,
      'amount', v_partner_quote.amount,
      'currency_code', v_partner_quote.currency_code
    )
  );

  RETURN v_customer_quote;
END;
$function$;

CREATE OR REPLACE FUNCTION public.krim_customer_prepare_partner_quote(p_partner_quote_id bigint, p_valid_until timestamp with time zone DEFAULT (now() + '7 days'::interval))
 RETURNS krim_quotes
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION USING errcode='28000', message='Authentication required';
  END IF;
  RETURN public.krim_award_partner_quote_for_checkout(p_partner_quote_id,p_valid_until);
END;
$function$;

CREATE OR REPLACE FUNCTION public.krim_customer_list_partner_quotes(p_shipment_id bigint)
 RETURNS TABLE(id bigint, opportunity_id bigint, shipment_id bigint, quote_number text, amount numeric, currency_code text, status text, submitted_at timestamp with time zone, valid_until timestamp with time zone, notes text, partner_name text, partner_legal_name text, partner_verified boolean, compliance_current boolean, capability_current boolean, eligible_now boolean)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_customer_org_id bigint;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION USING errcode='28000', message='Authentication required';
  END IF;
  IF p_shipment_id IS NULL OR p_shipment_id <= 0 THEN
    RAISE EXCEPTION USING errcode='22023', message='A valid shipment reference is required';
  END IF;

  SELECT s.customer_organization_id
    INTO v_customer_org_id
  FROM public.krim_shipments s
  WHERE s.id=p_shipment_id
  FOR KEY SHARE;

  IF v_customer_org_id IS NULL
     OR NOT private.krim_has_organization_access(v_user_id,v_customer_org_id) THEN
    RAISE EXCEPTION USING errcode='42501', message='Shipment is not accessible in your active customer organization';
  END IF;

  RETURN QUERY
  SELECT
    q.id,
    q.opportunity_id,
    q.shipment_id,
    q.quote_number,
    q.amount,
    q.currency_code::text,
    q.status,
    q.submitted_at,
    q.valid_until,
    q.notes,
    COALESCE(NULLIF(btrim(o.display_name),''),NULLIF(btrim(o.legal_name),''),'Verified logistics partner') AS partner_name,
    COALESCE(o.legal_name,'') AS partner_legal_name,
    (o.status='active'
      AND o.partner_account_mode='registered_business'
      AND o.partner_verification_status IN ('verified','approved')
      AND o.partner_lifecycle_status IN ('active','verified')) AS partner_verified,
    private.krim_partner_compliance_is_current(o.id) AS compliance_current,
    (private.krim_partner_capability_covers_shipment(o.id,p_shipment_id)
      AND EXISTS (
        SELECT 1
        FROM public.krim_partner_capabilities pc
        WHERE pc.organization_id=o.id
          AND pc.active IS TRUE
          AND pc.verification_status='verified'
          AND (pc.effective_from IS NULL OR pc.effective_from<=now())
          AND (pc.effective_until IS NULL OR pc.effective_until>now())
      )) AS capability_current,
    (o.status='active'
      AND o.partner_account_mode='registered_business'
      AND o.partner_verification_status IN ('verified','approved')
      AND o.partner_lifecycle_status IN ('active','verified')
      AND private.krim_partner_compliance_is_current(o.id)
      AND private.krim_partner_capability_covers_shipment(o.id,p_shipment_id)
      AND EXISTS (
        SELECT 1
        FROM public.krim_partner_capabilities pc
        WHERE pc.organization_id=o.id
          AND pc.active IS TRUE
          AND pc.verification_status='verified'
          AND (pc.effective_from IS NULL OR pc.effective_from<=now())
          AND (pc.effective_until IS NULL OR pc.effective_until>now())
      )) AS eligible_now
  FROM public.krim_partner_quotes q
  JOIN public.krim_partner_opportunities po
    ON po.id=q.opportunity_id
   AND po.shipment_id=q.shipment_id
   AND po.customer_organization_id=v_customer_org_id
  JOIN public.krim_organizations o ON o.id=q.partner_organization_id
  WHERE q.shipment_id=p_shipment_id
    AND q.status IN ('submitted','under_review','shortlisted','accepted')
    AND (
      q.status='accepted'
      OR (
        o.status='active'
        AND o.partner_account_mode='registered_business'
        AND o.partner_verification_status IN ('verified','approved')
        AND o.partner_lifecycle_status IN ('active','verified')
        AND private.krim_partner_compliance_is_current(o.id)
        AND private.krim_partner_capability_covers_shipment(o.id,p_shipment_id)
        AND EXISTS (
          SELECT 1
          FROM public.krim_partner_capabilities pc
          WHERE pc.organization_id=o.id
            AND pc.active IS TRUE
            AND pc.verification_status='verified'
            AND (pc.effective_from IS NULL OR pc.effective_from<=now())
            AND (pc.effective_until IS NULL OR pc.effective_until>now())
        )
      )
    )
  ORDER BY q.submitted_at DESC NULLS LAST,q.id DESC;
END;
$function$;

CREATE OR REPLACE FUNCTION public.krim_respond_to_partner_assignment(p_assignment_id bigint, p_accept boolean, p_reason text DEFAULT NULL::text)
 RETURNS krim_shipment_partner_assignments
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_user_id uuid := auth.uid();
  v_assignment public.krim_shipment_partner_assignments%rowtype;
  v_quote public.krim_partner_quotes%rowtype;
  v_opportunity public.krim_partner_opportunities%rowtype;
  v_shipment public.krim_shipments%rowtype;
  v_leg_id bigint;
  v_leg_sequence integer;
  v_transport_mode_id bigint;
  v_mode_code text;
  v_finalize_result jsonb;
begin
  if v_user_id is null then
    raise exception using errcode='28000', message='Authentication required';
  end if;
  if p_assignment_id is null or p_assignment_id <= 0 then
    raise exception using errcode='22023', message='A valid assignment is required';
  end if;
  if p_reason is not null and char_length(btrim(p_reason)) > 500 then
    raise exception using errcode='22023', message='Reason must be 500 characters or fewer';
  end if;

  select * into v_assignment
  from public.krim_shipment_partner_assignments
  where id=p_assignment_id
  for update;
  if not found then
    raise exception using errcode='P0002', message='Assignment not found';
  end if;
  if not private.krim_has_organization_access(v_user_id,v_assignment.partner_organization_id) then
    raise exception using errcode='42501', message='Assignment does not belong to your partner organization';
  end if;
  if not private.krim_has_permission(v_user_id, v_assignment.partner_organization_id, 'shipment.update') then
    raise exception using errcode='42501', message='Permission denied: shipment.update';
  end if;

  -- Idempotent retry: a provider may accept while the customer quote is still
  -- pending. Keep the shipment quoted until customer acceptance; finalize only
  -- after the shipment has reached the confirmed state.
  if v_assignment.status in ('accepted','active') and p_accept then
    select * into v_shipment
    from public.krim_shipments
    where id=v_assignment.shipment_id
    for update;
    if not found then
      raise exception using errcode='P0002', message='Shipment not found for partner assignment';
    end if;
    if v_shipment.status='confirmed' then
      v_finalize_result := public.krim_internal_finalize_partner_assignment(v_assignment.id);
    elsif v_shipment.status='quoted' and v_assignment.status='accepted' then
      v_finalize_result := jsonb_build_object('assigned',false,'deferred',true,'assignment_id',v_assignment.id,'shipment_id',v_shipment.id,'next_step','customer_quote_acceptance');
    elsif v_shipment.status='assigned' and v_assignment.status in ('active','completed') then
      v_finalize_result := jsonb_build_object('assigned',true,'idempotent',true,'assignment_id',v_assignment.id,'shipment_id',v_shipment.id,'status','assigned');
    else
      raise exception using errcode='55000', message='Partner acceptance cannot be finalized from the current shipment state';
    end if;
    select * into v_assignment
    from public.krim_shipment_partner_assignments
    where id=v_assignment.id;
    return v_assignment;
  end if;

  if v_assignment.status='rejected' and not p_accept then
    return v_assignment;
  end if;
  if v_assignment.status <> 'offered' then
    raise exception using errcode='22023', message='Only offered assignments can be accepted or rejected';
  end if;
  if v_assignment.response_deadline is not null and v_assignment.response_deadline <= now() then
    raise exception using errcode='22023', message='Assignment response deadline has passed';
  end if;

  select * into v_quote
  from public.krim_partner_quotes
  where id=v_assignment.partner_quote_id;
  if not found then
    raise exception using errcode='23503', message='Partner quote is missing for this assignment';
  end if;
  if p_accept and v_quote.valid_until is not null and v_quote.valid_until <= now() then
    raise exception using errcode='22023', message='Partner quote has expired; request a fresh offer';
  end if;
  select * into v_opportunity
  from public.krim_partner_opportunities
  where id=v_quote.opportunity_id;
  select * into v_shipment
  from public.krim_shipments
  where id=v_assignment.shipment_id
  for update;

  if p_accept and not private.krim_partner_capability_covers_shipment(v_assignment.partner_organization_id,v_shipment.id) then
    raise exception using errcode='42501', message='Partner capability no longer covers the shipment route, transport mode or weight';
  end if;

  if p_accept then
    if not private.krim_partner_compliance_is_current(v_assignment.partner_organization_id) then
      raise exception using errcode='42501', message='Partner verification or compliance is no longer active';
    end if;

    update public.krim_shipment_partner_assignments
    set status='accepted', accepted_at=now(), updated_at=now()
    where id=v_assignment.id
    returning * into v_assignment;

    v_leg_id := v_assignment.shipment_leg_id;
    if v_leg_id is null then
      select id into v_leg_id
      from public.krim_shipment_legs
      where shipment_id=v_shipment.id
      order by leg_sequence asc
      limit 1;
    end if;

    if v_leg_id is null then
      select coalesce(max(leg_sequence),0)+1 into v_leg_sequence
      from public.krim_shipment_legs
      where shipment_id=v_shipment.id;
      v_mode_code := case
        when coalesce(v_opportunity.metadata->>'service_tier','surface_express')='air_priority' then 'AIR'
        when coalesce(v_opportunity.metadata->>'service_tier','surface_express')='heavy_haul' then 'ROAD'
        else 'ROAD'
      end;
      select id into v_transport_mode_id
      from public.krim_transport_modes
      where code=v_mode_code and is_active=true
      limit 1;
      if v_transport_mode_id is null then
        raise exception using errcode='55000', message='Required transport mode is not configured';
      end if;
      insert into public.krim_shipment_legs (
        shipment_id, leg_sequence, origin_location_id, destination_location_id,
        transport_mode_id, partner_organization_id, status, assignment_status
      ) values (
        v_shipment.id, v_leg_sequence, v_shipment.origin_location_id, v_shipment.destination_location_id,
        v_transport_mode_id, v_assignment.partner_organization_id, 'assigned', 'accepted'
      )
      returning id into v_leg_id;
    else
      update public.krim_shipment_legs
      set partner_organization_id=v_assignment.partner_organization_id,
          assignment_status='accepted',
          status='assigned',
          updated_at=now()
      where id=v_leg_id and shipment_id=v_shipment.id;
    end if;

    update public.krim_shipment_partner_assignments
    set shipment_leg_id=v_leg_id, updated_at=now()
    where id=v_assignment.id
    returning * into v_assignment;

    insert into public.krim_tracking_events (
      shipment_id, shipment_leg_id, event_type, event_time, source_type,
      partner_organization_id, assignment_id, metadata
    ) values (
      v_shipment.id, v_leg_id, 'partner_assignment_accepted', now(), 'partner_portal',
      v_assignment.partner_organization_id, v_assignment.id,
      jsonb_build_object('assignment_number',v_assignment.assignment_number,'quote_number',v_quote.quote_number)
    );

    insert into public.krim_audit_events (
      actor_user_id, organization_id, event_type, entity_type, entity_id, source, metadata
    ) values (
      v_user_id, v_assignment.partner_organization_id, 'partner.assignment.accepted',
      'shipment_partner_assignment', v_assignment.id::text, 'partner_portal',
      jsonb_build_object('shipment_id',v_assignment.shipment_id,'shipment_leg_id',v_leg_id)
    );

    -- Provider acceptance is recorded first. If the customer quote is still
    -- quoted, defer shipment assignment until the customer accepts that quote.
    if v_shipment.status='confirmed' then
      v_finalize_result := public.krim_internal_finalize_partner_assignment(v_assignment.id);
    elsif v_shipment.status='quoted' then
      v_finalize_result := jsonb_build_object('assigned',false,'deferred',true,'assignment_id',v_assignment.id,'shipment_id',v_shipment.id,'next_step','customer_quote_acceptance');
    else
      raise exception using errcode='55000', message='Partner assignment cannot proceed from the current shipment state';
    end if;
    select * into v_assignment
    from public.krim_shipment_partner_assignments
    where id=v_assignment.id;
  else
    update public.krim_shipment_partner_assignments
    set status='rejected', rejected_at=now(), rejection_reason=nullif(btrim(p_reason),''), updated_at=now()
    where id=v_assignment.id
    returning * into v_assignment;

    update public.krim_partner_quotes
    set status='withdrawn', withdrawn_at=now(), updated_at=now()
    where id=v_quote.id;

    update public.krim_partner_quotes
    set status='submitted', rejected_at=NULL, updated_at=now()
    where opportunity_id=v_opportunity.id and id<>v_quote.id and status='rejected';

    update public.krim_partner_opportunities
    set status='open', awarded_partner_organization_id=NULL, awarded_at=NULL, updated_at=now()
    where id=v_opportunity.id;

    insert into public.krim_audit_events (
      actor_user_id, organization_id, event_type, entity_type, entity_id, source, metadata
    ) values (
      v_user_id, v_assignment.partner_organization_id, 'partner.assignment.rejected',
      'shipment_partner_assignment', v_assignment.id::text, 'partner_portal',
      jsonb_build_object('shipment_id',v_assignment.shipment_id,'reason',p_reason)
    );
  end if;

  return v_assignment;
end;
$function$;

CREATE OR REPLACE FUNCTION public.krim_accept_global_quote(p_quote_id bigint)
 RETURNS krim_quotes
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_quote public.krim_quotes%ROWTYPE;
  v_shipment public.krim_shipments%ROWTYPE;
  v_assignment_id bigint;
BEGIN
  SELECT * INTO v_quote
  FROM public.krim_quotes
  WHERE id = p_quote_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION USING errcode='P0002', message='Global quote not found';
  END IF;

  SELECT * INTO v_shipment
  FROM public.krim_shipments
  WHERE id = v_quote.shipment_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION USING errcode='P0002', message='Shipment not found';
  END IF;

  IF v_quote.customer_organization_id IS NULL THEN
    RAISE EXCEPTION USING errcode='23514', message='Quote has no customer organization';
  END IF;

  IF NOT public.krim_has_organization_access(auth.uid(), v_quote.customer_organization_id) THEN
    RAISE EXCEPTION USING errcode='42501', message='Organization access denied';
  END IF;

  IF NOT public.krim_has_permission(auth.uid(), v_quote.customer_organization_id, 'shipment.update') THEN
    RAISE EXCEPTION USING errcode='42501', message='Permission denied';
  END IF;

  IF v_quote.status = 'accepted' THEN
    SELECT a.id INTO v_assignment_id
    FROM public.krim_shipment_partner_assignments a
    WHERE a.shipment_id=v_shipment.id
      AND a.partner_quote_id=v_quote.partner_quote_id
      AND a.status IN ('accepted','active')
    ORDER BY a.created_at DESC
    LIMIT 1
    FOR UPDATE;
    IF v_assignment_id IS NULL THEN
      RAISE EXCEPTION USING errcode='55000', message='Accepted quote has no matching accepted partner assignment';
    END IF;
    IF v_shipment.status='confirmed' THEN
      PERFORM public.krim_internal_finalize_partner_assignment(v_assignment_id);
    ELSIF v_shipment.status<>'assigned' THEN
      RAISE EXCEPTION USING errcode='55000', message='Accepted quote is not in a finalizable shipment state';
    END IF;
    RETURN v_quote;
  ELSIF v_quote.status <> 'sent' THEN
    RAISE EXCEPTION USING errcode='55000',
      message=format('Quote cannot be accepted from status: %s', v_quote.status);
  END IF;

  IF v_quote.valid_until IS NOT NULL AND v_quote.valid_until <= now() THEN
    UPDATE public.krim_quotes
    SET status='expired', updated_at=now()
    WHERE id=v_quote.id
    RETURNING * INTO v_quote;
    RETURN v_quote;
  END IF;

  IF v_shipment.status <> 'quoted' THEN
    RAISE EXCEPTION USING errcode='55000',
      message=format('Shipment must be in quoted status. Current status: %s', v_shipment.status);
  END IF;

  -- A customer quote cannot confirm a shipment unless it is bound to an
  -- accepted partner quote and an accepted partner assignment for this exact
  -- shipment, from an active and verified partner with current capability.
  IF v_quote.partner_quote_id IS NULL OR NOT EXISTS (
    SELECT 1
    FROM public.krim_partner_quotes pq
    JOIN public.krim_shipment_partner_assignments a
      ON a.partner_quote_id = pq.id
     AND a.shipment_id = pq.shipment_id
     AND a.partner_organization_id = pq.partner_organization_id
    JOIN public.krim_organizations o
      ON o.id = a.partner_organization_id
     AND o.status = 'active'
     AND o.partner_verification_status IN ('verified','approved')
     AND o.partner_lifecycle_status IN ('active','verified')
     AND o.partner_compliance_status IN ('clear','compliant','approved','verified','not_required','not_applicable')
    WHERE pq.id = v_quote.partner_quote_id
      AND pq.shipment_id = v_shipment.id
      AND pq.status = 'accepted'
      AND a.status = 'accepted'
      AND pq.amount = v_quote.amount
      AND upper(pq.currency_code) = upper(v_quote.currency_code)
      AND EXISTS (
        SELECT 1
        FROM public.krim_partner_capabilities pc
        WHERE pc.organization_id = o.id
          AND pc.active IS TRUE
          AND pc.verification_status = 'verified'
          AND (pc.effective_from IS NULL OR pc.effective_from <= now())
          AND (pc.effective_until IS NULL OR pc.effective_until > now())
      )
      AND private.krim_partner_capability_covers_shipment(o.id, v_shipment.id)
  ) THEN
    RAISE EXCEPTION USING errcode='23514',
      message='A customer quote can be accepted only after a verified partner quote and matching partner assignment have been accepted for this shipment';
  END IF;

  UPDATE public.krim_quotes
  SET status='accepted', updated_at=now()
  WHERE id=v_quote.id
  RETURNING * INTO v_quote;

  PERFORM public.krim_transition_shipment(
    v_shipment.id,
    'confirmed',
    'Customer accepted the quote after provider assignment acceptance',
    jsonb_build_object(
      'quote_id', v_quote.id,
      'partner_quote_id', v_quote.partner_quote_id,
      'amount', v_quote.amount,
      'currency_code', v_quote.currency_code
    )
  );

  SELECT a.id INTO v_assignment_id
  FROM public.krim_shipment_partner_assignments a
  WHERE a.shipment_id=v_shipment.id
    AND a.partner_quote_id=v_quote.partner_quote_id
    AND a.status='accepted'
  ORDER BY a.created_at DESC
  LIMIT 1
  FOR UPDATE;
  IF v_assignment_id IS NULL THEN
    RAISE EXCEPTION USING errcode='23514', message='Accepted quote lost its matching accepted partner assignment';
  END IF;
  PERFORM public.krim_internal_finalize_partner_assignment(v_assignment_id);

  RETURN v_quote;
END;
$function$;

CREATE OR REPLACE FUNCTION public.krim_cancel_customer_quote_after_partner_rejection()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_quote_id bigint;
  v_version_id bigint;
  v_previous_status text;
  v_previous_version_status text;
BEGIN
  IF OLD.status = 'offered'
     AND NEW.status = 'rejected'
     AND NEW.partner_quote_id IS NOT NULL THEN
    SELECT q.id, q.status INTO v_quote_id, v_previous_status
    FROM public.krim_quotes q
    WHERE q.partner_quote_id = NEW.partner_quote_id
      AND q.status IN ('sent','accepted')
    ORDER BY q.id DESC
    LIMIT 1
    FOR UPDATE;

    IF FOUND THEN
      UPDATE public.krim_quotes
      SET status = 'cancelled', updated_at = now()
      WHERE id = v_quote_id;

      SELECT qv.id, qv.status INTO v_version_id, v_previous_version_status
      FROM public.krim_quote_versions qv
      WHERE qv.quote_id = v_quote_id
        AND qv.status IN ('sent','accepted')
      ORDER BY qv.version_number DESC
      LIMIT 1
      FOR UPDATE;

      IF v_version_id IS NOT NULL THEN
        UPDATE public.krim_quote_versions
        SET status = 'cancelled', superseded_at = now()
        WHERE id = v_version_id;
      END IF;

      INSERT INTO public.krim_quote_events (
        quote_id, version_id, event_type, previous_status, new_status,
        actor_user_id, event_time, payload
      ) VALUES (
        v_quote_id, v_version_id, 'quote.cancelled_partner_assignment_rejected',
        v_previous_status, 'cancelled', auth.uid(), now(),
        jsonb_build_object('assignment_id', NEW.id, 'partner_quote_id', NEW.partner_quote_id)
      );
    END IF;
  END IF;
  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION public.krim_set_partner_account_mode(p_mode text, p_profile jsonb) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.krim_set_partner_account_mode(p_mode text, p_profile jsonb) TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.krim_award_partner_quote(p_partner_quote_id bigint) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.krim_award_partner_quote(p_partner_quote_id bigint) TO service_role;
REVOKE ALL ON FUNCTION public.krim_submit_partner_quote(p_opportunity_id bigint, p_amount numeric, p_currency_code text, p_valid_until timestamp with time zone, p_notes text) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.krim_submit_partner_quote(p_opportunity_id bigint, p_amount numeric, p_currency_code text, p_valid_until timestamp with time zone, p_notes text) TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.krim_award_partner_quote_for_checkout(p_partner_quote_id bigint, p_valid_until timestamp with time zone) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.krim_award_partner_quote_for_checkout(p_partner_quote_id bigint, p_valid_until timestamp with time zone) TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.krim_customer_prepare_partner_quote(p_partner_quote_id bigint, p_valid_until timestamp with time zone) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.krim_customer_prepare_partner_quote(p_partner_quote_id bigint, p_valid_until timestamp with time zone) TO authenticated;
REVOKE ALL ON FUNCTION public.krim_customer_list_partner_quotes(p_shipment_id bigint) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.krim_customer_list_partner_quotes(p_shipment_id bigint) TO authenticated;
REVOKE ALL ON FUNCTION public.krim_respond_to_partner_assignment(p_assignment_id bigint, p_accept boolean, p_reason text) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.krim_respond_to_partner_assignment(p_assignment_id bigint, p_accept boolean, p_reason text) TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.krim_accept_global_quote(p_quote_id bigint) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.krim_accept_global_quote(p_quote_id bigint) TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.krim_cancel_customer_quote_after_partner_rejection() FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.krim_cancel_customer_quote_after_partner_rejection() TO service_role;
