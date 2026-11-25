# Phase 00 — Gate C3.1: repository-wide static link graph audit

Date: 2026-11-25
Repository: rimjhimkrn-web/logistics-saas
Target branch: `qa/phase-00-baseline-2026-11-25`
Immutable application baseline: `72d75a18f985ceb09e468839435ee95700e11e46`

## Existing automated audit inspected

The QA branch already contains:
- `scripts/audit-krim-links.mjs`: recursively scans repository HTML files, literal href/src/action/formaction/poster attributes, GitHub Pages `/logistics-saas/` root paths, path traversal, and canonical route registry destinations.
- `scripts/krim-complete-static-audit.mjs`: recursively scans HTML files, extracts literal static HTML edges, counts inbound HTML links, reports zero-inbound HTML candidates, identifies redirect/noindex/staging routes, and emits JSON/Markdown artifacts.
- `.github/workflows/krim-static-link-audit.yml`: runs both scripts on pushes to `main` and `qa/phase-00-baseline-2026-11-25`, and uploads audit artifacts.

## Static analysis capabilities and important limitations

The complete audit's zero-inbound list is explicitly a *candidate* list, not proof of orphaned pages. It excludes root index/404 and known redirect routes, but does not account for all JS-generated routes, server-side routing, external inbound links, or business-critical direct-entry routes.

The literal link parser resolves relative paths and the GitHub Pages project prefix, but its behavior is heuristic. It does not fetch deployed URLs, follow HTTP redirects, validate query-dependent route logic, or test authentication. It scans literal HTML attributes and linked local JS for backend signals; backend signals are not runtime integration proof.

The workflow currently uses `|| true` for the first link-audit command, so that command's non-zero exit alone is masked. A later summary prints the broken-link count and an enforcement step fails if `broken_local_references > 0`. The complete audit generates a JSON artifact but does not independently fail on every category (for example, zero-inbound candidates). This is acceptable for triage but should not be described as a full browser crawl.

## Execution status

This evidence note is committed to the QA branch to trigger the existing push-based workflow. The repository-wide audit result is **PENDING** until the corresponding GitHub Actions run and uploaded artifacts are inspected. No totals or broken/orphan counts are claimed in advance.

## Gate disposition

- Existing repository-wide static scanner source reviewed: PASS.
- Eight-page sample from Gate C3: PASS (289/289 tracked references).
- Repository-wide scanner execution and artifact verification: BLOCKED / PENDING.
- Browser HTTP/redirect checks and deployed-route validation: NOT TESTED.
- True orphan-page determination: NOT TESTED.

No application source, Production/Staging deployment, database, secrets, or external provider state changed.
