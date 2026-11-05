-- Restrict partner capability records to active members of their own organization.
-- Direct writes remain unavailable; partner submissions use the validated RPC.
REVOKE SELECT ON TABLE public.krim_partner_capabilities FROM anon;
GRANT SELECT ON TABLE public.krim_partner_capabilities TO authenticated;
DROP POLICY IF EXISTS "krim_partner_capabilities_read_own_active_org" ON public.krim_partner_capabilities;
CREATE POLICY "krim_partner_capabilities_read_own_active_org"
ON public.krim_partner_capabilities
FOR SELECT TO authenticated
USING (private.krim_has_organization_access((SELECT auth.uid()),organization_id));
