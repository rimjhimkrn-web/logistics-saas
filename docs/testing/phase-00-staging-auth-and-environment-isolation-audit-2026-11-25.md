# KRIM Phase 00 — Staging Authentication and Environment Isolation Audit

**Date:** 2026-11-25  
**Branch:** `qa/phase-00-baseline-2026-11-25`  
**Scope:** Read-only review of environment selection, authentication entrypoints, privileged workspace bootstrap and selected route consumers. Web only; mobile apps excluded.

## 1. Executive result

**Status: BLOCKED — authenticated staging is not yet proven safe.**

The shared `config.js` has an environment-aware project selector, but selected high-impact pages and legacy auth modules create Supabase clients with hard-coded project URLs. This bypasses the shared selector.

Consequently, host-based routing alone is not sufficient to guarantee staging/production isolation. The actual client created by each page must be inventoried and tested.

No code/configuration was changed.

## 2. Verified shared configuration behavior

From `config.js`:
- `krim-staging.pages.dev` and its subdomains are classified as `preview`.
- `development` and `preview` select the staging project.
- `production` selects the production project.
- `window.KRIM_AUTH_DISABLED` is set equal to `window.KRIM_STAGING_PREVIEW`.

This is an explicit staging preview bypass flag, not a safe authenticated E2E setting. It should not be disabled or reinterpreted until every consumer and all routes are mapped.

## 3. High-impact hard-coded project clients found

### P00-ENV-03 — Platform Admin workspace hard-codes production
File: `app/platform-admin/index.html`

The page loads shared `config.js`, then creates a second Supabase client using literal production project URL and publishable key:
`https://ebltviniygljwwseplph.supabase.co`

The page invokes `global-admin-control` through this locally created client. This bypasses the environment-aware shared client on this route.

**Risk:** opening the platform-admin page on a staging hostname may still direct privileged operations to production. This is a release-blocking environment-isolation defect until corrected and tested.

### P00-ENV-04 — Admin access page hard-codes staging
File: `auth/krim-admin-access.html`

This page creates a client using literal staging project URL and staging publishable key, then invokes `owner-testing-authorize`.

**Risk:** the privileged sign-in route may target staging even when opened from a production hostname. The access route and the destination workspace must use the same explicitly selected environment. The function's authorization and redirect behavior require separate review.

### P00-ENV-05 — Legacy auth modules hard-code production
Files:
- `auth-core.js`
- `auth/krim-admin-guard.js`
- `platform/krim-config.js`

These files contain literal production Supabase URL/key values. The legacy admin guard creates a direct production client and invokes `global-admin-control`. `platform/krim-config.js` also defines a fixed production Supabase configuration.

Their use across the active route graph has not yet been exhaustively established. Treat them as high-priority candidate environment bypasses until all import/script references are mapped. Do not assume they are dead code.

## 4. Authentication and route guard observations

### Current shared login
`auth/login.html` loads `config.js`, signs in with Supabase Auth, resolves active organization membership, maps roles, checks MFA and redirects to canonical workspace routes. This is a promising primary flow, but runtime behavior has not been tested.

### Partner staging review mode
`auth/partner-signin.html` contains a page-specific review mode for `krim-staging.pages.dev` and for query parameter `mode=review`. In this mode the sign-in inputs are disabled and the page explicitly states that authentication is disabled.

This is a UI review mode; it is not proof that every other staging route is protected or that the backend is unreachable.

### Legacy browser guard
`js/guards.js` uses a localStorage session object (`KrimSession`) and checks a locally stored role for route navigation. `js/session.js` shows this object is browser storage, not a Supabase-authenticated session. The guard's own comments say frontend is not the security boundary elsewhere in the platform config, but the legacy guard should not be treated as authoritative access control. Backend RLS and server-side authorization must remain decisive.

## 5. Required remediation before authenticated E2E

1. **Single client factory:** all web pages and modules must obtain their Supabase client from one environment-aware factory. Remove per-page hard-coded project clients after reviewing each route's dependencies.
2. **Host allowlist:** production project selection must require an explicit production hostname allowlist; unknown hosts should fail closed rather than default to production.
3. **Staging-only mutation guard:** staging test harness must verify the Supabase project ref before every write-capable test and abort if the ref is production.
4. **Protected staging host:** use a stable, access-controlled staging hostname with authentication enabled. Keep a separate no-auth visual review mode only if explicitly isolated and read-only.
5. **Privileged route isolation:** admin sign-in and admin workspace must resolve to the same environment and must enforce server-side AAL2 + platform role.
6. **Legacy module dependency map:** locate every script/import consumer of `auth-core.js`, `auth/krim-admin-guard.js`, `platform/krim-config.js`, `js/guards.js` and `js/session.js`; retire or migrate any active legacy route.
7. **Negative tests:** production host -> production client; protected staging host -> staging client; unknown host -> fail closed; staging admin -> staging only; unauthenticated and non-admin users -> denied; no frontend role/localStorage value may grant access.

## 6. Evidence status

| Check | Status |
|---|---|
| Shared config host classification | Source inspected |
| Shared config preview auth flag | Source inspected |
| Platform Admin hard-coded production client | CONFIRMED |
| Admin access hard-coded staging client | CONFIRMED |
| Legacy production clients | CONFIRMED in source; route usage incomplete |
| Full consumer/import map | NOT COMPLETE |
| Staging host access control | NOT VERIFIED |
| Runtime host-to-project tests | NOT TESTED |
| Admin MFA/role negative tests | NOT TESTED |
| Browser E2E | NOT TESTED |

## 7. Safety record

Only GitHub source reads were performed. No code, environment variables, Supabase settings, credentials, schema, users, rows, grants, functions or deployments were changed. No payment, email, SMS, Telegram, webhook or other provider side effect was triggered.

**Release position:** Do not create synthetic users or run write-capable browser tests until environment routing is consolidated and a staging project identity check is enforced.
