# Phase 01 — Gate 01C: HTML census reconciliation and dynamic-navigation source review

Date: 2026-11-25
Repository: `rimjhimkrn-web/logistics-saas`
Immutable source baseline: `72d75a18f985ceb09e468839435ee95700e11e46`
QA branch: `qa/phase-00-baseline-2026-11-25`
Scope: read-only Git tree comparison, scanner exclusion reconciliation and targeted JavaScript/TypeScript route-generation/auth-navigation source review.

## 1. Verdict

- **Gate 01C — PASS: the 1,023 versus 1,018 HTML count discrepancy is explained.**
- **Gate 01D — PARTIAL: primary dynamic route registry and selected navigation/auth helpers inspected; exhaustive JS/TS-generated route extraction is not complete.**
- No source code or runtime environment was changed.

## 2. Exact HTML census reconciliation

The earlier Phase 01A report recorded 1,023 HTML blobs in immutable baseline `72d75a18f985ceb09e468839435ee95700e11e46`. Gate 01B correctly carried the discrepancy as unresolved pending exact path comparison. The exact tree comparison now establishes:

| Snapshot | All tracked HTML blobs | Scanner-excluded HTML | Eligible HTML |
|---|---:|---:|---:|
| Immutable baseline `72d75a1...` | 1,023 | 6 | 1,017 |
| CI scan commit `3f37e08...` | 1,024 | 6 | 1,018 |
| CI scan commit `6306bf1...` | 1,024 | 6 | 1,018 |
| CI scan commit `47d38c9...` | 1,024 | 6 | 1,018 |

The six HTML files excluded by the complete static audit's `IGNORE` set are third-party Playwright Vite report/recorder/trace-viewer pages under `node_modules/playwright-core/lib/vite/`:
1. `dashboard/index.html`
2. `htmlReport/index.html`
3. `recorder/index.html`
4. `traceViewer/index.html`
5. `traceViewer/snapshot.html`
6. `traceViewer/uiMode.html`

The three CI snapshots each add one HTML file not present in the immutable baseline: `scripts/browser-environment-smoke.html`. Thus `1,023 - 6 = 1,017` eligible HTML pages in the baseline, and `1,024 - 6 = 1,018` eligible HTML pages in the later CI commits. The earlier shorthand “five-file discrepancy” was not an accurate path-level explanation; the exact difference consists of six ignored dependency HTML files and one later-added tracked QA smoke fixture.

**Disposition:** discrepancy closed. Do not count the six dependency pages as KRIM website routes. Keep the browser smoke fixture classified as test infrastructure, not a customer route.

## 3. Route registry and dynamic URL construction

The immutable baseline `config.js` was read in full. It defines:
- `window.KRIM_BASE_PATH` from GitHub Pages host/path detection.
- `window.krimPath(path)` to prefix the `/logistics-saas` project base path on GitHub Pages.
- `window.KRIM_ROUTES`, frozen canonical registry with **27 named keys and 25 unique destination paths**.
- `window.krimRoute(routeName, query)`, which resolves a named route, constructs a URL against the current origin and appends nonempty query values using `URLSearchParams`.

The 27 route keys cover home/access/login, nine workspaces (customer, partner, driver, warehouse, customs, finance, operations, enterprise, platform admin), booking/quote/tracking, partner onboarding/marketplace, driver assignments, warehouse inbound/inventory, customs queue, finance invoices, operations control, enterprise shipments and support. Two key pairs intentionally share a destination: customs/customsQueue and operations/operationsControl. This is why 27 keys resolve to 25 unique destinations.

The route helper is source-level evidence only. It does not prove every caller uses it, all route values are valid after deployment, query parameters are safely allow-listed, or session/workspace context is preserved.

## 4. Targeted dynamic-navigation and auth source review

Read-only inspection of selected immutable-baseline source files found:

| Source | Observed route/navigation behavior | Limitation |
|---|---|---|
| `config.js` | Canonical route registry and `krimPath` / `krimRoute` builders | Caller coverage not exhaustively enumerated |
| `auth-core.js` | Redirects to sign-in and MFA challenge using centralized auth route constants | Auth configuration/runtime not tested |
| `core/js/auth-flows.js` | Delayed redirect to `/app/sign-in.html` | Root-relative path requires GitHub Pages base-path validation |
| `public/app/app-runtime.js` | Dynamically creates anchor elements; login redirect and generic link construction | Generated target values not all enumerated |
| `public/app/backend-modules.js` | Constructs links to contact, guides and login destinations in shared UI | Runtime menu rendering not tested |
| `auth/krim-account-actions.js` | Session sign-out then redirect to login | Supabase session behavior not tested |
| `auth/krim-admin-guard.js` | Uses `location.replace(gate)` when guard denies | Backend authorization must remain authoritative |
| `src/lib/auth/auth-context.tsx` | Client-side redirect to `/sign-in` | Source app/prototype route family; no runtime proof |
| `platform/krim-auth.js` | Shared auth helper inspected; no direct route navigation statement found in targeted pattern scan | Other call sites may navigate |

The absolute `/app/sign-in.html` path in `core/js/auth-flows.js` is a **P1 base-path risk** on GitHub Pages, where the app is published beneath `/logistics-saas/`. It needs correction or proof of a compatible redirect handler in a separate remediation gate. Do not modify during inventory.

The `config.js` environment selector maps the GitHub Pages hostname to its production environment and maps non-production hosts to Staging; that is source configuration only and does not establish actual deployed runtime configuration or isolation.

## 5. Route and access risks retained

1. Every dynamic route target must be validated against the exact repository tree and deployment base path.
2. Root-relative paths may escape the GitHub Pages repository prefix.
3. Client-side redirects/guards do not substitute for backend RPC/RLS authorization.
4. Auth email, MFA, invitation and recovery deep links must preserve safe query/token context; no emails or tokens were generated or followed.
5. Dynamic links may point to a route with an incompatible workspace or role guard.
6. Source/prototype Next.js route files under `src/app/` are not automatically deployed website routes; the Pages deployment artifact and actual router ownership must be established.

## 6. Remaining Phase 01 sub-gates

| Sub-gate | Work | Status |
|---|---|---|
| 01A | Repository census | PASS |
| 01B | Static literal navigation graph and zero-inbound triage | PASS WITH LIMITATIONS |
| 01C | Exact HTML count/path reconciliation | PASS |
| 01D | Dynamic JS/TS route extraction | PARTIAL |
| 01E | Route ownership/workspace/permission/AAL mapping | NOT COMPLETE |
| 01F | HTML → JS/CSS/assets → Auth/RPC/Edge/DB/Storage dependency map | NOT COMPLETE |
| 01G | Deployed browser route checks | BLOCKED pending environment and deployment safety proof |

Next priority: systematically extract all route construction and navigation sinks across the 116 non-dependency JS/TS source files in the immutable baseline, then map route targets to intended workspace and access policy. Do not use filenames alone to classify a route as active.

## 7. Safety and release disposition

- Read-only GitHub tree and source-file reads only.
- No source edits, deployments, merges, workflow dispatches or environment changes.
- No Production/Staging SQL/RPC, Auth calls, synthetic users, real emails, tokens, payments, notifications, Storage operations or provider calls.
- No browser/HTTP route crawl performed.
- Phase 01 remains IN PROGRESS; Phase 00 consolidated release decision remains FAIL / BLOCKED. General customer booking and operational partner/driver onboarding remain NO-GO.

## 8. Evidence

- Immutable baseline tree: `72d75a18f985ceb09e468839435ee95700e11e46`
- CI source snapshots: `3f37e0817bee4ba1ae773f18f9ef5a7ed0e934c0`, `6306bf1b65fa5b6fffb99986efe0b5603b23a6c1`, `47d38c9bc96266f4c02167500e0f2da79ad4667f`
- `scripts/krim-complete-static-audit.mjs` — scanner exclusion set
- `config.js` — canonical route registry and route builders
- `auth-core.js`, `core/js/auth-flows.js`, `public/app/app-runtime.js`, `public/app/backend-modules.js`, `auth/krim-account-actions.js`, `auth/krim-admin-guard.js`, `platform/krim-auth.js`, `src/lib/auth/auth-context.tsx`
