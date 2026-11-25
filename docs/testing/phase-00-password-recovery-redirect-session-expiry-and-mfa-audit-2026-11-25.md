# Phase 00 — Password recovery, auth redirects, session lifecycle and MFA audit

Date: 2026-11-25  
Repository: `rimjhimkrn-web/logistics-saas`  
Ref: `qa/phase-00-baseline-2026-11-25`  
Scope: Read-only source review of canonical auth login, forgot/reset password, callback, MFA enrollment/challenge, logout, shared auth guard and account-session pages. Correlated with the prior read-only Auth catalog snapshot. No login, recovery email, OTP, MFA challenge, password change, logout, user mutation or provider call was performed.

## Executive verdict

**NOT VERIFIED for real-user onboarding.** KRIM has a substantial client-side recovery and MFA flow: recovery links use an explicit same-origin destination, password reset requires a recovery session, password change requests global sign-out, and login checks verified TOTP/AAL2 before routing. However, runtime behavior, Auth redirect allowlist, token/session expiry settings, SMTP delivery, rate limits, revocation semantics and protected-route enforcement across all nine workspaces remain unproven.

The most important source-level concerns are:
1. The shared `requireAuth()` guard checks `getSession()` but does not check the returned error from `getAuthenticatorAssuranceLevel()`; a failed MFA assurance lookup can fall through when AAL2 is required.
2. The password-reset timeout races an in-flight `updateUser()`; the UI correctly warns that the password may or may not have changed, but a retry can create uncertainty and the subsequent global sign-out is not guaranteed to execute if the page is closed.
3. `auth/logout.html` contains a malformed-looking closing sequence `</script>t>`; the script close tag itself is recognized by HTML parsing, but the trailing `t>` is stray page text and should be removed.
4. The callback stores a valid 64-hex driver invite token in `sessionStorage` and then routes based on user-editable `user_metadata`. The source comment correctly says email confirmation does not authorize a workspace; server-side membership and permission checks must remain authoritative.
5. The prior Auth snapshot showed 13 Production and 2 Staging session rows, but the session expiry column did not populate the expected expired/future buckets. This is not proof that sessions are expired or active; configured JWT lifetime and refresh/revocation behavior remain unknown.

## Source evidence

- `auth/login.html` — SHA `4bec947c6caea41a9dca9ceee01f07a4010c5b33`.
- `auth/forgot-password.html` — SHA `26f12c9c95651627ab02168cda6e73d894ab5a38`.
- `auth/reset-password.html` — SHA `b8a9b23fe2155fcb9a0517ceb3b65a8c403e5f08`.
- `auth/auth-callback.html` — SHA `a412a3f71b3ee18c6b38df1ec9cd16d50f099dad`.
- `auth/mfa-challenge.html` — SHA `52359a47f436380c49ba2362acac6e0f56061f89`.
- `auth/mfa-enroll.html` — SHA `6657cd54f12094d375def43877bfec635d588db2`.
- `auth/logout.html` — SHA `462bc0653044da0ace0e309988bcd67cb330003c`.
- `auth-core.js` — SHA `2cd5fb070ebfbaf2e712eef25dba8fc185e7f20f`.
- `auth/krim-account-actions.js` — SHA `a276dd647451e223816e691fb4cdbe107298b05d`.

## Findings

### 1. Password reset request — SOURCE PARTIAL PASS

- Calls Supabase `resetPasswordForEmail(email, { redirectTo })`.
- Redirect is constructed from the current origin and known GitHub Pages base path to `auth/reset-password.html`; it is not taken from an arbitrary user-provided redirect URL.
- Success response uses generic wording: “If an eligible KRIM account exists…”, reducing account enumeration.
- Errors are displayed using `textContent`.
- No client-side request throttling is visible; provider-level rate limits/CAPTCHA and email delivery controls were not verified.
- Supabase redirect allowlist and Site URL were not inspectable through the available project tools in this pass.

### 2. Password reset completion — SOURCE PARTIAL PASS / NEEDS RUNTIME TEST

Positive:
- Requires recovery indicators in the URL (recovery access token/type or PKCE code) and then requires an established Supabase session.
- PKCE `code` is exchanged using `exchangeCodeForSession`.
- Rejects missing/expired recovery session.
- Requires minimum 12-character password and matching confirmation.
- Checks MFA assurance and requires AAL2 when `nextLevel` indicates it.
- After successful password update, requests `signOut({scope:"global"})`.

Risks/unknowns:
- Hash-based recovery token/session bootstrap depends on Supabase client `detectSessionInUrl` behavior; it was not tested with a real controlled recovery link.
- Password update is raced against a 20-second timeout. The UI explicitly warns that outcome may be indeterminate. The underlying promise is not cancelled when the timeout wins.
- Global sign-out runs 1.5 seconds later. Browser closure/network failure can interrupt it; the code does not independently verify that all other sessions were revoked.
- Password history, breached-password protection, strength policy, recovery OTP expiry, one-time-use behavior and recovery email delivery remain unverified.
- URL fragment/query token exposure to browser extensions, analytics, referrers and third-party scripts must be tested and minimized. Do not log recovery URLs.

### 3. Authentication callback — SOURCE PARTIAL PASS

- Exchanges PKCE `code` or reads the resulting session.
- Does not treat email confirmation as workspace authorization.
- Chooses a next login path using `user_metadata` account type, which is user-editable metadata. This is acceptable only as a routing hint; it must never grant roles or privileges.
- Stores a syntactically valid driver invitation token in `sessionStorage`; downstream invitation acceptance must verify token signature/ownership/expiry server-side and consume it atomically.
- Callback errors are logged to browser console. Confirm no error object contains credential-bearing URLs/tokens before logging.
- No actual redirect allowlist, invitation replay or invalid/expired callback tests were performed.

### 4. Login routing and MFA — SOURCE PARTIAL PASS

- Password sign-in requires a usable returned session.
- Workspace routing uses an Edge Function and organization memberships, not only the requested role query parameter.
- Requested `next` path is limited to same-origin booking request paths.
- Platform Admin login requires verified TOTP factor and AAL2 before opening the control centre; the protected admin workspace is expected to independently re-check authorization.
- Other workspace login flow checks a verified TOTP factor and performs MFA challenge when the next assurance level is AAL2. If no factor is present, it sends the user to MFA enrollment before opening the workspace.
- After MFA verification, it checks `currentLevel === "aal2"`.
- This is promising source evidence, not proof that every sensitive server function independently enforces AAL2. The nine-workspace server-side route/guard matrix and runtime negative tests remain outstanding.
- Some client console logs include raw error objects; review for accidental credential or personal-data leakage.

### 5. Shared auth guard — HIGH PRIORITY SOURCE ISSUE

`auth-core.js` `requireAuth(minimumAal)`:
- Reads session with `getSession()`.
- If missing/error, redirects to sign-in.
- For `minimumAal === "aal2"`, calls `getAuthenticatorAssuranceLevel()`.
- It does not inspect the returned error before checking `currentLevel`.

If the assurance lookup fails and returns no data, the optional chain yields an undefined level, which triggers the redirect to MFA challenge; this specific implementation does not grant access, but it also does not distinguish service failure from an AAL1 session. This is fail-closed for this branch, but error handling and redirect-loop behavior need correction and testing. More importantly, any page that does not invoke this guard must rely on server-side authorization; frontend guard presence alone is not a security boundary.

Also, `getSession()` reads the locally stored session. Sensitive server operations must validate the JWT and enforce permissions/AAL on the server; never trust client session state alone.

### 6. MFA enrollment and challenge — SOURCE PARTIAL PASS

- TOTP enrollment and verification use Supabase MFA APIs.
- AAL2 is checked after verification.
- MFA factor ID is stored in sessionStorage for challenge routing; it is an identifier, not a factor secret.
- Return path is restricted to a same-origin allowlist of KRIM workspace/auth paths.
- Enrollment allows return to the Admin Control Centre and selected workspace paths; downstream authorization must independently enforce role and AAL2.
- Backup-code, factor removal/replacement, lost-device recovery, MFA downgrade, factor reset and admin recovery procedures were not tested.
- Existing snapshot: Production had 4 verified TOTP factors and 1 unverified; Staging had 1 verified and 0 unverified. Factor counts do not prove that every user or every privileged route enforces MFA.

### 7. Logout and session revocation — SOURCE PARTIAL PASS

- Logout requests global sign-out.
- If global sign-out fails, it attempts local sign-out and explicitly warns that other sessions may remain active.
- It clears the MFA factor selector and driver invite token from sessionStorage.
- Account active-sessions page says its sign-out action affects this browser only and uses `scope:"local"`; it should not be confused with global revocation.
- The HTML has a stray `t>` immediately after the closing script tag.
- No runtime tests of global/local revocation, refresh-token reuse, deleted-user sessions, cross-device invalidation or logout while offline were performed.

### 8. Session expiry, refresh and Auth configuration — NOT VERIFIED

Prior Auth inventory:
- Production: 9 Auth users, 9 confirmed email identities, 4 verified TOTP, 1 unverified TOTP, 13 session rows.
- Staging: 1 Auth user, 1 confirmed email identity, 1 verified TOTP, 2 session rows.
- Session `not_after` did not fall into either expired or future timestamp bucket in the prior snapshot; likely NULL/not populated, but exact rows/settings require a controlled follow-up.

Not available from the connected project inspection in this pass:
- JWT expiry duration and refresh token rotation/reuse interval.
- Inactivity timeout and absolute session lifetime.
- Email OTP expiry and resend throttling.
- Password policy, leaked-password protection and CAPTCHA.
- Signup enablement and identity provider settings.
- Auth Site URL and redirect allowlist.
- SMTP sender, delivery, bounce and complaint handling.
- Whether user deletion or password changes revoke every session as intended.

Do not infer these settings from frontend source or the presence of Auth session rows.

### 9. Recovery and access journey coverage — NOT VERIFIED

No controlled test was run for:
- Unknown email vs registered email response equivalence.
- Expired, replayed, malformed and cross-environment recovery links.
- Recovery link on Staging attempting to land on Production or vice versa.
- PKCE callback success/failure.
- MFA enrolled/unverified/removed factor paths.
- AAL1 denial on AAL2-required workspace pages and RPCs.
- Concurrent password reset/change and session revocation.
- Email change and phone change verification.
- Driver invite expiry/replay/consumption.
- Cross-tenant workspace redirects and role tampering.

## Required remediation and test gates

1. Review and harden shared `requireAuth()` error handling; keep server-side authorization authoritative for every protected operation.
2. Remove the stray `t>` after the logout script closing tag.
3. Replace the password-reset timeout race with an idempotent status/recovery design that avoids ambiguous retry and verifies sign-out outcome.
4. Confirm reset and callback redirects are explicitly allowlisted separately for Production and Staging; prove no cross-project callback.
5. Review browser console logging and ensure no recovery URLs, tokens, raw JWTs or sensitive Auth errors are logged.
6. Obtain Auth configuration metadata for both projects (no secret values): JWT expiry, refresh rotation/reuse, OTP expiry, CAPTCHA/rate limits, password/leaked-password settings, Site URL, redirect allowlist and signup/provider toggles.
7. Perform controlled Staging tests using isolated synthetic identities and a mail sink; do not use real user accounts or send to real addresses.
8. Test expired/replayed recovery links, password change, global/local logout, cross-device session revocation, MFA AAL1/AAL2 and protected-route denial.
9. Verify every sensitive RPC/Edge Function independently enforces user identity, organization permission and AAL requirements.

## Release decision

- Password reset request: **SOURCE PARTIAL PASS; delivery/config/runtime not verified**.
- Recovery session validation and password update: **SOURCE PARTIAL PASS; token lifecycle and revocation not verified**.
- Auth callback/redirect: **SOURCE PARTIAL PASS; redirect allowlist and invite token lifecycle not verified**.
- Workspace login/MFA routing: **SOURCE PARTIAL PASS; runtime and full server enforcement matrix not verified**.
- Shared auth guard: **SOURCE FAIL-CLOSED but error/coverage hardening required**.
- Logout: **SOURCE PARTIAL PASS; global revocation runtime not verified**.
- Session expiry/refresh settings: **NOT VERIFIED**.
- Real-user onboarding: **NOT APPROVED**.

No code, Auth settings, sessions, users, secrets, emails or deployments were changed. NO EVIDENCE = NO PASS.
