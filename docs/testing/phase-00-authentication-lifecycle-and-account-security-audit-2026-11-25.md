# Phase 00 — Authentication lifecycle and account security audit

Date: 2026-11-25  
Environments: Production and Staging Supabase  
Scope: Read-only Auth catalog inspection of user/email confirmation state, identity providers, session expiry metadata and MFA factor status. Repository auth-flow source and dashboard Auth policy configuration were not successfully retrieved in this pass. No login, signup, password reset, MFA challenge, email, session revocation or user mutation was performed.

## Executive verdict

**NOT VERIFIED for real-user onboarding.** The available Auth database snapshot confirms that the small existing user sets have confirmed email identities and that TOTP factors exist. It does not prove signup, verification, recovery, refresh-token rotation, session expiry, MFA enforcement, account deletion or deactivation flows work end to end.

## Read-only Auth snapshot

| Metric | Production | Staging |
|---|---:|---:|
| Auth users | 9 | 1 |
| Email-confirmed users | 9 | 1 |
| Unconfirmed users | 0 | 0 |
| Deleted-at users | 0 | 0 |
| Email identities | 9 | 1 |
| TOTP factors — verified | 4 | 1 |
| TOTP factors — unverified | 1 | 0 |
| Session rows | 13 | 2 |
| Session rows with not_after before now | 0 | 0 |
| Session rows with not_after at/after now | 0 | 0 |

**Session-count caveat:** The 13/2 session rows did not fall into either non-null `not_after` comparison bucket. This indicates that `not_after` is not populated for these rows (or otherwise not represented in the expected way). It is not evidence that sessions are currently valid or invalid. We did not inspect tokens or personal session details.

## Findings

1. **Email confirmation state is positive but limited.** All existing Auth users are email-confirmed in both environments. No unconfirmed account is available to exercise the pending-confirmation path. This is a snapshot, not a signup/verification test.

2. **TOTP enrollment exists, enforcement is unproven.** Production has four verified and one unverified TOTP factor; Staging has one verified TOTP factor. Factor existence does not establish that privileged actions enforce AAL2, that challenge/verify succeeds, or that recovery and factor removal are safe.

3. **Session expiry configuration requires inspection.** Session rows have no `not_after` values in the inspected snapshot. We could not establish the configured JWT lifetime, refresh-token rotation policy, inactivity timeout, single-session policy or revocation behavior from the database rows alone.

4. **No account lifecycle execution was performed.** Signup, duplicate-email handling, confirmation link delivery, expired/used token behavior, login lockout/rate limits, password reset, password update, logout, refresh, session revocation, MFA enrollment/challenge/unenrollment and account deletion are all untested.

5. **Auth provider and redirect policy remain unverified.** Identity rows show email as the only provider in the inspected snapshot. This does not reveal whether other providers are enabled in Auth configuration. Site URL, allowed redirect URLs, email OTP expiry, SMTP delivery configuration, CAPTCHA, password strength/leaked-password protection, signup enablement and rate limits require a dashboard/config review. Do not infer them from the identity rows.

6. **Repository auth-flow source retrieval was incomplete.** The code search did not return matching auth method references, and attempted file retrieval returned 404. No source-level conclusion is made about the current deployed signup, recovery, callback or session-handling UI. Earlier Phase 00 reports already identified shared-client/environment routing work on the QA branch and Production-main divergence; those findings remain relevant.

7. **AAL2 gates need systematic negative tests.** Prior source reviews found selected admin functions require AAL2, but the complete privileged RPC surface has not been mapped to an explicit AAL2 policy matrix. A verified TOTP factor alone is insufficient evidence.

8. **Deleted-user and token-revocation semantics remain open.** No deleted Auth users were present. The platform must explicitly test how sensitive operations behave after account suspension/deletion and whether existing sessions are revoked or rejected. Do not assume deleting an Auth user alone immediately invalidates already-issued access tokens.

## Required controlled test plan

Only after Staging isolation, test-user sink, and a dedicated synthetic identity set are approved:
- Signup with valid/invalid/duplicate email; verify confirmation-required behavior.
- Confirm email with valid, expired, reused and malformed links/tokens.
- Login with correct/incorrect credentials; test throttling and generic error responses.
- Password reset request, link callback, expiry, reuse, password update and existing-session behavior.
- Session refresh, expiry, logout and explicit session revocation.
- TOTP enrollment, unverified factor, challenge, verified factor, recovery and factor removal.
- Confirm AAL1 is rejected for AAL2-only operations and AAL2 succeeds only for authorized platform administrators.
- Disable/suspend a synthetic user and verify protected operations reject existing sessions.
- Verify redirect allowlist rejects untrusted origins and returns only to approved KRIM destinations.
- Capture delivery status via a test sink; do not send to real customers or partners.

## Release decision

- Existing email confirmation snapshot: **PASS (catalog-observed only)**.
- TOTP factors exist: **PASS (catalog-observed only)**.
- Signup and email verification lifecycle: **NOT TESTED**.
- Password recovery and reset: **NOT TESTED**.
- Session expiry, refresh and revocation: **NOT VERIFIED**.
- MFA challenge and AAL enforcement: **NOT VERIFIED end to end**.
- Auth redirect and provider configuration: **NOT VERIFIED**.
- Real-user onboarding: **NOT APPROVED**.

This report is limited to the evidence described above. NO EVIDENCE = NO PASS.
