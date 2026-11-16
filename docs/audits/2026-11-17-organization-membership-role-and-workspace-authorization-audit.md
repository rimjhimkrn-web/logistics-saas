# KRIM organization membership, role permissions and workspace authorization audit

**Date:** 2026-11-17
**Scope:** Organization/member RLS, role-assignment access helper, invitation functions and authenticated table privileges.
**Status:** PARTIAL — read-only production review; no production writes.

## Controls observed

- The following identity tables have RLS enabled: `krim_network_memberships`, `krim_organization_contacts`, `krim_organization_domains`, `krim_organization_invitations`, `krim_organization_locations`, `krim_organization_members`, `krim_organization_onboarding`, `krim_organization_relationships`, `krim_organization_verifications`, `krim_organizations`, `krim_role_permissions`, `krim_security_permissions`, `krim_security_roles`, `krim_user_role_assignments` and legacy `user_roles`.
- `krim_organization_members` authenticated policy is SELECT-only and restricts rows to `user_id = auth.uid()`.
- `krim_organizations` authenticated policy is SELECT-only and permits active members; platform administrators additionally require AAL2 and `admin.platform` permission.
- Organization contact/domain/location/onboarding/verification/network membership reads use `private.krim_has_organization_access`.
- Role-permission/security-role/security-permission catalogs are readable only by AAL2 platform administrators.
- `krim_user_role_assignments` and legacy `user_roles` authenticated policies expose only the caller's own role rows.
- No authenticated INSERT/UPDATE/DELETE table grants were found for the core `krim_organization_members`, `krim_organizations`, `krim_user_role_assignments`, `krim_role_permissions`, `krim_security_roles` or `krim_security_permissions` tables in the inspected grant results. Authenticated clients therefore rely on narrow RPCs for identity changes.
- `private.krim_has_permission` requires an active role assignment, a granted role-permission mapping, an active membership and an active organization. `private.krim_has_organization_access` requires an active membership and active organization.

## Defects and risks requiring remediation

### P1 — legacy driver invitation overload is inconsistent with the canonical flow

`krim_create_driver_invitation(text)` is executable by `service_role`/`postgres`, while the canonical `(bigint,text)` overload is executable by authenticated users and applies the stronger current eligibility checks. The legacy overload writes to `krim_organization_invitations` using an MD5 token hash, while the canonical acceptance RPC validates a SHA-256 hash in `private.krim_driver_invitations`. The two overloads appear to be separate invitation models and must not be treated as interchangeable. Inventory all callers and either remove/disable the legacy route after migration reconciliation or implement an explicit compatible adapter with one token store and one acceptance lifecycle.

### P1 — ambiguous partner organization selection in legacy invitation creator

`krim_create_driver_invitation(text)` selects the first active organization for which the caller has `partner.manage`; it does not require exactly one eligible organization. The canonical `(bigint,text)` overload binds the requested organization and is safer. The old overload is service-role-only, but any internal caller that relies on it must provide a validated organization context rather than an implicit first match.

### P1 — invitation acceptance grants membership before driver verification

`krim_accept_driver_invitation(text)` correctly requires a confirmed matching email, single-use unexpired unrevoked SHA-256 token, and currently eligible registered/compliant transport carrier. It creates or reactivates an organization membership with role `driver`, but driver profile verification remains `pending`. This is appropriate only if every driver operational RPC and read policy independently requires current driver verification, active carrier eligibility, and exact assignment binding. Do not equate invitation acceptance or active membership with driver authorization to operate.

### P1 — permission helper's NULL-auth behavior must be explicitly constrained

`private.krim_has_permission` and `private.krim_has_organization_access` include `(auth.uid() IS NULL OR auth.uid() = p_user_id)`. This accommodates trusted service-role execution, but it means these helpers must never be exposed through an authenticated-callable RPC that accepts an arbitrary `p_user_id`, and every SECURITY DEFINER caller must derive the user from `auth.uid()` or enforce a trusted server-only caller. Audit all callers before any change; do not alter this shared helper blindly.

### P1 — broad authenticated write grants require table-by-table reconciliation

A read-only grant inventory returned authenticated INSERT/UPDATE/DELETE privileges across numerous operational tables (including accounting configuration/posting, financial approval/posting records, customer acquisition, customer profiles, AI records, execution jobs, growth and offline queue tables). Grants alone do not prove exploitability because RLS policies may constrain them, but they materially expand the attack surface. Perform a table-by-table matrix of grants × RLS enabled × policies × policy predicates × triggers × RPC alternatives, then revoke direct writes where the intended design is permission-checked RPC-only. Do not issue blanket revokes without dependency and policy analysis.

## Required next work

1. Enumerate every SECURITY DEFINER function that calls either private access helper; classify caller identity derivation, EXECUTE grants and whether user/org IDs are caller-controlled.
2. Reconcile all identity mutation RPCs: provisioning, member invitation, invitation acceptance/revocation, role assignment, role change, membership suspension/removal and organization closure.
3. Trace both driver invitation overloads and all frontend callers; choose one canonical invitation store and acceptance path.
4. Verify active membership role and `krim_user_role_assignments` cannot diverge in a way that grants a higher role or stale permissions; inspect triggers and role assignment RPCs.
5. Build the authenticated-write grant/RLS matrix for the nine workspaces, starting with finance, accounting, shipments, driver evidence, warehouse inventory and customer records.
6. Add staging negative tests: cross-organization ID substitution, inactive membership, suspended organization, stale role assignment, user-supplied user ID, aal1 platform admin, invitation replay/expiry/email mismatch/revocation, and multiple partner memberships.
7. Run isolated staging tests and CI; only then mark any access-control domain CLOSED — VERIFIED.

## Production boundary

No membership, role, invitation, permission, RLS policy, grant or production data was changed. Do not apply remediation SQL until the 558-row production migration history is reconciled with repository migrations and the user explicitly authorizes production changes. This audit is not a blanket security clearance.