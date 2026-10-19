-- KRIM hardening: these privileged RPCs are intended only for signed-in users.
-- Keep SECURITY DEFINER because the reviewed routines enforce auth.uid(),
-- organization membership, and operation-specific permissions internally.
REVOKE EXECUTE ON FUNCTION public.krim_accept_global_quote(bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.krim_accept_global_quote(bigint) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.krim_award_partner_quote(bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.krim_award_partner_quote(bigint) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.krim_award_partner_quote_for_checkout(bigint, timestamptz) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.krim_award_partner_quote_for_checkout(bigint, timestamptz) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.krim_create_global_shipment(bigint, bigint, bigint, text, numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.krim_create_global_shipment(bigint, bigint, bigint, text, numeric) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.krim_create_partner_opportunity(bigint, timestamptz, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.krim_create_partner_opportunity(bigint, timestamptz, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.krim_create_tariff_quote(bigint, text, timestamptz) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.krim_create_tariff_quote(bigint, text, timestamptz) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.krim_provision_customer_organization(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.krim_provision_customer_organization(text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.krim_provision_partner_organization(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.krim_provision_partner_organization(text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.krim_respond_to_partner_assignment(bigint, boolean, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.krim_respond_to_partner_assignment(bigint, boolean, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.krim_submit_partner_onboarding(text, text, text, text, text[]) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.krim_submit_partner_onboarding(text, text, text, text, text[]) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.krim_submit_partner_quote(bigint, numeric, text, timestamptz, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.krim_submit_partner_quote(bigint, numeric, text, timestamptz, text) TO authenticated;
