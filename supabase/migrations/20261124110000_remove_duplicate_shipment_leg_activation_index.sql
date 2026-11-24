-- Remove one byte-for-byte equivalent unique index.
-- Keep uq_krim_leg_activation_idempotency as the canonical idempotency guard.
-- Both indexes previously enforced the same partial unique key:
-- (shipment_id, idempotency_key) WHERE idempotency_key IS NOT NULL.
DROP INDEX IF EXISTS public.uq_krim_leg_activation_request_key;
