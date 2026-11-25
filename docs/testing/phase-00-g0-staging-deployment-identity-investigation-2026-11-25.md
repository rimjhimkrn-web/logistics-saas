# Phase 00 — G0 Staging deployment identity investigation (follow-up)

**Date:** 2026-11-25  
**Branch:** `qa/phase-00-baseline-2026-11-25`  
**Gate:** G0 — prove canonical Staging origin, deployed commit and Supabase project identity together.

## Result

**G0 remains BLOCKED — hosting deployment provenance is not accessible from the connected repository evidence.**

This pass confirms the following:

1. The repository's only website deployment workflow inspected is `.github/workflows/deploy-krim-pages.yml`. It triggers on `main` and deploys using GitHub Pages actions. It does not deploy the QA branch or configure Cloudflare Pages.
2. `.github/workflows/krim-staging-schema-bootstrap.yml` is a database schema bootstrap workflow, not a website deployment workflow. It must not be mistaken for a website deploy.
3. QA `config.js` maps `krim-staging.pages.dev` to Staging project ref `qrpcivhdxobiaofppbkl`, but this is only source-level mapping. It does not prove what the public hostname is serving.
4. The connected tool inventory has no Cloudflare Pages/DNS deployment action. The web fetch attempt for `https://krim-staging.pages.dev/` returned an internal fetch error. This is inconclusive, not proof of outage.
5. The browser CI test intentionally maps the staging hostname to a local HTTPS fixture. Its successful result proves the hostname resolver logic in Chromium; it does not contact or identify the real Cloudflare Pages deployment.

## CI milestone confirmed

The latest QA commit at the time of this report, `ae1bbe86e1d0378c8e860d43d689a6961bf45b6a`, has both required repository workflows completed successfully:

- Repository smoke checks: run `45573084338` — SUCCESS.
- Chromium environment isolation: run `45573084316` — SUCCESS.

The Chromium test remains a local-fixture test, not live Staging verification.

## What evidence will close G0

The Staging owner must provide one read-only deployment record from Cloudflare:

- Workers & Pages → select the KRIM Staging Pages project → Deployments.
- Show the production deployment URL/project subdomain, branch, commit SHA and deployment status.
- Also show the project name and production branch in project settings if the deployment row does not expose them.

Cloudflare's own documentation says the Pages project dashboard exposes its production URL and associated commit, and its Deployments view shows individual deployments. See the official [Cloudflare Pages Git integration guide](https://developers.cloudflare.com/pages/configuration/git-integration/) and [preview deployments guide](https://developers.cloudflare.com/pages/configuration/preview-deployments/).

A URL copied from the browser address bar alone is insufficient to prove the deployed commit. A preview URL is not automatically the canonical Staging origin; it must be tied to the intended branch and project.

After receiving the deployment record, verify:
1. The hostname resolves and serves the root page and required auth callback route.
2. The served `config.js` matches the QA or approved Staging artifact expected for that deployment.
3. The browser-selected project ref is exactly `qrpcivhdxobiaofppbkl`.
4. No Production project URL/key or Production Auth callback is loaded by the Staging origin.

## Safety

No Cloudflare setting, DNS record, GitHub Pages setting, Supabase Auth URL, database, Storage policy, user, secret, or provider was changed. No website deployment was triggered. Do not create a new Pages project or add callback URLs until the current project owner and canonical origin are established.

**Decision:** G0 stays BLOCKED. Continue QA-only source remediation and browser-harness work, but do not begin authenticated live Staging testing until deployment provenance is proven.
