-- Prevent concurrent retries from creating multiple partner payables for one assignment.
-- The payable workflow already treats assignment_id as its idempotency boundary.
CREATE UNIQUE INDEX IF NOT EXISTS uq_krim_partner_payables_assignment_id
ON public.krim_partner_payables (assignment_id)
WHERE assignment_id IS NOT NULL;
