# KRIM Driver Ecosystem — Route Deduplication & Canonical Inventory

Status: staging branch inventory. This document records the 54 candidate routes supplied for the Driver Ecosystem and the canonical route model.

## Canonical scope

**21 canonical pages**
- **18 Driver OS pages** under `app/driver/staging/`
- **3 driver authentication pages** under `auth/`

The 33 legacy Driver Workspace routes are retained as compatibility entry points and map to the canonical Driver OS or authentication route. They are not 33 additional product pages.

## Canonical Driver OS — 18 pages

| # | Canonical page | Staging route |
|---:|---|---|
| 1 | Driver Dashboard | `app/driver/staging/page-01-driver-dashboard.html` |
| 2 | Assignment Inbox | `app/driver/staging/page-02-assignment-inbox.html` |
| 3 | Assignment Details | `app/driver/staging/page-03-assignment-details.html` |
| 4 | Assignment Acceptance | `app/driver/staging/page-04-assignment-acceptance.html` |
| 5 | Driver & Vehicle Readiness | `app/driver/staging/page-05-driver-vehicle-readiness.html` |
| 6 | Pickup & Collection | `app/driver/staging/page-06-pickup-collection.html` |
| 7 | Shipment Milestones | `app/driver/staging/page-07-shipment-milestones.html` |
| 8 | Route & Stop Management | `app/driver/staging/page-08-route-stop-management.html` |
| 9 | Live Tracking | `app/driver/staging/page-09-live-tracking.html` |
| 10 | Exceptions & Incidents | `app/driver/staging/page-10-exceptions-incidents.html` |
| 11 | Proof of Delivery | `app/driver/staging/page-11-proof-of-delivery.html` |
| 12 | Failed Delivery & Returns | `app/driver/staging/page-12-failed-delivery-returns.html` |
| 13 | Delivery History | `app/driver/staging/page-13-delivery-history.html` |
| 14 | Earnings & Settlements | `app/driver/staging/page-14-earnings-settlements.html` |
| 15 | Performance & Quality | `app/driver/staging/page-15-performance-quality.html` |
| 16 | Notifications & Support | `app/driver/staging/page-16-notifications-support.html` |
| 17 | Driver Profile & Compliance | `app/driver/staging/page-17-driver-profile-compliance.html` |
| 18 | Security & Audit | `app/driver/staging/page-18-security-audit.html` |

## Canonical authentication — 3 pages

| Page | Route |
|---|---|
| Driver Access | `auth/driver-access.html` |
| Driver Sign In | `auth/driver-signin.html` |
| Driver Sign Up | `auth/driver-signup.html` |

## Legacy route compatibility — 33 routes

| Legacy route | Canonical destination |
|---|---|
| `public/driver/assigned-trips.html` | Assignment Inbox |
| `public/driver/assignment-details.html` | Assignment Details |
| `public/driver/assignment-inbox.html` | Assignment Inbox |
| `public/driver/cargo-condition.html` | Pickup & Collection |
| `public/driver/delay-report.html` | Exceptions & Incidents |
| `public/driver/delivery-checklist.html` | Proof of Delivery |
| `public/driver/driver-earnings.html` | Earnings & Settlements |
| `public/driver/driver-settings.html` | Driver Profile & Compliance |
| `public/driver/emergency-support.html` | Notifications & Support |
| `public/driver/expense-submission.html` | Earnings & Settlements |
| `public/driver/failed-delivery.html` | Failed Delivery & Returns |
| `public/driver/incident-report.html` | Exceptions & Incidents |
| `public/driver/loading-confirmation.html` | Pickup & Collection |
| `public/driver/location-sharing.html` | Live Tracking |
| `public/driver/login.html` | Driver Sign In |
| `public/driver/maintenance-log.html` | Driver & Vehicle Readiness |
| `public/driver/offline-sync.html` | Live Tracking / offline capability |
| `public/driver/performance-metrics.html` | Performance & Quality |
| `public/driver/photo-proof.html` | Proof of Delivery |
| `public/driver/pickup-checklist.html` | Pickup & Collection |
| `public/driver/pod-submission.html` | Proof of Delivery |
| `public/driver/pod-summary.html` | Delivery History |
| `public/driver/profile.html` | Driver Profile & Compliance |
| `public/driver/recipient-verification.html` | Proof of Delivery |
| `public/driver/return-trip.html` | Failed Delivery & Returns |
| `public/driver/route-navigation.html` | Route & Stop Management |
| `public/driver/safety-checklist.html` | Driver & Vehicle Readiness |
| `public/driver/signature-capture.html` | Proof of Delivery |
| `public/driver/support-center.html` | Notifications & Support |
| `public/driver/trip-completion.html` | Proof of Delivery |
| `public/driver/trip-details.html` | Assignment Details |
| `public/driver/trip-status.html` | Shipment Milestones |

The existing `app/driver/index.html` is the legacy Driver Workspace landing page and maps to Driver Dashboard. It is a legacy landing route outside the 33 public legacy-route count above.

## Additional legacy app route compatibility

The repository also contained the legacy `app/driver/index.html` dashboard and 17 `app/driver/module-*.html` module routes. These are older duplicate entry points outside the supplied 54-candidate count. On the staging branch, the dashboard and all 17 module routes now redirect to the corresponding canonical page 01–18, preserving the old paths while preventing a second, divergent Driver OS implementation.

## Explicit exclusions

These are adjacent partner/admin capabilities, not driver-owned workspace pages:
- Partner Driver & Vehicle Assignment
- Platform Admin Driver Verification

They remain outside the 21-page Driver Ecosystem count.

## Implementation and release rules

- All rebuild work stays on `staging/driver-ecosystem`; production `main` is not modified by this inventory.
- Legacy URLs must remain usable and route to their canonical equivalent.
- The 18 Driver OS pages share a complete 18-item navigation.
- Authentication pages remain separate from operational Driver OS navigation.
- Public staging page shells may render without login redirects; private driver records/actions require an authenticated driver session, exactly one active driver membership and active organization, with user/org-scoped data access.
- A visible page shell does not mean its workflow is fully live. GPS collection, POD evidence submission, return authorization, earnings/settlement feeds and several event writes remain gated until their exact data contracts, security, privacy and end-to-end tests are verified.
- Production release occurs only after the complete staging review and explicit release approval.

## Verification note

The 33 legacy public route files were checked on the staging branch and are compact redirect/compatibility pages pointing to canonical destinations (the login route points to Driver Sign In). The 18 canonical page files and three authentication routes exist on the staging branch. This is a repository-level inventory, not a substitute for browser, responsive-device, authenticated-RLS or live end-to-end verification.
