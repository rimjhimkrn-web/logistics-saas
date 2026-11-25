# KRIM Phase 00 — Environment Foundation Implementation & Verification

**Date:** 2026-11-25  
**Branch:** `qa/phase-00-baseline-2026-11-25`  
**Scope:** First controlled remediation slice for environment resolution and selected privileged routes. No deployment.

## Executive result

**Environment resolver slice: PASS in isolated source-level tests.**  
**Overall authenticated staging readiness: BLOCKED.**

The shared environment resolver now uses an explicit hostname allowlist and fails closed for unknown hosts. It clears pre-existing global Supabase client references before host resolution, selects an environment-specific project mapping, and initializes a new client from that mapping. Selected privileged routes now consume the shared client rather than embedding their own project URLs.

This is a QA-branch-only implementation. It has not been deployed to production or staging.

## 1. Changes committed

| File | Change |
|---|---|
| `config.js` | Explicit hostname allowlist; unknown hosts throw before client initialization; stale global clients cleared; selected project ref exposed; shared client created from verified environment mapping |
| `platform/krim-config.js` | Removed its independent hostname detector and hard-coded production Supabase configuration; now requires shared environment config |
| `app/platform-admin/index.html` | Uses shared client and refuses to initialize unless selected project ref is production |
| `auth/krim-admin-guard.js` | Uses shared client; removed hard-coded production project URL/key |
| `auth/krim-admin-access.html` | Uses shared client and refuses owner-testing authorization outside preview/staging |
| `public/admin/security-desk.html` | Loads Supabase SDK and shared config before admin guard |
| `public/app/shared/security-manager.html` | Loads Supabase SDK and shared config before admin guard |
| `public/production/security-hardening.html` | Loads Supabase SDK and shared config before admin guard |
| `scripts/krim-environment-isolation.test.mjs` | Added isolated environment and route bootstrap regression suite |
| `scripts/krim-production-smoke.mjs` | Added host routing, unknown-host, stale-client and static project URL guards |
| `.github/workflows/krim-production-smoke.yml` | Added environment isolation test step to existing workflow |

## 2. Current hostname policy

| Host | Selected environment | Supabase target |
|---|---|---|
| `rimjhimkrn-web.github.io` | production | production project |
| `krim-staging.pages.dev` and its subdomains | preview | staging project |
| `localhost`, `127.0.0.1`, `::1` | development | staging project |
| Any other hostname | BLOCKED | no client initialized |

The resolver ignores page-level environment overrides and meta tags. Unknown hosts cannot force production by setting `KRIM_ENVIRONMENT=production`.

The currently verified public production host is GitHub Pages. No custom production hostname has been added to the allowlist.

## 3. Verification performed

The dedicated test script was executed against the current branch source fixtures in an isolated JavaScript VM harness.

| Test | Result |
|---|---|
| Staging root hostname -> staging project | PASS |
| Staging subdomain -> staging project | PASS |
| Localhost -> staging project | PASS |
| Local IPv4 -> staging project | PASS |
| GitHub Pages -> production project | PASS |
| Unknown hostname -> blocked | PASS |
| Random Pages hostname -> blocked | PASS |
| Unconfigured custom hostname -> blocked | PASS |
| Unknown host cannot create Supabase client | PASS |
| Pre-existing legacy client is cleared/replaced | PASS |
| Platform Admin uses shared client | PASS |
| Admin guard uses shared client | PASS |
| Owner-testing access is staging-only | PASS |
| Three privileged security pages load SDK/config before guard | PASS |
| JavaScript syntax checks for config, platform config, admin guard and test scripts | PASS |

Executed test output:
`KRIM environment isolation tests passed: 5 allowed hosts, 3 blocked hosts, 4 static guards, 3 privileged bootstraps.`

**Not yet verified:** GitHub Actions workflow execution. The dedicated script was run in an isolated fixture harness; the actual GitHub-hosted workflow has not run against this QA branch.

## 4. Remaining blockers — do not start synthetic-user E2E yet

This patch intentionally does not claim the entire repository is migrated. Confirmed direct-client consumers still requiring migration and verification include:

- `auth-core.js` — imported by logout and disabled-account pages.
- `auth/krim-account-actions.js` — loaded by six account-security pages.
- `auth/owner-testing-forgot-password.html` — hard-coded staging client.
- `auth/owner-testing-reset-password.html` — hard-coded staging client.
- `auth/owner-testing-mfa.html` — hard-coded staging client.

The partner sign-in review mode still disables the sign-in UI on the staging hostname. The shared `KRIM_AUTH_DISABLED` flag also remains enabled for preview. That behavior is not an authenticated E2E environment and needs a separate, controlled change.

A complete repository-wide direct-client scan and migration is still required. The current static checks cover the privileged files changed in this slice, not every route in the platform.

## 5. Safety and release record

- All changes are on `qa/phase-00-baseline-2026-11-25`.
- No commit was made to `main`.
- No production or staging deployment was triggered.
- No Supabase project settings, secrets, schema, rows, RLS policies, functions or users were changed.
- No synthetic users were created.
- No real payment, email, Telegram, SMS, webhook or other provider operation was triggered.

**Gate:** This is a successful first remediation slice, not approval to onboard users. Continue by migrating the remaining authentication/account modules to the shared client, then run the actual GitHub Actions workflow and browser-level host/project identity checks before creating synthetic users.
