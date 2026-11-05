-- Require an active organization membership and active organization
-- before a role assignment can grant any permission.
-- This closes stale authorization after membership removal/suspension.

CREATE OR REPLACE FUNCTION private.krim_has_permission(
  p_user_id uuid,
  p_organization_id bigint,
  p_permission_code text
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'pg_catalog'
AS $function$
  SELECT
    (auth.uid() IS NULL OR auth.uid() = p_user_id)
    AND EXISTS (
      SELECT 1
      FROM public.krim_user_role_assignments ura
      JOIN public.krim_role_permissions rp
        ON rp.role_id = ura.role_id
       AND rp.granted = true
      JOIN public.krim_security_permissions sp
        ON sp.id = rp.permission_id
      JOIN public.krim_organization_members m
        ON m.user_id = ura.user_id
       AND m.organization_id = ura.organization_id
       AND m.status = 'active'
      JOIN public.krim_organizations o
        ON o.id = ura.organization_id
       AND o.status = 'active'
      WHERE ura.user_id = p_user_id
        AND ura.organization_id = p_organization_id
        AND ura.is_active = true
        AND sp.permission_code = p_permission_code
    );
$function$;
