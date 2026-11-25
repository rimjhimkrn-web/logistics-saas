# KRIM Phase 00 — Route and Existing Test-Coverage Checkpoint 04

**Date:** 25 November 2026  
**Scope:** Web platform only; mobile applications excluded.  
**Method:** Read-only source inspection of main-branch HTML entry pages, CI workflow definitions and test scripts.

## 1. HTML inventory interpretation

The recursive repository tree contains 1,023 HTML files. Six are under vendored `node_modules/playwright-core` / Playwright packages, so the repository contains 1,017 first-party HTML files. There are 103 HTML paths under explicit `staging` folders. Counts alone do not identify deployed routes; every candidate still requires route classification.

The largest first-party HTML groups include:
- `public/`: 673 HTML files
- `app/`: 230 HTML files (103 are in explicit staging folders)
- `auth/`: 41 HTML files
- Repository root: 37 HTML files

The `public/` directory is a major part of the platform, not merely marketing pages. Workspace landing pages link into `public/customer-os/`, `public/partner/`, `public/finance/`, `public/warehouse/`, `public/operations/`, `public/shipments/`, `public/quotes/`, `public/support/` and other functional areas. Testing only the 9 `app/*/index.html` pages would miss substantial platform surface.

## 2. Entry-page source inspection

Read-only inspection of the homepage and workspace landing pages confirmed:
- Homepage links into Customer, Partner, Warehouse, Customs, Finance, Enterprise, public quote, tracking and other routes.
- Customer workspace links into customer OS services, booking, quote request, shipment list, tracking, invoices, support, approvals and document vault.
- Partner workspace links into development, individual and business partner pathways.
- Driver landing page is a redirect to `dashboard.html`; it should be treated as a redirect alias, not as a standalone feature.
- Warehouse workspace links to Operations and multiple warehouse public workflows.
- Customs, Finance, Operations, Enterprise and Platform Admin landing pages expose multiple nested routes and controls.

This is static source evidence only. No browser session was launched and no authenticated user journey was executed.

## 3. Existing CI test coverage — verified limitations

The 24 November main-branch deployment, static-link audit and production smoke workflows passed.

Source inspection shows:
- `scripts/audit-krim-links.mjs` walks HTML files outside `.git`, `node_modules`, and `.github`, and checks literal local href/src/action/formaction/poster targets. It also emits heuristic brand/operational-risk findings. These heuristics are review signals, not proof of a feature defect or feature correctness.
- `krim-static-link-audit.yml` enforces broken literal local references, uploads JSON/static audit artifacts, and prints counts for duplicates, redirect aliases, integration candidates and placeholder signals. Those other counts are not all enforced as release-failing assertions.
- `scripts/krim-production-smoke.mjs` performs repository-file presence checks, environment-to-Supabase target checks for selected hostnames, and migration timestamp collision guard checks. It is not a browser-driven, authenticated end-to-end suite.
- Repository tree search found the Playwright package checked into `node_modules`, but no committed Playwright spec files or Playwright configuration were found outside dependencies. A package being present is not evidence that automated browser tests exist or ran.

## 4. Evidence links

- Main-branch deployment run: https://github.com/rimjhimkrn-web/logistics-saas/actions/runs/45375792608
- Main-branch static-link audit run: https://github.com/rimjhimkrn-web/logistics-saas/actions/runs/45375793107
- Main-branch production smoke run: https://github.com/rimjhimkrn-web/logistics-saas/actions/runs/45375793045

Static audit artifacts from run 45375793107:
- `krim-complete-static-audit` (artifact ID 14909784612)
- `krim-static-link-audit` (artifact ID 14909549593)

Smoke workflow artifact from run 45375793045:
- `krim-complete-static-audit` (artifact ID 14911490798)

## 5. Required next actions

1. Reconcile the 1,017 first-party HTML files into production routes, staging-only routes, redirects, internal/admin routes, templates and obsolete/unreachable pages.
2. Follow local navigation, script imports and dynamic route construction beyond literal HTML links.
3. Build a canonical route-to-role-to-permission-to-backend map.
4. Add Playwright browser tests in an explicit test directory with deterministic test data and evidence retention.
5. Make test outcomes fail closed: no swallowed failures and no treating heuristic output as a pass.
6. Provision a safe synthetic staging test harness before authenticated end-to-end tests.

## 6. Phase status

**PHASE 00 remains IN PROGRESS.** No browser-level functional test, artificial-user simulation, load test, or full end-to-end workflow has been executed or certified in this checkpoint.
