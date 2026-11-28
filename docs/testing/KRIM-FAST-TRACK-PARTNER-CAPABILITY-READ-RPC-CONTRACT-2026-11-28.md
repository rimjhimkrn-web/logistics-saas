# KRIM Fast-Track — Partner Capability Read RPC Contract
Date: 2026-11-28
Environment: Staging-only design artifact
Branch: staging/phase00-env-isolation
Status: CONTRACT DESIGN — NOT IMPLEMENTED

## Objective
Replace the partner workspace's direct SELECT from public.krim_partner_capabilities with a narrowly scoped authenticated RPC. This resolves the table privilege mismatch without opening direct table access or reusing the platform-admin listing endpoint.

## Proposed RPC
Name: public.krim_partner_list_capabilities_v1(p_organization_id bigint)
Return: jsonb

The organization id is a requested scope, not proof of access. The function must independently authorize the caller for that exact organization.

### Authorization contract
1. Require auth.uid() IS NOT NULL; reject anonymous and unauthenticated sessions.
2. Require private.krim_has_permission(auth.uid(), p_organization_id, 'partner.manage') OR a separately approved read-only capability permission if the permission catalogue supports it. Do not rely only on organization membership.
3. Lock/read the organization and require an active partner-type organization, registered_business account mode, active lifecycle, and current compliance/verification state consistent with capability visibility policy.
4. Verify membership/permission for the requested org. A user with multiple org memberships may request only one authorized organization at a time.
5. Never accept actor UUID, role, permission, owner ID or tenant identity from client payload.
6. No AAL2 requirement for ordinary partner self-service listing unless the risk assessment explicitly classifies this as privileged; AAL2 remains required for platform-admin approval/revocation.

### Response allowlist
Return only fields needed for the partner workspace:
- capability_id
- organization_id
- transport_mode_id and safe mode label/code
- service_type
- coverage_country_id and safe country label/code
- coverage_region
- max_weight_kg
- refrigerated
- hazardous_goods_capable
- active
- verification_status
- effective_from / effective_until
- created_at
- safe submission summary: evidence_submitted boolean, evidence_count integer, submitted_at timestamp if valid

Do NOT return:
- raw Storage object paths
- submitter UUID
- reviewer UUID or private reviewer notes
- raw metadata JSON
- internal audit state, tokens or authorization internals

The function must filter by exact requested organization and must never return rows for another organization. If the organization is not authorized, return a consistent authorization error rather than an empty result that can be used for tenant enumeration.

### Function execution/security model
- Prefer SECURITY INVOKER if it can safely read the required tables through the caller's narrowly granted privileges and RLS. Do not add broad direct table grants merely to make the function work.
- If a privileged read is technically required, use a carefully reviewed SECURITY DEFINER function with fixed empty search_path, fully schema-qualified references, auth.uid() checks, exact tenant permission validation, strict output allowlist and explicit grants.
- For a SECURITY DEFINER public RPC: REVOKE ALL EXECUTE ON FUNCTION ... FROM PUBLIC, anon, authenticated; then GRANT EXECUTE only to authenticated. (The explicit revoke from authenticated is followed by a deliberate grant.)
- Do not rely on RLS alone inside SECURITY DEFINER; it runs with owner privileges and may bypass RLS.
- Do not reuse public.krim_admin_list_partner_capabilities(); it is AAL2 + admin.platform and returns platform-wide pending records.
- Do not expose a generic organization selector or arbitrary SQL/filter JSON.

## Suggested SQL implementation shape (pseudocode, not executable migration)
CREATE FUNCTION public.krim_partner_list_capabilities_v1(p_organization_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE v_uid uuid := auth.uid();
BEGIN
  -- reject missing auth and null org
  -- assert private.krim_has_permission(v_uid, p_organization_id, 'partner.manage')
  -- assert active partner org + registered_business + current compliance
  -- aggregate only rows with c.organization_id = p_organization_id
  -- join safe mode/country labels
  -- compute evidence_submitted/count from validated metadata without returning paths
  -- return {organization_id, items, count}
END;
$$;

The above is a design outline only. It must not be copied into a migration without completing function dependency, grants, Data API exposure, RLS and local test review.

## Frontend contract
In public/partner/services-capabilities.html:
- Remove direct client.from('krim_partner_capabilities').select(...).
- Call client.rpc('krim_partner_list_capabilities_v1', {p_organization_id: Number(org.id)}).
- Validate response shape and organization_id equals the selected org.
- Map safe response fields to existing renderer.
- Preserve country/mode catalogue loading only if their current direct SELECT grants and RLS are separately confirmed.
- Keep form submission via krim_partner_submit_service_capability_v2 unchanged in this isolated read-path patch.
- Do not mix evidence-attachment migration into this read API patch.
- For uncertain RPC/network outcomes, show safe error state; never infer empty list from an error.

## Two-tenant security test plan
Provision only through the approved isolated test-fixture workflow after its own gates pass. Use separate identities:
- Partner A: active membership + partner.manage on Org A.
- Partner B: active membership + partner.manage on Org B.
- User C: authenticated but no partner permission.
- Optional user D: membership in Org A but inactive or revoked.
Seed two distinct capability rows in test-only isolated fixtures.

Required assertions:
1. A requesting Org A receives only A records.
2. B requesting Org B receives only B records.
3. A requesting Org B is denied.
4. B requesting Org A is denied.
5. C requesting either org is denied.
6. D with inactive/revoked membership is denied.
7. Anonymous request is denied.
8. Unknown org and non-partner org are denied without data leakage.
9. A response contains no raw evidence path, submitter UUID, reviewer notes or raw metadata.
10. Empty org returns a valid empty list only after authorization succeeds.
11. Capability rows with malformed evidence metadata produce safe summary values and do not crash or disclose paths.
12. Direct authenticated SELECT on krim_partner_capabilities remains denied.
13. Anonymous EXECUTE is denied; authenticated EXECUTE is granted only after all function guards are present.
14. Admin listing/review still requires AAL2 and admin.platform; partner RPC cannot invoke or bypass review.
15. No fixture or synthetic test data enters production tables or triggers real notifications/email.

## Integration/acceptance checks
- Browser authenticated partner session can load the workspace without direct capability table grants.
- Browser receives correct rows and safe status summaries.
- Partner A/B isolation verified with two real independent sessions, not a single owner session.
- Existing staging preview remains visibly illustrative and is not counted as an integration test.
- Test active, pending, rejected, suspended and expired records.
- Check PostgREST function schema exposure and function signature cache refresh behavior.
- Run Supabase security advisors after migration; manually inspect grants and RLS.
- Confirm current CLI version and use explicit Staging target for any CLI database operation. Supabase CLI v3 defaults database commands to local; hosted commands require explicit --remote and hosted mutations require confirmation/--yes in unattended contexts.

## Rollout boundary
This contract is a separate minimal patch from the append-only evidence-history feature. Implement and verify the read RPC first, then update the frontend. Do not add direct table SELECT grants. Do not deploy until migration review, test plan and backup/rollback evidence are approved.

## Current evidence
- Frontend path inspected: public/partner/services-capabilities.html, blob 12a0d32dd5e850165cf92acf252b0f75c8482156.
- Deployed Staging helper krim_partner_submit_service_capability() checks auth.uid(), partner.manage, active registered-business partner org and current compliance. It is SECURITY DEFINER with empty search_path.
- Staging capability table has RLS and organization SELECT policy, but authenticated has no direct SELECT/INSERT/UPDATE table privilege in the inspected snapshot.
- Existing admin list RPC is SECURITY DEFINER, requires AAL2 and admin.platform, returns platform pending review queue; not a partner read endpoint.
- Staging partner workspace hostname branch deliberately renders local illustrative data and returns before auth/client initialization.
- No database or frontend code change was made in this checkpoint.

## Open gates
- Validate permission semantics and exact organization lifecycle rules against canonical permission catalogue.
- Verify country/mode table grants for frontend catalogue reads.
- Determine if function can safely be SECURITY INVOKER; otherwise threat-model SECURITY DEFINER.
- Build local isolated SQL test harness or approved Staging fixtures.
- Complete full repository-wide dynamic/indirect caller certification.
- No implementation, migration, fixture, deployment or Production access in this checkpoint.

Phase 00 remains OPEN. Phase 01 is not authorized.
