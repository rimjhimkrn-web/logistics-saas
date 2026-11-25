# Phase 00 — Gate C3.1: repository-wide static link graph audit — results

Date: 2026-11-25
Repository: rimjhimkrn-web/logistics-saas
Branch: `qa/phase-00-baseline-2026-11-25`
Audited commit: `47d38c9bc96266f4c02167500e0f2da79ad4667f`
Workflow: [KRIM static link audit — run 45594112014](https://github.com/rimjhimkrn-web/logistics-saas/actions/runs/45594112014)
Workflow conclusion: SUCCESS
Artifact: `krim-complete-static-audit` (artifact ID 15012162215; SHA-256 `bc8b73df21ee0cca5d0066435f7fb8dd2be184cb7dacc14b9411fed889e38c39`)
Second artifact: `krim-static-link-audit` (artifact ID 15011633407; SHA-256 `ac2c25b8d6b27a16cc031b320f4cb138b258c7f989b9db0b6058b2351aab82b7`)

## 1. Repository-wide static scan results

| Metric | Result |
|---|---:|
| Repository files scanned | 2,132 |
| HTML pages scanned | 1,018 |
| Literal static HTML edges | 9,453 |
| HTML pages with at least one inbound static HTML link | 757 |
| Zero-inbound HTML candidates | 89 |
| Unresolved local/root references | 0 |
| Canonical route registry entries checked | 27 |
| Exact duplicate-content groups | 0 |
| Placeholder/demo wording candidates | 0 |
| Compatibility redirect routes detected | 343 |
| noindex pages | 523 |
| Staging pages | 103 |
| Staging pages without visible Supabase/backend signals | 48 |
| Operational-looking pages without visible Supabase/backend signals | 67 |
| HTML pages with direct backend/client signals | 312 |
| HTML pages with backend-related signals in linked local scripts | 350 |
| Operational pages with at least one backend-related signal | 194 |

The independent link-audit artifact reported 1,018 HTML pages, 27 canonical routes, **0 broken local references**, 0 legacy-brand findings and 0 operational-risk pattern findings. The workflow's eight steps completed successfully, including its final broken-link enforcement step.

## 2. Zero-inbound candidates — do not treat as confirmed orphans

The scanner found 89 HTML files with no inbound *literal static HTML edge*. These are candidates for manual route ownership review, not pages approved for deletion or retirement. Some may be direct-entry authentication pages, email-link destinations, deep links, internal shells, noindex pages, or JS-generated navigation targets.

Prefix distribution:
- `public/`: 39
- `auth/`: 28
- `app/`: 7
- `src/`: 5
- One each: `control/`, `docs/`, root `financial-management.html`, root `forgot-password.html`, root `home-v2.html`, `platform/`, `scripts/`, root `shipment-preparation.html`, root `shipment-tracking-policy.html`, `templates/`.

26 of the 89 candidates are marked noindex; 2 are in staging paths. The scanner did not identify these 89 as redirects. No page was deleted or modified.

### Full candidate list

```text
app/customer/customs-documents.html
app/customs/staging/hs-classification.html
app/driver/staging/index.html
app/field/index.html
app/index.html
app/platform-admin/support-desk.html
app/reset-password.html
auth/account-deactivation.html
auth/account-deletion.html
auth/account-recovery-status.html
auth/active-sessions.html
auth/auth-callback.html
auth/backup-codes.html
auth/change-email.html
auth/change-password.html
auth/change-phone.html
auth/consent-management.html
auth/device-management.html
auth/disabled.html
auth/identity-verification.html
auth/invitation.html
auth/logout.html
auth/mfa-challenge.html
auth/mfa-enroll.html
auth/organization-invitation-acceptance.html
auth/organization-switch.html
auth/owner-testing-mfa.html
auth/owner-testing-reset-password.html
auth/partner-redirect.html
auth/passkey-management.html
auth/reset-password.html
auth/session-expired.html
auth/step-up-verification.html
auth/verify-email.html
auth/verify-phone.html
control/partner-verification.html
docs/legal/index.html
financial-management.html
forgot-password.html
home-v2.html
platform/krim-platform-shell.html
public/404.html
public/about.html
public/admin/platform-health.html
public/analytics/carrier-scorecard.html
public/analytics/lane-analytics.html
public/app/admin/control-tower.html
public/app/carrier/dashboard.html
public/app/command-palette.html
public/app/shipper/dashboard.html
public/compliance/customs-audit-ledger.html
public/compliance/dangerous-goods-decl.html
public/customer-os/rates-coverage/shipper-rate-calculator.html
public/customer-os/review-all-pages.html
public/developer/app-registration.html
public/developer/rate-limit-telemetry.html
public/freight/broker-management.html
public/freight/carrier-bookings.html
public/freight/forwarder-dashboard.html
public/freight/trade-dashboard.html
public/get-started.html
public/global-coverage.html
public/growth/customer-conversion.html
public/growth/customer-retention.html
public/growth/network-gap-analyzer.html
public/growth/onboarding-tracker.html
public/growth/source-governance.html
public/industries.html
public/krim-global-advertisement.html
public/offline.html
public/operations/autonomous-reroute.html
public/operations/index.html
public/partner/export-center.html
public/partner/offboarding.html
public/partners.html
public/portal.html
public/shipper/partner-bid-status.html
public/status.html
public/testing/chaos-resilience.html
public/warehousing.html
scripts/browser-environment-smoke.html
shipment-preparation.html
shipment-tracking-policy.html
src/auth/unified_gateway.html
src/customer/workspace.html
src/driver/app.html
src/enterprise/portal.html
src/partner/workspace.html
templates/krim-connected-page.html
```

## 3. Redirect route findings

343 HTML files were classified by the script as compatibility redirects. 335 of those also carry noindex metadata. This strongly suggests a large alias/compatibility layer, but does not establish that every redirect target resolves or that redirect chains terminate correctly. Eight redirect candidates are not noindex and should receive manual review.

Examples include:
- `admin.html` → `admin-control-center.html`
- `admin-login.html` → `auth/login.html?workspace=platform_admin`
- `app/driver/index.html` → `./dashboard.html`
- Multiple `public/customer/*` aliases → `public/customer-os/customer-services/*`
- Multiple `public/driver/*` aliases → `app/driver/staging/*`

No redirect was changed. Browser redirect-chain testing remains pending.

## 4. Operational integration signal candidates

The static scanner flagged 67 operational-looking pages with no visible Supabase/backend signal in the HTML or linked local JS. This is a triage queue only: pages may be informational, legal, UI shells, intentionally read-only, or use a shared backend path the heuristic does not recognize. It does not prove they are nonfunctional.

The 48 staging pages without visible backend signals are also a separate staging-only triage set; do not treat them as production defects without route/environment classification.

## 5. What this proves — and what it does not

**Proven by this CI run:** at the audited QA branch commit, the static scripts scanned 1,018 HTML files; no unresolved local/root references were reported; 27 canonical route registry entries resolved; artifacts were uploaded; the workflow and final enforcement step succeeded.

**Not proven:** deployed GitHub Pages HTTP status, browser rendering, redirect destinations/loops, JS-generated navigation, authentication and authorization, true orphan status, page business purpose, Supabase runtime connectivity, integration correctness, or any user journey. A backend-related code signal is not proof of a working integration.

## 6. Gate disposition

- Repository-wide literal local-reference scan: PASS (0 unresolved; 1,018 pages).
- Canonical route registry static check: PASS (27/27).
- Static graph extraction: PASS (9,453 edges; 757 pages have inbound static HTML links).
- 89 zero-inbound candidates: REVIEW REQUIRED; NOT TESTED as true orphans.
- 343 redirect candidates: NOT TESTED in browser.
- 67 operational integration-signal candidates: REVIEW REQUIRED; NOT TESTED at runtime.
- Gate C3.1: PARTIAL PASS / BLOCKED for full route verification.

No Production/Staging deployment, database, provider, or application source changed. This was a QA-branch documentation commit and read-only CI analysis.
