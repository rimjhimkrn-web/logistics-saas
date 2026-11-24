-- Proposed least-privilege hardening for the shipment-number default function.
-- Review only: do not apply until migration-history reconciliation is complete.
-- The function is used as the default for public.krim_shipments.shipment_number.
-- Authenticated inserts and trusted service-role workflows retain EXECUTE.
-- Anonymous callers must not be able to burn shipment-number sequence values.

begin;

revoke execute on function public.generate_krim_shipment_number() from public;
revoke execute on function public.generate_krim_shipment_number() from anon;
grant execute on function public.generate_krim_shipment_number() to authenticated, service_role;

-- Defense in depth: the sequence is needed by the default function for
-- authenticated/service_role inserts, but not by anonymous API callers.
revoke usage, select, update on sequence public.krim_shipment_number_seq from public;
revoke usage, select, update on sequence public.krim_shipment_number_seq from anon;
grant usage, select, update on sequence public.krim_shipment_number_seq to authenticated, service_role;

commit;
