# Phase 01 — Gate 01K: HTML census reconciliation and canonical page denominator
Date: 2026-11-25
Immutable baseline: 72d75a18f985ceb09e468839435ee95700e11e46
Prior static graph audit commit: 6306bf1b65fa5b6fffb99986efe0b5603b23a6c1
Scope: read-only comparison of Git tree HTML paths and exact CI audit script. No runtime/browser testing.

## Verdict
**PASS — the 1,023 versus 1,018 census discrepancy is reconciled at source level.** The totals described different file sets.

## Exact reconciliation
- Immutable baseline tree: **1,023** .html blobs.
- Prior CI audit commit tree: **1,024** .html blobs.
- Exact path difference: CI tree adds one file, scripts/browser-environment-smoke.html; there are no baseline-only HTML paths.
- Both trees contain the same six HTML files under node_modules/playwright-core/lib/vite/: dashboard/index.html, htmlReport/index.html, recorder/index.html, traceViewer/index.html, traceViewer/snapshot.html, traceViewer/uiMode.html.
- Exact CI script scripts/krim-complete-static-audit.mjs defines IGNORE = {'.git','node_modules','.next','dist','build'}; recursive walker excludes node_modules, so those six dependency HTML files are not scanned.
- CI commit adds browser-environment-smoke.html under scripts/; the walker does not exclude scripts/, so that tooling HTML is counted.
- Arithmetic: 1,023 baseline HTML blobs − 6 dependency HTML files + 1 CI-only tooling HTML = **1,018 scanned HTML files**.
- Canonical source website HTML denominator for immutable baseline: **1,017** (= 1,023 − 6 dependency artifacts).
- The 1,018 CI scanner total is not the canonical website-page count because it includes one scripts tooling HTML page.

## Interpretation and limits
- This reconciles the five-file net difference; it does not assert that CI and baseline were the same commit.
- Six Playwright Vite HTML files are dependency/vendor UI, not KRIM website pages.
- scripts/browser-environment-smoke.html is a test/tooling artifact, not a customer-facing route.
- 1,017 is a repository-source denominator after excluding six dependency artifacts. It does not prove all pages are public, reachable, unique business routes, deployed or functional.
- Page-purpose classifications, redirect candidates, staging-only pages and access restrictions still require disposition. No files were removed or reclassified.
- CI performs static parsing, not a deployed browser crawl or HTTP reachability test.

## Safety boundary
Read-only Git tree and script inspection. No source changes, SQL/RPC/Auth/Storage/provider operations, form submissions, browser tests, deployment or data mutation.

## Gate decision
Gate 01K **PASS for census reconciliation**. Phase 01 remains IN PROGRESS because route purpose, reachability, dynamic navigation, access control and runtime behaviour are not certified. Phase 00 remains FAIL / BLOCKED; general operational onboarding remains NO-GO.

## Next gate
Gate 01L — reconcile the canonical 1,017 source-page inventory with page-purpose classes, staging-only/redirect/entry/workflow categories and excluded tooling artifacts, then produce a stable page manifest and unresolved-classification list.
