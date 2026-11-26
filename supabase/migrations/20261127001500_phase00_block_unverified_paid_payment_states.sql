-- Phase 00: keep legacy freight/payment tables fail-closed until KRIM commercial billing is implemented.
-- This blocks a privileged backend write from marking a payment paid and firing
-- legacy financial/notification triggers without verified provider evidence.

CREATE OR REPLACE FUNCTION public.krim_block_unverified_paid_payment_state()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = pg_catalog
AS $function$
BEGIN
  IF NEW.status = 'paid' THEN
    RAISE EXCEPTION
      'payment_activation_disabled: provider verification and KRIM commercial-purpose binding are not implemented'
      USING ERRCODE = '55000';
  END IF;
  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION public.krim_block_unverified_paid_payment_state()
  FROM PUBLIC, anon, authenticated, service_role;

DROP TRIGGER IF EXISTS trg_krim_block_unverified_paid_payment_order
  ON public.payment_orders;
CREATE TRIGGER trg_krim_block_unverified_paid_payment_order
BEFORE INSERT OR UPDATE OF status ON public.payment_orders
FOR EACH ROW
EXECUTE FUNCTION public.krim_block_unverified_paid_payment_state();

DROP TRIGGER IF EXISTS trg_krim_block_unverified_paid_payment
  ON public.payments;
CREATE TRIGGER trg_krim_block_unverified_paid_payment
BEFORE INSERT OR UPDATE OF status ON public.payments
FOR EACH ROW
EXECUTE FUNCTION public.krim_block_unverified_paid_payment_state();
