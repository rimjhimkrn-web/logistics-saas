# KRIM Authentication, Registration, MFA, Recovery and Session-Security Audit
**Date:** 16 November 2026  
**Project:** Supabase `ebltviniygljwwseplph`; repository `rimjhimkrn-web/logistics-saas`  
**Method:** Read-only Auth catalog counts, deployed project metadata, account/session/MFA counts, static source review of sign-in, registration, recovery, MFA, session, account-action and workspace-auth components. No login attempt, password reset, MFA challenge/enrollment, user impersonation, session revocation, account mutation or provider email was triggered.

## Executive decision
**NO-GO for authentication/security certification.** KRIM has a functioning Supabase Auth foundation and MFA implementation, but account security is split across several generations of frontend code. Important controls are present in the canonical sign-in path, while legacy localStorage guards and a separate React auth context still trust user-editable metadata for client-side role/tenant state. Session-management pages are partly informational and do not revoke all sessions. MFA enrollment and recovery require end-to-end testing and clearer recovery safeguards.

## 1. Live Auth baseline
| Measure | Observed |
|---|---:|
| Auth users | 9 |
| Email-confirmed users | 9 |
| Unconfirmed users | 0 |
| Currently banned users | 0 |
| Auth sessions | 16 |
| Sessions with non-null factor_id | 5 |
| MFA factors | 4 |
| Verified MFA factors | 4 |
| Pending MFA factors | 0 |
| Active organization memberships | 13 |
| KRIM auth session registry rows | 0 |
| KRIM device registry rows | 0 |
| Account action requests | 0 |
| Consent event rows | 0 |
| Users with role/tenant fields in app_metadata | 0 |
| Users with role/tenant/krim_account_type in user_metadata | 4 |

These are snapshot counts, not a complete assurance-level or account-security assessment. Five sessions with factor_id does not prove all active sessions are at AAL2; factor enrollment and session assurance are different concepts. The database snapshot contains no custom session/device registry rows.

## 2. Positive controls observed
- Canonical `auth/login.html` verifies password through Supabase Auth, then queries active `krim_organization_members` and organization type before choosing a workspace.
- Selected workspace is treated as a routing preference and must match an active membership; backend permissions remain authoritative.
- Customer/partner/driver self-provisioning uses specific RPCs and then re-queries active membership. Provisioning is not treated as approval of partner capability or driver licence.
- The canonical sign-in flow requires a verified TOTP factor for all workspace users and challenges AAL2 when Supabase reports `nextLevel='aal2'`.
- Registration page explicitly states that account creation does not create organization membership or grant workspace access.
- Password recovery uses a neutral success message to reduce account enumeration.
- Reset page validates password confirmation client-side and updates through Supabase Auth.
- Privileged admin sign-in separately verifies AAL2 and invokes `global-admin-control`; server-side platform role checks remain authoritative.
- MFA enrollment uses Supabase TOTP and verifies a challenge before treating the factor as enabled.
- Account-action pages are deliberately honest about features that are not implemented (passkeys, backup codes, device trust, full account deletion/deactivation, identity verification).

## 3. P0/P1 findings
### AUTH-01 — P0: Legacy localStorage route guard is not an authentication boundary
`js/session.js` stores a custom session object in localStorage and considers it valid when a token field exists and a client-side 24-hour activity timer has not expired. `js/guards.js` uses that local object and a locally stored role to gate old route prefixes. It does not validate the token with Supabase Auth or ask the server to verify membership/permission. This can be forged by the browser user and must never protect sensitive pages or actions.
**Action:** inventory all references to `KrimSession`/`js/guards.js`; remove/deprecate this legacy guard or make it a non-security navigation hint. Every sensitive page and every backend operation must use server-verified Supabase identity, membership, permission and AAL.

### AUTH-02 — P1: React AuthContext trusts user-editable user_metadata for role and tenant
`src/lib/auth/auth-context.tsx` sets role from `currentSession.user.user_metadata.role` and tenant from `user_metadata.tenant_id`. Supabase user metadata is user-editable and must not be used for authorization or tenant isolation. Current database snapshot has zero users with these fields in app_metadata and four with role/tenant/account-type fields in user_metadata.
**Action:** remove metadata-derived authorization state; resolve roles and tenant relationships from authoritative organization memberships and server-side RBAC. If JWT claims are needed, use trusted app_metadata/custom claims and account for token refresh staleness. Backend RLS/RPC checks remain mandatory.

### AUTH-03 — P1: Client-only MFA policy is inconsistent across auth implementations
Canonical `auth/login.html` enforces verified TOTP enrollment before workspace entry and prompts for MFA when `nextLevel='aal2'`. The React AuthContext derives its privileged-role MFA requirement from user_metadata and only updates client state; it does not itself block protected routes. Other helpers have different semantics. This creates inconsistent user experience and makes frontend enforcement easy to bypass if any route relies on it.
**Action:** define a server-side AAL policy by workspace and operation; enforce AAL2 in privileged RPCs/Edge Functions and critical RLS-adjacent workflows. Treat frontend MFA redirects as UX only. Test AAL1 denial and AAL2 success for all nine workspaces.

### AUTH-04 — P1: Session management UI cannot enumerate/revoke all real Auth sessions
The account-actions module explicitly says it cannot enumerate and revoke every other session; its “active sessions” page reads `krim_auth_sessions`, which has zero rows in the live snapshot. The action only signs out the current browser with `scope:'local'`. React AuthContext exposes a global sign-out method, but this is not integrated into the static account-security workflow. Session revocation and recovery are therefore not a unified, tested user capability.
**Action:** implement a server-verified session inventory/revocation flow or clearly label the feature as “sign out this device only”. For high-risk actions, validate current session identity/revocation server-side; test local, global and revoked-session behavior.

### AUTH-05 — P1: MFA enrollment page mutates account state during page initialization
`auth/mfa-enroll.html` automatically removes all unverified TOTP factors before starting a new enrollment. Opening/refreshing the page is therefore not read-only and may delete an in-progress enrollment the user intended to continue. It also displays the TOTP secret in a visible manual setup field. The secret is necessary for setup but requires explicit warning, no analytics/logging, no persistence, and controlled lifetime.
**Action:** do not delete pending factors automatically on page load. Offer an explicit restart action after showing which pending enrollment will be discarded; expire/reconcile abandoned factors server-side. Ensure setup secret is never logged, persisted, or sent to analytics and is cleared from the DOM after successful verification.

### AUTH-06 — P1: MFA recovery/backup-code flow is not implemented
The account-action page correctly states that backup codes need secure server-side generation and verification and does not fabricate client-side codes. The recovery page exists, but the complete lost-authenticator identity proof, recovery approval, factor reset, notification and audit trail were not certified.
**Action:** implement a controlled recovery process with strong re-authentication, independent review for privileged users, user notification, immutable audit evidence and recovery-factor re-enrollment. Do not bypass AAL2 through a self-asserted email-only flow.

### AUTH-07 — P1: Multiple overlapping auth entry points
The repo contains `app/sign-in.html`, `auth/login.html`, `auth/partner-signin.html`, `auth/driver-signin.html`, legacy `admin-login.html`, and several older auth routes. Canonical login checks memberships and workspace type; other entry points may not have identical behavior. This increases the chance of bypassed onboarding, inconsistent MFA, stale redirect handling and divergent account recovery.
**Action:** choose one canonical authentication gateway and shared tested flow. Other URLs should redirect to it while preserving only validated same-origin return paths.

### AUTH-08 — P1: Account lifecycle pages are partly placeholders
Passkeys, backup codes, trusted devices, account deletion/deactivation and identity verification are explicitly not implemented. Organization invitation acceptance is also disabled until a server-validated token endpoint exists. These should not be presented as operational account capabilities.
**Action:** label unavailable features as unavailable in navigation and product claims; implement each only with server-side authorization, re-authentication, audit and retention controls.

### AUTH-09 — P1: Session helper uses getSession() in some authorization-adjacent paths
Several helpers use `auth.getSession()` for initial route checks, while other flows use `getUser()`. A locally persisted session should not be treated as proof of current identity for high-risk server decisions.
**Action:** use `getUser()`/verified JWT on server or rely on database-side `auth.uid()` plus current membership/session checks. Use `getSession()` only to obtain the local session for client UX/token refresh.

### AUTH-10 — P2: Redirect and account enumeration regression tests needed
Some routes accept return URLs and role/workspace query parameters. Canonical login has an allowlisted same-origin booking redirect and membership-bound workspace selection, but all legacy entry points and recovery callbacks need the same open-redirect and role-confusion tests. Registration/recovery messages are neutral, which is positive.
**Action:** test external URL, protocol-relative URL, encoded traversal, nested return parameters, unknown workspace, platform-admin role metadata, duplicate account registration and unknown recovery email.

## 4. Workspace-specific assurance matrix
| Workspace | Authentication entry | Required authorization beyond login | Additional assurance |
|---|---|---|---|
| Customer/Shipper | Canonical login | Active customer membership, own tenant/record | AAL1 for ordinary read; AAL2 for defined sensitive actions |
| Partner/Carrier | Canonical login | Active partner membership, verification/compliance/capability | AAL2 for capability approvals and privileged partner actions |
| Driver | Canonical login / driver entry | Driver identity, active membership, own accepted assignment | AAL2 for sensitive evidence/identity changes as policy defines |
| Warehouse | Canonical login | Approved facility, warehouse capability, operator permission | AAL2 for QC/release/transfer approvals |
| Customs | Canonical login | Customs org membership and jurisdiction/licence | AAL2 for broker/document approvals |
| Finance | Canonical login | Finance permission, legal entity and tenant scope | AAL2 for every financial approval; live finance deferred |
| Operations | Canonical login | Operations membership and operations-specific permission | AAL2 for dispatch/critical exception approvals |
| Enterprise | Canonical login | Enterprise membership plus explicit customer/network relationship | AAL2 for sensitive exports/admin actions |
| Admin | Separate privileged login | Server-side platform-admin role and platform permission | AAL2 mandatory; independent audit |

This is a target control matrix, not proof every workspace has been tested.

## 5. Required staging acceptance tests
1. Valid confirmed account signs in and resolves only active memberships.
2. Unconfirmed, banned, disabled and revoked-membership accounts are denied appropriately.
3. User-editable metadata role/tenant forged to admin/another tenant does not grant access.
4. Wrong workspace query parameter is rejected unless a matching active membership/capability exists.
5. No membership cannot self-provision privileged workspace.
6. Partner/driver limited self-provisioning cannot approve capability/licence or access another tenant.
7. AAL1 is denied for every AAL2-protected RPC/Edge Function; AAL2 succeeds with authorized membership.
8. No verified factor follows safe enrollment; existing verified factor follows challenge; abandoned pending enrollment is preserved until explicit restart.
9. Invalid, expired, replayed and wrong-user recovery links are rejected.
10. Password reset changes password and revokes/invalidates sessions according to the approved policy.
11. Local sign-out, global sign-out, password change and membership revocation have tested effects across existing sessions.
12. Same-origin redirect allowlist rejects external and protocol-relative URLs across every auth entry point.
13. Admin recovery cannot be completed through email-only self-service without required independent controls.
14. Auth callback, MFA callback and refresh behavior are tested on GitHub Pages base path and direct page reload.
15. Browser storage disabled/cleared, stale tabs, concurrent refresh and network failure recover safely without trusting legacy localStorage state.

No staging test in this list was executed during this audit.

## 6. Safe remediation sequence
1. Complete source/migration reconciliation before any production DDL or function changes.
2. Deprecate legacy localStorage role/session guard and remove user_metadata-derived role/tenant state from React AuthContext.
3. Consolidate all sign-in paths to one canonical membership-bound gateway.
4. Make MFA policy authoritative in server-side operations and standardize AAL2 by action.
5. Correct MFA enrollment lifecycle and implement a secure recovery process.
6. Implement honest session revocation capability and account-action workflows.
7. Run isolated staging tests, then repeat security advisors and full route checks.

## Release decision
**NO-GO for authentication certification and unrestricted operations.** Supabase Auth currently has 9 confirmed users, 16 sessions and 4 verified TOTP factors, but counts alone do not establish secure session lifecycle. The most important code risks are the legacy localStorage guard and user_metadata-derived role/tenant state in the React auth context. No production auth setting, user, factor or session was modified.

## Change boundary
Only read-only Supabase Auth counts/project metadata and repository source were inspected. No credentials, password hashes, MFA secrets, factor IDs, emails, user IDs or session tokens were exported into this report. No sign-in, sign-out, MFA, recovery email, account action or session revocation was initiated.
