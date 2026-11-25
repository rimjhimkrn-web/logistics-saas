# Phase 00 — Chromium harness TLS/HSTS correction and CI rerun

**Date:** 2026-11-25  
**Branch:** `qa/phase-00-baseline-2026-11-25`  
**Latest implementation commit:** `aff98778e929d5db82e0345537105b04ffc435e8`  
**Latest CI run:** [45572353370](https://github.com/rimjhimkrn-web/logistics-saas/actions/runs/45572353370)

## Updated failure diagnosis

Two real Chromium attempts were inspected:

- Run `45572086588`: failed at the first navigation with `ERR_SSL_PROTOCOL_ERROR`.
- Run `45572201026`: failed with the same error after adding `--no-proxy-server`.

The second failure demonstrates that disabling the runner proxy alone did not solve the issue. The likely cause is HSTS behavior for the `pages.dev` hostname: Chromium upgrades the local HTTP fixture URL to HTTPS, while the fixture server was plain HTTP. This is a browser-origin transport behavior, not a Supabase or application resolver failure.

## Correction now committed

- Added `scripts/serve-https-fixture.py`, a minimal local TLS fixture server.
- Updated the CI workflow to generate a short-lived self-signed certificate for the two local fixture hostnames and serve the fixture over HTTPS.
- Updated Playwright navigation to HTTPS.
- Added Chromium `--ignore-certificate-errors` for this test-only self-signed local certificate.
- Retained host-resolver rules and `--no-proxy-server`, so both names still resolve to the local fixture only.

The fixture remains isolated and does not connect to the real Staging host, Supabase, or any provider.

## Current verification status

The latest workflow run `45572353370` was created for commit `aff98778e929d5db82e0345537105b04ffc435e8`. At report time, Playwright installation was in progress; HTTPS fixture startup and browser assertions had not run yet.

**Result: PENDING.** Do not claim a passing Chromium test until the run completes successfully and the browser assertion step is green.

## Safety and scope

No deployment was triggered. No Production or Staging settings, Auth users, database rows, Storage objects, secrets, payment, notification or provider operations were changed.
