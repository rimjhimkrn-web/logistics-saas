# Phase 01 — Gate 01M: Canonical route registry and sitemap crosswalk

Date: 2026-11-25
Immutable source baseline: 72d75a18f985ceb09e468839435ee95700e11e46
Canonical page manifest: phase-01-canonical-website-page-inventory-2026-11-25.csv
Crosswalk artifact commit: e039f11c0f6f1ac14c6cc48ef0f225569eebdd50

## Verdict
**PARTIAL / BLOCKED — core route-registry and sitemap destinations reconcile to source files, but the full 1,004-candidate route graph, redirect aliases, inbound counts and zero-inbound identities cannot yet be certified against the exact immutable baseline.**

## Verified source crosswalk
- Canonical registry in config.js: **27 keys**, **25 unique destination paths**.
- Two keys intentionally share destinations: customsQueue → app/customs/index.html (customs) and operationsControl → app/operations/index.html (operations). These are registry aliases, not additional HTML pages.
- All **25 unique registry destinations** exist in the 1,017-row canonical source inventory. Missing destinations: **0**.
- sitemap.xml contains **36 URL entries**.
- All **36 sitemap paths** exist in the canonical source inventory. Missing sitemap destinations: **0**.
- The 25 core registry destinations and 36 sitemap paths have **zero path overlap**. This is not automatically an error: the registry primarily maps application/auth/workflow entry points, while the sitemap lists public marketing/legal content. It does mean the sitemap does not advertise the core app route destinations.
- Crosswalk file: docs/testing/phase-01-route-registry-sitemap-crosswalk-2026-11-25.csv. It contains the 27 registry key rows and 36 sitemap rows with path-presence evidence.

## What this proves — and what it does not
1. Registry and sitemap paths resolve to tracked source HTML files in the immutable baseline.
2. It does not prove HTTP 200, deployed availability, redirects, browser navigation, correct GitHub Pages base-path behavior, authentication, permissions, tenant isolation, or workflow completion.
3. The static graph report from a different QA commit recorded 9,453 literal edges, 757 pages with inbound links, 89 zero-inbound candidates, 343 compatibility redirects and 523 noindex pages. Those figures are historical parser results, not a path-by-path crosswalk to the exact 1,017-row baseline.
4. The prior zero-inbound dispositions (28 direct-entry, 35 restrict, 10 keep, 14 consolidate-review, 2 retire-review) were summary counts. The exact 89 path identities are not present in the immutable baseline artifacts retrieved for this gate; no page may be retired or deleted based on those counts.
5. The 343 redirect count is not reconciled to a complete per-path redirect register in this gate. Runtime redirect destination, query/hash preservation, auth context, loops and GitHub Pages behavior remain untested.
6. Registry entries are not a complete route inventory: 1,004 route candidates remain, including public, legacy, staging, direct-entry and workflow candidates. Hash/SPA states and JS-built links may not be separate HTML pages.

## Required next work
- Extract every literal HTML inbound edge from the exact immutable baseline, excluding the six Playwright dependency files, and produce per-path inbound counts.
- Parse redirect mechanisms and noindex metadata for every eligible HTML page; create a path-specific redirect/alias/noindex register.
- Extract JS/TS-created navigation and auth/deep links, preserving source file and construction evidence.
- Reconcile all 89 historical zero-inbound candidates by exact path; keep all unresolved candidates in review and authorize no deletion.
- Resolve 103 staging-path candidates and 13 workflow candidates as route, child state, preview, or internal surface without relying on folder names alone.
- Later run browser/HTTP route assertions only after Phase 03 proves isolated Staging and the environment/client bypasses are remediated.

## Safety
Read-only source inspection and QA documentation only. No pages deleted, renamed or changed; no deployment, browser test, SQL/RPC/Auth/Storage/provider operation, synthetic user, payment, notification or external side effect.

## Gate disposition
Gate 01M **PARTIAL / BLOCKED**. Phase 01 remains IN PROGRESS. Phase 00 remains FAIL / BLOCKED. Runtime verification NOT PROVEN; production readiness NOT CERTIFIED; general operational onboarding NO-GO.

## Next gate
Gate 01N — exact-baseline static inbound-link and redirect/noindex extraction for all 1,017 eligible HTML pages, producing per-path evidence and reconciling the historical zero-inbound and redirect summaries.
