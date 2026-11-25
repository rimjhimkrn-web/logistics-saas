# Phase 00 — Organization membership, role assignment and permission-boundary audit

Date: 2026-11-25  
Environment: Production and Staging Supabase catalogs; read-only SQL  
Scope: Canonical organization membership, role assignments, role-permission mapping, permission definitions, legacy user roles, authorization helper functions, RLS policies, table grants, constraints, triggers and environment parity.

## Executive verdict

**NOT VERIFIED for real-user onboarding.** The canonical authorization helper functions implement useful user/org scoping, and direct authenticated table writes are not granted in either environment. However, Staging is not ready for authenticated workspace tests, membership and role-change audit coverage is incomplete, and runtime cross-tenant/role-escalation tests have not been performed.

No SQL writes, grants, test identities, or permission changes were made.

## Catalog snapshot

| Item | Production | Staging |
|---|---:|---:|
| Organization memberships | 13 | 0 |
| User role assignments | 17 | 1 |
| Role-permission mappings | 155 | 0 |
| Permission definitions | 23 | 0 |
| Legacy `user_roles` rows | 5 | 0 |

These are current row counts at inspection time, not proof that records are correct or usable.

## Positive controls observed

### Canonical organization access
`private.krim_has_organization_access(user_id, organization_id)`:
- Requires the requested user to equal `auth.uid()` whenever a JWT user is present.
- Requires an active membership for that user and organization.
- Requires the organization itself to be active.
- Uses SECURITY DEFINER with a fixed `search_path=public, pg_catalog`.
- The public wrapper is not SECURITY DEFINER and delegates to the private helper.

### Canonical permission check
`private.krim_has_permission(user_id, organization_id, permission_code)`:
- Applies the same caller/requested-user equality check.
- Requires an active user-role assignment scoped to the same user and organization.
- Requires a granted role-permission mapping and a matching permission code.
- Requires active membership and active organization.
- Uses SECURITY DEFINER with a fixed search path; the public wrapper is invoker-security and delegates to the private helper.

### Table-level protections
- All five inspected tables have RLS enabled in both environments.
- Production authenticated grants on the canonical membership, role-assignment, role-permission and permission-definition tables are SELECT only.
- Staging has no authenticated table privileges on those five tables.
- No authenticated INSERT/UPDATE/DELETE grants were observed on the canonical membership or role-assignment tables.
- Policies restrict membership and role-assignment reads to the caller's own user ID; role-permission and permission-catalog reads require platform-admin permission.
- Unique constraints prevent duplicate organization/user membership, duplicate user/org/role assignment, duplicate role/permission pairs and duplicate permission codes.
- Foreign keys tie membership and role assignments to Auth users and organizations/roles.

## Findings and risks

1. **Staging authorization foundation is empty/incomplete — hard blocker for signed-in QA.** Staging has no memberships, no permission definitions and no role-permission mappings, and authenticated EXECUTE is not granted on the canonical public/private authorization helper functions. Do not copy Production ACLs or data wholesale. A reviewed synthetic tenant/role seed and least-privilege grants are required after isolation safeguards are established.

2. **Membership role field and canonical role assignments can diverge.** `krim_organization_members` contains a legacy `role` field with its own allowed values, while `krim_has_permission` authorizes through `krim_user_role_assignments` and `krim_role_permissions`. No consistency trigger or constraint linking these representations was observed. Treat the role-assignment graph as canonical and document/deprecate the legacy role field, or enforce synchronization.

3. **Membership audit is INSERT-only.** Production has an AFTER INSERT trigger that records `organization_member_added`. No UPDATE or DELETE audit trigger was observed for `krim_organization_members`, and no role-assignment audit trigger was found on `krim_user_role_assignments`. Membership suspension/reactivation, role grant/revocation and assignment deletion therefore lack equivalent trigger-based before/after evidence in this inspected trigger inventory. This is a governance and incident-investigation gap.

4. **Legacy `user_roles` remains a parallel role surface.** It permits only customer/partner/admin and has an authenticated UPDATE table grant in Production, but its only inspected RLS policy is SELECT-own-row and there is no authenticated UPDATE policy. RLS should block that update path, but runtime confirmation is absent. Keep legacy role data out of authorization decisions unless a deliberate migration contract exists. Confirm no older page or RPC still trusts it.

5. **Service-role context bypasses requested-user equality by design.** The helper condition `auth.uid() IS NULL OR auth.uid() = p_user_id` permits internal contexts without a JWT to evaluate a specified user. Authenticated clients cannot use this to test another user's permissions because their `auth.uid()` must match. Keep service-role credentials server-only and never expose service-role execution to browser clients.

6. **Role assignment model allows multiple roles per user/org.** The unique constraint is on (user, organization, role), not one role per user/org. This can be intentional for additive RBAC, but the application must define whether permissions union across roles, whether conflicting roles are allowed, and how role revocation affects effective permissions. The helper currently unions all granted mappings from active assignments.

7. **No mutation RPC surfaced in the targeted public function-name inventory.** The targeted search found authorization helpers and the membership insert audit trigger, but no obvious public membership/role grant/revoke RPC. This does not prove no mutation path exists: direct server/service-role operations, functions with unrelated names, Auth hooks, and external automation require separate provenance review.

8. **SECURITY DEFINER helper tests remain absent.** Source checks are positive, but there are no JWT-based positive/negative tests for forged user IDs, inactive memberships, suspended organizations, inactive assignments, revoked permissions, role changes, or cross-organization access.

9. **FORCE RLS is not enabled on these inspected tables.** RLS is enabled, authenticated table privileges are constrained, and service-role operations are expected to bypass RLS. Review whether privileged owner-context paths are adequately constrained by SECURITY DEFINER helpers and server-only credential controls. Do not turn on FORCE RLS without reviewing owners, triggers, and service-role workflows.

## Required runtime test matrix

After a dedicated Staging test sink and isolated synthetic identities are approved:
- Authenticated user checks own active organization membership → expected allow.
- User supplies a different user UUID → expected deny.
- User checks another organization without membership → expected deny.
- Inactive membership / suspended organization → expected deny.
- Active membership but no active role assignment → expected deny.
- Inactive role assignment or revoked mapping → expected deny.
- Two roles in one organization → verify intended union semantics.
- AAL1 versus AAL2 admin operations → verify each privileged RPC's policy.
- Attempt direct INSERT/UPDATE/DELETE against membership and role tables → expected deny.
- Attempt legacy `user_roles` update → expected deny under RLS.
- Membership and role grant/revoke lifecycle → verify actor, timestamp, before/after audit and notification intent.
- Verify one tenant cannot enumerate another tenant's memberships, role assignments or permission map.

## Release decision

- Authorization helper source review: **PASS (source-observed only)**.
- Production authenticated direct-write restrictions: **PASS (catalog-observed only)**.
- Staging signed-in authorization readiness: **FAIL / NOT READY**.
- Membership and role-change audit completeness: **FAIL / REMEDIATION REQUIRED**.
- Cross-tenant and privilege-escalation runtime tests: **NOT RUN**.
- Real-user onboarding: **NOT APPROVED**.

This report does not certify runtime RLS behavior, user provisioning, role changes, or workspace access. NO EVIDENCE = NO PASS.
