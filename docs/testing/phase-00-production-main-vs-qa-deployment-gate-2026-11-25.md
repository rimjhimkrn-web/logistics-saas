# Phase 00 — Production Main vs QA Branch Deployment Gate Review
Date: 2026-11-25
Repository: `rimjhimkrn-web/logistics-saas`
Production branch: `main`
QA branch: `qa/phase-00-baseline-2026-11-25`

## Executive result
**Release gate: BLOCKED — QA hardening is not yet present on the production branch.**
The current Production GitHub Pages workflow is configured to deploy from `main` only. The reviewed environment isolation and shared-auth changes are committed to the QA branch and have not been merged/deployed to Production. A direct comparison of `config.js` on the two branches confirms materially different behavior.

## Direct source comparison
### Production `main` version
The current main-branch `config.js`:
- Accepts page-level `window.KRIM_ENVIRONMENT` or a meta tag as an environment selector.
- Recognizes several broad preview-host patterns.
- Falls back to `production` for any hostname not otherwise classified.
- Reuses pre-existing `window.KRIM_SUPABASE` / `window.supabaseClient` if present, rather than always clearing and recreating a client from a verified host mapping.
- Sets `KRIM_AUTH_DISABLED` true for preview hosts.

### QA branch version
The QA `config.js`:
- Uses an explicit hostname allowlist.
- Blocks unknown hostnames before Supabase client initialization.
- Clears legacy global client references before environment resolution.
- Selects project URL/key from a fixed environment map.
- Creates a fresh shared client with PKCE configuration.
- Keeps staging authentication enabled and uses explicit `?mode=review` for read-only review mode.

## Deployment workflow evidence
The repository workflow `.github/workflows/deploy-krim-pages.yml`:
- Triggers on pushes to `main` and manual dispatch.
- Deploys via GitHub Pages.
- Does not deploy the QA branch.
- Does not deploy to Cloudflare Pages.

Therefore, QA source-level PASS results do not prove that the live Production site is running those changes. The live Production site is governed by the `main` deployment until a separately approved merge and deployment occurs.

## Risk interpretation
The main-branch resolver's production fallback and page/meta environment override are weaker than the QA branch's fail-closed host allowlist. This is a concrete source-level hardening gap in the current production branch, not proof that an unauthorized party has accessed or changed production data. Existing backend RLS and server-side authorization remain independent controls and still require runtime verification.

## Required release controls
1. Keep the QA branch as the audit/remediation workspace.
2. Do not merge or deploy this change automatically as part of Phase 00.
3. Before a future production release, review the complete QA-to-main diff, rerun all CI checks, and require explicit owner approval.
4. Deploy in a controlled window, then verify the actual production site's loaded config, project identity, sign-in, callback routes and critical smoke journeys.
5. Preserve a rollback point and verify no QA-only review or owner-testing route becomes reachable as an active Production workflow.

## Evidence status
| Check | Result |
|---|---|
| Main and QA `config.js` inspected | PASS |
| Main has explicit unknown-host fail-closed behavior | FAIL (source comparison) |
| QA has explicit unknown-host fail-closed behavior | PASS (source inspection) |
| Main ignores page/meta environment overrides | FAIL (source comparison) |
| QA ignores page/meta environment overrides | PASS (source inspection) |
| Production deployment workflow targets main only | PASS (workflow inspection) |
| QA hardening deployed to Production | NO — not merged/deployed |
| Production runtime behavior tested | NOT TESTED |
| Production or staging changed during this review | NO |

## Readiness decision
Do not certify Production environment isolation or overall Phase 00 readiness yet. The hardening implementation is in QA only; release and runtime verification are separate future gates. No merge, deployment, Supabase setting change, database mutation, user operation, or provider call was performed. NO EVIDENCE = NO PASS.


## QA workflow verification for this report commit
The workflow was run against the exact report commit `9673549fab305a07fb436eaf99baa14e5ea03c78`.
- GitHub Actions run: `45559294832`
- Conclusion: **success**
- Critical workflow smoke checks: PASS
- Shared authentication module syntax: PASS
- Fail-closed environment isolation tests: PASS
- Repository-wide static audit: PASS
- Audit artifact upload: PASS
- Artifact: `krim-complete-static-audit` (31,350 bytes; retained through 2026-12-25)

The static audit log reported:
- 1,017 HTML pages scanned.
- 0 duplicate groups.
- 0 unresolved local references.
- 0 placeholder pages.
- 343 redirect routes.
- 523 noindex pages.
- 103 staging pages.
- 48 staging pages without visible Supabase signals.
- 67 operational pages without visible Supabase signals.
- 311 HTML pages with direct backend signals.
- 349 pages with linked-script backend signals.
- 194 operational pages with backend signals.

These are static-source heuristics, not runtime behavior. In particular, a page without visible Supabase signals is not automatically broken; it may use a shared script, a different integration, or be a static informational page. Likewise, zero unresolved local references does not prove every route loads or every user journey succeeds in a browser.

Run URL: https://github.com/rimjhimkrn-web/logistics-saas/actions/runs/45559294832
