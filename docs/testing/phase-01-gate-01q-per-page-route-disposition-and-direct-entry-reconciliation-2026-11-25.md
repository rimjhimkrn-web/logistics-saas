# Phase 01 — Gate 01Q: Per-page route disposition and direct-entry reconciliation

**Date:** 2026-11-25  
**Source baseline:** `72d75a18f985ceb09e468839435ee95700e11e46`  
**QA branch:** `qa/phase-00-baseline-2026-11-25`  
**Artifact:** workflow run `45653728284`, artifact ID `15041742755`

## Verdict

**PARTIAL / BLOCKED — artifact rows independently inspected and major route classes reconciled; complete owner-approved disposition and runtime route verification remain open.** This gate closes the prior artifact-access gap by downloading the actual ZIP and verifying its SHA-256 digest against GitHub's artifact log. It does not authorize deletion, route retirement, or deployment.

## Artifact integrity and exact-baseline evidence

- Downloaded archive: `krim-exact-baseline-route-graph.zip`.
- Independently calculated SHA-256: `4904e3c1cd7d6bf7d263aba811036ac531d8237a321e4f7c01532f51901429db`, matching the GitHub Actions upload log.
- Archive contains `krim-route-graph.json` (1,809,609 bytes) and `krim-route-graph.csv` (64,697 bytes).
- Exact baseline inventory: 1,017 eligible HTML pages.
- Literal HTML graph: 9,285 inbound edges; 757 pages with inbound edges; 260 zero-literal-inbound pages; 499 pages with one or more redirect-pattern candidates; 529 pages with robots noindex; zero unresolved local HTML-route references within the parser's limited scope.
- Redirect parser found 669 pattern instances across 499 pages. Instances include duplicated meta-refresh/script mechanisms on the same page; this is not 669 distinct redirects.

## Zero-inbound page reconciliation

The 260 zero-inbound pages partition as follows:

| Static signal | Pages | Interpretation |
|---|---:|---|
| Zero inbound + redirect-pattern candidate | 185 | Includes legacy aliases and login/role guards; not safe-to-retire evidence |
| Zero inbound + noindex, without redirect candidate | 24 | Likely restricted/direct-entry or workflow surfaces; keep pending owner and dependency review |
| Zero inbound + neither noindex nor redirect candidate | 51 | Direct-entry, sitemap-only, legacy, internal or otherwise unlinked candidates; individually review |
| **Total** | **260** | No deletion disposition granted |

Additional cross-signal findings:
- 196 of the 260 zero-inbound pages have a robots noindex meta tag.
- 64 zero-inbound pages do not have a robots noindex meta tag.
- 185 zero-inbound pages also contain a redirect-pattern candidate.
- Six sitemap-listed public pages have zero literal inbound edges: `public/about.html`, `public/get-started.html`, `public/global-coverage.html`, `public/industries.html`, `public/partners.html`, and `public/warehousing.html`. Their sitemap membership is direct-discovery evidence; they are not orphans for disposition purposes.
- The canonical registry contains 25 unique destinations (27 keys including aliases). Only one registry destination has zero literal inbound edges: `public/partner/load-marketplace.html`.

## High-priority route exceptions

1. **Partner marketplace registry mismatch — P1.** The canonical registry points to `public/partner/load-marketplace.html`, which is zero-inbound, noindex and redirects to `available-loads.html`. The page's visible fallback link also targets `available-loads.html`. Confirm the intended canonical public/partner destination and update the route registry or redirect target in a separately approved source-change task. Do not remove the alias before confirming bookmarks, partner acquisition links and external references.
2. **Tracking route alias — P1.** Registry destination `public/tracking.html` has inbound links but is noindex and redirects to `../tracking.html`. Confirm which tracking page is canonical, whether query/hash values survive, and whether the public tracking flow remains available under the GitHub Pages project base path.
3. **Driver assignment route alias — P1.** Registry destination `app/driver/module-01-assignment-inbox.html` has inbound links and a meta-refresh to `./staging/page-02-assignment-inbox.html`. This is a staging-named destination in a canonical route path. Confirm intended driver route and access controls before changing either path.
4. **Auth callback and invitation direct entry — protected KEEP.** `auth/auth-callback.html` reads query parameters and preserves a validated driver invitation token in session storage before redirecting; `auth/invitation.html` processes the invitation session. Their low/no inbound counts must not be treated as orphan evidence. Preserve exact token/query/hash semantics and verify only in an isolated approved environment.
5. **Password recovery direct entry — protected KEEP.** `auth/reset-password.html` consumes recovery query/hash parameters and validates a recovery session. It may be opened from email rather than an HTML link. Preserve it; noindex and zero-inbound are expected possibilities for this workflow.
6. **Driver index alias — KEEP pending route contract.** `app/driver/index.html` redirects to `./dashboard.html` while the route registry maps the driver workspace to this index. Confirm query/hash preservation and dashboard authorization before replacing the alias.
7. **Legacy source/template paths — owner review.** Zero-inbound paths under `src/` and `templates/` are not automatically public routes. Classify their build/runtime dependency before any cleanup.

## Registry and sitemap crosswalk

- All 25 unique registry destinations are present in the canonical HTML inventory.
- All 36 sitemap entries are present in the canonical HTML inventory.
- Registry and sitemap sets remain distinct in purpose: app/auth/workflow entry points versus public discovery/legal pages.
- The six zero-inbound sitemap entries above should remain retained and crawlable unless a separate content/SEO owner approves a change.
- Noindex tags describe source crawler directives only; they do not prove access restriction, authentication, privacy, or retirement status.

## Redirect and noindex interpretation

- 499 pages contain at least one recognized literal redirect pattern: meta refresh, `location.replace`, or literal `location` assignment. Pattern detection does not evaluate conditions, execution order, browser behavior, target status, redirect loops, query/hash preservation or whether the page is a compatibility alias versus an authentication guard.
- 529 pages contain a robots noindex meta tag. This is not an access-control mechanism and does not establish that a page is private.
- 404 redirect-candidate pages also have noindex; 95 redirect-candidate pages do not. These overlapping signals require route-by-route review, not bulk rules.

## Parser limitations

The extractor builds a literal HTML graph from supported HTML navigation attributes; it excludes JavaScript/TypeScript-generated navigation and event handlers, CSS navigation, external backlinks, email links, bookmarks, dynamic route construction, runtime HTTP status, deployed GitHub Pages behavior, auth/tenant authorization and actual form/API behavior. A zero unresolved count applies only to local HTML-route references recognized by this parser; non-HTML assets and dynamic references are outside scope.

## Disposition decision

- **KEEP:** all 25 registry destinations and 36 sitemap destinations pending explicit route contract review; preserve auth callback, invitation, reset-password, verification and other email/token direct-entry workflows.
- **KEEP / REVIEW:** all 260 zero-inbound paths, 499 redirect-candidate pages and 529 noindex pages. Review is non-destructive.
- **NO RETIRE / NO DELETE:** no route is approved for removal by this gate.
- **NO DEPLOY:** no application source was changed.

## Next gate

**Gate 01R — JavaScript/TypeScript navigation and dynamic route dependency inventory.** Extract static string route targets, event-handler navigation, `window.location`/History API calls, router declarations, dynamic imports and email/invitation callback destinations. Reconcile them against the 1,017-page inventory and this route matrix. After that, perform owner review of route aliases and direct-entry routes. Runtime browser verification remains deferred until the Phase 00 staging-isolation and Production-client bypass blockers are resolved.

## Safety

Read-only artifact and immutable-baseline source inspection. No Production/Staging SQL/RPC/Auth/Storage operations, synthetic users, browser tests, deployments, payments, provider calls, notifications, secrets reads, data exports, page deletion or external side effects.

**Overall status:** Phase 01 IN PROGRESS. Phase 00 FAIL / BLOCKED. Runtime verification NOT PROVEN. Production readiness NOT CERTIFIED. General partner/customer/driver operational onboarding NO-GO.
