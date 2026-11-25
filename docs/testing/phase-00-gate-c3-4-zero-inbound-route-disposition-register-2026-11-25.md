# Phase 00 — Gate C3.4: zero-inbound route disposition register

Date: 2026-11-25
Source baseline: `72d75a18f985ceb09e468839435ee95700e11e46`
QA branch: `qa/phase-00-baseline-2026-11-25`
Scope: non-destructive disposition of all 89 zero-inbound HTML candidates using C3.1 inventory, C3.2 triage, C3.3 route/auth checks, and targeted source inspections. No app routes were changed.

## Disposition meanings

- **KEEP** — retain as an intentional public/product route; this is not a claim that all functionality or commercial claims are runtime-verified.
- **KEEP AS DIRECT ENTRY** — retain for email, authentication, system fallback, or explicit deep-link entry; do not add to general public navigation.
- **RESTRICT** — keep the file but require/verify role, environment, or internal access controls; noindex and navigation hiding are not authorization.
- **CONSOLIDATE REVIEW** — potential duplicate/legacy/shell; compare callers, content, auth behavior and SEO before deciding canonical ownership.
- **RETIRE REVIEW** — appears test-only, template-only, preview-only or stale candidate; do not delete until owner approval and dependency review.

## 1. Full 89-route register

| # | Route | Disposition | Reason / required control |
|---:|---|---|---|
| 1 | `app/customer/customs-documents.html` | RESTRICT | Customer customs-document workspace; noindex and authenticated permission/RLS signals observed. Verify shipment/org scope and document access. |
| 2 | `app/customs/staging/hs-classification.html` | RESTRICT | Explicit staging visual preview; noindex; page says no live tariff/classification service. Keep out of production product navigation. |
| 3 | `app/driver/staging/index.html` | RESTRICT | Explicit staging review page with no auth/backend signals. Do not expose as production driver entry. |
| 4 | `app/field/index.html` | CONSOLIDATE REVIEW | Field workspace shell loads platform/portal modules; role ownership and actual route contract not established. |
| 5 | `app/index.html` | CONSOLIDATE REVIEW | Legacy customer workspace. Prior audit found it accepts any active organization membership without checking customer organization type. Prefer newer `app/customer/index.html`; remediate/migrate before retirement. |
| 6 | `app/platform-admin/support-desk.html` | RESTRICT | noindex restricted support desk; source checks platform-admin roles and claims server AAL2/action permission. Runtime denial tests still required. |
| 7 | `app/reset-password.html` | CONSOLIDATE REVIEW | Alternate reset page; active `auth/forgot-password.html` sends reset email to `auth/reset-password.html`. Compare dependencies before retiring. |
| 8 | `auth/account-deactivation.html` | KEEP AS DIRECT ENTRY | Sensitive account lifecycle page; retain behind authenticated confirmation and server authorization. |
| 9 | `auth/account-deletion.html` | KEEP AS DIRECT ENTRY | Sensitive account lifecycle page; retain behind authenticated confirmation, retention/legal checks and server authorization. |
| 10 | `auth/account-recovery-status.html` | KEEP AS DIRECT ENTRY | Account recovery status helper; authenticated/recovery context only. |
| 11 | `auth/active-sessions.html` | KEEP AS DIRECT ENTRY | Session management/security page; retain behind account authentication. |
| 12 | `auth/auth-callback.html` | KEEP AS DIRECT ENTRY | Confirmed signup email callback; code exchange then role-specific sign-in. Never grant workspace access from email confirmation alone. |
| 13 | `auth/backup-codes.html` | KEEP AS DIRECT ENTRY | MFA recovery/security function; verify secure one-time generation, display and invalidation. |
| 14 | `auth/change-email.html` | KEEP AS DIRECT ENTRY | Account email-change flow; require reauthentication and provider verification. |
| 15 | `auth/change-password.html` | KEEP AS DIRECT ENTRY | Authenticated password change; enforce consistent password policy and reauthentication. |
| 16 | `auth/change-phone.html` | KEEP AS DIRECT ENTRY | Phone update/verification entry; provider and country-code behavior remain to be tested. |
| 17 | `auth/consent-management.html` | KEEP AS DIRECT ENTRY | Account consent settings; separate essential service notices from optional marketing consent. |
| 18 | `auth/device-management.html` | KEEP AS DIRECT ENTRY | Account/device security page; verify device revocation semantics. |
| 19 | `auth/disabled.html` | KEEP AS DIRECT ENTRY | Disabled-account state/notice; preserve as direct system destination. |
| 20 | `auth/identity-verification.html` | KEEP AS DIRECT ENTRY | Identity verification journey; evidence and review access must be server-authorized. |
| 21 | `auth/invitation.html` | KEEP AS DIRECT ENTRY | Invitation direct-entry route; verify token issuer, expiry, recipient binding and replay protection. |
| 22 | `auth/logout.html` | KEEP AS DIRECT ENTRY | Logout/system action route; verify global versus local revocation outcome. |
| 23 | `auth/mfa-challenge.html` | KEEP AS DIRECT ENTRY | MFA challenge destination; enforce AAL2 on sensitive server operations. |
| 24 | `auth/mfa-enroll.html` | KEEP AS DIRECT ENTRY | MFA enrollment destination; verify factor enrollment, confirmation and recovery. |
| 25 | `auth/organization-invitation-acceptance.html` | KEEP AS DIRECT ENTRY | Token-entry UI exists. Actual invitation email sender/template and server acceptance flow are not proven; fail closed until verified. |
| 26 | `auth/organization-switch.html` | KEEP AS DIRECT ENTRY | Authenticated membership switch; database authorization must not trust client-selected organization. |
| 27 | `auth/owner-testing-mfa.html` | RESTRICT | Owner test route; prove server-side owner gate and exclude from public navigation/indexing. |
| 28 | `auth/owner-testing-reset-password.html` | RESTRICT | Owner test route; prove server-side owner gate and prevent real-user reset actions. |
| 29 | `auth/partner-redirect.html` | KEEP AS DIRECT ENTRY | Partner gateway route; source checks session, but staging preview deliberately bypasses auth. Verify only approved deployed environment behavior. |
| 30 | `auth/passkey-management.html` | KEEP AS DIRECT ENTRY | Account security entry; verify provider support and recovery fallback. |
| 31 | `auth/reset-password.html` | KEEP AS DIRECT ENTRY | Confirmed reset email destination; PKCE/recovery session and MFA checks present in source. |
| 32 | `auth/session-expired.html` | KEEP AS DIRECT ENTRY | System/session-expiry destination; preserve safe return-path handling. |
| 33 | `auth/step-up-verification.html` | KEEP AS DIRECT ENTRY | Sensitive action step-up route; verify resulting AAL2 server-side. |
| 34 | `auth/verify-email.html` | KEEP AS DIRECT ENTRY | Manual signup OTP/resend flow exists; active signup flow primarily uses callback-code path. |
| 35 | `auth/verify-phone.html` | KEEP AS DIRECT ENTRY | Phone verification direct-entry; verify provider setup and anti-abuse controls. |
| 36 | `control/partner-verification.html` | RESTRICT | Internal partner verification control desk; noindex and auth/backend signals. Enforce privileged control-plane authorization server-side. |
| 37 | `docs/legal/index.html` | KEEP | Legal document index; link from legal/footer surfaces and keep version ownership clear. |
| 38 | `financial-management.html` | CONSOLIDATE REVIEW | Root-level financial-management route may overlap Finance workspace. Do not expose privileged finance controls through a legacy entry. |
| 39 | `forgot-password.html` | CONSOLIDATE REVIEW | Root-level alternate; inspected login links to `auth/forgot-password.html`. Compare before retirement. |
| 40 | `home-v2.html` | CONSOLIDATE REVIEW | Alternate homepage/experiment; canonical homepage ownership and external references need product approval. |
| 41 | `platform/krim-platform-shell.html` | RESTRICT | Internal platform shell; verify trusted router entry and server-side role enforcement. |
| 42 | `public/404.html` | KEEP AS DIRECT ENTRY | Public error fallback; retain as system route. |
| 43 | `public/about.html` | KEEP | Public institutional/about page; retain as public informational route. |
| 44 | `public/admin/platform-health.html` | RESTRICT | Operational platform-health surface; require admin/operator authorization and noindex. |
| 45 | `public/analytics/carrier-scorecard.html` | RESTRICT | Operational/partner analytics; require tenant-scoped access and prevent cross-partner disclosure. |
| 46 | `public/analytics/lane-analytics.html` | RESTRICT | Commercial/operational lane analytics; verify data source, role access and tenant scoping. |
| 47 | `public/app/admin/control-tower.html` | RESTRICT | Admin control-tower surface; verify privileged authorization and no public data leakage. |
| 48 | `public/app/carrier/dashboard.html` | RESTRICT | Carrier dashboard shell; verify canonical partner workspace mapping and tenant-scoped backend. |
| 49 | `public/app/command-palette.html` | RESTRICT | Shared command palette; verify authenticated context and hide privileged actions from unauthorized roles. |
| 50 | `public/app/shipper/dashboard.html` | RESTRICT | Shipper dashboard shell; verify customer organization membership and data isolation. |
| 51 | `public/compliance/customs-audit-ledger.html` | RESTRICT | Compliance/audit records are sensitive; enforce jurisdiction and organization permissions. |
| 52 | `public/compliance/dangerous-goods-decl.html` | RESTRICT | Regulated shipment declarations; require authenticated authorized roles and validated data. |
| 53 | `public/customer-os/rates-coverage/shipper-rate-calculator.html` | KEEP | Customer-facing calculator may be useful as a public tool only if clearly marks estimates and never represents unverified live rates/capacity as confirmed. |
| 54 | `public/customer-os/review-all-pages.html` | RESTRICT | Review/index surface; keep out of public navigation and verify it exposes no internal route inventory or sensitive metadata. |
| 55 | `public/developer/app-registration.html` | RESTRICT | Developer application registration; verify authentication, ownership, key issuance and abuse controls. |
| 56 | `public/developer/rate-limit-telemetry.html` | RESTRICT | Developer/operational telemetry; keep private to authorized developer/admin roles. |
| 57 | `public/freight/broker-management.html` | RESTRICT | Broker management is operational; require authenticated organization membership and role checks. |
| 58 | `public/freight/carrier-bookings.html` | RESTRICT | Carrier booking operations; verify partner membership, assignment and shipment authorization. |
| 59 | `public/freight/forwarder-dashboard.html` | RESTRICT | Forwarder dashboard; verify tenant-specific partner access and no cross-org data. |
| 60 | `public/freight/trade-dashboard.html` | RESTRICT | Trade dashboard; verify intended audience and data classification. |
| 61 | `public/get-started.html` | KEEP | Public onboarding/CTA route; ensure service claims are conditional on verified route/partner availability. |
| 62 | `public/global-coverage.html` | KEEP | Public coverage information only when clearly distinguishes verified live corridors from planned/aspirational geography. |
| 63 | `public/growth/customer-conversion.html` | RESTRICT | Internal growth/CRM surface; restrict to authorized acquisition operators. |
| 64 | `public/growth/customer-retention.html` | RESTRICT | Internal customer retention/CRM surface; restrict and apply consent/data minimization. |
| 65 | `public/growth/network-gap-analyzer.html` | RESTRICT | Internal network intelligence; restrict partner/customer commercial data. |
| 66 | `public/growth/onboarding-tracker.html` | RESTRICT | Internal onboarding operations; restrict applicant and partner records. |
| 67 | `public/growth/source-governance.html` | RESTRICT | Internal source/prospect governance; restrict access and personal data. |
| 68 | `public/industries.html` | KEEP | Public industry information; ensure claims match currently supported services. |
| 69 | `public/krim-global-advertisement.html` | CONSOLIDATE REVIEW | Campaign landing page; confirm campaign status, claims and canonical CTA before publishing/promoting. |
| 70 | `public/offline.html` | KEEP AS DIRECT ENTRY | Offline fallback/system page; retain for service-worker/offline handling. |
| 71 | `public/operations/autonomous-reroute.html` | RESTRICT | Operational rerouting/automation surface; never allow unapproved route changes or claims of autonomous execution. |
| 72 | `public/operations/index.html` | RESTRICT | Operations workspace entry; verify operations.view and shipment-level authorization, not merely hidden navigation. |
| 73 | `public/partner/export-center.html` | RESTRICT | Partner data export; verify org-scoped authorization, export audit and data minimization. |
| 74 | `public/partner/offboarding.html` | RESTRICT | Partner offboarding; require authorized partner/admin roles and explicit confirmation. |
| 75 | `public/partners.html` | KEEP | Public partner acquisition information; compare with root `partners.html` and establish one canonical public URL. |
| 76 | `public/portal.html` | CONSOLIDATE REVIEW | Institutional login/portal entry; compare with canonical `auth/access.html` and workspace gateways. Do not treat marketing-facing portal shell as an authorization boundary. |
| 77 | `public/shipper/partner-bid-status.html` | RESTRICT | Commercial bid status; require authenticated shipper organization and shipment-level authorization. |
| 78 | `public/status.html` | KEEP | Public service status page if it reports only validated operational status and does not leak internal telemetry. |
| 79 | `public/testing/chaos-resilience.html` | RESTRICT | Testing/chaos surface; exclude from public navigation, noindex and enforce server-side test-owner access; no destructive action without explicit controlled test authorization. |
| 80 | `public/warehousing.html` | KEEP | Public warehousing information; represent actual coverage only after warehouse partner/capability verification. |
| 81 | `scripts/browser-environment-smoke.html` | RETIRE REVIEW | Test fixture, not a customer route. Retain only while referenced by CI; remove only after dependency check. |
| 82 | `shipment-preparation.html` | CONSOLIDATE REVIEW | Root shipment preparation route; compare with canonical booking/shipper shipment creation and verify no duplicate submission path. |
| 83 | `shipment-tracking-policy.html` | KEEP | Public tracking policy/information route; link from tracking/legal help where appropriate. |
| 84 | `src/auth/unified_gateway.html` | CONSOLIDATE REVIEW | Source/prototype authentication gateway; compare against active `auth/access.html` and sign-in pages before retirement. |
| 85 | `src/customer/workspace.html` | CONSOLIDATE REVIEW | Source/prototype customer workspace; verify no deployed router or legacy dependency. |
| 86 | `src/driver/app.html` | CONSOLIDATE REVIEW | Source/prototype driver app; compare with active `app/driver/index.html` and route dependencies. |
| 87 | `src/enterprise/portal.html` | CONSOLIDATE REVIEW | Source/prototype enterprise portal; compare with active `app/enterprise/index.html`. |
| 88 | `src/partner/workspace.html` | CONSOLIDATE REVIEW | Source/prototype partner workspace; compare with active `app/partner/index.html`. |
| 89 | `templates/krim-connected-page.html` | RETIRE REVIEW | Template scaffold, not a customer route. Retain while page-generation dependencies exist; remove only after dependency check. |

## 2. Important cross-route controls

1. **Legacy customer workspace:** `app/index.html` remains a known weaker route guard than `app/customer/index.html`. Do not treat the page as safe merely because it has an auth check. The route must be fixed, migrated or retired only after dependency review.
2. **Auth email destinations:** `auth/auth-callback.html` and `auth/reset-password.html` are source-confirmed direct-entry targets. Supabase Site URL, redirect allowlist and actual email templates remain unverified.
3. **Invitation flows:** driver invite token handoff is source-backed; organization invite sender/template and end-to-end acceptance remain unverified.
4. **Staging routes:** `app/customs/staging/hs-classification.html` and `app/driver/staging/index.html` must not be represented as live services.
5. **Privileged/internal surfaces:** `control/partner-verification.html`, `app/platform-admin/support-desk.html`, admin control tower, platform health, growth, developer and chaos/testing pages require server-side authorization. Noindex or lack of navigation is not a security control.
6. **Commercial claims:** public coverage, warehousing, rate calculators, autonomous reroute and advertisement pages must not imply live service coverage, confirmed rates, autonomous actions or capacity without verified partner/service evidence.
7. **Compatibility redirects:** retain existing 343 redirects pending browser chain, auth context, query/hash and loop tests. Do not delete or alter aliases during this gate.

## 3. Verification and limitations

- The C3.1 CI static audit scanned 1,018 HTML files and 9,453 literal HTML edges; it reported zero unresolved local/root references and 27/27 canonical route registry targets existing.
- The 89 paths above are the complete C3.1 zero-inbound list.
- Targeted source inspection confirmed: `app/index.html` legacy customer shell; `app/platform-admin/support-desk.html` noindex plus platform-admin role check; `app/customer/customs-documents.html` noindex plus backend/permission signals; customs staging page explicitly disclaims live classification; driver staging page has no backend/auth signals; `control/partner-verification.html` is noindex and has an environment-specific staging preview; public about/partners/industries/global-coverage/get-started are public informational pages; public portal is auth/backend-aware.
- The registry is a reasoned disposition, not a complete full-content review of all 89 pages. Some entries are deliberately conservative based on path and purpose.
- Static links do not establish runtime HTTP, rendering, access denial, tenant isolation, working APIs, or email delivery.
- No Production or Staging settings, database, users, emails, external providers, pages or application source were modified.

## 4. Gate result

| Item | Status |
|---|---|
| All 89 zero-inbound candidates enumerated | PASS |
| All 89 assigned a non-destructive disposition | PASS |
| High-risk legacy and privileged routes identified | PASS |
| Source-level auth/deep-link spot checks | PARTIAL PASS |
| All 89 full content and dependencies reviewed | NOT TESTED |
| Browser/HTTP/deep-link/redirect runtime checks | BLOCKED |
| Route owner approvals for consolidation/retirement | NOT TESTED |

**Gate C3.4: PARTIAL PASS / BLOCKED.** This register recommends what to keep, directly enter, restrict, or review; it does not authorize deletion or route changes.
