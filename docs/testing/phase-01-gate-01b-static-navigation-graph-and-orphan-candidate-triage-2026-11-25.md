# Phase 01 — Gate 01B: Static navigation graph and orphan-candidate triage

Date: 2026-11-25
Repository: `rimjhimkrn-web/logistics-saas`
Immutable source baseline: `72d75a18f985ceb09e468839435ee95700e11e46`
QA branch: `qa/phase-00-baseline-2026-11-25`
Scope: website static HTML navigation graph, literal local reference resolution, redirect aliases and zero-inbound candidate classification. This gate reuses previously executed CI artifacts and reconciles their findings; it does not claim a fresh browser crawl.

## 1. Verdict

**PASS — static navigation graph and literal local-reference checks have prior successful CI evidence. PARTIAL / BLOCKED — five-file census discrepancy, JS-generated routes, external/deep-link sources, redirect runtime behavior and deployed reachability remain unresolved.**

The static graph is useful for prioritizing route verification. It is not proof that a route loads, that an action works, or that authorization is correct.

## 2. Evidence provenance

The repository's `krim-static-link-audit` workflow previously executed both static analyzers on the QA branch:
- Complete static graph report: source commit `3f37e0817bee4ba1ae773f18f9ef5a7ed0e934c0`, workflow run `45593997090`.
- Independent static local-link audit and complete graph: workflow run `45594126547`, audited commit `6306bf1b65fa5b6fffb99986efe0b5603b23a6c1`.
- Follow-up candidate classification and disposition reports: C3.2, C3.3 and C3.4 under `docs/testing/`.

These are historical QA-branch source scans, not a fresh scan of the exact Phase 01 immutable baseline and not runtime evidence. The two graph runs agree on the principal counts below.

## 3. Static navigation graph results

| Measure | Result |
|---|---:|
| HTML pages scanned by CI | 1,018 |
| Literal HTML-to-HTML static edges | 9,453 |
| Pages with at least one inbound literal static HTML link | 757 |
| Zero-inbound HTML candidates | 89 |
| Unresolved local/root references | 0 |
| Canonical route registry keys checked | 27 |
| Canonical route destinations | 25 unique |
| Exact duplicate-content groups | 0 |
| Compatibility redirect routes | 343 |
| noindex pages | 523 |
| Staging HTML pages | 103 |
| Operational-looking non-staging pages without visible Supabase signal in their own HTML | 67 |
| Pages with direct backend/client signals | 312 |
| Pages with backend-related signals in linked local scripts | 350 |
| Operational pages with backend-related signals | 194 |
| Placeholder/demo/TODO wording signals | 0 |

Independent local-link audit also reported zero broken literal local references, zero legacy-brand findings and zero operational-risk heuristic findings. Those are parser-specific static results, not functional test passes.

## 4. Zero-inbound candidate disposition

All 89 zero-inbound candidates were assigned a non-destructive disposition in the existing C3.4 register:

| Disposition | Count | Interpretation |
|---|---:|---|
| KEEP AS DIRECT ENTRY | 28 | Auth, account, system or deep-link destination; not necessarily general navigation |
| RESTRICT | 35 | Internal, privileged, staging or role-bound surface; navigation hiding is not authorization |
| KEEP | 10 | Retain as public/system/documentation route |
| CONSOLIDATE REVIEW | 14 | Potential legacy/duplicate/shell; compare dependencies and owner intent |
| RETIRE REVIEW | 2 | Test fixture/template candidates; removal still requires dependency and owner approval |
| **Total** | **89** | No deletion/retirement authorized |

The 89 candidates include authentication callbacks, password reset, invitation, MFA, session/security pages, internal admin/control pages, public discovery pages, legacy shells, source prototypes and test/template pages. Static zero-inbound status is not evidence that a page is unused: email callbacks, bookmarks, external links, route registry entries and JS-generated navigation may provide legitimate entry.

The canonical route registry has 27 keys / 25 unique destinations. C3.3 reconciled 89 candidates against that registry: one exact registry match and 88 requiring other direct-entry evidence or route-owner review. Source inspection confirmed signup callback and password-reset email destinations; driver invitation token handoff is source-backed but actual invitation delivery and acceptance remain unverified.

## 5. Redirect/compatibility route findings

The analyzer classified 343 HTML files as compatibility redirects:
- 324 under `public/`
- 11 under `app/`
- 3 under `partner/`
- 2 at repository root
- 2 under `legal/`
- 1 under `auth/`

335/343 carry noindex; eight do not. The eight non-noindex redirect destinations exist in the tracked tree, but file existence is not proof of successful browser navigation. Two driver aliases point into a staging-named destination and must not be treated as production-ready. The other 335 destinations have not all been individually verified in a browser.

Required runtime assertions later: final HTTP status, destination, query/hash preservation, safe return-path handling, authentication/session preservation, redirect-loop absence and no accidental transition from public routes into privileged workspaces.

## 6. Census discrepancy — explicit unresolved item

Phase 01A's immutable baseline Git tree contains **1,023 HTML blobs**, while the prior CI graph scans reported **1,018 HTML pages**. The existing CI scanner excludes `.git`, `node_modules`, `.next`, `dist` and `build`; this alone does not explain the five-file difference because the Git tree census counts tracked blobs. The reports also refer to different QA commits.

Therefore:
- Do not present 1,018 as the complete 1,023-page immutable-baseline census.
- Do not assume the missing five are irrelevant, duplicates or non-routes.
- Gate 01B does not mark this discrepancy closed.
- Gate 01C/01D must reconcile the exact five paths by comparing the tree at each audited commit and rerunning the static graph against the exact immutable baseline or an explicitly recorded QA snapshot.

## 7. What the static graph cannot see

1. JavaScript-created links, route builders and SPA history changes unless separately extracted from scripts.
2. External backlinks, emailed links, Auth callback destinations, bookmarks and third-party integrations.
3. Runtime redirects, server-side redirects, HTTP status, TLS, MIME/CSP, missing deployed assets or GitHub Pages 404 behavior.
4. Authentication, role/permission/AAL checks, tenant isolation or backend RPC/RLS enforcement.
5. Form submission success, button behavior, API results, Storage access or real business workflow completion.
6. CSS background assets and dynamically constructed asset paths in all cases.
7. Whether a route is commercially approved, live, or supported by a verified logistics partner.

The 67 operational-looking pages without visible Supabase signals and 48 staging pages without visible backend signals are triage signals only; pages may delegate through shared scripts or be intentionally informational. Conversely, visible backend signals do not prove a successful or authorized operation.

## 8. Required next sub-gates

| Sub-gate | Required work | Status |
|---|---|---|
| 01A repository census | Tracked file and HTML candidate inventory | PASS |
| 01B static navigation graph | Prior CI graph evidence reconciled; zero-inbound dispositions recorded | PASS WITH LIMITATIONS |
| 01C exact five-file reconciliation | Compare audited commits to immutable baseline; identify all five paths and classify | NOT COMPLETE |
| 01D dynamic route extraction | Inspect JS/TS route builders, window.location, history API, onclick/data-href, form targets and auth callback URLs | NOT COMPLETE |
| 01E route ownership/workspace map | Map canonical and direct-entry routes to user type, workspace, permission and AAL | NOT COMPLETE |
| 01F page dependency graph | Map HTML → scripts/styles/assets → Auth/RPC/Edge Functions/tables/Storage | NOT COMPLETE |
| 01G deployed browser route check | Approved browser tests after environment safety gate | BLOCKED |

## 9. Safety and release disposition

- No page was deleted, renamed, modified or redirected.
- No Production or Staging deployment/configuration was changed.
- No database, Auth, Storage, payment, notification or provider operation was performed.
- No synthetic users or real customer/partner data were used.
- No HTTP browser crawl or live redirect test was performed by this gate.
- Phase 01 remains IN PROGRESS.
- Phase 00 overall release remains FAIL / BLOCKED. Real customer booking and operational partner/driver onboarding remain NO-GO pending the consolidated P0 remediation and controlled runtime verification.

## 10. Evidence reviewed

- `phase-00-gate-c3-repository-wide-link-graph-2026-11-25.md`
- `phase-00-gate-c3-repository-wide-static-link-audit-results-2026-11-25.md`
- `phase-00-gate-c3-1-repository-wide-static-link-audit-results-2026-11-25.md`
- `phase-00-gate-c3-2-zero-inbound-route-and-redirect-classification-2026-11-25.md`
- `phase-00-gate-c3-3-canonical-route-and-auth-deeplink-reconciliation-2026-11-25.md`
- `phase-00-gate-c3-4-zero-inbound-route-disposition-register-2026-11-25.md`
- `.github/workflows/krim-static-link-audit.yml`
- `scripts/krim-complete-static-audit.mjs`
- `scripts/audit-krim-links.mjs`
