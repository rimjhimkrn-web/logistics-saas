# Phase 00 — Complete HTML Route Candidate Inventory

Date: 2026-11-25
Repository: rimjhimkrn-web/logistics-saas
Branch: qa/phase-00-baseline-2026-11-25
Scope: Web platform source tree only; native/mobile apps excluded.

## Result

Recursive Git tree snapshot: 2,464 entries; `truncated=false`.
HTML files excluding vendored `node_modules`: **1,017**.
Public sitemap URLs in the inspected branch: **36**.
Canonical `window.KRIM_ROUTES` registry: **27 keys / 25 unique destination files** (from prior source-level registry audit).

Full row-level candidate inventory: `phase-00-web-html-route-candidate-manifest-2026-11-25.csv` (1,017 HTML paths). Each row includes file path, provisional source classification and verification status.

## Source-tree distribution

| Group | HTML files |
|---|---:|
| Root-level | 37 |
| app/admin | 22 |
| app/customer | 2 |
| app/customs | 29 |
| app/driver | 39 |
| app/enterprise | 14 |
| app/field | 1 |
| app/finance | 24 |
| app/operations | 28 |
| app/partner | 19 |
| app/platform-admin | 21 |
| app/warehouse | 26 |
| auth | 41 |
| control | 1 |
| domains | 13 |
| public (all public subfolders/root) | 673 |
| src | 12 |
| templates | 1 |
| workspaces | 3 |
| Other legal/docs paths | 10 |

Counts are source files, not unique, reachable or commercially functional routes. Some groups are intentionally aliases, shells, previews, redirects, prototypes or source artifacts.

## Canonical route and sitemap interpretation

- The canonical route registry contains 27 keys and 25 unique destination files. Duplicate keys point to the same Customs and Operations entry pages.
- The sitemap contains 36 public URLs. It is a public discovery list, not a complete inventory of authenticated workspaces.
- Prior route-source review confirmed all 27 canonical targets existed in the inspected tree. This does not prove deployed HTTP reachability or functional behavior.
- Examples of aliases/redirects already identified: `app/driver/index.html`, `app/driver/module-01-assignment-inbox.html`, `public/partner/load-marketplace.html`, `public/tracking.html`, and `public/quote-result.html`.
- Some pages explicitly provide preview/local-only behavior, while others are read-only or have paused write actions. Such pages must not be counted as live workflows.

## Provisional route classification

The CSV applies conservative source-path categories only:
- `AUTHENTICATION_OR_ACCOUNT_SYSTEM`: authentication and account lifecycle candidates.
- `PRIVILEGED_ADMIN_CANDIDATE`: admin/control-plane candidates requiring privileged runtime tests.
- `WORKSPACE_APP_CANDIDATE`: app workspace candidates requiring protected runtime tests.
- `PUBLIC_PREFIX_ROUTE_CANDIDATE`: files under `public/`; the directory name does not prove that every page is intended for anonymous access.
- `WORKSPACE_OR_DOMAIN_INFORMATION_CANDIDATE`: workspace/domain information candidates requiring runtime classification.
- `ROOT_OR_LEGACY_ROUTE_CANDIDATE`: root and compatibility candidates requiring canonical/redirect review.
- `INTERNAL_SOURCE_OR_TEMPLATE` / `DOCUMENTATION`: not presumed to be user-facing routes.

Every CSV row is marked unverified. No route is marked PASS solely because a file exists.

## Important discrepancies and limitations

1. Historical reports record tree totals of 2,392, 2,396 and 2,179 for different inspected snapshots/commits. This run observed 2,464 entries at the exact inspected tree SHA. Preserve historical counts; reconcile them by commit before using counts as trend data.
2. The current 1,017 HTML count excludes `node_modules`; earlier report showed 1,023 including vendored package HTML. These are different counting scopes, not necessarily a defect.
3. Source path does not reliably establish whether a page is public, protected, reachable, canonical, retired or a prototype.
4. The candidate manifest does not yet include resolved redirects, script dependencies, role/permission requirements, RPC/Edge Function/table/Storage dependencies, or live HTTP status for every row.
5. No live Pages crawling, authenticated browser access, form submission, RPC execution, database write or provider operation was performed.

## Required next steps

1. Parse every HTML page's title, canonical link, robots/noindex, meta refresh, JS redirects, local script references and navigation links.
2. Resolve redirect chains and deduplicate canonical destinations; retain aliases as explicit rows.
3. Map every candidate to its required authentication/role/AAL, workspace, and frontend/backend dependencies.
4. Establish protected authenticated Staging before live browser reachability and role tests.
5. Add Playwright route tests only after Staging origin and isolation gates pass.

## Safety record

Read-only GitHub tree/source inspection and QA-branch documentation only. No Production or Staging changes, synthetic identities, DB writes, provider calls, deployment or merge.

**Disposition:** Source-tree HTML candidate inventory captured (1,017 rows). Canonical route and runtime classification remains IN PROGRESS; deployed reachability and authorization remain NOT TESTED.