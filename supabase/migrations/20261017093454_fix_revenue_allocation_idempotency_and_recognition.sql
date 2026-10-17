-- Make revenue allocation references stable and idempotent per organization/shipment/source/rule.
-- Fixes the previous PLAN-<rule_code> reference, which collided across shipments.
CREATE OR REPLACE FUNCTION krim_internal.plan_revenue_allocation(
  p_organization_id bigint,
  p_source_transaction_id bigint,
  p_shipment_id bigint,
  p_gross_amount numeric,
  p_currency_code text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
  r record;
  v_amount numeric;
  v_count integer := 0;
  v_inserted integer := 0;
  v_reference text;
BEGIN
  IF p_gross_amount IS NULL OR p_gross_amount < 0 THEN
    RAISE EXCEPTION 'invalid_revenue';
  END IF;
  IF p_organization_id IS NULL THEN
    RAISE EXCEPTION 'organization_required';
  END IF;
  IF p_currency_code IS NULL OR upper(p_currency_code) !~ '^[A-Z]{3}$' THEN
    RAISE EXCEPTION 'invalid_currency';
  END IF;

  FOR r IN
    SELECT *
    FROM public.krim_revenue_allocation_rules
    WHERE status = 'active'
      AND (organization_id = p_organization_id OR organization_id IS NULL)
      AND revenue_scope = 'customer_revenue'
      AND (currency_code IS NULL OR upper(currency_code) = upper(p_currency_code))
      AND (effective_from IS NULL OR effective_from <= now())
      AND (effective_until IS NULL OR effective_until > now())
    ORDER BY (organization_id IS NOT NULL) DESC, priority, id
  LOOP
    IF r.percentage IS NOT NULL THEN
      v_amount := round(p_gross_amount * r.percentage / 100, 2);
    ELSE
      v_amount := least(p_gross_amount, coalesce(r.fixed_amount, 0));
    END IF;

    v_reference := 'KRIM-REV:' || p_organization_id::text || ':' ||
      coalesce(p_shipment_id::text, 'none') || ':' ||
      coalesce(p_source_transaction_id::text, 'none') || ':' || r.id::text;

    INSERT INTO public.krim_revenue_allocations(
      organization_id, source_transaction_id, shipment_id, allocation_type,
      amount, currency_code, status, allocation_reference, policy_snapshot
    )
    VALUES (
      p_organization_id, p_source_transaction_id, p_shipment_id, r.allocation_type,
      v_amount, upper(p_currency_code), 'planned', v_reference,
      jsonb_build_object(
        'rule_id', r.id, 'rule_code', r.rule_code,
        'percentage', r.percentage, 'fixed_amount', r.fixed_amount,
        'revenue_scope', r.revenue_scope
      )
    )
    ON CONFLICT (allocation_reference) WHERE allocation_reference IS NOT NULL DO NOTHING;

    GET DIAGNOSTICS v_inserted = ROW_COUNT;
    v_count := v_count + v_inserted;
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'planned_allocations', v_count, 'idempotent', v_count = 0);
END;
$function$;

-- Revenue recognition uses the same stable reference namespace for retry detection.
CREATE OR REPLACE FUNCTION public.krim_internal_recognize_delivered_revenue(p_shipment_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, krim_internal, pg_temp
AS $function$
DECLARE
  v_shipment public.krim_shipments%ROWTYPE;
  v_invoice public.krim_invoices%ROWTYPE;
  v_existing_count integer;
  v_plan jsonb;
BEGIN
  SELECT * INTO v_shipment
  FROM public.krim_shipments
  WHERE id = p_shipment_id
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Shipment % not found', p_shipment_id;
  END IF;
  IF v_shipment.status <> 'delivered' THEN
    RAISE EXCEPTION 'Shipment % must be delivered; current status %', p_shipment_id, v_shipment.status;
  END IF;

  SELECT * INTO v_invoice
  FROM public.krim_invoices
  WHERE shipment_id = p_shipment_id AND invoice_type = 'customer'
  ORDER BY id DESC
  LIMIT 1
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Customer invoice not found for shipment %', p_shipment_id;
  END IF;
  IF v_invoice.status NOT IN ('issued', 'partially_paid', 'paid') THEN
    RAISE EXCEPTION 'Invoice % is not financially eligible; status %', v_invoice.id, v_invoice.status;
  END IF;

  SELECT count(*) INTO v_existing_count
  FROM public.krim_revenue_allocations
  WHERE organization_id = v_invoice.organization_id
    AND shipment_id = p_shipment_id
    AND allocation_reference LIKE
      'KRIM-REV:' || v_invoice.organization_id::text || ':' || p_shipment_id::text || ':%';

  IF v_existing_count > 0 THEN
    RETURN jsonb_build_object(
      'recognized', true, 'idempotent', true, 'shipment_id', p_shipment_id,
      'invoice_id', v_invoice.id, 'allocation_count', v_existing_count,
      'currency_code', v_invoice.currency_code, 'gross_amount', v_invoice.total_amount,
      'next_step', 'partner_payable'
    );
  END IF;

  v_plan := krim_internal.plan_revenue_allocation(
    v_invoice.organization_id, NULL, p_shipment_id,
    v_invoice.total_amount, v_invoice.currency_code
  );

  IF coalesce((v_plan->>'planned_allocations')::integer, 0) = 0 THEN
    RETURN jsonb_build_object(
      'recognized', false, 'idempotent', false, 'shipment_id', p_shipment_id,
      'invoice_id', v_invoice.id, 'currency_code', v_invoice.currency_code,
      'gross_amount', v_invoice.total_amount, 'allocation_status', 'awaiting_policy',
      'plan', v_plan, 'next_step', 'configure_revenue_policy'
    );
  END IF;

  INSERT INTO public.krim_audit_events
    (actor_user_id, organization_id, event_type, entity_type, entity_id, source, metadata, previous_state, new_state, created_at)
  VALUES
    (NULL, v_shipment.customer_organization_id, 'revenue.recognized', 'shipment',
     p_shipment_id::text, 'finance',
     jsonb_build_object('invoice_id', v_invoice.id, 'currency_code', v_invoice.currency_code,
       'gross_amount', v_invoice.total_amount, 'plan', v_plan),
     NULL, jsonb_build_object('allocation_count', (v_plan->>'planned_allocations')::integer), now());

  RETURN jsonb_build_object(
    'recognized', true, 'idempotent', false, 'shipment_id', p_shipment_id,
    'invoice_id', v_invoice.id, 'currency_code', v_invoice.currency_code,
    'gross_amount', v_invoice.total_amount, 'plan', v_plan, 'next_step', 'partner_payable'
  );
END;
$function$;
