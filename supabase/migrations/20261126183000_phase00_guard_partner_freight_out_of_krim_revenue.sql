-- Phase 00 fast-track safety guard: prevent partner freight from being
-- invoiced/recognised as KRIM revenue until the independent commercial
-- billing model and ownership checks are implemented and verified.
-- Staging only; no data is modified.
CREATE OR REPLACE FUNCTION public.krim_internal_create_customer_invoice_for_delivered_shipment(p_shipment_id bigint)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public
AS $$
BEGIN
  RAISE EXCEPTION 'freight_invoice_creation_disabled: partner must invoice customer directly; KRIM invoices only its own contracted commercial fees';
END;
$$;

CREATE OR REPLACE FUNCTION public.krim_internal_post_revenue_recognition_to_ledger(p_shipment_id bigint)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public
AS $$
BEGIN
  RAISE EXCEPTION 'freight_revenue_recognition_disabled: partner freight value must not be posted as KRIM revenue';
END;
$$;

CREATE OR REPLACE FUNCTION public.krim_internal_recognize_delivered_revenue(p_shipment_id bigint)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, krim_internal, public
AS $$
BEGIN
  RAISE EXCEPTION 'freight_revenue_allocation_disabled: only independently earned KRIM commercial revenue may be allocated';
END;
$$;

CREATE OR REPLACE FUNCTION krim_internal.apply_verified_payment_to_invoice(
  p_payment_id bigint, p_invoice_id bigint, p_idempotency_key text
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public
AS $$
BEGIN
  RAISE EXCEPTION 'invoice_payment_application_disabled: payment ownership and commercial-purpose binding are not yet verified';
END;
$$;

REVOKE ALL ON FUNCTION public.krim_internal_create_customer_invoice_for_delivered_shipment(bigint) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.krim_internal_create_customer_invoice_for_delivered_shipment(bigint) TO service_role;
REVOKE ALL ON FUNCTION public.krim_internal_post_revenue_recognition_to_ledger(bigint) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.krim_internal_post_revenue_recognition_to_ledger(bigint) TO service_role;
REVOKE ALL ON FUNCTION public.krim_internal_recognize_delivered_revenue(bigint) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.krim_internal_recognize_delivered_revenue(bigint) TO service_role;
REVOKE ALL ON FUNCTION krim_internal.apply_verified_payment_to_invoice(bigint,bigint,text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION krim_internal.apply_verified_payment_to_invoice(bigint,bigint,text) TO service_role;

COMMENT ON FUNCTION public.krim_internal_create_customer_invoice_for_delivered_shipment(bigint) IS
'DISABLED: legacy shipment freight invoicing conflicts with KRIM partner-direct model. Partner invoices customer; KRIM separately invoices own commercial fees.';
COMMENT ON FUNCTION public.krim_internal_post_revenue_recognition_to_ledger(bigint) IS
'DISABLED: legacy full-freight revenue posting is prohibited under KRIM partner-direct model.';
COMMENT ON FUNCTION public.krim_internal_recognize_delivered_revenue(bigint) IS
'DISABLED: legacy shipment gross revenue allocation is prohibited until KRIM-owned fee revenue is independently recorded.';
COMMENT ON FUNCTION krim_internal.apply_verified_payment_to_invoice(bigint,bigint,text) IS
'DISABLED: legacy payment schema/ownership binding is invalid; do not apply freight payments to KRIM invoices.';
