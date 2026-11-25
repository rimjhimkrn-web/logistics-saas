# Phase 00 — Gate C3.61: Global identity, organization, registration, membership, roles, MFA, tenant access and revocation readiness

**Audit date:** 25 November 2026  
**Evidence baseline:** immutable source commit `72d75a18f985ceb09e468839435ee95700e11e46`; read-only source review plus previously dated 16–17 November audit artifacts.  
**Branch:** `qa/phase-00-baseline-2026-11-25`  
**Verdict:** **FAIL / BLOCKED — NO-GO for unrestricted external account/team onboarding or nine-workspace access certification.**

## Scope and method

Reviewed the immutable baseline's React AuthContext, browser auth core, shared auth service, customer/partner/driver registration entry points, invitation and MFA pages, organization provisioning migrations, driver invitation migrations, and prior organization/RBAC/session audit artifacts. This is source and historical evidence review—not a live authentication test, current deployed database catalog query, penetration test, or compliance certification.

Covered identity creation, email confirmation/callback, organization provisioning, membership, invitations, role assignment, MFA, workspace routing, tenant boundaries, session revocation, suspension/deactivation, and auditability.

## Positive controls observed

1. Customer and partner registration call Supabase Auth and then narrowly scoped organization-provisioning RPCs. The reviewed customer/partner provisioning functions bind the actor to `auth.uid()`, validate legal-name length, use per-user advisory transaction locks, and avoid duplicate active organizations for the supported pathways.
2. Partner self-provisioning deliberately creates pending verification/compliance/onboarding state; account creation does not itself approve commercial partner operations.
3. The canonical HTML login path, as recorded in the 16–17 November audits, reads active organization memberships, resolves organization types, validates requested workspace against membership, rejects platform-admin access through ordinary sign-in, and requires verified TOTP/AAL2 before protected workspace routing.
4. MFA enrollment and challenge source explicitly check Supabase's resulting `currentLevel === 'aal2'` before declaring successful verification or redirecting.
5. Canonical driver invitations have meaningful controls: exact organization `partner.manage`, currently eligible registered/verified/compliant transport carrier, verified active transport capability, per-inviter rate limit, 32-byte random token stored as SHA-256 hash, seven-day expiry, confirmed matching email, one-time acceptance, eligibility recheck, and audit event. Driver verification remains pending after membership acceptance.
6. A dated 17 November catalog audit reported RLS and self-scoped reads on core organization/membership/role tables, with no authenticated direct INSERT/UPDATE/DELETE grants on the reviewed core membership and role tables. This is historical evidence only; it does not prove current deployed grants/policies.
7. A dated account-security closure gate explicitly remained NOT CLOSED — VERIFIED pending isolated Staging tests and Supabase Auth configuration review.

## P0 — Release-blocking evidence gaps

### ID-01 — Current deployed authorization state is not revalidated
The available database/RLS/grant evidence is dated 16–17 November. This audit did not query current Production or Staging catalogs, migration history, effective grants, policies, function ACLs, or deployed function bodies. Given the recorded migration-history mismatch and prior security findings, source migrations cannot prove that deployed authorization matches the reviewed source.

**Required:** reconcile deployed migration history before backend changes; perform an authorized read-only current catalog audit of identity tables, grants, RLS policies, views, triggers, SECURITY DEFINER functions, EXECUTE ACLs and Auth configuration; compare to immutable source. No live query was executed in this gate.

### ID-02 — No isolated Staging identity lifecycle or tenant-negative test evidence
No end-to-end test has been performed in this gate for registration, confirmation callback, interrupted provisioning, invitation, membership, role resolution, MFA, workspace routing, revocation, stale sessions, or cross-tenant access. No synthetic identities are authorized until Phase 03 proves Staging isolation.

**Required:** after the environment safety gate, test every supported persona and organization type, wrong-role/wrong-tenant cases, AAL1 denial, suspended/revoked membership, token replay, concurrent invitation acceptance/revocation, and stale-session access against backend RLS/RPC—not merely browser redirects.

## P1 — Source and lifecycle defects / material risks

### ID-03 — Parallel React AuthContext trusts user-editable metadata for role, tenant and MFA policy
In `src/lib/auth/auth-context.tsx`, `syncAuthState` derives `role` from `currentSession.user.user_metadata.role`, `tenantId` from `user_metadata.tenant_id`, and determines whether MFA is required using that metadata-derived role. Supabase user metadata is user-editable. This must not be an authorization source. The canonical HTML login path is more robust, but this React context is a separate parallel auth path and any consumer treating these values as authority can misroute or misrepresent access.

**Required:** derive organization and role from trusted server/database membership and role-permission resolution; use app metadata only where carefully server-controlled and still revalidate sensitive actions. Treat client context as display state only. Search every consumer and prove all data/mutations are protected server-side.

### ID-04 — Generic organization/team invitation lifecycle is not implemented as a proven end-to-end workflow
The dated lifecycle audit found no verified generic create/accept/revoke API for `krim_organization_invitations`; the table had zero rows in that historical snapshot. The canonical driver invitation flow is not a substitute for customer, enterprise, warehouse, customs, finance or operations team invitations.

**Required:** define a least-privilege role allowlist, inviter permission, organization binding, random one-time token hashing, normalized email binding, expiry/revocation, atomic membership and role provisioning, audit trail, notification delivery and recovery. Never permit invitees to choose platform or privileged finance roles.

### ID-05 — Membership change/revocation audit is incomplete
The dated audit found an AFTER INSERT membership audit trigger but no equivalent UPDATE/DELETE trigger for role changes, suspension, deactivation or removal. The trigger's entity identifier was the organization rather than the membership row; service-driven events could have null actor attribution.

**Required:** controlled state-transition RPCs and immutable audit events containing membership ID, organization, subject, prior/new role and status, actor/system identity, reason, session/request correlation and timestamp.

### ID-06 — Role authority is split across three models
The dated snapshot contained organization membership's free-text role, numeric `krim_user_role_assignments` + role-permission mappings, and legacy `user_roles`. Historical audit evidence did not establish a canonical precedence/compatibility contract. Numeric role assignment organization scope is nullable; global-vs-tenant semantics and duplicate prevention require explicit invariants.

**Required:** nominate one authoritative organization-scoped RBAC model; explicitly separate platform-global roles; migrate/retire legacy paths only after dependency inventory; prove conflicting or nullable-scope records cannot elevate privileges.

### ID-07 — Organization onboarding and status lifecycle is incomplete
The dated snapshot reported zero generic organization invitations and onboarding records. Customer/partner provisioning exists, but the complete lifecycle for enterprise, warehouse, customs, finance and operations organization creation, approval, relationship binding, suspension and closure was not proven. Partner organizations may have generic `status='active'` while partner-specific verification/compliance remains pending; every operational path must check current eligibility rather than generic active status.

### ID-08 — Session revocation, account suspension and deletion are not certified
The account-control pages/source describe limitations: generic session enumeration/revocation is incomplete; deactivation/deletion require a server-side workflow; device registry and trusted-device enforcement were not verified in the historical audit. A successful global sign-out attempt does not prove every stale access token is rejected by every sensitive operation.

**Required:** test refresh-token revocation, access-token expiry, session-id checks for sensitive actions, suspended/deleted user denial, active-session invalidation and recovery. Keep unavailable controls explicitly unavailable.

### ID-09 — MFA enrollment concurrency and recovery lifecycle remain unverified
The enrollment page cleans up existing unverified TOTP factors before starting a new enrollment. The dated closure gate flags multi-tab/device concurrency, recovery, logout failure behavior and provider configuration as untested. A frontend MFA screen is not proof that every privileged RPC independently enforces AAL2.

**Required:** test concurrent enrollment, abandoned factor cleanup, invalid/expired/replayed codes, AAL1 denial at backend RPCs, recovery flows, global sign-out and provider assurance configuration.

### ID-10 — Driver invitation legacy surfaces and profile metadata need reconciliation
The canonical private SHA-256 driver invitation flow is materially stronger than older public-table/MD5 invitation code. Historical migrations revoke/retire older overloads, but every caller, overload and deployed EXECUTE ACL must be reconciled. The driver acceptance path reads profile fields from user metadata; those fields may populate a pending profile only and must never establish identity verification or operational authority.

## Required Staging acceptance matrix (not executed)

- Customer/partner/driver sign-up, email confirmation, callback interruption and idempotent recovery.
- Partner individual/development/registered pathways; pending status never equals approved supply.
- Wrong email, wrong organization, expired/revoked/replayed invitation; concurrent accept vs revoke.
- Generic team invitations for every supported org type with prohibited role escalation denied.
- User-editable metadata changes cannot create roles, tenants, membership, MFA exemptions or privileged routes.
- Role × organization × table × operation matrix; tenant A cannot read/write tenant B.
- Inactive/suspended/revoked membership and stale AAL1/session denied at backend.
- AAL2 required for all designated privileged actions; no frontend-only enforcement.
- Role change, suspension, revocation, organization closure and service jobs produce complete attributable audit records.
- Conflicting legacy/numeric/free-text role assignments cannot elevate access.
- Account recovery, password change, email change, session revocation and deletion retention workflow.
- Rate limits, abuse protection, redirect allowlist, email deliverability, password/leaked-password policy and session lifetime.

## Evidence classification

- **Immutable source findings:** React AuthContext metadata trust; registration calls; provisioning function structure; driver invitation migrations; MFA page behavior.
- **Historical database/audit evidence:** 16–17 November counts, grants, policies, trigger findings and closure-gate status. Not current live-state proof.
- **Runtime status:** NOT TESTED in isolated Staging. No real/synthetic login, registration, invitation, MFA challenge, membership change, RPC, SQL, notification or provider call was performed in this gate.

## Decision

**FAIL / BLOCKED.** Do not certify unrestricted account/team onboarding, nine-workspace authorization, tenant isolation, or revocation readiness. Limited customer/partner self-provisioning and driver invitations have meaningful source controls, but current deployed parity and end-to-end negative tests remain absent.

## Safety boundary

Read-only immutable-source inspection and review of existing historical audit artifacts only. No Production or Staging SQL/RPC/Auth operations, no user or organization creation, no invitations, no membership/role changes, no MFA enrollment/reset, no session revocation, no email/notification/provider calls, no secrets access, and no deployment or merge.
