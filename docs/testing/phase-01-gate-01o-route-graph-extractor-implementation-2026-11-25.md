# Phase 01 — Gate 01O: Deterministic route-graph extractor implementation

Date: 2026-11-25  
Implementation branch: qa/phase-00-baseline-2026-11-25  
Immutable source target: 72d75a18f985ceb09e468839435ee95700e11e46

## Verdict

**IMPLEMENTED — CI EXECUTION / INVENTORY OUTPUT PENDING.** The deterministic extractor, unit-test suite and isolated GitHub Actions workflow are committed to the QA branch. No test run or 1,017-page output artifact has yet been independently observed, so the parser is not marked test-PASS and the exact-baseline counts remain unverified.

## Artifacts

- `scripts/krim-route-graph-audit.mjs` — read-only extractor that inventories HTML files, normalizes relative and GitHub Pages project-prefix references, builds per-page inbound edges and unique inbound-source counts, identifies zero-inbound pages, captures robots noindex metadata, literal meta-refresh/location redirect candidates, and unresolved local references. Emits JSON with edge detail and a per-page CSV.
- `scripts/krim-route-graph-audit.test.mjs` — Node built-in test suite covering relative paths and query/hash suffixes, project-prefix paths, root-relative directory index resolution, public mirror resolution, external/dynamic skips, path traversal, invalid encoding, HTML-vs-script parsing, inbound graph totals, noindex and meta-refresh detection.
- `.github/workflows/krim-exact-baseline-route-graph.yml` — read-only GitHub Actions workflow. It checks out the QA extractor, runs Node tests, separately checks out the immutable baseline, generates JSON/CSV, asserts exactly 1,017 HTML files, and uploads artifacts. It runs on QA-branch pushes and supports manual dispatch with an explicit baseline SHA.

## Static review and limitations

- Script source and workflow were read back after commits. The parser retains literal external script `src` attributes but strips script bodies from HTML-link extraction. JavaScript-generated links are intentionally excluded and must be audited separately.
- The parser's root-relative normalization supports this GitHub Pages project's `/logistics-saas/` prefix. It records unresolved paths rather than guessing a valid destination.
- Redirect candidates are source-pattern evidence only; they do not prove execution, final redirect target after JavaScript, HTTP behavior, or absence of loops.
- Unit tests have been authored but not executed in this interaction. The GitHub Actions workflow run and uploaded artifact are not yet verified.
- The output is expected to include every eligible HTML path, per-path inbound counts and edge details, zero-inbound path identities, noindex paths, redirect candidates and unresolved references. No result counts are claimed until the workflow artifact is inspected.

## Safety

QA-branch code and workflow only. No application page or business logic was changed. No Production or Staging database, Auth, Storage, Edge Function, provider, payment, notification, browser, deployment or user operation was performed. The workflow checks out the immutable source baseline read-only and has `contents: read` permission.

## Gate disposition

Gate 01O **IMPLEMENTED / VALIDATION PENDING**. Phase 01 remains IN PROGRESS. Phase 00 remains FAIL / BLOCKED. Runtime verification NOT PROVEN. Production readiness NOT CERTIFIED. General partner/customer/driver operational onboarding remains NO-GO.

## Next gate

Gate 01P — inspect the completed CI run, test results, 1,017-page JSON/CSV artifact and checksums; fix any parser/test/inventory mismatch before reconciling historical zero-inbound, redirect and noindex path identities.

## CI validation update (run 45653698622)

The workflow completed successfully against immutable baseline SHA `72d75a18f985ceb09e468839435ee95700e11e46` using QA extractor commit `e694aae7cae977c53a0a955dda1e6817717f7e7e`. Node unit tests passed; exact HTML inventory assertion passed at **1,017 pages**; JSON and CSV artifacts uploaded successfully.

Observed output from that run:
- HTML pages: **1,017**
- Literal HTML inbound edges: **9,285**
- Pages with inbound edges: **757**
- Zero-inbound pages: **260**
- Redirect candidate pages: **499**
- robots noindex pages: **529**
- Unresolved local HTML route references: **0**

Artifact: `krim-exact-baseline-route-graph`, artifact ID `15040563725`, SHA-256 `75f181a9bdce92364d2eed544af94ff7cab3a628ef0bd2ec8da716058cac0809`. It contains per-page JSON and CSV evidence and is retained in GitHub Actions through 2026-12-25.

**Interpretation cautions:** the 499 are broad source-pattern redirect candidates, including literal `location.href` assignments and `location.replace` calls; they are not yet 499 confirmed compatibility redirects. The 260 zero-inbound count is for the complete 1,017-file HTML census, not the narrower 89-candidate subset from the earlier route-triage summary. The 529 noindex count is the new parser's metadata result. The zero unresolved count is for HTML route references after excluding static assets and non-navigation resource attributes; it is not a full asset audit. These counts must be path-reconciled and manually classified before retirement decisions.

A ninth test covering asset exclusion and non-navigation resource attributes was added after this successful run. A follow-up CI run is required to verify that final test revision. Gate 01O is therefore **PASS for the run's 8-test parser revision and 1,017-page extraction; final branch revision validation remains pending**.
