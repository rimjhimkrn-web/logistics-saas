-- Proposed least-privilege hardening for the shipment-number default function.
-- Review only: do not apply until migration-history reconciliation is complete.
-- public.krim_shipments INSERT is service_role-only in both audited environments.
-- Therefore the default generator and its sequence must remain service_role-only.

begin;

revoke execute on function public.generate_krim_shipment_number() from public;
revoke execute on function public.generate_krim_shipment_number() from anon;
revoke execute on function public.generate_krim_shipment_number() from authenticated;
grant execute on function public.generate_krim_shipment_number() to service_role;

-- Defense in depth: only the trusted server-side shipment creation path inserts
-- krim_shipments, so only service_role needs sequence privileges.
revoke usage, select, update on sequence public.krim_shipment_number_seq from public;
revoke usage, select, update on sequence public.krim_shipment_number_seq from anon;
revoke usage, select, update on sequence public.krim_shipment_number_seq from authenticated;
grant usage, select, update on sequence public.krim_shipment_number_seq to service_role;

commit;
