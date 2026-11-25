# C3.50 — Global identity lifecycle, authentication recovery, MFA, session security and account-takeover resilience
**Date:** 25 November 2026  
**Immutable source baseline:** `72d75a18f985ceb09e468839435ee95700e11e46`  
**Method:** Read-only inspection of canonical and legacy authentication pages, React auth context, MFA enrollment/challenge, password recovery/reset, session/logout, localStorage route guards, and dated 16–17 November Auth audits/closure evidence. Historical Auth aggregate counts are identified as dated snapshots. No login, signup, reset email, MFA challenge/enrollment, invitation, session revocation, user mutation, provider call or live database operation was performed.

## Executive verdict
**FAIL / BLOCKED — NO-GO for authentication lifecycle certification or unrestricted real-user/partner onboarding.**

Positive controls exist in the canonical HTML sign-in and privileged RPC paths: Supabase password authentication, active-membership workspace resolution, verified TOTP enrollment/challenge, AAL2 checks for selected privileged operations, neutral reset-request messaging, recovery-session validation, and a stronger one-time driver invitation workflow. These controls are not consistently applied across all application generations, sessions, user roles and backend operations.

## 1. Positive controls — PARTIAL PASS
- Canonical `auth/login.html` authenticates with Supabase, queries active organization memberships and organization types, rejects requested workspaces unsupported by membership, excludes platform-admin access from ordinary sign-in, requires verified TOTP and checks AAL2 where Supabase reports it as the next level.
- Driver invitation path uses 32 random bytes, stores SHA-256 token hashes, expires after seven days, binds exact confirmed email, checks current carrier eligibility, locks invitation acceptance, creates membership and audit event, and supports authorized revoke/list.
- Password recovery uses `resetPasswordForEmail`, neutral account-existence messaging, PKCE/recovery code exchange, recovery-session validation, MFA checks where required, 12-character minimum and a global sign-out attempt after password update.
- Selected admin/partner verification RPCs independently require authenticated identity, AAL2 and platform permission; partner verification direct DML was revoked in a reviewed migration.
- The account-security UI honestly labels passkeys, backup codes, trusted devices and full account deactivation/deletion as not implemented.

These are source observations and dated evidence, not live proof that every deployed route/function/configuration matches the baseline.

## 2. P0 — Legacy localStorage session/role guard is not an authentication boundary
`js/session.js` stores a custom session object in localStorage and treats it as valid when a token field exists and a browser-controlled 24-hour activity timer has not elapsed. `js/guards.js` reads this local object and its locally stored role to gate legacy route prefixes; it does not validate the token with Supabase Auth or verify membership/permission with the server. A user can edit browser storage and forge the role/session object.

**Impact:** legacy route guards can be bypassed and must never protect sensitive data or actions. Client-side routing is not authorization.

**Required:** inventory all imports/references to `KrimSession` and `js/guards.js`; remove/deprecate them or make them non-security navigation hints. Every protected page must validate Supabase identity for UX, while every data read/write and sensitive action must independently enforce RLS/RPC/Edge Function membership, tenant, permission and AAL.

## 3. P0 — React AuthContext trusts editable user_metadata for role and tenant
`src/lib/auth/auth-context.tsx` derives role from `currentSession.user.user_metadata.role` and tenant ID from `user_metadata.tenant_id`; its frontend MFA requirement also uses this metadata-derived role. Supabase user metadata is user-editable and is not a trusted authorization or tenant source. A dated 16 November Auth snapshot found four users with role/tenant/account-type fields in user_metadata and zero with these fields in app_metadata. This count is historical, not current.

**Required:** remove user_metadata-derived role/tenant authority; resolve organization membership and roles through canonical server-backed RBAC. Fail closed when lookup fails. Treat client MFA flags as UX only and enforce AAL on privileged backend operations. Audit all React AuthContext consumers and legacy routing paths before declaring retirement.

## 4. P1 — Session inventory and remote revocation are incomplete
The dated 16 November audit found 16 Auth session rows, 11 AAL1 and five AAL2, four verified MFA factors, zero rows in `krim_auth_sessions` and zero device registry rows. These are point-in-time counts; factor count does not mean every user or session has MFA.

The same audit found:
- `auth/active-sessions.html` cannot reliably enumerate remote sessions and its action uses `signOut({scope:'local'})`, which signs out only the current browser.
- No registry population/synchronization path was found.
- React `signOutAllDevices` ignored the returned error before redirecting.
- A previous logout implementation did not reliably distinguish global revocation failure from local cleanup. The baseline logout page now has an explicit global-revocation error branch and a local-only fallback, which is a useful source improvement; it still requires browser/network verification.

**Required:** build server-authoritative session inventory tied to Supabase session IDs, or label the feature strictly as current-device sign-out. For global revocation, check errors and show confirmed outcome. For selected revocation, require a trusted server-side operation. Test unexpired access tokens, refresh-token revocation, stale tabs, network loss and membership removal. Deleting a user or clearing browser storage alone does not prove immediate access-token invalidation.

## 5. P1 — MFA enrollment page performs cleanup on page load
`auth/mfa-enroll.html` lists factors on initialization. If no verified TOTP factor exists, it iterates every unverified TOTP factor and calls `mfa.unenroll` before starting a new enrollment. This is an automatic destructive side effect triggered merely by opening the page. It can remove an abandoned enrollment that a user intended to resume and may race with another tab/device. The 17 November closure audit explicitly called for multi-tab enrollment testing.

The page does verify a new TOTP challenge and checks that resulting session AAL is `aal2` before declaring enrollment complete. The standalone challenge page likewise checks AAL2 before redirecting. These are useful controls, but no enrollment/challenge/replay/clock-drift/concurrency test was executed.

**Required:** do not delete pending factors silently on page load. Present the pending factor and explicit restart/cancel action, confirm before removal, handle concurrent tabs safely, and verify factor status/AAL after each transition.

## 6. P1 — Recovery and account takeover protections remain incomplete
- Password reset requires a recovery session and checks MFA when Supabase reports AAL2 as next level. However, recovery-link replay/expiry, MFA-required and non-MFA accounts, password update and remote session revocation have not been exercised.
- Password policy, compromised-password protection, Auth provider rate limits, email/phone change notifications, recovery notification templates and delivery are not verified from current deployed settings.
- Backup-code workflow is explicitly disabled; no KRIM recovery-code generation/verification workflow was evidenced. Passkeys and trusted-device controls are also explicitly not implemented.
- Public customer/partner/driver signup source has no CAPTCHA/Turnstile integration. A dated abuse audit found no server-side KRIM signup quota or registration abuse telemetry.
- Dated public abuse review found login/recovery error handling inconsistent, including partner login exposing raw provider error messages. Normalize user-facing errors and log redacted security telemetry only.
- No demonstrated breached-password check, credential-stuffing detection, anomaly/risk signal, lockout policy, notification-on-credential-change, or security incident response journey was completed in this gate. Supabase-side controls are unverified, not proven absent.

## 7. P1 — Invitations, membership changes and account lifecycle
The verified driver invitation workflow is materially stronger than the generic organization invitation path. The dated audit found the generic organization invitation page accepts a token but explicitly says the acceptance endpoint is not configured; no complete create/accept/revoke RPC lifecycle was found. Membership audit coverage was found for insert but not a complete update/delete/revocation lifecycle. Membership revocation was not coordinated with session revocation. Driver self-provisioning uses editable user_metadata as an eligibility signal; this must not grant carrier membership, verified status or operational trip access.

Account deactivation/deletion pages remain request-only, not a verified identity/session revocation workflow. See C3.49 for privacy rights and deletion lifecycle findings.

## 8. P0/P1 remediation and acceptance criteria
### P0 before unrestricted onboarding
1. Retire legacy localStorage session/role guards as security controls; confirm every protected backend operation independently enforces identity, tenant, membership, permission and AAL.
2. Remove editable user_metadata as role/tenant authority from React AuthContext and all other protected routes.
3. Audit all route and RPC/Edge Function entry points for bypasses; no client-only gate may be the only protection.

### P1 before authentication readiness claims
1. Implement and verify server-authoritative session inventory/revocation or clearly label current-device-only sign-out.
2. Replace destructive MFA page-load cleanup with explicit user-confirmed recovery/restart; test concurrent tabs and already-enrolled factors.
3. Complete password recovery, MFA, email/phone change and global sign-out journeys, including provider delivery and failure modes.
4. Configure and verify Auth rate limits, CAPTCHA/bot protection, password policy/breached-password protection where available, safe error normalization and security notifications.
5. Implement documented recovery alternatives (secure backup/recovery codes or support-assisted verified recovery) without insecure bypass.
6. Implement generic organization invitations and membership/role revocation audit + session coordination.
7. Keep driver self-provisioning separate from carrier membership, verification and dispatch authorization.

### Mandatory isolated-Staging tests — NOT EXECUTED
- Signed-out, expired, revoked and forged localStorage session/role; direct URL and API/RPC bypass attempts.
- Metadata tampering for role, tenant, account type and MFA requirement; cross-tenant access must remain denied.
- AAL1 denial/AAL2 success for every privileged RPC/Edge Function and all nine workspaces.
- TOTP enroll, abandoned factor, explicit factor removal, concurrent tabs, invalid/replayed/expired codes, clock drift, verified-factor challenge and AAL2 confirmation.
- Password reset valid/expired/replayed link, MFA-required/non-MFA user, password policy, credential notification, remote refresh-token revocation and old-session denial.
- Local/global logout success, network outage and error reporting; verify server-side revocation separately from browser cleanup.
- Credential stuffing/rate-limit/CAPTCHA, account enumeration, safe error messages and redacted telemetry.
- Organization invitation wrong email, expiry, revoke, replay, role escalation and idempotency; membership removal with unexpired JWT and open tab.
- Recovery and account-takeover incident simulation with support verification and audit trail.

## Final decision
**C3.50 FAIL / BLOCKED.** NO-GO for authentication lifecycle certification or unrestricted real-user/partner onboarding. Canonical sign-in, TOTP/AAL2 checks, password recovery and driver invitation are useful partial controls, but legacy localStorage authorization, editable metadata-derived React role/tenant state, incomplete session revocation, page-load MFA cleanup, absent recovery-code/trusted-device capability, incomplete invitation lifecycle and untested Auth abuse protections remain unresolved.

This was a read-only repository and dated-evidence audit. No user data, password, secret, Auth setting, session, MFA factor, invitation, membership, database record or provider state was read or changed; no login, reset, email, MFA, revocation or deployment was triggered. Historical counts are not current live-state assertions. Technical audit is not penetration testing or security certification.
