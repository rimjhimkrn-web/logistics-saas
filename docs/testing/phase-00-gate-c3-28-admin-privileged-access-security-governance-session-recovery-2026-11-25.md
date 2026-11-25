# Phase 00 Gate C3.28 — Platform Admin, privileged access, security governance and recovery audit

**Date:** 2026-11-25  
**Immutable source baseline:** `72d75a18f985ceb09e468839435ee95700e11e46`  
**Method:** Read-only source review and reconciliation with prior Production audit evidence dated 2026-11-16 and 2026-11-24. Historical live catalog counts are not refreshed here. No Admin Edge Function was invoked; no role, account, session, MFA factor, audit record, RLS policy, grant, Auth setting, incident, integration or deployment was changed.

## Executive decision

**FAIL / BLOCKED — NO-GO for platform security certification, routine privileged administration, reliable audit completeness, active-session management, account lifecycle certification, SIEM/KMS certification or emergency administrative recovery.**

KRIM has a meaningful privileged control plane: the primary `global-admin-control` Edge Function authenticates the bearer token, checks AAL2, reads active platform roles from the server-side RBAC tables, requires platform admin/superadmin and performs destructive operations only for platform superadmin. Platform role assignment/revocation and user disable/enable/global session revocation are server-side operations. The control plane uses a service-role client only after identity, MFA and platform-role checks. The primary platform-admin dashboard also documents that browser-side visibility is not authorization and that backend checks are authoritative.

But the audit path is not fail-closed, privileged mutation and audit are not atomic, read helpers can turn errors into empty datasets, one parallel React auth path derives roles/tenant from editable metadata, session management is not connected to real Auth sessions, and account deactivation/deletion remain request-only. There is also a privileged sign-in route configured against Staging while the canonical platform-admin dashboard is configured against Production, with the sign-in page redirecting to a separate owner-testing route. This is a serious environment/entry-point consistency issue requiring explicit route mapping before real administrator use.

**P0 — client-editable role/tenant metadata remains in a parallel React authentication path.**  
**P1 — audit writes are best-effort and can fail silently after privileged state changes.**  
Other P1 issues include stale/incomplete session inventory, membership/role revocation not coordinated with session invalidation, MFA lifecycle defects, account action requests that do not execute the requested lifecycle, and incomplete monitoring/incident recovery. No live privileged action was performed during this gate.

## Scope and evidence reviewed

### Source files
- `app/platform-admin/index.html`
- `auth/krim-admin-access.html`
- `auth/krim-admin-guard.js`
- `auth/active-sessions.html`
- `public/admin/admin-runtime.js`
- `supabase/functions/global-admin-control/index.ts`
- `supabase/migrations/20261123101000_refine_admin_driver_licence_expiry_rpc_security.sql`

### Prior audit evidence
- `docs/audits/KRIM-OPERATIONS-CONTROL-TOWER-ENTERPRISE-ACCESS-AND-PLATFORM-GOVERNANCE-AUDIT-2026-11-16.md`
- `docs/audits/KRIM-AUTHENTICATION-LIFECYCLE-INVITATION-MFA-SESSION-REVOCATION-AND-ACCOUNT-CONTROL-DEEP-AUDIT-2026-11-16.md`
- `docs/audits/KRIM-PAGE-83-ADMIN-DASHBOARD-REVIEW-2026-11-16.md`
- `docs/audits/KRIM-PAGE-84-USER-AND-ROLE-MANAGEMENT-REVIEW-2026-11-16.md`
- `docs/audits/KRIM-PAGE-88-PLATFORM-CONFIGURATION-AND-HEALTH-REVIEW-2026-11-16.md`
- `docs/audits/KRIM-PAGE-89-SECURITY-AND-AUDIT-LOGS-REVIEW-2026-11-16.md`
- `docs/audits/KRIM-PAGE-100-ACCESS-AND-SESSION-MANAGEMENT-REVIEW-2026-11-16.md`
- `docs/audits/KRIM-PAGE-101-SYSTEM-HEALTH-AND-INTEGRATION-MONITORING-REVIEW-2026-11-16.md`
- `docs/audits/KRIM-PRODUCTION-SECURITY-RLS-GRANT-TRIAGE-2026-11-24.md`
- `docs/audits/KRIM-PRODUCTION-SECURITY-DEFINER-INITIAL-TRIAGE-2026-11-24.md`
- `docs/audits/KRIM-SECURITY-DEFINER-DELEGATED-GUARD-REVIEW-2026-11-24.md`
- `docs/audits/2026-11-17-account-security-and-mfa-second-functional-pass.md`
- `docs/audits/2026-11-17-authentication-and-account-security-closure-gate.md`

## Positive controls confirmed

1. **Primary Edge Function identity and assurance gate:** `global-admin-control` requires a bearer token, calls Auth `getUser()`, checks current AAL2 and rejects non-platform roles. It reads active `krim_user_role_assignments` joined to `krim_security_roles`; the browser cannot grant itself a platform role.
2. **Server-side role separation:** platform admin can use read/control-plane views; high-impact role assignment/revocation, user disable/enable and global session revocation require `platform_superadmin`.
3. **Self-disable guard:** the Edge Function blocks a superadmin from disabling their own account.
4. **Service-role boundary:** the Edge Function creates the service-role client after bearer authentication, user validation, AAL2 and active platform role checks. This remains a high-trust code path requiring narrow review.
5. **Canonical dashboard invokes the privileged function:** `app/platform-admin/index.html` calls `global-admin-control` for overview and all data/actions; the page explicitly says browser gating is not the security boundary.
6. **Privileged driver expiry function:** the 2026-11-23 migration keeps implementation in private schema, requires auth.uid(), AAL2 and `admin.platform`, locks the target profile, requires a reason, returns changed profile to pending review, writes before/after audit data and exposes a SECURITY INVOKER wrapper.
7. **RLS baseline is not blindly permissive:** prior 2026-11-24 production triage found zero public tables without RLS. The 24 public RLS-enabled tables with no policies had no anon/authenticated data privileges in that catalog query and therefore failed closed for ordinary roles. No blanket policy creation is justified.
8. **SECURITY DEFINER review is underway:** prior triage counted 333 public SECURITY DEFINER functions, 151 callable by authenticated, none callable by anon, and zero missing search_path configuration. The review explicitly states that aggregate counts do not certify all delegated guards/callees.
9. **Admin UI honesty:** `public/admin/admin-runtime.js` explicitly labels itself a UI helper and does not claim SIEM, cryptographic audit sealing, KMS key rotation or certification.
10. **Separate access/session page does not pretend to revoke sessions:** the page routes into account-action code; prior review confirms the actual session registry is empty and does not enumerate Auth sessions.

## Critical and high-priority findings

### ADM-01 — P0: client-editable metadata still influences role/tenant decisions in a parallel React auth path

The prior authentication lifecycle audit found `src/lib/auth/auth-context.tsx` derives role/tenant context from `user_metadata` / client-editable metadata in a parallel React authentication path. Supabase user metadata can be edited by the account holder and must never be trusted for authorization. This is separate from the primary `global-admin-control` Edge Function, which correctly reads server-side role assignments.

**Impact:** any protected route, component, API call or data query relying on this metadata-derived role/tenant state may display or route an account as a role/tenant it has not been granted. Frontend display alone is not a privilege escalation, but any backend policy or function that trusts the same editable claim is a security vulnerability.

**Required:** remove metadata-derived authorization from all clients; use metadata only for non-security profile preferences. Enforce current active membership, tenant scope, permission and AAL in every backend operation. Use app_metadata only where trusted claims are deliberately maintained, while still considering JWT staleness; prefer current server-side checks for sensitive operations. Trace every consumer of the legacy React auth context and test tampered metadata in isolated Staging.

### ADM-02 — P1: privileged audit writes are best-effort, not fail-closed

In `global-admin-control/index.ts`, `audit()` awaits an insert into `krim_audit_events` but does not inspect or propagate the returned error. Several privileged operations mutate state first and call audit afterwards:
- assign/revoke platform or workspace role;
- disable/enable Auth user;
- revoke all Auth sessions;
- inquiry status and follow-up operations.

If the audit insert fails, the handler can still return `ok:true` and the UI says the operation was audited. The mutation and audit event are not one transaction. Read-only action-access audit is also best-effort.

**Required:** move database role mutations and their audit into one transaction/RPC. For Auth Admin API operations that cannot share a Postgres transaction, use a durable intent/outbox with explicit pending/completed/failed state, provider result, reconciliation and alerting. Do not return an “audited success” until the durable audit/outbox state is confirmed. Include actor, target, before/after state, reason, request ID, idempotency key and result; exclude credentials and unnecessary PII.

### ADM-03 — P1: admin read helper hides data-source failures as empty arrays

The Edge Function helper `rows()` logs a table query error and returns `[]`. Admin pages can therefore display an empty table for missing table, RLS/grant denial, schema drift, timeout or service failure. The overview count loop distinguishes error by setting `null`, but other list panels silently conflate unavailable with no records.

**Required:** return a typed unavailable/error state with request ID and source name; preserve empty as a valid empty result only when the query succeeds. Add monitoring for permission/schema/timeouts and prevent exports or administrative decisions from incomplete datasets.

### ADM-04 — P1: session management does not enumerate or revoke actual Auth sessions

Prior 2026-11-16 Production snapshot found 16 rows in `auth.sessions` (11 AAL1, 5 AAL2) but zero rows in `krim_auth_sessions`. `auth/active-sessions.html` routes through `krim-account-actions.js`; the prior page audit states the UI does not enumerate real sessions. The Admin Edge Function's `revoke_sessions` calls Auth Admin global sign-out, but this does not provide a selected-device/session inventory or proof that all already-issued access tokens are immediately rejected by every sensitive endpoint.

**Required:** provide a supported session inventory with session IDs, device/browser context minimized, creation/last-seen/assurance and revocation status; use Auth-supported revocation for selected/all sessions. For strict sensitive-operation revocation, validate session_id against current Auth session state where feasible. Test refresh-token invalidation, outstanding access token, offline client, stale JWT, selected-session revoke, global revoke and provider error in Staging.

### ADM-05 — P1: role/membership revocation is not coordinated with session revocation or fully audited

Prior membership audit found an AFTER INSERT trigger for `krim_organization_members`, but no corresponding UPDATE/DELETE audit trigger; no equivalent membership lifecycle audit was found for `krim_user_role_assignments`. Backend permission helpers re-check active membership/role, which is a positive control, but there is no demonstrated policy coordinating role removal, organization suspension and Auth session revocation. Stale JWT claims and parallel metadata paths add risk.

**Required:** implement atomic, complete role/membership transition audit and define session response by severity: remove membership, invalidate sensitive sessions, require token refresh or revoke all sessions where needed. Record actor, target, org, prior/new role/status, reason and request context. Verify access is denied immediately on backend even with an old JWT.

### ADM-06 — P1: MFA enrollment lifecycle has destructive/unsafe edge cases

The prior authentication audit found the MFA enrollment page deletes pending factors when the page is opened. This can disrupt interrupted enrollment or multiple-tab workflows. MFA enrollment, factor replacement/removal, lost authenticator recovery, backup/recovery codes and global sign-out error behavior were not fully certified.

**Required:** do not delete pending factors on page load. Implement explicit user-confirmed cancellation with factor identity and audit. Test zero/one/multiple verified factors, pending factor, two tabs, interrupted challenge, factor replacement, lost authenticator, recovery path and AAL2 enforcement for every privileged RPC and Edge Function.

### ADM-07 — P1: account deactivation/deletion are request-only

`krim_account_action_requests` permits a user to submit/read their own pending request. `krim-account-actions.js` explicitly states that a request does not deactivate or delete the account. Prior snapshot had zero requests. There is no complete approval, identity verification, retention/legal-hold assessment, data export, scheduled execution, revocation and completion workflow.

**Required:** define distinct deactivation vs deletion semantics, cooling-off/withdrawal, legal retention and data rights, identity proof, approval and execution. Ensure account/session revocation happens before destructive removal, preserve legally required financial/audit records, and report request vs completed state accurately.

### ADM-08 — P1: privileged sign-in and canonical admin control plane have environment/route mismatch

`auth/krim-admin-access.html` hard-codes the Staging Supabase project and invokes `owner-testing-authorize`, then redirects to `owner-testing.html`. `app/platform-admin/index.html` and `auth/krim-admin-guard.js` use the Production Supabase project and the canonical dashboard invokes `global-admin-control`. These are separate Auth projects and do not share sessions. The exact intended route/deployment mapping and whether the owner-testing entry is a separate testing-only boundary are not established by static inspection.

**Required:** document one explicit route/environment matrix. Keep owner-testing routes and Staging project isolated and clearly labelled; Production admin sign-in must authenticate against Production and invoke the intended Production guard. Prevent cross-environment session assumptions and never silently redirect a production administrator into a testing route. Validate the actual deployed redirect chain in a controlled browser test before use.

### ADM-09 — P1: privileged role mutation needs stronger invariants and lifecycle evidence

The Edge Function requires superadmin for assignment/revocation, but direct code path performs role assignment/revocation through service-role table mutations. The reviewed logic does not require a reason, explicit second-person approval, idempotency key or a durable audit commit. The revoke path does not verify a row was actually changed before reporting `revoked:true`; assign path does not prove the target account is active/confirmed or that the requested role/org combination is valid for the target. No last-superadmin/owner continuity guard is evident in these action branches.

**Required:** validate target Auth user, role allowlist, role scope, active organization, uniqueness and platform-vs-tenant semantics; require reason and request idempotency; add independent approval for superadmin assignment/revocation and high-impact access disable; enforce last-owner/superadmin continuity and self-escalation constraints. Verify affected-row counts and durable audit before success.

### ADM-10 — P1/P2: security desk, audit and monitoring surfaces are not SIEM or resilience certification

The legacy AdminRuntime explicitly disclaims SIEM, cryptographic audit sealing, KMS rotation and ISO/SOC certification. Prior Page 101 audit found integration directory did not query connector health, API/EDI delivery, webhook latency or automation execution. Prior Admin governance audit found audit visibility gaps and best-effort audit writes. Prior 2026-11-24 security triage still had 151 authenticated-callable SECURITY DEFINER functions to review and a leaked-password-protection warning; 24 public RLS-enabled/no-policy tables had zero anon/authenticated table grants in that snapshot, so do not blanket-grant them. No current complete independent SIEM ingestion, immutable retention, alert routing, key rotation drill or break-glass recovery proof exists in this gate.

**Required:** complete object-by-object RLS/grant review and recursive SECURITY DEFINER delegated-guard/ACL review; enable/test leaked-password protection with controlled rollout; define append-only audit retention and external independent monitoring; verify key lifecycle/rotation and break-glass access with two-person approval and post-event review. Never claim ISO 27001, SOC 2, SIEM, cryptographic audit seal or KMS rotation from UI labels.

## Historical Production snapshot (not refreshed in this gate)

Prior 2026-11-16 authentication audit recorded 16 Auth sessions (11 AAL1, 5 AAL2), zero `krim_auth_sessions`, zero `krim_user_devices`, four verified MFA factors, zero generic organization invitations and zero account action requests. Prior 2026-11-24 security triage counted 333 public SECURITY DEFINER functions, 151 callable by authenticated, zero callable by anon, and 24 public RLS-enabled tables with no policies but zero anon/authenticated table grants. These are prior audit snapshots, not current measurements or proof of present production state.

## Readiness matrix

| Admin capability | Result | Boundary |
|---|---|---|
| Primary global-admin-control authentication | PARTIAL PASS | Source AAL2 + active server-side role checks; no runtime test |
| Platform vs superadmin separation | PARTIAL PASS | High-impact actions superadmin-only in source |
| Client metadata authorization isolation | FAIL / P0 | Parallel React auth path trusts editable metadata |
| Privileged audit completeness | FAIL / P1 | Best-effort audit after mutation |
| Admin list/read error handling | FAIL / P1 | Query errors become empty arrays |
| Real session inventory | FAIL / P1 | Registry empty in historical snapshot; UI not connected to Auth sessions |
| Global session revoke | PARTIAL PASS / BLOCKED | Auth Admin call exists; no runtime/token-replay proof |
| Membership/role revocation lifecycle | FAIL / P1 | Audit and session coordination incomplete |
| MFA lifecycle | FAIL / P1 | Pending-factor page-load deletion; recovery tests incomplete |
| Account deactivation/deletion | FAIL / P1 | Request-only, not executable lifecycle |
| Admin environment/entry route consistency | FAIL / P1 | Staging sign-in route vs Production dashboard mismatch |
| Role assignment/revocation invariants | FAIL / P1 | No reason/idempotency/second-person/last-admin guard proven |
| SIEM/KMS/cryptographic audit certification | NOT READY | UI explicitly disclaims capabilities |
| Security monitoring/integration health | NOT READY | No verified live connector telemetry |
| SECURITY DEFINER/RLS/grant closure | BLOCKED | 151 authenticated functions remain in review; no blanket policy fix |
| Break-glass/recovery drill | NOT TESTED / BLOCKED | No controlled evidence in this gate |

## Required remediation and controlled test order

1. Remove editable user metadata as an authorization source across all React and legacy clients; trace every consumer and enforce backend current-state authorization.
2. Repair the admin sign-in/environment route contract: distinguish Staging owner-testing from Production platform admin; verify actual deployed redirect and project identity.
3. Make audit writes fail-closed: transactionally couple database changes and audit, and use a durable outbox/state machine for Auth Admin API changes.
4. Change every admin data helper to distinguish successful empty results from unavailable/error; prohibit decision/export on incomplete reads.
5. Implement true session inventory/revocation and test stale access-token behavior, refresh-token invalidation and sensitive-operation session_id checks.
6. Complete role/membership UPDATE/revoke audit and session coordination; enforce role/org invariants, reason, idempotency, second-person approval and last-admin continuity.
7. Repair MFA enrollment lifecycle and test factor recovery and every privileged endpoint at AAL1/AAL2.
8. Implement the account deactivation/deletion lifecycle with privacy/legal retention review and verified execution.
9. Continue recursive review of all authenticated-callable SECURITY DEFINER functions, callees and grants; assess all no-policy tables individually; configure leaked-password protection through controlled rollout.
10. Establish external audit retention/alerting, incident ownership, key rotation and break-glass test. No certification claims until independently evidenced.
11. In isolated Staging only, test unauthorized, AAL1, inactive role, wrong org, role escalation, last-admin revoke, audit sink failure, Auth Admin failure, missing tables, RLS denial, stale token, selected/global session revoke, MFA interruption, user deletion retention and environment mismatch. Do not use real user identities or send uncontrolled alerts.

## Safety and release boundary

This gate was read-only. No Production or Staging function invocation, SQL/RPC, Auth Admin action, role assignment/revocation, user ban/unban, session revocation, MFA factor operation, audit write, RLS/grant change, security setting change, notification or deployment was executed. Prior live counts are explicitly historical and were not refreshed.

**Gate C3.28: FAIL / BLOCKED — NO-GO for platform security certification, routine privileged administration, reliable audit completeness, active-session management, account lifecycle certification, SIEM/KMS certification or emergency administrative recovery.**
