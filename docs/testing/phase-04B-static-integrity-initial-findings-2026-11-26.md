# Phase 04B — Static integrity and route dependency audit (initial pass)

Date: 2026-11-26
Inspected source commit: ac71a99d6f3f831081b2c76772fde08235a6a61b
Working branch: remediation/phase-03dw-isolation-2026-11-26

## Scope completed
Read-only inspection of the repository tree, Phase 00 route manifest, shared configuration, homepage, authentication entry, and core Customer, Partner, Driver, Operations, Enterprise and Admin entry pages.

## Inventory reconciliation
- Git tree: 2,400 tracked files, 1,024 HTML files.
- Existing Phase 00 page manifest: 1,023 rows.
- One HTML page is absent from the manifest: scripts/browser-environment-smoke.html.
- No manifest path was found absent from the inspected tree.
- All 1,023 manifest entries still have runtime status NOT TESTED.
- Manifest classifications: 869 ACTIVE/OTHER candidates, 103 STAGING-ONLY candidates, 38 ACTIVE-ENTRY candidates, 13 WORKFLOW ROUTE candidates. These are candidate labels, not runtime dispositions.

## Static findings from core entry pages
1. **Potential GitHub Pages / Cloudflare base-path inconsistency — P1 candidate.** Several shared asset references in index.html, auth/login.html, app/customer/index.html, app/operations/index.html and app/enterprise/index.html are absolute paths beginning /logistics-saas/assets/. That prefix is appropriate for the GitHub Pages project path, but Cloudflare Pages serves the site at the host root. The config.js defines window.krimPath() for environment-aware paths, but the cited static asset references are not consistently routed through it. Confirm with HTTP/browser checks in the actual Staging deployment before assigning final severity or changing references.
2. **Duplicate asset references — cleanup candidate.** app/customer/index.html contains repeated brand script and stylesheet references; app/operations/index.html and app/enterprise/index.html also contain repeated brand assets. Duplicate loads may cause redundant work or repeated event handlers; runtime impact not yet tested.
3. **Partner entrypoints use dynamic script loaders.** Business, Individual and Carrier pages construct scripts at runtime, so a simple HTML src scan is insufficient. Their loader dependency order and exact resolved URLs need dedicated static/runtime inspection.
4. **Shared configuration is environment-aware.** config.js defines the environment-specific krimPath helper and separates GitHub Pages production from Cloudflare preview. This is source evidence only; no deployed behavior was exercised.
5. **Protected entrypoints remain untested.** Login, Customer, Partner, Driver, Operations, Enterprise and Platform Admin contain auth/session logic. Static source inspection cannot prove valid login, correct redirects, role authorization or tenant isolation.
6. **Visual-only Admin staging page.** app/admin/staging/page-01-command-centre.html has no Supabase client/config/auth references in the inspected source and is therefore a visual review surface, not evidence of a working privileged admin workflow.

## Test execution status
- Source tree and manifest reconciliation: PARTIAL PASS.
- Static shared-entry inspection: PARTIAL; findings recorded above.
- Asset HTTP resolution: NOT TESTED.
- Browser console/network: NOT TESTED.
- Responsive and interaction tests: NOT TESTED.
- Authentication/RBAC/tenant isolation: NOT TESTED.
- End-to-end workflow: NOT TESTED.

## Safety
No Production deployment, Staging deployment, database mutation, Edge Function deployment, permission change, test user creation, shipment creation, payment, email, notification or external provider call was performed.

## Gate disposition
**04B — IN PROGRESS.** This is an initial core-entrypoint pass, not a complete audit of all 1,024 HTML pages. Phase 03 security/compliance blockers remain open. No real-user onboarding clearance is granted.

## Next work
Continue 04B across all ecosystem entrypoints and shared assets; inspect dynamic Partner loaders and every canonical route's local script/style/image references; then prepare isolated Staging browser smoke tests only after confirming that the deployed Staging build and environment boundaries are safe.
