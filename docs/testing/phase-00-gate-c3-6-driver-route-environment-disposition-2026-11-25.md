# Phase 00 — Gate C3.6: driver staging-destination and canonical-route disposition

Date: 2026-11-25
Repository: rimjhimkrn-web/logistics-saas
Immutable source baseline: `72d75a18f985ceb09e468839435ee95700e11e46`
QA branch: `qa/phase-00-baseline-2026-11-25`
Scope: source-level inspection of all 33 compatibility redirects identified in C3.5 that point into `app/driver/staging/*`, their unique destination pages, the driver dashboard, the canonical route registry, driver sign-in routing and environment resolver. No browser, auth session, database write, deployment or environment mutation was performed.

## 1. Executive finding

**The `staging` folder name is misleading as an environment indicator.** It contains a mixed set of driver workspace pages, not a separate deployment. These pages load the shared `config.js` environment resolver and Supabase client. On the public GitHub Pages hostname, the resolver falls through to `production` and therefore selects the Production Supabase project. On the candidate `krim-staging.pages.dev` hostname it selects `preview` and the Staging Supabase project.

Therefore:
- The 33 aliases do not simply point to a safe, isolated preview website.
- On GitHub Pages, the target pages are served as part of the Production site and their client code connects to Production Supabase.
- Their `Public staging preview` copy describes the unauthenticated page state; it is not a server-side environment boundary.
- Access control must be enforced by Supabase/RPC/RLS and page-level checks, and still requires runtime verification.

This corrects the C3.5 shorthand interpretation: the staging-named paths are **mixed-environment workspace implementation pages**. The folder name alone cannot determine whether a page is preview-only.

## 2. Redirect inventory reconciliation

C3.5 found 33 aliases whose destinations contain `app/driver/staging/`:
- 31 legacy `public/driver/*` aliases.
- 2 app-level compatibility aliases:
  - `app/driver/module-01-assignment-inbox.html` → `app/driver/staging/page-02-assignment-inbox.html`
  - `app/driver/module-05-pickup-collection.html` → `app/driver/staging/page-06-pickup-collection.html`

The 31 legacy public aliases map to 13 distinct driver workflow pages, plus the two app aliases make 15 distinct staging-directory targets in total. The login alias `public/driver/login.html` is separate and points to `auth/driver-signin.html`, not into the staging directory.

## 3. Canonical route chain

Source-level routing resolves as follows:

1. `config.js` canonical route registry: `driver` → `app/driver/index.html`.
2. `app/driver/index.html` is a compatibility redirect to `app/driver/dashboard.html`, preserving query and hash.
3. `driverAssignments` registry entry points to `app/driver/module-01-assignment-inbox.html`.
4. That legacy module alias redirects to `app/driver/staging/page-02-assignment-inbox.html`.
5. `page-02-assignment-inbox.html` is a tiny noindex redirect to `../dashboard.html#assignments`.

**Recommended canonical landing page: `app/driver/dashboard.html`.** Keep `app/driver/index.html` as the stable external/canonical route-registry entry unless a separate controlled route migration is approved. Treat assignment inbox as a dashboard section, not a second workspace entry point. No route was changed in this gate.

Driver sign-in performs password authentication, checks active `krim_organization_members` rows for the signed-in user, requires a driver role, verifies an active linked organization, checks verified TOTP/AAL2 flow, and then redirects to `app/driver/index.html?release=20261021-driver-workspace-v8`. The client-side source is encouraging, but it is not proof that database policies independently enforce every check.

## 4. Destination-page source inspection

Inspected the dashboard plus all 15 distinct staging-directory targets. Findings:

| Page / feature | Source evidence | Disposition |
|---|---|---|
| `page-02-assignment-inbox.html` | 536-byte noindex alias; forwards to dashboard `#assignments` | **KEEP AS ALIAS** |
| `page-03-assignment-details.html` | Loads shared config; session, membership/org checks; reads driver assignments | **KEEP / AUTH TEST** |
| `page-05-driver-vehicle-readiness.html` | Session and membership/org checks; profile, verification documents, `krim_driver_my_vehicle`, assignment reads | **KEEP / AUTH TEST** |
| `page-06-pickup-collection.html` | Session and membership/org checks; assignment list; `krim_driver_record_trip_event` pickup RPC | **KEEP / HIGH-RISK WRITE TEST** |
| `page-07-shipment-milestones.html` | Session and membership/org checks; assignments/events; trip-event RPC | **KEEP / HIGH-RISK WRITE TEST** |
| `page-08-route-stop-management.html` | Session and membership/org checks; assignment, shipment route and route segment reads | **KEEP / AUTH TEST** |
| `page-09-live-tracking.html` | Session and membership/org checks; assignment/tracking-event reads | **KEEP / PRIVACY TEST** |
| `page-10-exceptions-incidents.html` | Session and membership/org checks; assignment/event reads and trip-event RPC | **KEEP / HIGH-RISK WRITE TEST** |
| `page-11-proof-of-delivery.html` | Session and membership/org checks; assignment reads; no proof of live evidence submission established by this page inspection | **KEEP / EVIDENCE FLOW NOT PROVEN** |
| `page-12-failed-delivery-returns.html` | Session and membership/org checks; assignment/event reads and trip-event RPC | **KEEP / HIGH-RISK WRITE TEST** |
| `page-13-delivery-history.html` | Session and membership/org checks; driver assignment history reads | **KEEP / AUTH TEST** |
| `page-14-earnings-settlements.html` | Session and membership/org checks; assignment activity reads; earnings feed explicitly shown as not connected | **KEEP / NOT FINANCIALLY LIVE** |
| `page-15-performance-quality.html` | Session and membership/org checks; assignment/event/evidence reads | **KEEP / AUTH TEST** |
| `page-16-notifications-support.html` | Session and membership/org checks; notification and support ticket reads; notification mark-read update, ticket insert and support reply RPC | **KEEP / HIGH-RISK WRITE TEST** |
| `page-17-driver-profile-compliance.html` | Session and membership/org checks; driver profile/document metadata reads; page states read-only | **KEEP / AUTH TEST** |

The inspected destination pages load `config.js` and call `auth.getSession()`; their private-data paths check membership/organization context before displaying records. Some actions invoke privileged workflow RPCs or write support/notification records. A source-level session check does not replace server-side authorization, tenant-scoped RLS, assignment ownership checks, milestone state-machine validation or immutable audit history.

The dashboard separately checks the authenticated session, active organization membership, reads assignments filtered to the current user ID, and loads the driver profile. It displays a no-session preview state without loading operational records.

## 5. Environment resolver finding

The baseline `config.js`:
- Explicitly returns `preview` for hostname `krim-staging.pages.dev` and its subdomains.
- Selects the Staging Supabase URL/key for `preview` and `development`.
- Returns `production` for all other unrecognized hostnames.
- Therefore GitHub Pages `rimjhimkrn-web.github.io/logistics-saas/` resolves to Production unless overridden by a supported page-level environment setting.
- Sets `KRIM_AUTH_DISABLED=true` for preview, but the inspected driver pages manually call Supabase `auth.getSession()`; the flag itself is not evidence that those pages bypass or enforce auth.

No deployed staging origin, DNS/TLS reachability, build commit or runtime host-to-project mapping was tested in this task. The resolver is source evidence only.

## 6. Required safety decisions

1. **Keep** the 33 compatibility aliases for now; no deletion or redirect rewrite.
2. **Keep** `app/driver/index.html` as the canonical route-registry URL, with dashboard as its stable landing destination.
3. **Treat** `app/driver/staging/*` as an implementation folder name, not an environment security boundary.
4. **Do not label** driver workflows as live/production-ready merely because their pages load or show Supabase code.
5. **Block real driver operations** until the server-side authorization and lifecycle RPCs are reviewed and tested: pickup, transit, exceptions, returns, support ticket creation/replies, notification updates, proof-of-delivery evidence and tracking.
6. **Do not use Production for synthetic tests.** First resolve Phase 00 staging deployment and migration parity gates; then create synthetic identities only in verified isolated Staging.
7. **Resolve earnings truthfully:** page currently identifies earnings feed as not connected. Do not show calculated/settled earnings until a verified ledger/payout source exists.
8. **Resolve the assignment inbox duplicate:** keep it as dashboard anchor alias; do not present it as an independent module until it has its own distinct supported workflow.

## 7. Gate result

| Check | Status |
|---|---|
| All 33 aliases reconciled | PASS |
| 31 public aliases / 2 app aliases counted | PASS |
| 15 unique destination pages + dashboard inspected | PASS |
| Canonical route chain traced | PASS |
| Driver sign-in role/org/MFA source path inspected | PASS |
| Shared environment resolver inspected | PASS |
| Staging folder proven to be isolated deployment | NOT TESTED |
| Runtime HTTP/final URL/redirect behavior | BLOCKED |
| RLS/tenant/assignment ownership for all driver RPCs | NOT TESTED |
| Pickup/transit/incident/return/support write paths | NOT TESTED |
| POD upload, signed URL, evidence audit and recipient verification | NOT TESTED |
| Earnings/settlement data source | BLOCKED (page says not connected) |

**Gate C3.6: PARTIAL PASS / BLOCKED.** The 33 routes have been reconciled; their staging-named destinations are real mixed-environment driver workspace implementation pages, not proof of an isolated staging site. The safest canonical driver landing page is `app/driver/dashboard.html`, reached through the existing `app/driver/index.html` registry route. No route, page, environment, database, account, provider or deployment was changed.
