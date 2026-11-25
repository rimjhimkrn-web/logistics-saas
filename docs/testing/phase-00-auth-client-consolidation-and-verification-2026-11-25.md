# Phase 00 — Authentication Client Consolidation and Verification
Date: 2026-11-25
Branch: `qa/phase-00-baseline-2026-11-25`
Scope: QA branch only. No production deployment and no Supabase database changes.

## Objective
Remove independent/hard-coded Supabase project selection from the remaining authentication and account-security browser modules. All migrated modules must consume the hostname-verified client initialized by `config.js`.

## Changes made
- Replaced the fallback-capable `platform/krim-supabase.js` with a strict shared-client accessor. It now requires `KRIM_SUPABASE_CONFIG`, `KRIM_SUPABASE`, and a matching `KRIM_SUPABASE_PROJECT_REF`; it validates the configured project reference and URL and has no production fallback.
- Reworked root `auth-core.js` to import and re-export the shared client rather than instantiate its own production client.
- Reworked `auth/krim-account-actions.js` to import the shared client. Removed its hard-coded production URL and publishable key.
- Updated six account-security pages to load the Supabase browser SDK and `../config.js` before the module: account deactivation, account deletion, recovery status, active sessions, change email, and change password.
- Updated global sign-out and restricted-account pages to load the verified environment client before importing auth-core. Corrected the restricted-account page's auth-core module path to the root module.
- Updated owner-testing password recovery, password reset, and MFA pages to use `window.KRIM_SUPABASE` from the verified shared configuration. Each explicitly refuses to operate unless the environment is `preview` and the selected project reference is the staging project.
- Added static regression guards to `scripts/krim-production-smoke.mjs` for migrated auth modules, consumer page bootstrapping, owner-testing staging-only guards, and removal of embedded project URLs/publishable keys.
- Added Node syntax checks for the three shared authentication JavaScript modules to the existing GitHub Actions workflow.
- Enabled the smoke workflow to run on pushes to this QA branch.

## Verification evidence
Final verified commit: `cecedbd9db6462f08faece05944003fad91fbd14`

GitHub Actions run:
- Run ID: `45556650142`
- Conclusion: **success**
- Successful steps: critical KRIM workflow smoke checks; shared authentication module syntax checks; fail-closed environment isolation checks; repository-wide static audit; audit artifact upload.
- Run URL: https://github.com/rimjhimkrn-web/logistics-saas/actions/runs/45556650142

A prior run at commit `80ac83e3b94e870e1db72590eec7fff1812c63dd` failed because the newly added static URL guard contained an invalid regular-expression literal. That guard was replaced with explicit string checks. The next run passed, and the final run above also passed after the MFA staging guard was made user-visible and safe.

## What this proves
- The migrated source modules no longer embed a production or staging Supabase URL or publishable key.
- The migrated HTML consumers load the shared environment configuration before their authentication module.
- The owner-testing recovery/reset/MFA pages contain staging-only environment/project checks.
- The shared JavaScript modules pass Node syntax checks.
- The existing repository smoke suite and static audit pass on the QA branch at the final commit.

## What this does not prove
- It does not prove that a browser can sign in to staging, complete MFA, recover a password, or perform each account action successfully.
- It does not prove the staging hostname is protected or that all nine workspaces have authenticated access.
- `KRIM_AUTH_DISABLED` is still set for preview in `config.js`; its consumers and intended distinction between a public preview/review mode and an authenticated staging environment remain to be mapped and resolved before normal authenticated E2E testing.
- The owner-testing routes and account actions have not been exercised with synthetic users. No reset emails, MFA enrollments, password changes, account requests, or other live auth operations were triggered.
- No production files, production database objects, secrets, payment systems, or customer/partner records were modified.

## Readiness decision
- Shared auth client consolidation: **PASS (source + CI evidence)**
- Auth module syntax: **PASS**
- Static environment isolation guards: **PASS**
- Runtime browser authentication: **NOT TESTED**
- Protected authenticated staging: **BLOCKED**
- Synthetic-user E2E: **NOT STARTED**
- Production deployment: **NOT PERFORMED**

Next required work: resolve the preview/auth-disabled mode safely, prove the staging host and Supabase project isolation in a browser, then begin controlled synthetic-user authentication tests.
