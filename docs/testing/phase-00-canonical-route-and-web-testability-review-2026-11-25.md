# KRIM Phase 00 — Canonical Route and Web Testability Review

**Date:** 2026-11-25  
**Branch:** `qa/phase-00-baseline-2026-11-25`  
**Scope:** Web platform source/configuration only. Native apps are explicitly out of scope for this test campaign.

## 1. Canonical route registry verification

Fetched `config.js` from the QA branch and parsed its `window.KRIM_ROUTES` registry. Cross-checked every destination against the complete Git tree (2,396 entries; GitHub reported `truncated=false`).

- Canonical registry entries: **27** (corrected from the earlier report's 26-entry count).
- Missing canonical route targets: **0**.
- All 27 destinations exist in the repository tree.

The 27 entries include 12 top-level/workspace/auth destinations and workflow destinations for customer booking/quotes/shipments/tracking, partner onboarding/marketplace, driver assignments, warehouse receiving/inventory, customs, finance, operations, enterprise and support. Several registry keys intentionally resolve to the same workspace index (e.g. customs queue and customs home); existence is not proof that each workflow is separately implemented.

## 2. Sitemap reconciliation

Fetched `sitemap.xml` from the same branch.

- Sitemap URLs: **36**.
- Canonical route registry entries: **27**.
- The sitemap covers public marketing/legal pages; it is not a complete inventory of authenticated workspace routes.
- Sitemap membership does not establish that a page is functionally complete or publicly accessible in a deployed environment.

## 3. Environment routing — critical testability blocker

Reviewed the actual `config.js` environment detection and client initialization.

Observed behavior:
- `krim-staging.pages.dev` and its subdomains are classified as `preview`.
- Preview/development hosts select the staging Supabase project.
- Preview hosts set `window.KRIM_AUTH_DISABLED = true`.
- The GitHub Pages host `rimjhimkrn-web.github.io` falls through to `production` and therefore selects the production Supabase project.

This means the current staging Pages hostname is not a valid authenticated end-to-end acceptance environment while the auth-disabled flag is enabled. It is suitable only for the limited preview behavior intentionally designed around that flag. The GitHub Pages production host must not be used for synthetic mutation testing because it selects production.

**Required gate:** establish a protected, authenticated staging web host/environment that uses the staging project, keeps authentication enabled, and has isolated provider adapters/mocks. Do not simply flip the flag without reviewing every consumer of `KRIM_AUTH_DISABLED` and ensuring no staging route can select production.

## 4. Existing CI workflow review

Reviewed:
- `.github/workflows/krim-production-smoke.yml`
- `.github/workflows/krim-static-link-audit.yml`
- `scripts/krim-production-smoke.mjs`
- `scripts/audit-krim-links.mjs`

Current checks include:
- Required-file existence checks.
- Static environment-routing regression checks for localhost, staging Pages, and GitHub Pages.
- Static Razorpay source guards.
- Retired Cashfree endpoint fail-closed source checks.
- Literal local HTML link/asset audit.
- Canonical route target existence checks.
- Static operational-risk and duplicate/placeholder signals through the complete static audit.

These checks are valuable regression controls, but they do **not** run a real browser, sign in as synthetic personas, submit forms, assert database mutations, verify RLS isolation, exercise notification delivery, or capture user-journey recordings. The workflow names contain “production smoke”, but its inspected steps are source/static checks, not full live production transaction tests.

The static-link workflow currently uses `|| true` for the first link-audit invocation, then separately enforces the broken-reference count. This is intentional in the current workflow to preserve artifact/summary generation; final enforcement still fails if broken local references are present.

## 5. Page source spot-checks

Inspected customer workspace, customer booking source and partner onboarding source.

The customer workspace loads the shared Supabase client configuration. Booking and partner onboarding pages also load the shared configuration and contain substantial form/UI code. This is only a source-level connection signal; complete submit handlers, authorization paths, backend writes, notifications and error states have not yet been mapped or executed.

## 6. Findings and disposition

| ID | Finding | Priority | Status |
|---|---|---|---|
| P00-WEB-01 | All 27 canonical route destinations exist in repository tree | Informational | PASS — existence only |
| P00-WEB-02 | Sitemap contains 36 public URLs and is not a complete workspace route map | Medium | Documented |
| P00-ENV-01 | Staging preview sets `KRIM_AUTH_DISABLED=true` | Critical blocker for authenticated E2E | BLOCKED |
| P00-ENV-02 | GitHub Pages selects production Supabase project | Critical safety constraint | Documented; do not use for mutation tests |
| P00-CI-01 | Current smoke workflow is static/source validation, not browser E2E | High | Documented |
| P00-CI-02 | No synthetic persona/browser test suite has been verified | High | NOT TESTED |
| P00-CI-03 | Route target existence does not prove distinct workflow implementation | High | NOT TESTED |

## 7. Next technical gate

Before synthetic user creation or browser mutation testing:
1. Audit every source reference to `KRIM_AUTH_DISABLED`.
2. Define a protected authenticated staging hostname and verify host-to-project routing.
3. Verify staging-only auth users and data isolation.
4. Add browser E2E runner and synthetic persona fixture strategy.
5. Mock or sandbox all payment, email, Telegram, SMS and external carrier/provider side effects.
6. Only then run read/write workflow tests against staging.

## 8. Safety record

This review used GitHub read operations only. No files, deployments, environment settings, auth settings, database objects, users, rows, secrets or provider integrations were changed. No emails, messages, payments, webhooks or load tests were triggered.

**Release position:** Not approved for unrestricted real-user onboarding. Canonical file existence passes; authenticated web E2E remains blocked pending a safe staging environment.
