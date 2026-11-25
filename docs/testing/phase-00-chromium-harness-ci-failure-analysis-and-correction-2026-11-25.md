# Phase 00 — Chromium harness CI failure analysis and correction

**Date:** 2026-11-25  
**Branch:** `qa/phase-00-baseline-2026-11-25`  
**Initial run:** [45572086588](https://github.com/rimjhimkrn-web/logistics-saas/actions/runs/45572086588)  
**Corrective commit:** `ac2330dbc771ae0c97ee7c03a7cb26e9a3adb5f9`  
**Follow-up run:** [45572201026](https://github.com/rimjhimkrn-web/logistics-saas/actions/runs/45572201026)

## Observed failure

The first real Chromium workflow reached and completed:
- Checkout
- Node.js setup
- Playwright installation
- Chromium installation
- Local fixture server startup

The browser test then failed at its first navigation with:

`page.goto: net::ERR_SSL_PROTOCOL_ERROR`

The URL was HTTP to `krim-staging.pages.dev:4173`, but the GitHub Actions runner's configured proxy was interfering with the custom-hostname-to-localhost browser test. This was a harness networking setup failure, not a failure of the KRIM environment resolver assertion. No live Staging or Supabase endpoint was contacted by design.

## Correction applied

Updated Chromium launch arguments to include `--no-proxy-server` while retaining explicit host-resolver rules that map both the Staging hostname and an unknown test hostname to the local fixture server.

This ensures Chromium connects directly to the local static server for the fixture rather than sending that local test hostname through the runner proxy.

The test remains isolated:
- No external Staging website connection.
- No Supabase SDK network request (fixture SDK stub only).
- No login, tokens, users, database writes, Storage writes or provider calls.

## Follow-up CI status at report time

The corrective push triggered workflow run **45572201026**. Checkout, Node.js and Playwright installation completed successfully. Chromium installation was still in progress when this report was written; the local-server and browser assertion steps had not yet completed.

Therefore the correction is **implemented but not yet proven passing**. Do not mark the harness green until the follow-up run concludes successfully and the browser test step is confirmed green.

## Separate production smoke workflow

The standard `KRIM production smoke checks` workflow on commit `b2474a7079ee7e25ea2a02548eb8c8d7cb65331e` completed successfully. This is a separate static/source smoke workflow and does not override the failed Chromium run.

## Next gate

1. Confirm follow-up run 45572201026 completes.
2. If it fails, inspect the exact browser step logs and correct only the harness.
3. After a green result, expand browser coverage to actual public routes using local fixtures and network interception before attempting any real Staging origin.
4. Keep actual Staging deployment and authenticated workflows blocked until hosting origin, deployment ownership, project identity and synthetic-test isolation are proven.

No Production or Staging configuration was changed. No deployments were triggered.
