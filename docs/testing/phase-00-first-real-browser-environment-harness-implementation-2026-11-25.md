# Phase 00 — First real-browser environment harness implementation

**Date:** 2026-11-25  
**Branch:** `qa/phase-00-baseline-2026-11-25`  
**Latest harness commit:** `59ba16aef59fd19c15b19855e2baabd1b801ce49`  
**Scope:** Add a real Chromium smoke harness for the QA environment resolver. No site deployment and no Supabase project access.

## Delivered on QA branch

1. `scripts/browser-environment-smoke.html` — isolated fixture that loads the actual repository `config.js`, but stubs the Supabase SDK client factory. This prevents network requests and records only the selected URL/options.
2. `scripts/krim-browser-environment-smoke.mjs` — Playwright Chromium test that:
   - routes the exact `krim-staging.pages.dev` hostname to a local fixture server using Chromium host-resolver rules;
   - asserts the resolver selects Staging project ref `qrpcivhdxobiaofppbkl`;
   - asserts PKCE and persistent-session configuration are present;
   - asserts authentication remains enabled;
   - asserts explicit `?mode=review` is recognized;
   - asserts a stale pre-existing client is replaced;
   - routes an unknown hostname to the local fixture and verifies the resolver fails closed before client initialization.
3. `.github/workflows/krim-browser-environment-smoke.yml` — QA-only/PR CI workflow that installs Playwright + Chromium, starts a local static server, runs the browser test, and stops the server.

## Safety design

- The browser fixture is served locally by the CI runner.
- The Staging hostname is mapped locally inside Chromium; it does **not** connect to the real Staging website.
- Supabase SDK is a local stub; no Supabase HTTP request, login, token, user, database write, Storage object, or provider operation occurs.
- No credentials or secrets are required.
- Workflow runs on the QA branch, pull requests to main, or manual dispatch. It does not deploy a website or touch Supabase.
- No merge to main.

## Verification status

The files are committed on the QA branch. The GitHub combined-status lookup for the latest harness commit returned an empty status list at audit time. The available GitHub connector surface did not expose a push-triggered workflow run listing for this commit, and this environment cannot execute the repository's CI runner locally.

Therefore:
- Harness implementation: **COMMITTED**
- Real Chromium execution: **PENDING CI EVIDENCE**
- Staging website deployment/origin: **NOT VERIFIED**
- Real browser-to-Supabase project identity: **NOT TESTED** (the fixture intentionally uses a local stub)
- Authentication, workspace, RLS, Storage and provider journeys: **NOT TESTED**

Do not report this as a passing browser test until the GitHub Actions run is observed and its job steps are green.

## Next gates

1. Observe and inspect the new Chromium workflow run; repair any test or workflow failures.
2. Confirm the actual Staging hosting provider, origin ownership and deployment target.
3. Establish a dedicated QA-only frontend deployment workflow only after that provider/origin is confirmed. Deploy the QA branch to Staging only, never Production.
4. Add runtime project identity assertion against the real Staging origin, without exposing keys or tokens.
5. Establish synthetic identities and provider test sink before authenticated workflow tests.
