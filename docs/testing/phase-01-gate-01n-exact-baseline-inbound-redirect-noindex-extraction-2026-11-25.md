# Phase 01 — Gate 01N: Exact-baseline inbound-link, redirect and noindex extraction

Date: 2026-11-25  
Immutable baseline: 72d75a18f985ceb09e468839435ee95700e11e46  
Canonical HTML inventory: 1,017 eligible files (six Playwright dependency HTML files excluded).

## Verdict

**NOT EXECUTED / BLOCKED — the exact-baseline per-path inbound-link, redirect and noindex dataset was not generated in this gate.** This is an explicit evidence gap, not a pass.

## Evidence reviewed

- The immutable Git tree confirms 1,017 eligible HTML blobs.
- The canonical manifest from Gate 01L reconciles all 1,017 eligible paths.
- The earlier static graph reports on QA commits 3f37e0817bee4ba1ae773f18f9ef5a7ed0e934c0 and 6306bf1b65fa5b6fffb99986efe0b5603b23a6c1 report 9,453 literal edges, 757 pages with inbound links, 89 zero-inbound candidates, and 343 compatibility redirects. These remain historical results from different source snapshots, not an exact-baseline extraction.
- The existing workflow `.github/workflows/krim-static-link-audit.yml` is configured for pushes to `main`, pull requests and manual dispatch. Its complete audit artifact is uploaded to Actions, but the historical aggregate summary does not provide the required per-path inbound-edge graph.
- The inspected `scripts/krim-complete-static-audit.mjs` records per-page outgoing literal link counts and redirect/noindex candidate lists, but does not build a reverse inbound-edge map. Its regex parser also intentionally skips script bodies, so JS-generated navigation is outside its scope.
- The separate `scripts/audit-krim-links.mjs` validates literal local references and canonical registry targets; it does not produce an inbound graph or a full redirect/noindex inventory.

## Why this gate is blocked

A complete 1,017-file source extraction could not be completed and independently verified within this tool execution. No partial sample has been promoted as a whole-platform result. Therefore this gate does not claim refreshed zero-inbound identities, redirect totals, noindex totals, or route-level inbound counts.

## Required corrective work

1. Add a deterministic, read-only Node.js extractor to the QA branch. It must read the checked-out immutable baseline tree, exclude exactly the six Playwright dependency files, normalize relative and GitHub Pages `/logistics-saas/` paths, and emit:
   - one row per eligible HTML path;
   - inbound edge count and unique inbound source count;
   - literal inbound edge detail (source, attribute, raw target, normalized target);
   - redirect mechanism and literal destination candidates;
   - robots noindex state;
   - unresolved local reference details.
2. Add explicit parser tests for relative paths, `../`, directory index targets, query/hash suffixes, encoded paths, root-relative paths and GitHub Pages project-prefix paths.
3. Keep JS/TS-created navigation as a separate extraction pass; do not silently mix it with literal HTML edges.
4. Run the extractor in an isolated read-only GitHub Actions job on the exact immutable baseline SHA and retain the CSV/JSON artifacts. Verify counts and artifact checksums.
5. Reconcile the 89 historical zero-inbound paths and 343 historical redirect paths by exact identity. Do not retire/delete any page without direct-entry, email/deep-link, auth, owner and dependency review.
6. Reconcile noindex metadata and sitemap coverage; noindex is not proof that a page is unused or safe to remove.

## Safety

No application source changes, page deletions, deployments, browser tests, Production/Staging database operations, Auth or Storage operations, synthetic users, payments, provider calls, notifications, secrets reads or external side effects were performed. QA documentation only.

## Gate disposition

Gate 01N **NOT EXECUTED / BLOCKED**. Phase 01 remains IN PROGRESS. Phase 00 remains FAIL / BLOCKED. Runtime verification remains NOT PROVEN. Production readiness is NOT CERTIFIED. General partner/customer/driver operational onboarding remains NO-GO.

## Next gate

Gate 01O — implement and unit-test the deterministic exact-baseline static route graph extractor, then run it in a read-only CI job against the immutable baseline SHA.