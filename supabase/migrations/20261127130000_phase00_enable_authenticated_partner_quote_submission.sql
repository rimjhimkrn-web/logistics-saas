-- Phase 00: allow authenticated partner users to invoke the guarded quote RPC.
-- The function itself enforces auth.uid(), active verified registered-business
-- partner membership, quote.create, current compliance/capability, currency,
-- opportunity state/deadline, and cross-organization restrictions.
-- No direct table write privileges are granted.
REVOKE ALL ON FUNCTION public.krim_submit_partner_quote(bigint, numeric, text, timestamptz, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.krim_submit_partner_quote(bigint, numeric, text, timestamptz, text) FROM anon;
GRANT EXECUTE ON FUNCTION public.krim_submit_partner_quote(bigint, numeric, text, timestamptz, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.krim_submit_partner_quote(bigint, numeric, text, timestamptz, text) TO service_role;
