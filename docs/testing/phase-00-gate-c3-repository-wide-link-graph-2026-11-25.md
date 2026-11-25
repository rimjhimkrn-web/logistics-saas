# Phase 00 — Gate C3: Repository-wide static link graph and orphan-candidate scan

Date: 2026-11-25
Repository: `rimjhimkrn-web/logistics-saas`
QA branch: `qa/phase-00-baseline-2026-11-25`
Source scanned by GitHub Actions at commit: `3f37e0817bee4ba1ae773f18f9ef5a7ed0e934c0`
Workflow run: [KRIM static link audit #45593997090](https://github.com/rimjhimkrn-web/logistics-saas/actions/runs/45593997090)

## Method and evidence

Executed the repository's Node.js static audits in GitHub Actions against the complete checked-out QA branch. The run completed successfully and uploaded two artifacts:
- `krim-complete-static-audit` (JSON and Markdown detailed reports)
- `krim-static-link-audit` (local-link audit JSON)

The detailed audit scans tracked working-tree files (excluding configured build/dependency directories), parses literal HTML href/src/action/data-href/formaction attributes, resolves local targets and records HTML-to-HTML static edges. It also classifies redirect routes, staging routes, noindex routes, backend-signal candidates and zero-inbound candidates. This is static source analysis, not a deployed browser crawl.

## Results

| Measure | Result |
|---|---:|
| Files scanned by complete audit | 2,131 |
| HTML pages scanned by complete audit | 1,018 |
| Literal static HTML-to-HTML edges | 9,453 |
| HTML pages with at least one inbound literal static link | 757 |
| Zero-inbound HTML candidates | 89 |
| Unresolved local/root references | 0 |
| Exact duplicate-content groups | 0 |
| Redirect/compatibility routes | 343 |
| noindex pages | 523 |
| Staging HTML pages | 103 |
| Staging pages without visible Supabase signals | 48 |
| Operational-looking non-staging pages without visible Supabase signals | 67 |
| Operational pages with backend-related signals | 194 |
| Pages with direct backend/client signals | 312 |
| Pages with linked local scripts carrying backend signals | 350 |
| Placeholder/demo/TODO wording signals | 0 |

Independent static local-link audit:
- HTML pages scanned: 1,018
- Canonical route destinations checked: 27
- Broken local references: 0
- Legacy brand asset findings: 0
- Operational-risk heuristic findings: 0

## Zero-inbound candidates — NOT confirmed orphans

These 89 pages had no inbound literal static HTML link in the scanned source graph, after excluding recognized redirect routes and root entry filenames. They may still be reached through JavaScript navigation, canonical route registry, auth callbacks, direct bookmarks, external links, forms, API responses or links generated at runtime. No page should be deleted or retired on this evidence alone.

- `app/customer/customs-documents.html`
- `app/customs/staging/hs-classification.html`
- `app/driver/staging/index.html`
- `app/field/index.html`
- `app/index.html`
- `app/platform-admin/support-desk.html`
- `app/reset-password.html`
- `auth/account-deactivation.html`
- `auth/account-deletion.html`
- `auth/account-recovery-status.html`
- `auth/active-sessions.html`
- `auth/auth-callback.html`
- `auth/backup-codes.html`
- `auth/change-email.html`
- `auth/change-password.html`
- `auth/change-phone.html`
- `auth/consent-management.html`
- `auth/device-management.html`
- `auth/disabled.html`
- `auth/identity-verification.html`
- `auth/invitation.html`
- `auth/logout.html`
- `auth/mfa-challenge.html`
- `auth/mfa-enroll.html`
- `auth/organization-invitation-acceptance.html`
- `auth/organization-switch.html`
- `auth/owner-testing-mfa.html`
- `auth/owner-testing-reset-password.html`
- `auth/partner-redirect.html`
- `auth/passkey-management.html`
- `auth/reset-password.html`
- `auth/session-expired.html`
- `auth/step-up-verification.html`
- `auth/verify-email.html`
- `auth/verify-phone.html`
- `control/partner-verification.html`
- `docs/legal/index.html`
- `financial-management.html`
- `forgot-password.html`
- `home-v2.html`
- `platform/krim-platform-shell.html`
- `public/404.html`
- `public/about.html`
- `public/admin/platform-health.html`
- `public/analytics/carrier-scorecard.html`
- `public/analytics/lane-analytics.html`
- `public/app/admin/control-tower.html`
- `public/app/carrier/dashboard.html`
- `public/app/command-palette.html`
- `public/app/shipper/dashboard.html`
- `public/compliance/customs-audit-ledger.html`
- `public/compliance/dangerous-goods-decl.html`
- `public/customer-os/rates-coverage/shipper-rate-calculator.html`
- `public/customer-os/review-all-pages.html`
- `public/developer/app-registration.html`
- `public/developer/rate-limit-telemetry.html`
- `public/freight/broker-management.html`
- `public/freight/carrier-bookings.html`
- `public/freight/forwarder-dashboard.html`
- `public/freight/trade-dashboard.html`
- `public/get-started.html`
- `public/global-coverage.html`
- `public/growth/customer-conversion.html`
- `public/growth/customer-retention.html`
- `public/growth/network-gap-analyzer.html`
- `public/growth/onboarding-tracker.html`
- `public/growth/source-governance.html`
- `public/industries.html`
- `public/krim-global-advertisement.html`
- `public/offline.html`
- `public/operations/autonomous-reroute.html`
- `public/operations/index.html`
- `public/partner/export-center.html`
- `public/partner/offboarding.html`
- `public/partners.html`
- `public/portal.html`
- `public/shipper/partner-bid-status.html`
- `public/status.html`
- `public/testing/chaos-resilience.html`
- `public/warehousing.html`

## Interpretation and follow-up

1. Static source link resolution is clean for the parser's supported literal references: 0 unresolved references across 1,018 HTML pages.
2. The 89 zero-inbound pages are review candidates, not proven orphan pages. Auth lifecycle routes, MFA, recovery, invite, support, internal tools and staging-only routes require explicit ownership/route-registry review before any retirement decision.
3. The 343 redirect routes must be tested for final destination, loops, HTTP status and auth/session preservation in a browser. They are not counted as normal operational integration gaps.
4. The 67 operational-looking non-staging pages without visible Supabase signals require manual source review; some may use APIs, linked scripts or intentionally static guidance. This is not proof of missing integration.
5. The 48 staging pages without visible backend signals remain a separate staging review set.
6. The 523 noindex pages need classification against intended visibility, not automatic removal.
7. No HTTP requests to the deployed KRIM site, authenticated browser journeys, redirects, external links, JS-generated routes, CSP or runtime authorization were tested.

## Gate disposition

- Repository-wide literal local-link checks: PASS (0 unresolved references in both static audits).
- Static inbound-link graph generation: PASS (9,453 edges).
- Zero-inbound candidate detection: PASS as a heuristic; all 89 remain NOT TESTED for true orphan status.
- Redirect behavior and deployed route reachability: NOT TESTED.
- Runtime navigation/auth/session preservation: NOT TESTED.
- Gate C3 overall: PARTIAL PASS / BLOCKED pending route-owner triage and browser verification.

No application page was deleted, no production or staging deployment occurred, and no database/provider state was changed. Only QA-branch audit tooling/workflow and QA evidence documentation were updated.
