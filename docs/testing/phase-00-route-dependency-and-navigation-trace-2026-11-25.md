# Phase 00 — Route Dependency and Navigation Trace (bounded source audit)

Date: 2026-11-25
Repository: rimjhimkrn-web/logistics-saas
Branch: qa/phase-00-baseline-2026-11-25
Scope: Web platform only. No runtime navigation or authenticated workflow execution.

## 1. Result and confidence

**Status: IN PROGRESS.** This is a bounded source trace of shared routing/auth files, the sitemap, the public tracking redirect, and one live warehouse evidence page. It is not a complete dependency map for all 1,017 HTML candidates.

Files inspected directly in this pass:
- `config.js`
- `auth-core.js`
- `platform/krim-supabase.js`
- `sitemap.xml`
- `public/tracking.html`
- `public/warehouse/warehouse-evidence.html`

Previously established inventory context: 1,017 HTML files excluding node_modules; 36 sitemap URLs; canonical route registry previously counted 27 keys / 25 unique destination files. The sitemap is not a complete authenticated route inventory.

## 2. Shared environment and client dependencies

- `config.js` is the central browser environment resolver and Supabase configuration source. QA-branch implementation uses host allowlisting: GitHub Pages host routes to Production; the designated Staging Pages host and local development route to Staging; unknown hosts fail closed. Page-level environment overrides are ignored. This is source evidence, not proof the deployed site uses this QA implementation.
- `platform/krim-supabase.js` is the shared client accessor/identity assertion module introduced in the QA branch. Its existence does not prove every page has migrated to it.
- `auth-core.js` centralizes account/auth routing and references these account destinations: `login.html`, `signup.html`, `verify-email.html`, `verify-phone.html`, `forgot-password.html`, `reset-password.html`, `mfa-enroll.html`, `mfa-challenge.html`, `recovery.html`, `invitation.html`, and `disabled.html`.
- Previous source audits found some pages still instantiate Supabase clients directly or load the Supabase SDK from a CDN. Therefore shared-client adoption must be measured route-by-route; do not assume universal adoption.

## 3. Direct page traces

| Page | Observed source dependencies | Observed backend actions | Provisional access classification |
|---|---|---|---|
| `public/tracking.html` | Redirect-only shim to root `/tracking.html` and relative `../tracking.html` | None in shim | Public alias; canonical tracking implementation must be audited separately |
| `public/warehouse/warehouse-evidence.html` | Supabase JS SDK via jsDelivr, `config.js`, global brand asset, warehouse navigation | `krim_warehouse_list_tasks`, `krim_warehouse_list_evidence`, `krim_warehouse_register_evidence`; Storage upload and signed preview | Authenticated warehouse workflow; runtime auth and tenant isolation still untested |
| `auth-core.js` | Shared account routing helper | Auth routing/session functions are in source; this bounded extraction did not enumerate runtime calls | Auth foundation; all dependent pages require coverage |
| `platform/krim-supabase.js` | Shared client accessor/identity assertion | No business RPC in this small module | Shared infrastructure module, not a page |

Important: the warehouse page source contains direct Storage use and three RPCs. This confirms that route tests must include backend/storage assertions, not just HTTP status or rendering.

## 4. Navigation and redirect observations

- `public/tracking.html` is a redirect/alias, not the tracking application itself.
- Warehouse evidence navigation points to multiple sibling warehouse pages including facility management, inbound receiving, goods receipt, putaway/storage, inventory ledger, picking/packing, dispatch handover, damage exceptions, performance, notifications and access audit. The presence of a link does not establish that its destination is implemented or reachable.
- `auth-core.js` exposes a defined account-route family. The full link graph and redirect chain resolution across all 1,017 candidates remains outstanding.

## 5. Test design derived from this trace

1. Add route metadata fields: canonical path, aliases, redirect target, public/protected, workspace, required role/permission/AAL, scripts/assets, RPCs, Edge Functions, tables, Storage buckets, and current verification status.
2. Add Playwright assertions for canonical route and redirect behavior; verify no redirect loops and preserve intended return path safely.
3. For protected routes, assert unauthenticated denial, correct-role access, wrong-role denial and cross-organization denial. Run only after Staging isolation is proven.
4. For warehouse evidence, assert task/evidence list RPCs, upload preconditions, registration outcome, cleanup behavior, signed preview authorization and audit evidence. Use synthetic files only in an approved isolated test environment.
5. Detect pages still using direct SDK/client creation and migrate or explicitly document exceptions before broad runtime acceptance.
6. Resolve every local navigation target in the candidate manifest, then classify missing links, aliases, prototypes, retired routes and duplicate destinations.

## 6. Limitations

- The complete 1,017-file route dependency graph was not fetched or parsed in this pass. A bulk source-fetch attempt exceeded the available tool-call budget; it did not produce a complete scan.
- No deployed Pages URL was crawled; no live HTTP status, redirect headers, browser console, network requests or asset load was tested.
- No login, RPC, Storage, database, payment or notification operation was executed.
- Route paths and source references do not prove deployed availability or access-control enforcement.

## 7. Disposition

**PASS:** bounded source trace completed for the six named files and the specific observations above.
**IN PROGRESS:** full route-to-script/navigation/backend dependency graph.
**NOT TESTED:** deployed reachability, authenticated route access, functional behavior, and backend authorization.

Safety: read-only source inspection and QA-branch documentation only. No Production or Staging writes, synthetic identities, provider calls, merge or deployment.