-- Remove the duplicate organization-read policy. The pre-existing
-- "KRIM partner capabilities organization access" policy already enforces
-- active organization membership. Anonymous access is not needed.
DROP POLICY IF EXISTS "krim_partner_capabilities_read_own_active_org" ON public.krim_partner_capabilities;
REVOKE SELECT ON TABLE public.krim_partner_capabilities FROM anon;
GRANT SELECT ON TABLE public.krim_partner_capabilities TO authenticated;
