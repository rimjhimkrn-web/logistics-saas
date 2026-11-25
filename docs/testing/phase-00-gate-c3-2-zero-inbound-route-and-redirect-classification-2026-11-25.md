# Phase 00 — Gate C3.2: zero-inbound route classification and redirect triage

Date: 2026-11-25
Repository: rimjhimkrn-web/logistics-saas
Source baseline: `72d75a18f985ceb09e468839435ee95700e11e46`
Static audit artifact: workflow run `45594112014`, artifact `krim-complete-static-audit`
Classification commit: documentation only on `qa/phase-00-baseline-2026-11-25`.

## 1. Scope and method

Reviewed all 89 zero-inbound candidates from the repository-wide static audit's JSON/Markdown output, using path namespace, filenames, audit metadata (noindex, staging, redirect, backend-signal flags), and their likely application role. This is a static triage classification, not a source-content review of every page or a browser test. No pages were deleted, renamed, hidden, or modified.

Reviewed the 343 detected compatibility redirects by family and priority. The eight redirect candidates without noindex metadata were separately checked for destination-file existence against the complete tracked Git tree at the source baseline.

## 2. Classification of all 89 zero-inbound candidates

| Namespace / class | Count | Disposition |
|---|---:|---|
| `auth/` | 28 | Likely legitimate direct-entry security/account routes; must be wired from auth email links, session states, settings or guarded navigation. |
| `public/` | 39 | Product, informational, operations, analytics, developer, growth and utility pages; route-owner/discoverability review required. |
| `app/` | 7 | Workspace shells, direct entry, reset-password, support and staging routes; verify router/guard registration. |
| Root-level HTML | 5 | Financial management, forgot password, alternate home, shipment preparation and tracking policy; establish canonical owner and link policy. |
| `src/` | 5 | Source/workspace gateway shells; likely internal or prototype route surfaces, not assumed public product pages. |
| `control/` | 1 | Partner verification control route; verify authorized control-plane entry. |
| `docs/` | 1 | Legal document index; direct-entry discoverability and legal navigation review. |
| `platform/` | 1 | Platform shell; likely internal application shell, verify router entry. |
| `scripts/` | 1 | Browser environment smoke fixture; classify as test infrastructure, not customer route. |
| `templates/` | 1 | Connected-page template; classify as scaffold/template, not customer route. |
| **Total** | **89** | |

Additional audit metadata:
- 26 of 89 carry noindex metadata.
- 63 of 89 do not carry noindex.
- 42 show a direct Supabase/backend signal; 47 do not.
- Two are explicitly staging paths: `app/customs/staging/hs-classification.html` and `app/driver/staging/index.html`.

### 2.1 Likely legitimate direct-entry routes — retain pending wiring verification

The 28 `auth/` routes include callback, reset-password, invitation, MFA challenge/enrolment, logout, verification, session-expired, recovery, account-security and organization-switch flows. Zero inbound HTML links are expected for several because the destination can be reached from an email deep link, an authentication redirect, a session event or an authenticated settings action. Do not add all of them to public navigation. Verify exact redirect URL allowlists and the auth router/email templates before calling them connected.

Other plausible direct-entry/system routes:
- `public/404.html` — error fallback.
- `public/offline.html` — offline fallback.
- `app/reset-password.html`, `forgot-password.html` — password recovery entry points; confirm canonical route to avoid duplicate reset flows.
- `scripts/browser-environment-smoke.html` — test fixture, not a product page.
- `templates/krim-connected-page.html` — template, not a live route.
- `src/*` and `platform/krim-platform-shell.html` — internal shells or prototypes; require route registry/entry-point confirmation.

### 2.2 Public discoverability and route ownership review

The following public routes are not safe to label orphaned, but should be reviewed for intended navigation, sitemap/route-registry inclusion, and workspace ownership:
- Public marketing/information: `public/about.html`, `public/partners.html`, `public/industries.html`, `public/global-coverage.html`, `public/warehousing.html`, `public/get-started.html`.
- Product/workspace shells: `public/portal.html`, `public/app/shipper/dashboard.html`, `public/app/carrier/dashboard.html`, `public/app/admin/control-tower.html`, `public/operations/index.html`.
- Analytics/compliance: carrier scorecard, lane analytics, customs audit ledger, dangerous-goods declaration.
- Partner/shipper operations: export center, offboarding, partner bid status, shipper rate calculator.
- Developer/admin/utility: app registration, rate-limit telemetry, platform health, command palette, status, chaos-resilience.
- Growth: customer conversion/retention, network-gap analyzer, onboarding tracker, source governance.

The 39 public paths are a triage list, not a proposed blanket addition to navigation. Several may be internal-only, unlaunched, noindex or informational.

### 2.3 High-priority individual route questions

- `home-v2.html`: determine whether it is an approved alternative homepage or stale experiment; do not replace canonical homepage without owner decision.
- `public/about.html` and `about.html`: potential duplicate public information pages; compare content and canonical metadata before consolidating.
- `public/partners.html` and root `partners.html`: possible duplicate partner acquisition surfaces; verify canonical acquisition route.
- `app/index.html` and `app/field/index.html`: verify if these are intentional role routers or disconnected shells.
- `app/customer/customs-documents.html`: customer-facing customs-document route with a backend signal; verify customer role and navigation.
- `app/platform-admin/support-desk.html` and `control/partner-verification.html`: ensure they are guarded by server-side platform-admin/authorized control-plane permissions, not merely hidden from navigation.
- `public/testing/chaos-resilience.html`: keep out of public customer navigation and verify it exposes no destructive test action to untrusted users.
- `public/krim-global-advertisement.html`: confirm whether this is an active campaign landing page or an unlaunched content route.

## 3. Redirect-family analysis

The static scanner detected 343 redirect routes:
- 324 under `public/`
- 11 under `app/`
- 3 under `partner/`
- 2 at repository root
- 2 under `legal/`
- 1 under `auth/`

335/343 carry noindex; 8 do not. Most `public/` routes appear to be compatibility aliases for consolidated Customer, Driver, Billing, Partner or Operations destinations. This is a useful migration pattern only if the destination remains valid and preserves the intended auth context and query/hash parameters.

### 3.1 Eight redirect candidates missing noindex — destination existence checked

All eight destination paths exist in the tracked source tree after relative-path normalization:

| Redirect source | Target | Tracked target |
|---|---|---|
| `app/driver/index.html` | `./dashboard.html` | YES |
| `app/driver/module-01-assignment-inbox.html` | `./staging/page-02-assignment-inbox.html` | YES |
| `public/customer/shipment-create.html` | `../shipper/booking-request.html` | YES |
| `public/customer-os/visibility/live-tracking-map.html` | `../customer-services/tracking-map.html` | YES |
| `public/legal/privacy.html` | `../../privacy.html` | YES |
| `public/legal/refund-policy.html` | `../../refund.html` | YES |
| `public/legal/terms.html` | `../../terms.html` | YES |
| `public/shipments/pickup.html` | `../pickup-tracking.html` | YES |

This proves only that the destination files exist in the source tree. It does not prove browser navigation, HTTP 200, query/hash preservation, auth guard behavior or absence of redirect loops. In particular, two driver aliases route into a staging-named destination and must not be treated as production-ready simply because the file exists.

### 3.2 Redirect remediation policy

- Preserve all existing aliases until inbound references, external backlinks and partner integrations have been assessed.
- Ensure all compatibility redirects are noindex unless there is an explicit SEO decision.
- Do not redirect authenticated workspace routes to a destination that drops the intended workspace or session context.
- Resolve redirect chains to a canonical destination and test for loops.
- Review aliases that target `staging/` directories before any production route is enabled.
- Retire only after route owner approval, inbound-reference review, browser verification and regression evidence.

## 4. Disposition

| Category | Status |
|---|---|
| 89 candidates classified by namespace/purpose | PASS (static triage) |
| Legitimate auth/system direct-entry candidates identified | PASS (classification only) |
| Eight non-noindex redirect destinations exist in tracked tree | PASS (source existence only) |
| Remaining 335 redirect destinations individually validated | NOT TESTED |
| All 343 redirects followed in browser | NOT TESTED |
| 89 routes checked against all JS-generated links, email templates and route registries | NOT TESTED |
| True orphan determination / page retirement approval | NOT TESTED |
| Deployed production/staging HTTP route checks | BLOCKED by staging identity/deployment gate |

**Gate C3.2: PARTIAL PASS / BLOCKED.** The audit now has a reviewable classification and explicit non-destructive disposition. No candidate is approved for deletion or retirement.

No application source, Production/Staging configuration, deployment, database, payment, notification or external provider state changed.
