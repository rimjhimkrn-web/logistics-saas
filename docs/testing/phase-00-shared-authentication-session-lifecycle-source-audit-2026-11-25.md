# Phase 00 — Shared Authentication and Session Lifecycle Source Audit
Date: 2026-11-25
Repository: rimjhimkrn-web/logistics-saas
Ref: qa/phase-00-baseline-2026-11-25

## Executive verdict

SOURCE AUDIT COMPLETED; END-TO-END AUTHENTICATION IS NOT VERIFIED FOR REAL-USER ONBOARDING. The repository contains login, callback, recovery, password reset, TOTP enrollment/challenge and logout flows. Main login checks a server-resolved workspace route, active organization membership and TOTP/AAL2 before redirecting. Session expiry/refresh/revocation configuration, actual email delivery, redirect allowlist behavior, recovery-token replay, invitation acceptance and server-side authorization for every protected route remain unproven.

This is a static source audit of the QA branch, not a live Auth test. No login, email, OTP, password change, session revocation, account mutation, Supabase configuration change or provider call was performed.

## 1. Files inspected

| File | Source SHA | Review |
|---|---|---|
| auth-core.js | 2cd5fb070ebfbaf2e712eef25dba8fc185e7f20f | Shared session/AAL guard |
| auth/login.html | 4bec947c6caea41a9dca9ceee01f07a4010c5b33 | Main login, workspace routing and MFA |
| auth/forgot-password.html | 26f12c9c95651627ab02168cda6e73d894ab5a38 | Recovery request |
| auth/reset-password.html | b8a9b23fe2155fcb9a0517ceb3b65a8c403e5f08 | Recovery session, MFA, password update |
| auth/auth-callback.html | a412a3f71b3ee18c6b38df1ec9cd16d50f099dad | PKCE callback and invite token handoff |
| auth/mfa-challenge.html | 52359a47f436380c49ba2362acac6e0f56061f89 | TOTP challenge and return path |
| auth/mfa-enroll.html | 6657cd54f12094d375def43877bfec635d588db2 | TOTP enrollment and return path |
| auth/logout.html | 462bc0653044da0ace0e309988bcd67cb330003c | Global/local logout |
| auth/krim-account-actions.js | a276dd647451e223816e691fb4cdbe107298b05d | Password/email/phone changes, local sessions, account actions |
| auth/partner-signin.html | e77bb61b64ebb0773f532c3cc694a247bb1c25bc | Partner-specific sign-in |
| auth/driver-signin.html | d896e1813f3041103670c327e615926baedc012c | Driver sign-in, invitation acceptance and MFA |
| config.js | 4ea7a73c3eb68444c86e3238043fb5f16b65c4a1 | Shared environment/client configuration |
| auth/owner-testing-reset-password.html | 7e68d833f87b8f50c9c4fab38f164bab52da2a36 | Staging-only owner reset guard |

Prior Phase 00 reports reconciled:
- phase-00-authentication-lifecycle-and-account-security-audit-2026-11-25.md
- phase-00-password-recovery-redirect-session-expiry-and-mfa-audit-2026-11-25.md
- phase-00-auth-callback-and-redirect-allowlist-inventory-2026-11-25.md

## 2. Lifecycle findings

### A. Login and workspace routing — SOURCE PARTIAL PASS

- Main login uses Supabase signInWithPassword and requires a returned session.
- It invokes krim-auth-workspace-route before normal workspace selection; failure is fail-closed.
- It resolves active organization memberships and organization types rather than trusting the requested workspace alone.
- Platform-admin routing is separately resolved server-side; the UI requires a verified TOTP factor and AAL2 before redirecting to the control centre.
- Other workspace users are required by this flow to enroll a verified TOTP factor and complete MFA where the next assurance level is AAL2.
- The post-MFA path is restricted to canonical KRIM workspace destinations.
- Driver sign-in has a separate invitation acceptance path through krim_accept_driver_invitation and checks the resulting identity/session.
- Partner sign-in is separate and has its own TOTP checks.

Limit: client-side routing is not a substitute for server-side RLS/RPC/Edge Function authorization. A user must not gain workspace access merely by changing query parameters, user_metadata, local storage or sessionStorage.

### B. Shared requireAuth guard — REMEDIATION REQUIRED

auth-core.js obtains the current session and redirects when no session exists. For minimumAal=aal2 it calls getAuthenticatorAssuranceLevel(), but destructures only data and does not inspect the returned error.

If the assurance lookup fails, missing data causes the currentLevel comparison to fail and redirects to the MFA challenge. This appears fail-closed for access, but masks an Auth service failure and may create a challenge/redirect loop. The guard should explicitly distinguish lookup error, insufficient assurance and missing session, show a recoverable error, and never treat an assurance lookup failure as a successful check.

The shared guard is only effective on pages that actually import and call it. Each protected route and every sensitive server operation must have independent enforcement.

### C. Password recovery request — SOURCE PARTIAL PASS

- Uses resetPasswordForEmail with a redirect constructed from current origin and repository base path.
- Uses canonical auth/reset-password.html completion route.
- UI uses generic account-existence wording, reducing email enumeration.
- Provider-level rate limits, CAPTCHA, email delivery, bounce handling and redirect allowlist behavior are not proven.

### D. Password reset completion — SOURCE PARTIAL PASS / HIGH PRIORITY

Positive:
- Requires recovery indicators and a usable Supabase recovery session.
- Exchanges PKCE code with exchangeCodeForSession.
- Rejects missing/expired session.
- Checks MFA assurance and requires AAL2 when the account's next level is AAL2.
- Requires a 12-character minimum and matching password confirmation.
- Requests global sign-out after password update.

Risks:
- updateUser is raced against a 20-second timeout. The timeout does not cancel the underlying request, so the UI may report an indeterminate outcome while the password update later succeeds.
- Global sign-out is scheduled 1.5 seconds later; closing the tab or losing connectivity can interrupt the attempt. The result is not verified before navigation.
- Password history, leaked-password policy, OTP expiry/reuse, session invalidation and recovery email delivery are untested.

### E. Account password change — POLICY INCONSISTENCY

auth/krim-account-actions.js requires current-password reauthentication before updateUser, which is positive. However, this path enforces only an 8-character client-side minimum, while password recovery enforces 12 characters. The policy must be consistent and enforced by Supabase Auth configuration, not only in browser code.

### F. MFA enrollment and challenge — SOURCE PARTIAL PASS

- Enrollment requires an authenticated session, checks existing verified factors, enrolls TOTP and verifies a challenge before completing.
- Challenge verifies the TOTP code and checks currentLevel === aal2 before returning to the requested workspace.
- Return paths are restricted to same-origin KRIM workspace/auth paths.
- Main login and driver login also check AAL2 after challenge.
- Backup-code generation, factor removal/replacement, lost-device recovery, MFA downgrade, factor recovery and administrator emergency recovery are not established by this source review.
- A verified factor count is not evidence that all protected RPCs enforce AAL2.

### G. Callback and invitation lifecycle — PARTIAL / NOT VERIFIED

- Callback exchanges a PKCE code or reads the resulting session.
- Account metadata is used as a routing hint, not as the authority for workspace access.
- A 64-character hexadecimal driver invitation token can be placed in sessionStorage and passed to the driver acceptance flow.
- Driver acceptance calls krim_accept_driver_invitation; token signature/ownership/expiry, one-time consumption and replay resistance must be verified in the database function.
- Generic organization-invitation acceptance remains explicitly unconfigured in krim-account-actions.js; it refuses to consume a token.
- No evidence from this source pass establishes invitation email issuance, token expiry or replay protection end-to-end.

### H. Logout and session registry — PARTIAL

- auth/logout.html attempts global sign-out and falls back to local sign-out if global revocation fails. The UI distinguishes the outcomes and clears selected sessionStorage values.
- The file contains stray text t> immediately after the closing script tag. It appears to be harmless stray page text, but should be removed.
- Account active-sessions UI reads KRIM session registry rows, but its sign-out action uses scope local. It signs out the current browser only and does not revoke every other session.
- The UI must not imply that a displayed KRIM session registry is a complete or authoritative list of Supabase Auth sessions unless synchronization and revocation are proven.
- No runtime proof of global refresh-token revocation, offline logout, cross-device invalidation or refresh-token reuse detection exists.

### I. Environment and redirects — PARTIAL

- QA config has explicit host-to-project mapping and no arbitrary project override; prior environment audit reports that the QA branch maps GitHub Pages to Production and krim-staging.pages.dev/localhost to Staging.
- The owner reset page refuses to initialize unless the environment is preview and the project ref equals the known Staging project ref.
- Prior callback inventory recorded the user-provided Production Site URL as https://rimjhimkrn-web.github.io/logistics-saas/ and its allowlist as the broader GitHub Pages base-path wildcard.
- Staging origin reachability and its actual Auth URL Configuration remain unverified. Do not add the staging host to Production allowlist.
- Redirect allowlist should be narrowed only after every signup, recovery, invitation and provider callback sender has been traced. No settings are changed by this report.

## 3. Prior Auth catalog evidence — snapshot only

A prior read-only catalog report recorded:
- Production: 9 Auth users, all 9 email-confirmed; 4 verified and 1 unverified TOTP factors; 13 session rows.
- Staging: 1 Auth user, email-confirmed; 1 verified TOTP factor; 2 session rows.
- Session not_after values did not populate expected expired/future buckets in that snapshot.

This does not prove accounts can sign in, recovery works, MFA is enforced or sessions are valid/invalid. JWT lifetime, refresh rotation, inactivity timeout, absolute session lifetime and revocation semantics remain unknown.

## 4. Required negative and lifecycle tests — NOT RUN

Execute only after Staging origin, project isolation, synthetic test identities, email sink and test configuration are approved:

| ID | Test | Expected result |
|---|---|---|
| AUTH-LIFE-01 | Valid and invalid credentials | Valid user gets only mapped workspace; invalid response does not reveal account existence |
| AUTH-LIFE-02 | Unconfirmed email attempts login | Denied or routed to confirmation according to configured policy |
| AUTH-LIFE-03 | Duplicate signup and resend confirmation | No duplicate account; safe generic response; bounded resend |
| AUTH-LIFE-04 | Valid, expired, reused and malformed confirmation link | Only valid unused token succeeds |
| AUTH-LIFE-05 | PKCE callback with missing/invalid/replayed code | No session and no privileged redirect |
| AUTH-LIFE-06 | Login with tampered role query/user_metadata | Server membership/role remains authoritative |
| AUTH-LIFE-07 | User with no active membership | No workspace access |
| AUTH-LIFE-08 | Verified TOTP absent, unverified or invalid | No protected workspace access |
| AUTH-LIFE-09 | AAL1 session invokes AAL2-only route/RPC | Server rejects |
| AUTH-LIFE-10 | MFA assurance lookup returns error | Explicit fail-closed error; no access and no infinite redirect loop |
| AUTH-LIFE-11 | MFA challenge expired/replayed/invalid code | No AAL2; no privileged access |
| AUTH-LIFE-12 | Password reset unknown vs known email | Equivalent outward response; test sink captures only synthetic messages |
| AUTH-LIFE-13 | Recovery token expired/reused/cross-environment | Reject; no Production↔Staging session exchange |
| AUTH-LIFE-14 | Password reset with AAL2-required account | Password change impossible until AAL2 verified |
| AUTH-LIFE-15 | Password update times out then completes late | UI resolves actual server outcome; no unsafe duplicate action |
| AUTH-LIFE-16 | Password changed; other sessions remain open | All prior sessions revoked according to policy, with verifiable result |
| AUTH-LIFE-17 | Global logout vs local logout | Global invalidates other sessions; local invalidates only current browser |
| AUTH-LIFE-18 | Refresh token reused after rotation/revocation | Rejected and handled without restoring access |
| AUTH-LIFE-19 | Inactive/deleted synthetic account with existing session | Sensitive server requests rejected |
| AUTH-LIFE-20 | Driver invitation valid/expired/reused/for another email | Only intended invitee can consume once |
| AUTH-LIFE-21 | Generic organization invitation | Remains unavailable until secure sender and acceptance endpoint are implemented |
| AUTH-LIFE-22 | External redirect URL, protocol-relative URL, encoded path and open-redirect payload | Redirect remains on approved same-origin KRIM route |
| AUTH-LIFE-23 | Staging recovery link opened on Production and vice versa | Reject; no cross-project callback |
| AUTH-LIFE-24 | Session expiry while form is open / refresh fails | Protected write denied and user receives safe reauthentication path |

## 5. Readiness register

| Area | Status |
|---|---|
| Main login source and membership-based routing | PASS — source inspection only |
| Main login TOTP/AAL2 source checks | PASS — source inspection only |
| PKCE callback source | PARTIAL |
| Password reset request source | PASS — source inspection only |
| Password reset completion source | PARTIAL; timeout/revocation behavior needs remediation |
| Shared requireAuth AAL2 error handling | REMEDIATION REQUIRED |
| Password policy consistency | REMEDIATION REQUIRED (8 vs 12 characters in UI flows) |
| MFA enrollment/challenge source | PASS — source inspection only |
| Global logout source | PARTIAL; runtime revocation not proven |
| Active-session revocation across devices | NOT IMPLEMENTED by sampled UI action |
| Generic organization invitation acceptance | NOT IMPLEMENTED in sampled account-actions handler |
| Driver invitation token lifecycle | NOT TESTED |
| Auth URL configuration and staging reachability | NOT VERIFIED |
| JWT expiry/refresh/reuse policy | NOT VERIFIED |
| Signup, email delivery and recovery runtime | NOT TESTED |
| Cross-workspace protected-route and RPC AAL enforcement | NOT TESTED |

## 6. Required remediation before controlled Staging execution

1. Harden auth-core.js requireAuth() to explicitly handle MFA assurance lookup errors and avoid redirect loops.
2. Unify password minimum policy; enforce the same policy server-side through Auth configuration.
3. Replace password-reset timeout race with a recoverable operation-status pattern and verify global sign-out result.
4. Remove stray t> from auth/logout.html.
5. Clarify active-sessions UI: current-browser logout is local, not all-session revocation; do not imply complete session inventory without proof.
6. Verify driver invitation token ownership, expiry, one-time atomic consumption and replay resistance in the database RPC.
7. Keep generic organization invitation acceptance disabled until a secure server-side sender and acceptance endpoint exist.
8. Obtain read-only Auth configuration values (never secrets): JWT expiry, refresh token rotation/reuse interval, OTP expiry, CAPTCHA/rate limits, password/leaked-password policy, Site URL, redirect allowlist, signup/provider toggles.
9. Verify the actual Staging deployment origin and Staging Auth URL configuration before runtime tests.
10. Test all 24 lifecycle/negative cases using synthetic Staging accounts and a mail sink. No production user or customer emails.

## 7. Safety and release decision

- This is a read-only source audit of the QA branch.
- No Supabase Auth calls, database queries, emails, OTPs, user creation, password updates, session revocation, storage operations, configuration edits, deployments or merges were performed.
- Do not approve unrestricted real-user onboarding on this evidence.
- Production remains untouched; QA changes are documentation only.

Phase 00 status: IN PROGRESS. Authentication lifecycle is NOT VERIFIED. NO EVIDENCE = NO PASS.
