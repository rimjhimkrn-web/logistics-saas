# KRIM Driver, Fleet and Vehicle Operational Readiness Audit — 2026-11-16

## Scope and method
Read-only inspection of the live production database and driver/vehicle assignment function definitions. Repository inventory included the driver app modules, driver signup/sign-in, partner driver/vehicle assignment and vehicle registry, platform-admin driver verification, and vehicle verification pages. No users, drivers, vehicles, documents, assignments or dispatches were created; no business RPC was executed.

## Live production snapshot
| Object | Rows |
|---|---:|
| Driver profiles | 0 |
| Driver verification documents | 0 |
| Driver assignments | 0 |
| Vehicles | 0 |
| Vehicle documents | 0 |
| Driver/vehicle bindings | 0 |
| Driver tracking sessions | 0 |
| Shipment-leg dispatch authorizations | 0 |
| Shipment dispatches | 0 |
| Driver delivery evidence | 0 |
| Driver trip events | 0 |

The live database therefore contains no evidence of an operational driver or fleet network, even though the workflow structures and application pages exist.

## Controls verified in the driver assignment acceptance function
The live `krim_driver_accept_assignment(uuid)` definition is SECURITY DEFINER, has an empty search_path, and is executable by authenticated users. Its body:
1. Binds the assignment lookup to `auth.uid()` and locks the driver's own assignment row.
2. Requires active driver membership in the assigned partner organisation.
3. Requires a verified/approved driver profile, non-empty licence number, future licence expiry, accepted front and back licence evidence, and accepted identity evidence.
4. Requires an assigned vehicle and an active binding between that vehicle and the same driver/partner organisation.
5. Requires a verified, operationally active vehicle and all country/category mandatory vehicle documents to be approved and unexpired.
6. Checks assignment/partner-assignment/shipment/leg identifiers and exact organisation linkage.
7. Supports later-leg acceptance only when the shipment is already in transit and the target leg belongs to an active multi-leg plan.
8. Requires shipment weight and vehicle payload, normalises supported weight units to kilograms, and blocks overload.
9. Requires the exact leg to remain assigned to the partner and be a road leg.
10. Requires a current verified partner capability, active approved service area matching pickup country/location, active organisation and current partner compliance before acceptance.

This is meaningful server-side defence-in-depth; the page's display state is not the security boundary.

## Operational design coverage identified
The repository contains separate surfaces for driver signup/sign-in, driver profile/compliance, driver assignment inbox/details/acceptance, readiness, pickup, milestones, route stops, tracking, incidents, POD, returns, earnings, performance and security. Partner surfaces include driver/vehicle assignment and vehicle registry; platform-admin surfaces include driver and vehicle verification.

Existing earlier audits already reviewed dispatch authorisation, custody, tracking and POD controls. This report complements those reviews and does not claim to repeat full verification of every downstream function.

## Priority risks and remaining verification

### P1 — No live operational evidence
Every core driver/fleet execution table queried is empty. Consequently, the system has not demonstrated an actual driver onboarding → independent verification → vehicle binding → assignment acceptance → dispatch → tracking → verified POD journey.

### P1 — Staging test matrix required
Use synthetic staging identities only to test:
- Driver identity/licence document ownership, front/back completeness, reviewer separation, licence expiry and identity changes resetting verification.
- Invitation email confirmation, expiry, replay, revocation and membership transfer.
- Vehicle registration uniqueness, organisation ownership, mandatory document matrix, expiry and independent approval.
- Driver/vehicle binding scope, conflicting active bindings, vehicle deactivation and revocation after assignment.
- Payload-unit conversions and overload rejection.
- Exact-leg partner assignment and multi-leg later-leg acceptance.
- Concurrent driver acceptance, reassignment, capacity change, vehicle revocation and dispatch authorization.
- Revoked/stale dispatch authorization replay and physical-departure event sequencing.
- Tracking consent, session expiry, location access scope and manual-vs-telematics provenance.
- POD evidence ownership, private storage, reviewer separation, failed delivery and return workflows.

### P1 — SECURITY DEFINER execution needs whole-path review
The inspected acceptance function has strong caller and workflow checks, but its privileged nature means all called helpers, table constraints, triggers, policies, and every state-changing entry point must be reviewed together. Do not infer safety from this one function.

### P2 — Driver-facing claims and live status
Do not advertise driver availability, vehicle capacity, live GPS, trip status or delivery proof until there is a real verified driver/vehicle and a successful staged/controlled operational record. A zero tracking-session count means no live driver session is evidenced now.

## Release decision
Driver and fleet foundations are substantial, but live production counts show zero drivers, zero vehicles, zero assignments and zero dispatches. KRIM cannot currently claim an operational fleet or real dispatch capability.

No production changes were made. Keep commercial dispatch gated until migration reconciliation, independent reviewer controls, staging concurrency tests and one fully evidenced partner-authorised pilot are complete.
