# KRIM Phase 00 — Authentication Dependency Map and Environment Isolation Findings

**Date:** 2026-11-25  
**Branch:** `qa/phase-00-baseline-2026-11-25`  
**Method:** Read-only source inspection of the QA baseline branch. This is a dependency map, not a runtime test.

## Executive result

**Status: FAIL — environment isolation is not safe to use for authenticated synthetic-user tests yet.**

The previous checkpoint found a hard-coded production client in Platform Admin and a hard-coded staging client in the admin sign-in page. This follow-up mapped additional consumers and confirmed a second systemic defect: both shared environment detectors default unknown hosts to **production**. A staging preview flag is also set in shared config, but no global guarantee exists that every route uses the shared client.

No source files or environment settings were changed.

## 1. Environment detection: unknown host falls through to production

### `config.js`
- Explicit staging host `krim-staging.pages.dev` and its subdomains -> `preview`.
- Localhost -> `development`.
- Known preview patterns -> `preview`.
- Any other host -> `production`.
- Project URL selection maps production to production Supabase; all other supported environments to staging.
- `KRIM_AUTH_DISABLED` is set equal to `KRIM_STAGING_PREVIEW`.

### `platform/krim-config.js`
- Has a separate environment detector.
- Also returns `production` for an unrecognized hostname.
- This creates two independently maintained environment detectors.

**Finding P00-ENV-06 (FAIL):** unknown hostnames do not fail closed. They are classified as production. The two independent detectors can drift.

## 2. Confirmed direct-client and script dependency map

| Source module/page | Direct project selection | Confirmed consumers / behavior | Status |
|---|---|---|---|
| `config.js` | Host-selected shared client | Main shared `window.KRIM_SUPABASE` factory | Inspected; unknown host -> production |
| `app/platform-admin/index.html` | Hard-coded production | Privileged workspace; invokes `global-admin-control` | FAIL |
| `auth/krim-admin-access.html` | Hard-coded staging | Admin sign-in; invokes `owner-testing-authorize` | FAIL |
| `auth/owner-testing-forgot-password.html` | Hard-coded staging | Owner/admin password recovery | FAIL |
| `auth/owner-testing-reset-password.html` | Hard-coded staging | Owner/admin password reset | FAIL |
| `auth/owner-testing-mfa.html` | Hard-coded staging | Owner/admin MFA workflow | FAIL |
| `auth-core.js` | Hard-coded production | Imported by `auth/logout.html` and `auth/disabled.html` | FAIL |
| `auth/krim-account-actions.js` | Hard-coded production | Loaded by account deactivation, account deletion, account recovery status, active sessions, change email and change password pages | FAIL |
| `auth/krim-admin-guard.js` | Hard-coded production | Dynamically loaded by `public/admin/security-desk.html`, `public/app/shared/security-manager.html`, and `public/production/security-hardening.html` | FAIL |
| `platform/krim-config.js` | Separate detector; unknown host -> production | Loaded by the same three privileged/security pages above | FAIL |
| `platform/krim-auth.js` | Uses `window.KRIM_SUPABASE` | Shared auth helper, provided the shared factory ran first | Conditional |
| `auth/login.html` and most newer auth routes | Uses `window.KRIM_SUPABASE` | Shared login, MFA, password and membership flows | Shared-client dependent |

The table lists the confirmed consumers found during this focused dependency pass. It is not a claim that every legacy or noncanonical page has been mapped.

## 3. Staging bypass scope

The shared config sets `window.KRIM_AUTH_DISABLED = window.KRIM_STAGING_PREVIEW`. The partner sign-in page also contains a local staging-review mode that disables its credential fields on `krim-staging.pages.dev`.

However:
- The review behavior is implemented locally in the partner sign-in page.
- No proof has been established that every route consumes `KRIM_AUTH_DISABLED`.
- A disabled login form does not prevent other pages or scripts from making direct requests.
- It does not replace database RLS, server-side authorization, or host-level access protection.

**Finding P00-AUTH-02 (BLOCKED):** a visual review mode must not be treated as a protected authenticated test environment.

## 4. Additional legacy security boundary

The previously inspected `js/guards.js` and `js/session.js` rely on browser-stored `KrimSession` state for frontend route behavior. This is not an authoritative identity boundary. Runtime and dependency usage still need a separate complete pass. Server-side permission checks and RLS must deny unauthorized access even if localStorage is edited.

## 5. Required target architecture

1. One environment resolver, imported/loaded before any client initialization.
2. Explicit hostname allowlist for production and staging.
3. Unknown host -> stop initialization and display a safe environment error; never infer production.
4. One Supabase client factory; no page/module may embed a project URL or key.
5. A staging test runner that checks the actual project ref before every write and aborts on production.
6. Protected authenticated staging domain. Keep any visual preview mode separate and read-only.
7. Admin sign-in, password recovery, MFA and admin workspace must all use the same environment-selected client and server-side role/MFA checks.
8. Static CI rule rejecting hard-coded Supabase project URLs/keys outside the single approved environment configuration module.
9. Browser negative tests for unknown hosts, cross-environment routes, unauthenticated access, non-admin access, role spoofing and localStorage tampering.

## 6. Remediation sequencing

**Do not perform a broad find-and-replace.** The hard-coded clients are in privileged flows and account-security actions. Consolidation must be done on the QA branch, one dependency family at a time, with tests for redirects, session persistence, MFA, recovery callbacks and server-side authorization.

Recommended order:
1. Build and unit-test a single fail-closed environment/client factory.
2. Migrate Platform Admin and owner/admin authentication routes as one controlled family.
3. Migrate security-desk modules and legacy auth imports.
4. Migrate account-security actions.
5. Add CI static guards and route-level runtime environment assertions.
6. Only then create synthetic accounts in staging and begin browser E2E.

## 7. Evidence ledger

| Check | Result |
|---|---|
| Shared `config.js` host logic inspected | CONFIRMED |
| Separate platform config host logic inspected | CONFIRMED |
| Unknown-host production fallback | CONFIRMED in both detectors |
| Platform Admin direct production client | CONFIRMED |
| Admin entry / owner testing direct staging clients | CONFIRMED |
| Auth-core production client consumers | CONFIRMED: 2 pages |
| Account-action production client consumers | CONFIRMED: 6 pages |
| Admin guard production client consumers | CONFIRMED: 3 pages |
| All 1,017+ HTML/source pages exhaustively mapped | NOT COMPLETE |
| All `KRIM_AUTH_DISABLED` consumers exhaustively mapped | NOT COMPLETE |
| Browser runtime environment tests | NOT TESTED |
| Protected staging hostname access control | NOT VERIFIED |
| Staging database write isolation tests | NOT TESTED |

## 8. Safety record

Only GitHub source reads and QA documentation writes were performed. No application code, Supabase schema, data, policies, functions, secrets, project settings, authentication users, deployments or live services were changed. No payment, email, Telegram, SMS, webhook or other provider side effects were triggered.

**Release gate:** NO synthetic-user or write-capable E2E testing until the environment factory is consolidated, unknown hosts fail closed, and the test runner proves the target Supabase project is staging.
