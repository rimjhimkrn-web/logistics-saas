# Phase 00 Gate A.1 — Deployment Pipeline and Environment Reachability Check
Date: 2026-11-25
Branch: qa/phase-00-baseline-2026-11-25

## Scope
Read-only verification of the production GitHub Pages deployment workflow, its latest main-branch run, recent QA checks, and the previously identified candidate Staging origin. No deployment was triggered by this audit.

## Evidence and results

### Production GitHub Pages pipeline — PASS (pipeline only)
- Main branch HEAD at inspection: 72d75a18f985ceb09e468839435ee95700e11e46.
- Workflow: .github/workflows/deploy-krim-pages.yml.
- Workflow triggers on push to main and manual dispatch.
- Build assembles repository content into _site, includes public/customer-os, verifies required logo/index/integration-manifest files, configures Pages, uploads the Pages artifact, then deploys.
- Latest main deployment run: 45554592755.
- Run commit: 72d75a18f985ceb09e468839435ee95700e11e46.
- Build job completed successfully; all listed steps passed.
- Deploy job completed successfully; Deploy to GitHub Pages passed.
- This proves the GitHub Actions pipeline reported a successful deployment for that commit. It does not independently prove every public route, asset, auth flow, or live HTTP security header works.

### QA branch static audit — PASS (source/static checks only)
- Run 45586120797 completed successfully.
- Validate critical KRIM workflows, shared authentication syntax, fail-closed environment isolation, repository-wide static audit, and audit artifact upload all passed.
- This is QA-branch validation, not production browser E2E.

### QA Chromium environment isolation — IN PROGRESS at inspection
- Run 45586120761.
- Playwright and Node setup passed; Chromium installation was still in progress.
- Fixture-server and browser checks had not started at inspection.
- Therefore no Chromium result is claimed.

### Staging deployment/reachability — BLOCKED
- Candidate origin remains https://krim-staging.pages.dev/.
- Direct inspection through the available web retrieval path did not yield a usable page response.
- No Cloudflare Pages project/deployment record, DNS/TLS/HTTP response, deployed commit SHA, or deployed runtime configuration was independently verified.
- This is not proof that the host is down; it means deployment and reachability remain unverified.
- QA source config mapping the candidate hostname to the Staging Supabase project is not deployment evidence.

### Repository governance note
- The inspected main branch API record reports branch protection disabled. This is a governance risk because production deployment is push-to-main. Do not enable/change branch protection without owner approval and review of existing release workflow.

## Outcome
- Production deployment pipeline: PASS (workflow run only).
- QA static audit: PASS (static/source-level scope only).
- QA Chromium test: IN PROGRESS at inspection; NOT TESTED to completion.
- Staging origin identity/reachability: BLOCKED.
- Live production route-by-route/browser/security-header verification: NOT TESTED.
- Phase 00 remains IN PROGRESS. Staging remains BLOCKED. KRIM is not release-ready for unrestricted real-user transactions.

## Safety
Read-only inspection only. No workflow dispatch, deployment, Supabase writes, provider calls, production data changes, or staging changes were performed.
