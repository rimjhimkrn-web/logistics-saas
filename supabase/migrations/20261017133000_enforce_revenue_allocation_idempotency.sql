-- Prevent duplicate revenue-allocation runs and duplicate allocation references on retries.
-- Existing rows are preserved; nullable references remain allowed.
CREATE UNIQUE INDEX IF NOT EXISTS uq_krim_revenue_allocation_runs_idempotency_key
ON public.krim_revenue_allocation_runs (idempotency_key)
WHERE idempotency_key IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_krim_revenue_allocations_allocation_reference
ON public.krim_revenue_allocations (allocation_reference)
WHERE allocation_reference IS NOT NULL;
