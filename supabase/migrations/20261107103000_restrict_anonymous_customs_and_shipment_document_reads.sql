-- Remove inherited PUBLIC/anon SELECT grants from customs and shipment document records.
-- Authenticated reads remain protected by each table's existing RLS policies.
REVOKE SELECT ON TABLE public.krim_shipment_customs FROM PUBLIC, anon;
REVOKE SELECT ON TABLE public.krim_exceptions FROM PUBLIC, anon;
REVOKE SELECT ON TABLE public.krim_shipment_documents FROM PUBLIC, anon;
REVOKE SELECT ON TABLE public.krim_documents FROM PUBLIC, anon;

GRANT SELECT ON TABLE public.krim_shipment_customs TO authenticated;
GRANT SELECT ON TABLE public.krim_exceptions TO authenticated;
GRANT SELECT ON TABLE public.krim_shipment_documents TO authenticated;
GRANT SELECT ON TABLE public.krim_documents TO authenticated;
