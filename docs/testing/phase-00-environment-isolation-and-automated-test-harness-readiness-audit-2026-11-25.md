# Phase 00 — Environment isolation and automated test-harness readiness audit

**Date:** 2026-11-25  
**Branch:** `qa/phase-00-baseline-2026-11-25`  
**Scope:** QA-branch source/workflow inspection, prior live Supabase catalog evidence, and available CI status lookup. No deployment, workflow dispatch, browser session, or database write.

## Executive result

The QA branch contains useful fail-closed environment logic and deterministic Node-based regression tests. However, Phase 00 is **not ready for signed-in Staging end-to-end testing**.

The most important blockers are:

1. The allowlisted Staging hostname `krim-staging.pages.dev` has no matching Cloudflare Pages deployment workflow in the inspected repository. The only website deployment workflow is GitHub Pages from `main`. The Staging origin could not be fetched with the available public-page retrieval route during this audit, so its actual availability and deployed commit remain **unverified**, not conclusively offline.
2. Existing environment isolation tests execute `config.js` in Node's VM with a mocked `window` and mocked `supabase.createClient`. They test resolver logic but do not test a real browser, actual DNS/HTTPS, deployed JavaScript, network calls, Supabase project identity at runtime, authentication, redirects, cookies, Storage, or RLS.
3. The CI workflow named `KRIM production smoke checks` runs static/source smoke checks, syntax checks, environment VM tests and a repository static audit. It does not install or run Playwright, Cypress, Webdriver, or another real browser automation framework.
4. The latest QA audit-report commit `2ce9908a90800f91c1e75f9f12c12f6edca0a810` has no combined commit status checks returned by the GitHub status endpoint. This means there is no CI result attached to this exact report commit in the queried status surface; it does not negate the earlier documented successful run on a different commit.
5. An older owner-testing boundary document says no Storage buckets are configured in Staging. The current live catalog comparison recorded in the preceding audit shows `krim-partner-verification` present in Staging, while the reviewed driver-verification, driver-evidence and warehouse-evidence buckets are absent. The older document is stale or describes a different point in time and must not be used as the current Storage inventory.

## Evidence reviewed

### Environment resolver

QA `config.js`:
- Allowlisted `rimjhimkrn-web.github.io` to Production project `ebltviniygljwwseplph`.
- Allowlisted `krim-staging.pages.dev` and its subdomains to Staging project `qrpcivhdxobiaofppbkl`.
- Maps localhost/127.0.0.1/::1 to Staging.
- Clears pre-existing global Supabase client references before resolving environment.
- Throws on unknown hosts before client initialization.
- Creates a fresh Supabase client with PKCE and persistent session configuration.
- Keeps Staging authentication enabled; `?mode=review` selects a read-only review UI mode.

This is a positive source-level design. It is not proof that the deployed Staging origin serves this exact file or that every page imports it before creating its own client.

### Deployment workflows

`.github/workflows/deploy-krim-pages.yml`:
- Triggers on pushes to `main` and manual dispatch.
- Builds and deploys to GitHub Pages.
- Does not deploy the QA branch.
- Does not deploy to Cloudflare Pages or `krim-staging.pages.dev`.

The separate `krim-staging-schema-bootstrap.yml` is a database schema bootstrap workflow, not a website deployment workflow. It can apply a schema-only dump to an empty Staging database under a tightly gated workflow trigger; it must not be mistaken for frontend Staging deployment.

### Current regression harness

`scripts/krim-environment-isolation.test.mjs`:
- Tests five allowlisted host mappings.
- Tests three blocked hostnames.
- Tests explicit review-mode selector behavior.
- Checks selected static pages and privileged bootstrap ordering.
- Uses Node `vm.runInNewContext` and a mocked Supabase client factory.
- Does not open a browser or make a network request.

`scripts/krim-production-smoke.mjs`:
- Checks a large required-file list.
- Runs additional static environment assertions and source guards.
- Does not execute a real browser journey.
- Does not test signed-in workspace navigation, browser storage, auth callback exchange, RLS, signed URLs or provider delivery.

`.github/workflows/krim-production-smoke.yml`:
- Runs on pushes to `main` and the QA branch, and on pull requests to main.
- Runs Node 22 smoke script, syntax checks, environment VM tests and static repository audit.
- Uploads a static audit artifact.
- Does not configure a browser runtime or invoke Playwright/Cypress.

### CI status

The GitHub combined-status lookup for commit `2ce9908a90800f91c1e75f9f12c12f6edca0a810` returned an empty status list. The prior deployment-gate report records a successful Actions run `45559294832` on an earlier report commit. That earlier success is useful evidence for the older commit only; it is not a fresh check result for the latest QA head.

### Staging owner-testing document reconciliation

`KRIM-STAGING-OWNER-TESTING.md` says the Staging database was schema-only, client privileges revoked, owner activation pending, and no Storage buckets or objects configured. The live Storage catalog query in the preceding audit shows one reviewed bucket, `krim-partner-verification`, present in Staging. Therefore the owner-testing document's Storage statement is stale relative to the current live catalog snapshot. Update the document only after an owner-approved documentation correction; do not infer any bucket/object contents from the discrepancy.

## Test-harness readiness decision

| Layer | Current evidence | Status |
|---|---|---|
| QA environment resolver logic | Node VM tests and source inspection | PASS — static/unit scope only |
| Production vs Staging project mapping in QA config | Fixed project refs in source | PASS — static scope only |
| Real Staging website deployment | No matching deploy workflow; origin fetch unavailable | NOT VERIFIED |
| Exact deployed QA commit | No deployment evidence for Staging origin | NOT VERIFIED |
| Real browser execution | No Playwright/Cypress/browser job | NOT IMPLEMENTED |
| Real Supabase client project identity in browser | No browser network/runtime trace | NOT TESTED |
| Auth login/callback/MFA/redirect journey | Source audits only | NOT TESTED |
| Nine-workspace navigation and authorization | Static route/RPC audits only | NOT TESTED |
| Storage upload/read/deny tests | Catalog/source only; Staging bucket gaps remain | BLOCKED |
| Provider test sink | Not established | BLOCKED |
| Latest QA commit CI status | Combined status empty | NOT VERIFIED |

## Required next engineering sequence

1. Confirm the intended Staging hosting provider and canonical origin. Do not use an allowlisted placeholder hostname as proof of a deployed site.
2. Add or document a dedicated Staging frontend deployment workflow only after confirming hosting ownership, branch source and environment secrets. It must deploy QA to Staging only and never Production.
3. Add a browser automation harness (Playwright or equivalent) with a deterministic static smoke suite first. Use test-only credentials and never place secrets in repository files or browser artifacts.
4. Add a runtime environment assertion that records hostname, resolved project ref, and a harmless authenticated-independent Supabase endpoint identity check without exposing keys or tokens.
5. Establish a dedicated synthetic test identity set and test sink before any signed-in write workflow. Keep provider functions disabled or redirected.
6. Fix the previously reported Staging Storage policy and bucket parity blockers before evidence upload tests.
7. Run browser smoke checks against the deployed Staging origin and attach exact commit SHA, workflow run, browser version, route results and redacted network outcomes.
8. Only after the browser harness is stable, proceed to authenticated nine-workspace synthetic journeys.

## Safety boundary

No deployment workflow was dispatched. No branch or workflow configuration was changed. No real browser login was attempted. No Auth users, Storage objects, provider events, database rows, policies, secrets, or environment settings were modified. No Production or Staging data writes occurred.
