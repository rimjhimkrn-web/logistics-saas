-- KRIM Cashfree sandbox payment-provider support
alter table public.payment_orders
  add column if not exists payment_provider text not null default 'razorpay',
  add column if not exists cashfree_order_id text,
  add column if not exists cashfree_payment_id text,
  add column if not exists cashfree_payment_session_id text;

create unique index if not exists payment_orders_cashfree_order_id_uidx
  on public.payment_orders (cashfree_order_id)
  where cashfree_order_id is not null;

create index if not exists payment_orders_provider_status_idx
  on public.payment_orders (payment_provider, status);

alter table public.payment_orders
  drop constraint if exists payment_orders_payment_provider_check;
alter table public.payment_orders
  add constraint payment_orders_payment_provider_check
  check (payment_provider in ('razorpay','cashfree'));
