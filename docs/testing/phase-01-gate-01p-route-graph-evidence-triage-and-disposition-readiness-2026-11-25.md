# Phase 01 — Gate 01P: Route-graph evidence triage and disposition readiness

**Date:** 2026-11-25  
**Scope:** Read-only review of the exact-baseline route-graph CI evidence, parser semantics, and readiness for per-path route disposition.  
**Source baseline:** `72d75a18f985ceb09e468839435ee95700e11e46`  
**QA branch:** `qa/phase-00-baseline-2026-11-25`

## Verdict

**PARTIAL / BLOCKED — aggregate graph validation is confirmed, but per-path route disposition is not completed.** The successful CI run proves the extractor and tests executed against the immutable 1,017-page baseline. It does not by itself establish which zero-inbound pages are safe to retire, which redirects are compatibility aliases, or which noindex pages are intentionally private/workflow routes.

## Confirmed evidence

- Workflow run `45653728284` completed successfully.
- QA code/test revision: `7c385898cb8c6d7b653c530b19c44821ba5f0c1f`.
- Immutable source baseline checked out separately: `72d75a18f985ceb09e468839435ee95700e11e46`.
- Nine Node tests passed; exact inventory assertion passed at 1,017 HTML files.
- Artifact `krim-exact-baseline-route-graph`, ID `15041742755`, SHA-256 `4904e3c1cd7d6bf7d263aba811036ac531d8237a321e4f7c01532f51901429db`.
- Aggregate output: 9,285 literal HTML inbound edges; 757 pages with inbound; 260 whole-inventory zero-inbound pages; 499 broad redirect-candidate pages; 529 robots noindex pages; zero unresolved local HTML route references under the parser's HTML-route-only scope.

## Parser and evidence limitations

1. The parser extracts literal HTML anchor/area `href`, form `action`, button `data-href/formaction`, and iframe `src` references. It removes script bodies before link extraction. JavaScript/TypeScript-generated navigation, event-handler routing, dynamic imports, runtime redirects, external backlinks, email links and bookmarks are not included.
2. The 499 redirect count is a broad source-pattern candidate set. It includes literal `location.replace` and `location` assignments, including protected-page redirects to login. It is not a count of verified compatibility redirects or redirect aliases.
3. The 260 zero-inbound pages are the entire eligible HTML inventory's zero-literal-inbound set. They are not equivalent to the earlier 89-candidate subset, which was computed on another QA snapshot and a different candidate universe.
4. The 529 noindex count describes source meta tags only. Noindex does not mean obsolete, unused, inaccessible or safe to delete.
5. The artifact archive is listed by GitHub with the recorded ID and digest, but the connected GitHub read interface exposes artifact metadata and workflow logs rather than the ZIP contents. The full per-path JSON/CSV rows therefore have not been independently inspected in this gate. Workflow logs expose only bounded samples.
6. Zero unresolved local HTML references excludes non-HTML assets and does not prove HTTP availability, GitHub Pages base-path correctness, authentication, authorization or runtime navigation.

## Required disposition controls

No route may be retired or deleted solely because it has zero literal inbound links, carries noindex, or contains a redirect pattern. Each candidate needs path-specific review for:
- canonical route-registry membership and aliases;
- sitemap membership and public SEO purpose;
- direct-entry, bookmark, invitation-token, password-reset, email and external-link use;
- role/tenant guards and intended authentication redirects;
- parent/child workflow dependencies and JavaScript-generated navigation;
- duplicate-content evidence, owner confirmation and replacement destination;
- deployed HTTP behavior and GitHub Pages project-subpath behavior, to be tested only in an approved safe environment.

## Next work

**Gate 01Q:** produce a path-by-path disposition matrix by obtaining and verifying the exact artifact JSON/CSV, then cross-referencing every zero-inbound, redirect-candidate and noindex path against the canonical registry, sitemap, historical redirect inventory and direct-entry/workflow evidence. Keep all candidates; no deletion without explicit owner approval. In parallel, create a separate JS/TS navigation inventory so literal HTML graph results are not mistaken for the complete route graph.

## Safety

Read-only repository and workflow evidence only. No source application changes, page deletions, deployments, browser tests, Production/Staging SQL/RPC/Auth/Storage operations, synthetic users, payments, provider calls, notifications, secrets reads, data exports or external side effects.

**Overall status:** Phase 01 IN PROGRESS. Phase 00 FAIL / BLOCKED. Runtime verification NOT PROVEN. Production readiness NOT CERTIFIED. General partner/customer/driver operational onboarding NO-GO.
