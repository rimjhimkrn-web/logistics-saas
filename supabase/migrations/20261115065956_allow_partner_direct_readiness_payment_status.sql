ALTER TABLE public.krim_shipment_readiness_gates
  DROP CONSTRAINT IF EXISTS chk_readiness_payment;

ALTER TABLE public.krim_shipment_readiness_gates
  ADD CONSTRAINT chk_readiness_payment
  CHECK (
    payment_status IS NULL
    OR payment_status = ANY (ARRAY[
      'not_required','pending','paid','failed','missing','partner_direct'
    ]::text[])
  );

COMMENT ON COLUMN public.krim_shipment_readiness_gates.payment_status IS
  'partner_direct means KRIM does not collect or verify freight payment; it is not a paid or settled state.';
