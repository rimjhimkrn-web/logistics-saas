# Phase 00 — Gate C3: repository-wide static link and route graph audit

Date: 2026-11-25
Repository: `rimjhimkrn-web/logistics-saas`
Branch: `qa/phase-00-baseline-2026-11-25`
Audited commit: `6306bf1b65fa5b6fffb99986efe0b5603b23a6c1`
Workflow run: `45594126547` — completed SUCCESS
Workflow: `.github/workflows/krim-static-link-audit.yml`

## 1. Repository-wide local-link audit (CI artifact)

The workflow ran `scripts/audit-krim-links.mjs` and produced artifact `krim-static-link-audit` (artifact ID `15012261968`, SHA-256 `0f848f9a9818b36f407a7a759d3ddbff3f9e282e50c4c730fcade8e71756576b`).

- HTML files scanned: **1,018**
- Canonical route registry entries checked: **27**
- Broken literal local references: **0**
- Legacy-brand references: **0**
- Operational-risk heuristic findings: **0**
- Workflow conclusion: **SUCCESS**

The scanner covers literal HTML href/src/action/formaction/poster references and canonical route destinations. Its result is a static source-level check, not HTTP/runtime verification.

## 2. Full static route graph audit

The same workflow ran `scripts/krim-complete-static-audit.mjs`; artifact `krim-complete-static-audit` (ID `15011443682`, SHA-256 `2f476392e05de0368852896c7f8b42c9ffbc2988c3088b83bb351ac1e74cba5b`) was downloaded and its JSON/Markdown contents inspected.

| Metric | Result |
|---|---:|
| Files scanned | 2,133 |
| HTML pages scanned | 1,018 |
| Static HTML link edges | 9,453 |
| Unresolved local references | 0 |
| Pages with inbound literal static links | 757 |
| Zero-inbound HTML candidates | 89 |
| Compatibility redirect routes | 343 |
| Exact duplicate-content groups | 0 |
| Placeholder/TODO wording signals | 0 |
| noindex pages | 523 |
| Staging pages | 103 |
| Staging pages without visible backend signals | 48 |
| Operational-looking pages without visible Supabase signals in their own HTML | 67 |
| Pages with direct backend/client signals | 312 |
| Pages with backend-related signals in linked local scripts | 350 |
| Operational pages with backend-related signals | 194 |

The full JSON and Markdown reports are retained in the GitHub Actions artifact for 14 days from the run. The counts above were read from the downloaded artifact, not inferred from a green badge.

## 3. Zero-inbound candidate triage

The analyzer reports **89 zero-inbound candidates**. This is not a finding that 89 pages are broken or unused. Static inbound-link analysis does not see every legitimate entry mechanism: auth callbacks, emailed links, bookmarks, redirects outside the scanned set, JavaScript-generated routes, deep links and operational entry points.

Of the 89:
- 26 carry a `noindex` marker, consistent with a number of private/auth/internal routes, but still needing route-owner confirmation.
- 2 are under a staging path.
- The remainder require classification by page owner and intended entry mechanism.
- None should be deleted or retired from this report alone.

Priority review candidates include:
- `app/field/index.html`, `app/index.html`, `app/platform-admin/support-desk.html`
- `auth/auth-callback.html`, `auth/invitation.html`, `auth/logout.html`, `auth/mfa-challenge.html`, `auth/mfa-enroll.html`, `auth/reset-password.html`, `auth/verify-email.html`
- `public/404.html`, `public/offline.html`, `public/status.html`
- `src/auth/unified_gateway.html`, `src/customer/workspace.html`, `src/driver/app.html`, `src/enterprise/portal.html`, `src/partner/workspace.html`
- `templates/krim-connected-page.html`, `scripts/browser-environment-smoke.html`

## 4. Redirect route inventory

There are **343 compatibility redirect routes**. They may be deliberate aliases and migration shims. They are excluded from operational integration-candidate counts by the analyzer. Redirect targets have not been tested in a browser or against the deployed GitHub Pages origin; the list is available in the artifact JSON/Markdown. Do not remove aliases without checking inbound references, external bookmarks, auth callbacks and campaign links.

## 5. Integration review signals

The static audit flags 67 operational-looking pages without visible Supabase signals in their own HTML, and 48 Staging pages without visible backend signals. Some may delegate all work to shared scripts, be informational shells, or be deliberate prototypes. Conversely, a visible SDK/API signal does not prove a successful backend transaction. These are prioritization signals for Phase 01/06, not automatic defects or PASS results.

## 6. Important coverage limitations

- The link graph is built from static HTML and local-script signals. It does not prove that JavaScript-created routes, CSS URLs/imports, form submissions, redirects or browser navigation work.
- It does not request live HTTP pages, test deployed HTTP status, MIME type, TLS, CSP, authentication, authorization or tenant isolation.
- Zero-inbound is a candidate classification, not confirmed orphan status.
- 1,018 pages were scanned by the workflow; the earlier Git tree inventory contained 1,023 HTML paths. The CI script's walk excludes `.git`, `node_modules` and `.github`; do not equate the 1,018 count with every path in the Git tree.
- The run was on the QA branch. No merge to main, GitHub Pages deployment, Staging deployment, database mutation or provider call was made.

## 7. Gate C3 disposition

- Repository-wide static local-reference integrity: **PASS** (0 unresolved references in 1,018 scanned HTML pages; 27 canonical routes checked).
- Static route graph generated: **PASS** (9,453 edges).
- Zero-inbound candidate list generated: **PASS as a triage list only** (89 candidates; no orphan deletion decision).
- Redirect behavior/runtime route availability: **NOT TESTED**.
- Whole-tree coverage beyond CI's 1,018-page scan: **NOT TESTED**.
- Gate C3 overall: **PARTIAL PASS / BLOCKED**.

Next recommended task: classify the 89 zero-inbound candidates into expected deep-link/auth/system routes, deliberate prototypes/staging pages, and genuine navigation gaps. Then test redirect and route behavior in an accepted isolated Staging browser environment.