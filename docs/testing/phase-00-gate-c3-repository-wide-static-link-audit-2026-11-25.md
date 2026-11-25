# Phase 00 — Gate C3: repository-wide static link audit execution

Date: 2026-11-25
Branch: `qa/phase-00-baseline-2026-11-25`
Audit implementation: `scripts/audit-krim-links.mjs`
Workflow: `.github/workflows/krim-static-link-audit.yml`

## Execution method

The repository already contains a Node.js static local-link audit and a GitHub Actions workflow. The script walks the repository and scans every tracked/worktree HTML file for literal local `href`, `src`, `action`, `formaction`, and `poster` targets; it also validates destinations in `window.KRIM_ROUTES` within `config.js`. It reports operational-risk and legacy-brand signals separately from broken-reference errors.

The workflow is configured for pushes to `main` and this QA branch, so this documentation-only commit requests a fresh CI run on the QA branch. No app source, database, deployment configuration, secrets, or provider settings were changed.

## Execution status

- Eight-page manual sample: PASS, 289/289 literal local references resolve after GitHub Pages base-path normalization.
- Repository-wide CI audit: PENDING workflow completion and artifact inspection.
- Orphan-page detection: NOT TESTED by the current script; it validates outgoing literal references, not inbound-link counts.
- Dynamic JavaScript navigation, CSS url/import references, runtime HTTP status, redirects and browser navigation: NOT TESTED.

## Acceptance criteria

The repository-wide audit is accepted only after the GitHub Actions run is completed, the exact HTML file count and broken-reference count are recorded, the JSON artifact is inspected, and any findings are classified. A green workflow alone does not establish runtime availability or prove that pages are functionally correct.

## Gate disposition

Gate C3 remains PARTIAL PASS / BLOCKED until the CI run and artifact are verified. If broken references are found, create a remediation list; do not delete or silently rewrite routes. No production or staging writes or deployments.
