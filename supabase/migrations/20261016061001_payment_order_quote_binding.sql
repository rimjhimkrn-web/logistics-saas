-- Bind each Razorpay order to the exact accepted quote, partner bid, and customer organization.
-- Nullable columns preserve compatibility with older payment-order records.
ALTER TABLE public.payment_orders
  ADD COLUMN IF NOT EXISTS krim_quote_id bigint,
  ADD COLUMN IF NOT EXISTS partner_quote_id bigint,
  ADD COLUMN IF NOT EXISTS customer_organization_id bigint;

DO $migration$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'payment_orders_krim_quote_id_fkey'
      AND conrelid = 'public.payment_orders'::regclass
  ) THEN
    ALTER TABLE public.payment_orders
      ADD CONSTRAINT payment_orders_krim_quote_id_fkey
      FOREIGN KEY (krim_quote_id) REFERENCES public.krim_quotes(id) ON DELETE RESTRICT;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'payment_orders_partner_quote_id_fkey'
      AND conrelid = 'public.payment_orders'::regclass
  ) THEN
    ALTER TABLE public.payment_orders
      ADD CONSTRAINT payment_orders_partner_quote_id_fkey
      FOREIGN KEY (partner_quote_id) REFERENCES public.krim_partner_quotes(id) ON DELETE RESTRICT;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'payment_orders_customer_organization_id_fkey'
      AND conrelid = 'public.payment_orders'::regclass
  ) THEN
    ALTER TABLE public.payment_orders
      ADD CONSTRAINT payment_orders_customer_organization_id_fkey
      FOREIGN KEY (customer_organization_id) REFERENCES public.krim_organizations(id) ON DELETE RESTRICT;
  END IF;
END
$migration$;

CREATE INDEX IF NOT EXISTS payment_orders_quote_lookup_idx
  ON public.payment_orders(krim_quote_id, created_at DESC)
  WHERE krim_quote_id IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS payment_orders_one_open_order_per_quote_uidx
  ON public.payment_orders(krim_quote_id)
  WHERE krim_quote_id IS NOT NULL AND status IN ('created','pending');
