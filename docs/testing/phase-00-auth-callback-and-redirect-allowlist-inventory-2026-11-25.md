# Phase 00 — Authentication Callback and Redirect Allowlist Inventory
Date: 2026-11-25
Branch: `qa/phase-00-baseline-2026-11-25`
Scope: Read-only source inspection of authentication callback, email confirmation, password recovery, invitation and MFA routes, compared with the Production Supabase Authentication → URL Configuration values supplied in this conversation. No Supabase settings, database records, secrets, deployments, users, or provider operations were changed.

## Production Supabase URL configuration observed
The user-provided Production dashboard view shows:
- Site URL: `https://rimjhimkrn-web.github.io/logistics-saas/`
- Redirect allowlist: `https://rimjhimkrn-web.github.io/logistics-saas/**`

The Site URL matches the repository's explicitly allowlisted Production host and base path. The redirect pattern is valid Supabase glob syntax, but is broader than necessary for a production allowlist.

## Source-confirmed Production callback destinations
The following routes are directly referenced by current source code:
1. `/logistics-saas/auth/auth-callback.html`
   - Customer signup and partner signup set `emailRedirectTo` to `auth-callback.html` relative to the current `/auth/` page.
   - Email verification resend also uses the shared callback route.
   - The callback exchanges the PKCE code for a session and routes by account type.
2. `/logistics-saas/auth/reset-password.html`
   - Both `auth/forgot-password.html` and `auth/recovery.html` explicitly set this as the password recovery redirect.
   - The page exchanges the recovery code, validates the session, checks MFA assurance when required, updates the password and signs out global sessions.

## Staging-only callback destination
- `https://krim-staging.pages.dev/auth/owner-testing-reset-password.html` is the intended staging owner password recovery route if and only if that exact Cloudflare Pages host is confirmed as the deployed staging origin.
- Its source explicitly refuses to initialize unless `KRIM_ENVIRONMENT === "preview"` and the Supabase project ref equals the staging project `qrpcivhdxobiaofppbkl`.
- The staging recovery request code constructs the redirect from the current origin, so it is expected to produce the staging origin plus this route on the staging host.
- This staging-only route must not be added to Production's redirect allowlist.

## Routes not yet proven to require allowlisting
- `auth/invitation.html` consumes invitation tokens/codes when opened, but the repository source reviewed in this pass did not identify the server-side invitation sender or its exact `redirectTo` value. Do not remove broad redirect coverage until invitation issuance is traced end-to-end.
- OAuth provider callback URLs and any external integration callback URLs were not confirmed in this source pass.
- `auth/verify-email.html` supports OTP entry and resends confirmation via the shared callback route; its direct OTP entry does not itself require a separate redirect URL.

## Recommended least-privilege Production allowlist (provisional)
After the remaining invitation/OAuth sender review is complete, the likely exact allowlist entries are:
- `https://rimjhimkrn-web.github.io/logistics-saas/auth/auth-callback.html`
- `https://rimjhimkrn-web.github.io/logistics-saas/auth/reset-password.html`
- Add `https://rimjhimkrn-web.github.io/logistics-saas/auth/invitation.html` only if the actual invitation sender sets that destination.
- Add any OAuth/provider callback path only after a code/config reference proves it is needed.

Do not replace the existing wildcard yet. The above is a proposed target, not an instruction to save settings. The Site URL should remain `https://rimjhimkrn-web.github.io/logistics-saas/` unless a separate verified deployment decision changes the canonical Production origin.

## Staging URL configuration
The repository's host allowlist identifies `krim-staging.pages.dev` as staging, but this pass could not independently verify that the Pages deployment is currently reachable or that its custom deployment alias is active. Therefore:
- Candidate staging Site URL: `https://krim-staging.pages.dev/`
- Candidate staging owner reset redirect: `https://krim-staging.pages.dev/auth/owner-testing-reset-password.html`
- Status: NOT VERIFIED — do not save until the live staging origin is confirmed.

## Evidence and test status
- Production host-to-project mapping: PASS (source inspection).
- Production callback route source references: PASS (static source inspection).
- Production Supabase dashboard values: OBSERVED (user-provided dashboard text; not independently read through Management API).
- Production redirect allowlist least-privilege review: INCOMPLETE (invitation/OAuth sender tracing remains).
- Staging callback source guard: PASS (static source inspection).
- Staging host reachability: NOT VERIFIED.
- Auth email delivery, PKCE exchange, recovery, invitation, OAuth and MFA runtime tests: NOT TESTED.
- No real email, OTP, password change, account creation or provider action was triggered.

## Next Phase 00 actions
1. Trace invitation email generation and any OAuth/provider redirect configuration before narrowing Production allowlist.
2. Verify the actual staging deployment hostname and its path behavior.
3. Obtain a read-only review of Staging URL Configuration and compare it with the verified host.
4. Only after the above, request explicit approval before any Auth URL setting is saved.
5. Continue to staging-only, controlled runtime auth tests with test accounts and external delivery disabled or safely isolated.

## Readiness decision
Authentication URL configuration is **PARTIALLY REVIEWED — NOT PASSED**. Do not declare Phase 00 complete. No settings were changed. NO EVIDENCE = NO PASS.
