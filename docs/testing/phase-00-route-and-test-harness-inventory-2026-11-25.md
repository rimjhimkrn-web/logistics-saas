# KRIM Phase 00 — Web Route and Test-Harness Inventory

**Audit date:** 2026-11-25  
**Repository:** `rimjhimkrn-web/logistics-saas`  
**Branch inspected:** `qa/phase-00-baseline-2026-11-25`  
**Scope:** Web platform only. Mobile app source/workflows are excluded from acceptance scope.

## 1. Recursive Git tree result

GitHub's recursive tree API returned `truncated=false` and 2,392 entries for the inspected branch.

| Measure | Observed count |
|---|---:|
| HTML files excluding `node_modules` | 1,017 |
| HTML files including vendored `node_modules` | 1,023 |
| Public HTML files | 673 |
| Non-public HTML files | 344 |
| Public sitemap URLs | 36 |
| Named canonical route-registry entries in `config.js` | 26 |

The 1,017 count is therefore consistent when vendored `node_modules` files are excluded. The 2,392 tree-entry count is the current recursive GitHub API observation; the earlier 2,179 count in the baseline report is a discrepancy to reconcile against the exact tree snapshot/commit used for that first count. Do not silently replace one count with the other.

## 2. HTML files by application workspace

| Workspace directory | HTML files |
|---|---:|
| Customer | 2 |
| Partner | 19 |
| Driver | 39 |
| Warehouse | 26 |
| Customs | 29 |
| Finance | 24 |
| Operations | 28 |
| Enterprise | 14 |
| Platform Admin | 21 |
| Additional app/admin/field and auth shell files | present separately |

These are source file counts, not counts of user-facing pages that are all reachable or production-ready. The platform also contains 673 HTML files under `public/`, plus authentication, control, domain, workspaces, templates and root-level pages.

## 3. Public directory distribution

| Public directory | HTML files |
|---|---:|
| customer-os | 78 |
| partner | 75 |
| enterprise | 48 |
| customer | 40 |
| finance | 36 |
| driver | 32 |
| warehouse | 32 |
| app | 27 |
| freight | 26 |
| operations | 26 |
| growth | 22 |
| shipments | 22 |
| ai | 21 |
| support | 20 |
| Other public folders and public root | remaining files |

This distribution demonstrates why a simple count of root-level HTML files would materially understate the web platform.

## 4. Test harness discovery

- The repository contains static audit and smoke-check scripts.
- The production smoke workflow calls `scripts/krim-production-smoke.mjs` and `scripts/krim-complete-static-audit.mjs`.
- The static-link workflow calls `scripts/audit-krim-links.mjs`.
- A filename scan for conventional `*.test.*` and `*.spec.*` files found only vendored Playwright package files under `node_modules`; it did not find a project-owned Playwright/Cypress/Vitest/Jest test suite by those naming conventions.
- This filename scan is not exhaustive proof that no tests exist: scripts may contain inline assertions or use non-standard filenames. It does establish that a dedicated project-owned browser E2E suite was not apparent from this scan.

## 5. Route classification still required

Each of the 1,017 HTML files must be assigned one classification:
1. Public production route.
2. Authenticated customer route.
3. Authenticated partner route.
4. Authenticated driver route.
5. Authenticated warehouse route.
6. Authenticated customs route.
7. Authenticated finance route.
8. Authenticated operations route.
9. Authenticated enterprise route.
10. Privileged admin route.
11. Authentication/system route.
12. Compatibility redirect/alias.
13. Internal preview/staging route.
14. Documentation/template/source artifact.
15. Orphan/retired/duplicate candidate requiring human review.

For each route record: file path, canonical URL, role(s), auth requirement, required MFA assurance, environment, redirect target, linked scripts, backend dependencies, sitemap presence, noindex state, and runtime HTTP/browser verification status.

No pages should be deleted or disabled based only on filename similarity or static scan findings.

## 6. Phase 00 status

**Route source-tree inventory: PASS (inventory counts captured).**  
**Route classification: BLOCKED / IN PROGRESS.**  
**Deployed URL and browser reachability: NOT TESTED.**  
**Interactive route authorization: NOT TESTED.**  
**Full browser E2E harness: NOT YET ESTABLISHED.**

The next work item is to generate a row-level route manifest and map each route to shared scripts, APIs/RPCs, Supabase tables and Edge Functions. Continue to keep all runtime/destructive testing away from production.
