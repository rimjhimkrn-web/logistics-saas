# Phase 00 — Gate C3.5: compatibility redirect safety register

Date: 2026-11-25
Repository: rimjhimkrn-web/logistics-saas
Immutable source baseline: `72d75a18f985ceb09e468839435ee95700e11e46`
QA branch: `qa/phase-00-baseline-2026-11-25`
Evidence input: successful repository-wide static audit workflow run `45594112014`, artifact `krim-complete-static-audit` (ID `15012162215`, SHA-256 `bc8b73df21ee0cca5d0066435f7fb8dd2be184cb7dacc14b9411fed889e38c39`). Artifact JSON was downloaded and independently parsed for redirect path, target and redirect-chain relationships.

## 1. Summary

| Check | Result |
|---|---:|
| Compatibility redirect pages | 343 |
| Static target references | 338 |
| Static targets resolving to an HTML file in repository inventory | 338 |
| Script-driven redirect pages requiring runtime/manual resolution | 5 |
| Redirects whose destination is another redirect (chain edges) | 22 |
| Static redirect cycles detected in repository redirect map | 0 |
| Redirect destinations containing a `/staging/` path | 33 |
| Missing static destination files in repository inventory | 0 |

**Important:** “Target resolves” means the referenced target path is present in the static repository HTML inventory. It does not prove deployed HTTP 200, successful rendering, correct auth context, preserved query/hash in every case, or correct business authorization.

## 2. Critical finding — driver aliases route into staging-named pages

**33 of 343 compatibility redirects target `app/driver/staging/*`.** This includes two app-level module aliases and 31 legacy public driver routes.

Two explicit app aliases:
- `app/driver/module-01-assignment-inbox.html` → `./staging/page-02-assignment-inbox.html`
- `app/driver/module-05-pickup-collection.html` → `./staging/page-06-pickup-collection.html`

The legacy public driver group includes:
`public/driver/assigned-trips.html`, `assignment-details.html`, `assignment-inbox.html`, `cargo-condition.html`, `delay-report.html`, `delivery-checklist.html`, `driver-earnings.html`, `driver-settings.html`, `emergency-support.html`, `expense-submission.html`, `failed-delivery.html`, `incident-report.html`, `loading-confirmation.html`, `location-sharing.html`, `maintenance-log.html`, `offline-sync.html`, `performance-metrics.html`, `photo-proof.html`, `pickup-checklist.html`, `pod-submission.html`, `pod-summary.html`, `profile.html`, `recipient-verification.html`, `return-trip.html`, `route-navigation.html`, `safety-checklist.html`, `signature-capture.html`, `support-center.html`, `trip-completion.html`, `trip-details.html`, `trip-status.html`.

These targets exist in the repository, but a staging-named folder is not proof of an isolated staging deployment. The pages need environment/config/auth inspection. **Do not treat the legacy driver aliases as production-ready until this is resolved.** This is the highest-priority redirect issue in this gate.

## 3. Script-driven redirects (five require dedicated browser checks)

| Source | Source-level behavior / risk |
|---|---|
| `auth/login.html` | If query `role=driver`, sends to `auth/driver-signin.html`; otherwise login page handles requested role/workspace and next-path logic. Must test safe return-path allowlist and role routing. |
| `public/admin/siem-audit-logs.html` | Dynamically loads `auth/krim-admin-guard.js`; on load failure redirects to `auth/krim-admin-access.html?reason=guard-unavailable`. Verify denied/failed guard and no content flash. |
| `public/control-centre/facility-matrix.html` | Dynamically loads same admin guard and redirects on load failure. Verify privileged page fails closed. |
| `public/partner/pickup-confirmation.html` | Outside hostname `krim-staging.pages.dev`, redirects to `../pickup-tracking.html`; preserves `shipment` query and hash. On that staging hostname it renders a browser-only illustrative checklist, not a live pickup workflow. Confirm staging host is not production-facing. |
| `public/shipments/milestones.html` | Redirects to `../customer-os/customer-services/shipment-timeline.html`, copying query and hash. Confirm target authorization and no leakage through query values. |

The static audit classified these as script-driven because it cannot safely determine their final URL from the HTML head alone. Source spot inspection confirms the behaviors above; no browser execution occurred.

## 4. Redirect-chain analysis

A repository-level redirect-map traversal found 22 cases where a redirect target is itself another redirect (including the dynamic `admin-login.html` → `auth/login.html` route). The longest statically observed chain is one redirect hop beyond the original URL. No cycles were found among the statically resolvable redirect map.

Notable chain groups:
- `admin-login.html` → `auth/login.html` → script role routing (dynamic).
- `app/driver/module-01-assignment-inbox.html` → staging assignment inbox.
- `app/operations/operations-reporting-export.html` → `public/operations/operations-reports.html`.
- `partner/verification.html` → `partner/partner-onboarding.html`.
- `public/driver/assigned-trips.html` and `public/driver/assignment-inbox.html` → staging assignment inbox.
- `public/shipments/carrier-assignment.html` → `public/partner-selection-assignment.html`.
- Fourteen `public/visibility/*` aliases converge on `public/tracking.html`.

No static cycle does not exclude a runtime loop caused by JavaScript, auth guards, host routing, query values or unavailable assets.

## 5. Destination concentration — alias groups

The highest convergence targets from the 343 routes:
- 43 → `app/partner/index.html`
- 18 → `app/warehouse/index.html`
- 16 → `public/tracking.html`
- 12 → `app/customs/index.html`
- 11 → `app/enterprise/finance.html)
- 9 → `app/finance/treasury-audit.html)
- 8 → `app/enterprise/organization.html)
- 7 → `app/enterprise/risk-compliance.html)
- 6 → driver staging proof-of-delivery page
- 5 each → selected enterprise commercial, finance reporting/payment, and operations destinations.

These may be deliberate compatibility aliases, but they also mean many legacy URLs converge on a small number of workspace shells. Each target must enforce its own authentication, role, organization membership and record-level authorization. A redirect is not an authorization control.

## 6. Specific redirect safety dispositions

| Route family / case | Disposition | Required action |
|---|---|---|
| 33 driver aliases to staging-named paths | **BLOCK RELEASE / INVESTIGATE** | Verify actual staging/production host behavior, page environment gates, auth and backend wiring. Do not present as live driver workflows until resolved. |
| `admin-login.html` and dynamic login redirect | **KEEP / RUNTIME TEST** | Verify role aliases, allowlisted next-paths, no open redirect, and correct workspace routing. |
| SIEM audit logs and facility matrix admin guard | **RESTRICT / FAIL-CLOSED TEST** | Verify guard load, no content flash, unauthenticated and non-admin denial. |
| Pickup confirmation redirect/staging preview | **RESTRICT / ENVIRONMENT TEST** | Confirm staging hostname isolated; production path must land in authenticated pickup tracking. |
| Shipment milestones redirect | **KEEP / AUTH TEST** | Verify query/hash preservation and shipment-level authorization at destination. |
| Customer/partner/warehouse/customs/finance/enterprise aliases | **KEEP PENDING TARGET TEST** | Keep compatibility; test destination permission, tenant isolation and intended route. |
| Legal aliases | **KEEP** | Verify target policy text/version and canonical legal links. |
| Tracking/visibility aliases | **KEEP** | Verify public token/consent scope and no private shipment data leak. |
| Any alias with no owner or caller evidence | **CONSOLIDATE REVIEW** | Preserve until navigation, SEO, email and external-link dependency audit is complete. |

## 7. Required runtime test matrix (blocked until Staging gate)

For every redirect family and all five dynamic cases:
1. Direct HTTP GET to source and destination; record status, final URL, redirect count and content type.
2. Test GitHub Pages base path `/logistics-saas/` and any approved staging host; verify no root-path escape.
3. Preserve and validate query strings and fragments where expected; reject unsafe external `next` destinations.
4. Test anonymous, authenticated wrong-role, correct-role, wrong-organization and authorized-user states.
5. Verify no privileged content flash before guard completion.
6. Verify driver routes never resolve to a preview/test-only surface in Production.
7. Test no redirect loops and bounded redirect depth.
8. Test missing JS/auth guard, expired session, unavailable backend and browser back navigation.
9. Record screenshots, console/network logs, final URL, auth identity/role, expected/actual, timestamp and build commit.

Staging deployment and identity isolation are still BLOCKED by Phase 00 Gates A/A2/B. Do not run authenticated route tests against Production.

## 8. Gate result

| Item | Status |
|---|---|
| All 343 redirect records parsed from CI audit artifact | PASS |
| 338 static target paths resolved against repository HTML inventory | PASS |
| Five script-driven redirects inspected at source level | PARTIAL PASS |
| Redirect-map chain and cycle analysis | PASS (static map only) |
| Driver staging destination risk identified (33) | PASS |
| Browser HTTP status/final URL/loop checks | BLOCKED |
| Auth/role/tenant isolation checks at redirect targets | BLOCKED |
| Production/Staging environment redirect verification | BLOCKED |

**Gate C3.5: PARTIAL PASS / BLOCKED.** All 343 aliases are inventoried and static targets resolve, but 33 driver aliases lead into staging-named paths. No redirect source was edited, no alias was deleted, and no Production/Staging setting, database, account, provider or deployment was changed.
