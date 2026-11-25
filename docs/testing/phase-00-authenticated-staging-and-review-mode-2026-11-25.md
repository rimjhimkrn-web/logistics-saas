# Phase 00 — Authenticated Staging Mode and Explicit Review Mode
Date: 2026-11-25
Branch: `qa/phase-00-baseline-2026-11-25`
Scope: QA branch only. No production deployment, database writes, account creation, or provider side effects.

## Problem confirmed
The staging hostname itself was being treated as a no-auth review environment in multiple partner-facing flows. This prevented normal staging authentication and partner registration even though the shared Supabase client was correctly pointed at the staging project. A compatibility flag, `KRIM_AUTH_DISABLED`, was also set to true for every preview host.

## Changes implemented
- `config.js` continues to map only the allowlisted staging hostname and its subdomains to the staging Supabase project.
- `KRIM_AUTH_DISABLED` is now explicitly false for staging. It is retained as a deprecated compatibility flag so legacy consumers do not silently disable authentication.
- Added `KRIM_STAGING_REVIEW_MODE`. It is true only when both conditions hold:
  1. The resolved environment is the approved preview/staging environment.
  2. The URL explicitly contains `?mode=review`.
- Staging without `?mode=review` now defaults to authenticated mode. The existing shared Supabase client remains initialized against staging.
- Updated partner onboarding, partner sign-in, and partner account registration to use the explicit review-mode flag instead of assuming every staging visit is a no-account preview.
- Removed the broad `endsWith(".pages.dev")` review-mode check from partner registration. Unknown hosts are still blocked earlier by the central hostname allowlist.
- In explicit review mode, partner forms remain read-only/local-preview and do not create accounts, submit applications, upload documents, or make backend changes.
- Added regression coverage for default authenticated staging, explicit review mode, project selection, and the three partner-facing routes.

## Automated verification
Final source commit under test: `d69172b18b85b4c3d9557c31e5c8507fbe2d0d85`

GitHub Actions run:
- Run ID: `45557128282`
- Conclusion: **success**
- Critical workflow smoke checks: PASS
- Shared auth module syntax checks: PASS
- Fail-closed environment isolation and explicit review-mode tests: PASS
- Repository-wide static audit: PASS
- Audit artifact upload: PASS
- Run URL: https://github.com/rimjhimkrn-web/logistics-saas/actions/runs/45557128282

## Expected route behavior
- Approved staging host, no mode parameter: Supabase Auth remains enabled; partner sign-in and registration are available against staging.
- Approved staging host with `?mode=review`: the partner sign-in/registration/onboarding pages display the read-only review experience and block account/backend actions.
- Production host: production Supabase mapping remains unchanged; staging review mode is false.
- Unknown hostname: configuration throws before any Supabase client is created.

## Safety boundaries and outstanding verification
This is a source/configuration and CI-level change only. It does **not** establish that authenticated staging is fully ready for E2E:
- No browser sign-in, account registration, email confirmation, MFA enrollment/challenge, password recovery, or partner onboarding journey has been executed.
- No synthetic accounts have been created.
- No emails, SMS, Telegram messages, payment calls, webhooks, or other external provider operations have been triggered.
- Staging database RLS/RPC behavior and organization-level access still require positive and negative runtime tests.
- Staging Edge Function parity and the known `KRIM_AUTH_DISABLED` consumer inventory still require further review. The flag is now false, but a repository-wide browser runtime test is needed to confirm no legacy UI path relies on it unexpectedly.
- The staging host is not a security boundary. Authentication, MFA, RLS, server-side role checks, and organization permissions must remain authoritative.
- Never use real customer or partner records for QA; use controlled synthetic identities and a controlled email sink before testing signup or recovery.

## Readiness decision
- Explicit review-mode separation: **PASS (source + CI)**
- Authenticated staging project mapping: **PASS (source + CI)**
- Partner sign-in/registration no longer forced into preview: **PASS (source + CI)**
- Browser runtime authentication: **NOT TESTED**
- Email confirmation and MFA: **NOT TESTED**
- Staging RLS/RPC authorization: **NOT TESTED**
- Synthetic-user E2E: **BLOCKED pending controlled test identities and email delivery isolation**
- Production deployment: **NOT PERFORMED**

Next work: verify staging Auth settings and callback/redirect allowlists without changing them, inspect Edge Function parity and staging email behavior, then design isolated synthetic test identities and a non-delivering email sink before any signup/recovery tests.
