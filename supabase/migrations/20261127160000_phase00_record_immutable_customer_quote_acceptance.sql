-- Phase 00: record customer acceptance of the exact selected partner quote.
-- This is an operational acceptance-evidence event, not a KRIM freight contract
-- and not a freight payment, invoice, receivable, or settlement record.

CREATE OR REPLACE FUNCTION private.krim_block_quote_event_mutation()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
  RAISE EXCEPTION USING
    errcode = '55000',
    message = 'Quote acceptance and lifecycle events are append-only';
END;
$function$;

REVOKE ALL ON FUNCTION private.krim_block_quote_event_mutation() FROM PUBLIC, anon, authenticated, service_role;

DROP TRIGGER IF EXISTS trg_krim_quote_events_no_update_delete ON public.krim_quote_events;
CREATE TRIGGER trg_krim_quote_events_no_update_delete
BEFORE UPDATE OR DELETE ON public.krim_quote_events
FOR EACH ROW EXECUTE FUNCTION private.krim_block_quote_event_mutation();

DROP TRIGGER IF EXISTS trg_krim_quote_events_no_truncate ON public.krim_quote_events;
CREATE TRIGGER trg_krim_quote_events_no_truncate
BEFORE TRUNCATE ON public.krim_quote_events
FOR EACH STATEMENT EXECUTE FUNCTION private.krim_block_quote_event_mutation();

CREATE OR REPLACE FUNCTION public.krim_accept_global_quote(p_quote_id bigint)
RETURNS public.krim_quotes
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_quote public.krim_quotes%ROWTYPE;
  v_shipment public.krim_shipments%ROWTYPE;
  v_assignment_id bigint;
  v_assignment public.krim_shipment_partner_assignments%ROWTYPE;
  v_partner_quote public.krim_partner_quotes%ROWTYPE;
  v_quote_version_id bigint;
  v_customer_terms jsonb := '{}'::jsonb;
  v_version_pricing_snapshot jsonb := '{}'::jsonb;
  v_accepted_at timestamptz := clock_timestamp();
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

  IF auth.uid() IS NULL OR NOT public.krim_has_organization_access(auth.uid(), v_quote.customer_organization_id) THEN
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

  -- Require an accepted partner offer and exact matching assignment.
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
      AND private.krim_partner_compliance_is_current(o.id)
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

  -- Capture the final assignment and the exact quote version after the
  -- server-side capacity finalizer has succeeded. The payload is a historical
  -- snapshot; it does not make KRIM a party to the freight contract.
  SELECT * INTO v_assignment
  FROM public.krim_shipment_partner_assignments
  WHERE id = v_assignment_id;

  SELECT * INTO v_partner_quote
  FROM public.krim_partner_quotes
  WHERE id = v_quote.partner_quote_id;

  SELECT qv.id, qv.customer_terms, qv.pricing_snapshot
  INTO v_quote_version_id, v_customer_terms, v_version_pricing_snapshot
  FROM public.krim_quote_versions qv
  WHERE qv.quote_id = v_quote.id
    AND qv.status = 'sent'
  ORDER BY qv.version_number DESC
  LIMIT 1
  FOR UPDATE;

  IF v_quote_version_id IS NOT NULL THEN
    UPDATE public.krim_quote_versions
    SET status = 'accepted'
    WHERE id = v_quote_version_id
      AND status = 'sent';
  END IF;

  INSERT INTO public.krim_quote_events (
    quote_id, version_id, event_type, previous_status, new_status,
    actor_user_id, event_time, payload
  ) VALUES (
    v_quote.id,
    v_quote_version_id,
    'customer.quote_accepted_partner_capacity_confirmed',
    'sent',
    'accepted',
    auth.uid(),
    v_accepted_at,
    jsonb_build_object(
      'quote_id', v_quote.id,
      'shipment_id', v_shipment.id,
      'customer_organization_id', v_quote.customer_organization_id,
      'partner_quote_id', v_partner_quote.id,
      'partner_quote_number', v_partner_quote.quote_number,
      'partner_organization_id', v_partner_quote.partner_organization_id,
      'assignment_id', v_assignment.id,
      'assignment_status_after_finalization', v_assignment.status,
      'capacity_binding_id', v_assignment.capacity_binding_id,
      'customer_quote_amount', v_quote.amount,
      'currency_code', v_quote.currency_code,
      'customer_quote_snapshot', v_quote.pricing_snapshot,
      'partner_quote_snapshot', v_partner_quote.pricing_snapshot,
      'customer_terms_snapshot', v_customer_terms,
      'quote_version_pricing_snapshot', v_version_pricing_snapshot,
      'accepted_by', auth.uid(),
      'accepted_at', v_accepted_at,
      'freight_payment_arrangement', 'direct_customer_to_provider',
      'krim_collects_freight_payment', false,
      'evidence_scope', 'operational_customer_acceptance_record_not_a_signed_contract'
    )
  );

  RETURN v_quote;
END;
$function$;

REVOKE ALL ON FUNCTION public.krim_accept_global_quote(bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.krim_accept_global_quote(bigint) TO authenticated, service_role;
