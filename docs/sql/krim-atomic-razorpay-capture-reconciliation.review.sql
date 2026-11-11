-- REVIEW ONLY: coordinated atomic Razorpay captured-payment transition.
-- Do not apply directly to production. Convert into a migration after staging parity
-- and regression/concurrency tests are available.

create or replace function public.krim_internal_reconcile_razorpay_captured_payment(
  p_payment_order_id uuid,
  p_razorpay_payment_id text
)
returns bigint
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_order public.payment_orders%rowtype;
  v_tx_id bigint;
  v_amount numeric;
begin
  if coalesce(auth.jwt() ->> 'role', '') <> 'service_role' then
    raise exception 'service_role required' using errcode = '42501';
  end if;

  if p_payment_order_id is null
     or nullif(btrim(p_razorpay_payment_id), '') is null then
    raise exception 'Payment order ID and Razorpay payment ID are required' using errcode = '22023';
  end if;

  select *
  into v_order
  from public.payment_orders
  where id = p_payment_order_id
    and payment_provider = 'razorpay'
  for update;

  if not found then
    raise exception 'Razorpay payment order not found' using errcode = 'P0002';
  end if;

  -- Only created/attempted orders may become paid. A paid replay is valid only
  -- for the exact same provider payment ID. Never revive terminal states.
  if v_order.status = 'paid' then
    if v_order.razorpay_payment_id is distinct from p_razorpay_payment_id then
      raise exception 'Conflicting Razorpay payment ID for already-paid order' using errcode = '23514';
    end if;
  elsif v_order.status in ('created', 'attempted') then
    if v_order.razorpay_payment_id is not null
       and v_order.razorpay_payment_id <> p_razorpay_payment_id then
      raise exception 'Payment order is already bound to a different Razorpay payment ID' using errcode = '23514';
    end if;

    update public.payment_orders
    set status = 'paid',
        razorpay_payment_id = p_razorpay_payment_id,
        paid_at = coalesce(paid_at, pg_catalog.now()),
        failure_reason = null,
        updated_at = pg_catalog.now()
    where id = p_payment_order_id
    returning * into v_order;
  else
    raise exception 'Payment order is in a terminal or unsupported state: %', v_order.status
      using errcode = '23514';
  end if;

  if v_order.krim_shipment_id is null
     or v_order.customer_organization_id is null
     or v_order.krim_quote_id is null
     or v_order.partner_quote_id is null
     or upper(v_order.currency) <> 'INR'
     or v_order.amount_paise is null
     or v_order.amount_paise <= 0 then
    raise exception 'Paid Razorpay order is not fully bound to a valid KRIM shipment and quote'
      using errcode = '23514';
  end if;

  if not exists (
    select 1
    from public.krim_shipments s
    join public.krim_quotes q
      on q.shipment_id = s.id
     and q.customer_organization_id = s.customer_organization_id
     and q.id = v_order.krim_quote_id
     and q.partner_quote_id = v_order.partner_quote_id
     and q.status = 'accepted'
    where s.id = v_order.krim_shipment_id
      and s.customer_organization_id = v_order.customer_organization_id
      and round(q.amount, 2) = round(v_order.amount_paise::numeric / 100, 2)
      and upper(q.currency_code) = 'INR'
  ) then
    raise exception 'Accepted quote does not match the paid order' using errcode = '23514';
  end if;

  if not exists (
    select 1
    from public.krim_shipment_partner_assignments a
    join public.krim_capacity_leg_bindings b
      on b.id = a.capacity_binding_id
     and b.shipment_id = a.shipment_id
     and b.shipment_leg_id = a.shipment_leg_id
     and b.status = 'confirmed'
    join public.krim_capacity_reservations r
      on r.id = b.reservation_id
     and r.organization_id = a.partner_organization_id
     and r.shipment_id = a.shipment_id
     and r.shipment_leg_id = a.shipment_leg_id
     and r.status = 'confirmed'
    where a.shipment_id = v_order.krim_shipment_id
      and a.partner_quote_id = v_order.partner_quote_id
      and a.status = 'accepted'
  ) then
    raise exception 'Accepted assignment and confirmed capacity reservation are required'
      using errcode = '23514';
  end if;

  v_amount := v_order.amount_paise::numeric / 100;

  insert into public.krim_financial_transactions (
    shipment_id, organization_id, transaction_type, amount, currency_code,
    provider, provider_reference, status, transaction_time, metadata,
    direction, ownership_scope, source_reference, idempotency_key
  ) values (
    v_order.krim_shipment_id,
    v_order.customer_organization_id,
    'payment',
    v_amount,
    'INR',
    'razorpay',
    p_razorpay_payment_id,
    'completed',
    coalesce(v_order.paid_at, pg_catalog.now()),
    pg_catalog.jsonb_build_object(
      'payment_order_id', v_order.id,
      'razorpay_order_id', v_order.razorpay_order_id,
      'razorpay_payment_id', p_razorpay_payment_id,
      'krim_quote_id', v_order.krim_quote_id,
      'partner_quote_id', v_order.partner_quote_id,
      'source', 'verified_razorpay_capture'
    ),
    'credit',
    'company',
    'payment_order:' || v_order.id::text,
    'razorpay_payment:' || p_razorpay_payment_id
  )
  on conflict (provider, provider_reference)
    where provider is not null and provider_reference is not null
  do nothing
  returning id into v_tx_id;

  if v_tx_id is null then
    select id into v_tx_id
    from public.krim_financial_transactions
    where provider = 'razorpay'
      and provider_reference = p_razorpay_payment_id
      and shipment_id = v_order.krim_shipment_id
      and organization_id = v_order.customer_organization_id
      and transaction_type = 'payment'
      and amount = v_amount
      and currency_code = 'INR'
      and status = 'completed'
      and direction = 'credit'
      and ownership_scope = 'company'
      and source_reference = 'payment_order:' || v_order.id::text
      and idempotency_key = 'razorpay_payment:' || p_razorpay_payment_id;

    if v_tx_id is null then
      raise exception 'Existing Razorpay transaction conflicts with verified payment order'
        using errcode = '23514';
    end if;
  end if;

  return v_tx_id;
end;
$function$;

revoke all on function public.krim_internal_reconcile_razorpay_captured_payment(uuid, text)
  from public, anon, authenticated;
grant execute on function public.krim_internal_reconcile_razorpay_captured_payment(uuid, text)
  to service_role;
