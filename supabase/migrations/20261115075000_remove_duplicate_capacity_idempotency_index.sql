-- Both indexes enforced the exact same partial unique key. Keep the original canonical index.
DROP INDEX IF EXISTS public.uq_krim_capacity_reservation_org_idempotency;
