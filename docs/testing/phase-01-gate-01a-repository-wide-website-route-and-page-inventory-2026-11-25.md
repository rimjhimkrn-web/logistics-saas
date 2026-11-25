# Phase 01 — Gate 01A: Repository-wide website route and page inventory

Date: 2026-11-25
Repository: rimjhimkrn-web/logistics-saas
Immutable source baseline: `72d75a18f985ceb09e468839435ee95700e11e46`
QA documentation branch: `qa/phase-00-baseline-2026-11-25`
Scope: web platform source inventory only. Native mobile apps excluded; mobile-browser compatibility remains in later testing.
Method: read-only recursive Git tree inspection, existing route-manifest review, sitemap/config/manifest inspection and bounded canonical-route source review. No browser crawl or runtime navigation.

## 1. Verdict

**PASS — repository census and baseline page inventory established. PARTIAL / IN PROGRESS — complete route graph, inbound-link classification, deployed reachability and all page-to-backend dependencies remain outstanding.**

This gate establishes what is tracked in the immutable repository snapshot. It does not assert that all pages are deployed, linked, functional, authorized or safe for real users.

## 2. Immutable repository census

GitHub recursive tree for the immutable baseline returned `truncated=false`.

| Inventory item | Count | Meaning |
|---|---:|---|
| Recursive tree entries | 2,256 | Files plus directories |
| Tracked blobs | 2,180 | All file objects in snapshot |
| HTML files | 1,023 | Page candidates, not 1,023 verified routes |
| JavaScript files | 134 | Source files |
| MJS files | 8 | Source files |
| TypeScript files | 36 | Source files |
| TSX files | 15 | Source files |
| CSS files | 31 | Stylesheets |
| JSON files | 23 | Configuration/data manifests |
| SQL files | 377 | Database migrations/scripts, not website routes |

The 1,023 HTML count matches the pre-existing `phase-00-page-route-manifest-2026-11-25.csv` row count. That manifest is path-based and records every row as NOT TESTED at runtime.

## 3. Existing route-candidate classification

The existing complete HTML manifest uses a single primary path-based candidate class:

| Candidate class | Count |
|---|---:|
| ACTIVE/OTHER CANDIDATE | 869 |
| STAGING-ONLY CANDIDATE | 103 |
| ACTIVE-ENTRY CANDIDATE | 38 |
| WORKFLOW ROUTE CANDIDATE | 13 |
| **Total** | **1,023** |

These are mutually exclusive manifest labels, but they are only naming/path heuristics. In particular:
- “Active” does not mean linked, deployed or operational.
- “Staging-only” is inferred from directory placement, not proven environment access control.
- “Workflow” does not prove a completed workflow.
- No candidate is classified as definitively orphaned or retired by this census.

The manifest's broad workspace candidates span public/other, admin/platform-admin, customer, partner, driver, warehouse, customs, finance, operations, enterprise and field paths. The manifest deliberately retains overlapping naming families (for example `customer` and `customer-candidate`); these are not unique user counts or canonical routes.

## 4. Public discovery and canonical routing

- `sitemap.xml` contains 36 URL entries. It is a public discovery list, not a full authenticated route inventory.
- `window.KRIM_ROUTES` has a previously audited 27 keys resolving to 25 unique destination files. Two pairs of keys share destinations.
- The canonical route audit found a mixture of public pages, authenticated workspace shells, read-only/previews, aliases and deliberately restricted flows.
- The route registry and sitemap do not cover every HTML file; many workspace and operations pages exist outside the public sitemap.

### Canonical route families already source-classified

| Route family | Canonical destinations / observations |
|---|---|
| Public/home | `index.html`; public marketing pages |
| Auth/access | `auth/access.html`, `auth/login.html`; runtime session/MFA not tested |
| Customer | `app/customer/index.html`; booking route is write-paused by release flag |
| Partner | `app/partner/index.html`; Staging review preview is not authenticated partner acceptance |
| Driver | `app/driver/index.html` redirects to `dashboard.html`; assignment inbox alias redirects into a staging-named destination |
| Warehouse | `app/warehouse/index.html`; operational workflows live in linked child pages |
| Customs | `app/customs/index.html`; authenticated customs shell |
| Finance | `app/finance/index.html`; restricted/read-only workspace shell |
| Operations | `app/operations/index.html`; operational control centre |
| Enterprise | `app/enterprise/index.html`; staging preview fallback must not be mistaken for persisted data |
| Platform admin | `app/platform-admin/index.html`; privileged shell, not proof every action is authorized |
| Support | `public/support/help-centre.html`; public help page is not proof of ticket creation or agent delivery |

### Confirmed source-level redirect/alias examples

1. `app/driver/index.html` → `app/driver/dashboard.html`.
2. `app/driver/module-01-assignment-inbox.html` → `app/driver/staging/page-02-assignment-inbox.html`.
3. `public/partner/load-marketplace.html` → `public/partner/available-loads.html`; source identifies the old page as fictional sample-load content.
4. `public/tracking.html` → root `tracking.html`.
5. `public/quote-result.html` → `public/shipper/payment-checkout.html`; the destination provides partner-direct payment guidance and is not a live KRIM freight checkout.

These are source observations only; redirect behavior was not browser-tested.

## 5. Deployment base-path and PWA route risks

The current source config identifies GitHub Pages as `rimjhimkrn-web.github.io`, uses `/logistics-saas` as the repository base path, and maps that host to the Production Supabase project. This is a source-level mapping, not a deployed configuration attestation.

The repository contains multiple manifests with conflicting path conventions:
- Root `manifest.json` declares `start_url: /logistics-saas/public/index.html` and `scope: /logistics-saas/`.
- `public/manifest.webmanifest` declares root-absolute `/index.html` and root-absolute icon paths.
- Prior Phase 00 audit also identified a service-worker precache using origin-root paths. This must be tested under the actual `/logistics-saas/` base path before PWA acceptance.

**P1 route risk:** root-absolute links/assets/service-worker paths can escape the GitHub Pages project path. Do not fix or deploy during this inventory gate; create a separate remediation and verify every affected path.

## 6. Inventory gaps and next sub-gates

| Sub-gate | Required work | Status |
|---|---|---|
| 01A repository census | Enumerate tracked HTML/source/config and preserve candidate manifest | PASS |
| 01B navigation graph | Parse HTML href/src/action/formaction plus JS-generated navigation; compute inbound/outbound edges and unresolved local targets | NOT COMPLETE |
| 01C page classification | Inspect redirect/shell/prototype/preview/auth/role classifications; identify duplicates and true orphans | NOT COMPLETE |
| 01D workspace mapping | Map all candidate routes to intended user type, permission/AAL and workspace entry | NOT COMPLETE |
| 01E dependency map | Map page → JS/CSS/assets → Auth → RPC/Edge Function → tables/Storage | NOT COMPLETE |
| 01F deployed route check | Verify deployed URL/status/redirect/console/network/assets after approved target and environment are established | BLOCKED |
| 01G mobile-browser compatibility | Test website at mobile viewport/device/browser; native mobile app remains out of scope | NOT STARTED |

Next execution priority is **01B — repository-wide static navigation graph**, excluding `node_modules`, build artifacts and mobile-app source. The static graph must distinguish literal local links from dynamically generated routes and external URLs.

## 7. Release and safety disposition

- Repository census: PASS.
- Complete route inventory: PARTIAL; all 1,023 HTML candidates are recorded, but not yet individually classified for reachability/orphan status.
- Deployed route availability: NOT TESTED.
- Browser rendering and mobile-browser behavior: NOT TESTED.
- Authenticated access/role enforcement: NOT TESTED.
- Forms, buttons, RPCs, Edge Functions, Storage and business workflows: NOT TESTED by this gate.
- No page was deleted, renamed, redirected, modified or deployed.
- No Production/Staging SQL/RPC, Auth operation, synthetic user, provider call, notification, Storage action, data mutation or load test was performed.

**Phase 01 overall remains IN PROGRESS. Phase 00 release decision remains FAIL / BLOCKED. Real customer booking and operational partner/driver onboarding remain NO-GO until the consolidated P0 gates are remediated and verified.**

## 8. Evidence files reviewed

- `docs/testing/phase-00-page-route-manifest-2026-11-25.csv`
- `docs/testing/phase-00-web-html-route-candidate-manifest-2026-11-25.csv`
- `docs/testing/phase-00-canonical-route-classification-and-redirect-preview-audit-2026-11-25.md`
- `docs/testing/phase-00-route-dependency-and-navigation-trace-2026-11-25.md`
- `docs/testing/phase-00-gate-c2-page-route-manifest-method-and-disposition-2026-11-25.md`
- `sitemap.xml`, `config.js`, `manifest.json`, `public/manifest.webmanifest`
- `scripts/audit-krim-links.mjs`, `scripts/krim-complete-static-audit.mjs`

