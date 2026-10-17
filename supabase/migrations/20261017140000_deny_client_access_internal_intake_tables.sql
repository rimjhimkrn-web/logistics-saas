-- Explicitly deny browser-role access to internal-only intake/recovery tables.
-- Trusted server-side service_role and database owners retain their intended access.
ALTER TABLE public.krim_public_contact_inquiries ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "deny_client_access_internal_contact_inquiries" ON public.krim_public_contact_inquiries;
CREATE POLICY "deny_client_access_internal_contact_inquiries"
ON public.krim_public_contact_inquiries
FOR ALL TO anon, authenticated
USING (false)
WITH CHECK (false);

ALTER TABLE public.krim_recovery_checkpoints ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "deny_client_access_internal_recovery_checkpoints" ON public.krim_recovery_checkpoints;
CREATE POLICY "deny_client_access_internal_recovery_checkpoints"
ON public.krim_recovery_checkpoints
FOR ALL TO anon, authenticated
USING (false)
WITH CHECK (false);
