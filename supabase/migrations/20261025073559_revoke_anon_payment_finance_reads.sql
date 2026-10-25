-- Anonymous clients must not have direct privileges on payment/finance rows.
-- Authenticated access remains governed by the existing organization-scoped RLS.
BEGIN;
REVOKE ALL PRIVILEGES ON TABLE public.payment_orders FROM PUBLIC, anon;
REVOKE ALL PRIVILEGES ON TABLE public.krim_financial_transactions FROM PUBLIC, anon;
REVOKE ALL PRIVILEGES ON TABLE public.krim_partner_payables FROM PUBLIC, anon;
COMMIT;
