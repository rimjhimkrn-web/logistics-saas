-- Phase 00 Checkpoint 16: authenticated RLS policy dependencies.
-- Staging migration: identity-bound organization/permission helpers and
-- minimum grants required to evaluate scoped organization/shipment policies.

CREATE OR REPLACE FUNCTION private.krim_has_organization_access(p_user_id uuid, p_organization_id bigint)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'pg_catalog'
AS $function$
  SELECT
    auth.uid() IS NOT NULL
    AND auth.uid() = p_user_id
    AND EXISTS (
      SELECT 1
      FROM public.krim_organization_members m
      JOIN public.krim_organizations o
        ON o.id = m.organization_id
       AND o.status = 'active'
      WHERE m.user_id = p_user_id
        AND m.organization_id = p_organization_id
        AND m.status = 'active'
    );
$function$;

CREATE OR REPLACE FUNCTION private.krim_has_permission(p_user_id uuid, p_organization_id bigint, p_permission_code text)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'pg_catalog'
AS $function$
  SELECT
    auth.uid() IS NOT NULL
    AND auth.uid() = p_user_id
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

-- Policy helper execution is available to authenticated only.
GRANT USAGE ON SCHEMA private TO authenticated;

GRANT EXECUTE ON FUNCTION
  private.krim_has_organization_access(uuid, bigint),
  private.krim_has_permission(uuid, bigint, text),
  private.krim_warehouse_org_eligible(bigint),
  private.krim_user_has_active_partner_assignment(bigint),
  private.krim_partner_compliance_is_current(bigint),
  private.krim_partner_capability_covers_shipment(bigint, bigint),
  private.krim_warehouse_is_operator(uuid, bigint, uuid)
TO authenticated;

GRANT EXECUTE ON FUNCTION
  public.krim_has_organization_access(uuid, bigint),
  public.krim_has_permission(uuid, bigint, text)
TO authenticated;

-- Required by direct EXISTS dependencies in scoped organization, partner
-- opportunity and shipment SELECT policies. RLS on both relations remains on.
GRANT SELECT ON TABLE
  public.krim_organizations,
  public.krim_partner_opportunities
TO authenticated;
