-- Link an awarded partner quote to the customer-facing payable quote.
-- Additive migration: does not modify or delete existing quote records.
ALTER TABLE public.krim_quotes
  ADD COLUMN IF NOT EXISTS partner_quote_id bigint;

DO $migration$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'krim_quotes_partner_quote_id_fkey'
      AND conrelid = 'public.krim_quotes'::regclass
  ) THEN
    ALTER TABLE public.krim_quotes
      ADD CONSTRAINT krim_quotes_partner_quote_id_fkey
      FOREIGN KEY (partner_quote_id)
      REFERENCES public.krim_partner_quotes(id)
      ON DELETE RESTRICT;
  END IF;
END
$migration$;

CREATE UNIQUE INDEX IF NOT EXISTS krim_quotes_partner_quote_id_uidx
  ON public.krim_quotes(partner_quote_id)
  WHERE partner_quote_id IS NOT NULL;

CREATE OR REPLACE FUNCTION public.krim_award_partner_quote_for_checkout(
  p_partner_quote_id bigint,
  p_valid_until timestamptz DEFAULT (now() + interval '7 days')
)
RETURNS public.krim_quotes
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public, pg_temp
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

  -- Safe retry: return the quote only while its partner assignment is still offered or accepted.
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
    IF v_existing_quote.status = 'accepted' AND v_assignment.status IN ('offered','accepted') THEN
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

  -- This function performs the verified partner assignment and shipment state transition.
  v_assignment := public.krim_award_partner_quote(p_partner_quote_id);

  -- The partner's submitted amount is the customer-facing freight total for this award.
  -- Tax breakdown is explicitly marked uncalculated; do not use this record as a tax invoice.
  INSERT INTO public.krim_quotes (
    shipment_id, customer_organization_id, amount, currency_code,
    valid_until, status, partner_quote_id
  ) VALUES (
    v_shipment.id, v_opportunity.customer_organization_id, v_partner_quote.amount,
    v_partner_quote.currency_code, v_valid_until, 'accepted', v_partner_quote.id
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
    v_customer_quote.id, v_version_number, 'accepted', v_partner_quote.currency_code,
    v_partner_quote.amount, 0, v_partner_quote.amount, now(), v_valid_until,
    jsonb_build_object(
      'price_basis', 'accepted_partner_quote_total',
      'applicable_charges_included_in_partner_total', true,
      'tax_breakdown_status', 'not_separately_calculated',
      'payment_terms', 'payment after partner assignment acceptance',
      'production_tax_invoice_ready', false
    ),
    jsonb_build_object(
      'source', 'accepted_partner_quote',
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
    v_customer_quote.id, v_version_id, 'quote.accepted_from_partner_award',
    NULL, 'accepted', v_user_id, now(),
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

REVOKE ALL ON FUNCTION public.krim_award_partner_quote_for_checkout(bigint, timestamptz) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.krim_award_partner_quote_for_checkout(bigint, timestamptz) TO authenticated;

CREATE OR REPLACE FUNCTION public.krim_cancel_customer_quote_after_partner_rejection()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public, pg_temp
AS $function$
DECLARE
  v_quote_id bigint;
  v_version_id bigint;
BEGIN
  IF OLD.status = 'offered'
     AND NEW.status = 'rejected'
     AND NEW.partner_quote_id IS NOT NULL THEN
    SELECT q.id INTO v_quote_id
    FROM public.krim_quotes q
    WHERE q.partner_quote_id = NEW.partner_quote_id
      AND q.status = 'accepted'
    FOR UPDATE;

    IF FOUND THEN
      UPDATE public.krim_quotes
      SET status = 'cancelled', updated_at = now()
      WHERE id = v_quote_id;

      SELECT qv.id INTO v_version_id
      FROM public.krim_quote_versions qv
      WHERE qv.quote_id = v_quote_id AND qv.status = 'accepted'
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
        'accepted', 'cancelled', auth.uid(), now(),
        jsonb_build_object('assignment_id', NEW.id, 'partner_quote_id', NEW.partner_quote_id)
      );
    END IF;
  END IF;
  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION public.krim_cancel_customer_quote_after_partner_rejection() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_krim_cancel_customer_quote_after_partner_rejection
  ON public.krim_shipment_partner_assignments;
CREATE TRIGGER trg_krim_cancel_customer_quote_after_partner_rejection
AFTER UPDATE OF status ON public.krim_shipment_partner_assignments
FOR EACH ROW
EXECUTE FUNCTION public.krim_cancel_customer_quote_after_partner_rejection();
