# Phase 00 — Shipment, Driver, Fleet and Partner RPC Source Security Review
Date: 2026-11-25
Branch: `qa/phase-00-baseline-2026-11-25`
Scope: Read-only source inspection of selected Production SECURITY DEFINER RPCs and comparison of selected helper-function execution grants with Staging. No RPC was invoked; no rows, permissions, functions or settings were changed.

## Executive result
**Selected source controls are substantial, but runtime authorization and privacy verification remain open.**
No anonymous EXECUTE privilege was found for the reviewed functions. Most selected partner, driver, dispatch and fleet operations explicitly bind the caller to an authenticated user, organization membership/permission, exact shipment leg, verified capability, evidence ownership and/or valid state transition. This is source review only, not proof of runtime behavior.

## 1. SECURITY DEFINER inventory refinement
A targeted Production inventory of authenticated-executable SECURITY DEFINER functions that contain no obvious direct `auth.uid()`, `auth.jwt()` or JWT subject reference returned eight entries:
- `krim_admin_list_capacity_resources_lane_aware()`
- `krim_partner_register_capacity_resource_for_lane(...)`
- `krim_partner_submit_service_capability_v2(...)`
- Five `krim_vehicle_*` functions.

The three capacity/capability functions were traced through their delegated functions:
- Lane-aware admin list calls `krim_admin_list_capacity_resources()`, which requires authenticated identity, AAL2 and `admin.platform`.
- Lane-specific capacity registration delegates to `krim_partner_register_capacity_resource()`, which requires authenticated identity, active organization membership, `partner.manage`, eligible organization/compliance, verified capability and uploader-owned evidence. The wrapper additionally verifies active lane, origin and transport-mode match.
- Capability v2 delegates to `krim_partner_submit_service_capability()`, which requires authenticated identity, `partner.manage`, active registered-business partner organization, current compliance, active transport mode/country, validated service type and uploader-owned evidence. The wrapper validates JSON object/size/field lengths before updating the newly created capability record.

These are **not automatically unauthenticated bypasses**: the security checks are in the delegated functions. However, the wrappers deserve negative runtime tests to prove their delegated checks remain enforced.

## 2. Driver assignment and dispatch controls
Selected source reviewed:
- `krim_assign_driver_to_partner_shipment(...)`
- `krim_authorize_leg_dispatch(...)`
- `krim_driver_accept_assignment(...)`
- `krim_driver_record_trip_event(...)`
- `krim_driver_submit_delivery_pod(...)` (earlier source review)

Observed controls include:
- Caller must be authenticated and hold `shipment.dispatch` for the partner organization before assigning a driver.
- Assignment must match an accepted partner assignment and the exact shipment/leg/partner organization.
- ROAD-only restriction for registered road vehicles.
- Partner verification, current compliance, verified capability and approved service-area checks.
- Driver must be active in the partner organization, verified, licensed and have independently accepted identity/licence evidence.
- Driver must have an active binding to a verified, operational vehicle; vehicle mandatory documents must be current.
- Shipment weight is compared with normalized vehicle payload capacity.
- Existing active driver/vehicle assignments are rejected; inconsistent idempotent replays are rejected.
- Dispatch authorization requires exact-leg confirmed capacity binding and partner-owned reservation; ROAD dispatch additionally requires an accepted driver assignment and current vehicle/driver evidence.
- Multi-leg continuation requires accepted custody transfer from the immediately preceding leg.
- Driver trip events are restricted to the assigned driver; pickup and transit require appropriate prior assignment state. Delivery is not accepted as a normal trip event and is reserved for POD verification.
- Multi-leg pickup/transit checks current exact-leg dispatch authorization.

These controls are positive source-level evidence. Cross-tenant, replay, stale-state, concurrent-update and negative role tests are still NOT TESTED.

## 3. Fleet verification and privacy review
Selected `krim_vehicle_*` functions were inspected:
- Admin vehicle listing, document requirement listing, document review, final verification and expiry refresh call `krim_vehicle_admin_guard()`, which requires authenticated AAL2 and `admin.platform`.
- Vehicle verification prevents the registrant from independently verifying their own vehicle and prevents a reviewer from verifying a vehicle containing evidence they submitted.
- Document registration requires active organization owner/manager access, uploader-owned private storage object, matching MIME/size metadata, scoped storage path and valid document metadata.
- Driver/vehicle binding requires `shipment.dispatch`, active/verified/compliant registered-business partner, current transport capability, verified vehicle, mandatory approved documents and a verified driver with accepted identity/licence evidence.
- Vehicle listing and document listing require active organization membership.

### Privacy item requiring review
`krim_vehicle_documents_list(p_vehicle_id)` returns document number, issuing country, dates, file name and review metadata to **any active member** of the vehicle's organization. `krim_vehicle_driver_eligible_drivers(p_organization_id)` returns the driver's full licence number to users with `shipment.dispatch`. These may be operationally intended, but the least-privilege need for exposing full document/license numbers has not been established. Treat this as a **privacy review item**, not a confirmed exploit. Before broad onboarding, confirm role-based need-to-know and consider masking identifiers for non-compliance reviewers.

## 4. Production–staging function grant difference
The three delegated helper functions inspected are authenticated-executable in Production but report no authenticated EXECUTE grant in Staging:
- `krim_admin_list_capacity_resources()`
- `krim_partner_register_capacity_resource(...)`
- `krim_partner_submit_service_capability(...)`

Their public wrappers remain authenticated-executable in both environments. Since wrappers execute as their owner and delegate internally, this can be an intentional grant-minimization design. Do not copy grants into Staging without confirming frontend calls and intended role matrix.

## 5. Evidence table
| Check | Result |
|---|---|
| Selected reviewed functions: anon EXECUTE | PASS — none found |
| No-auth-signal capacity wrappers traced to guarded delegates | PASS — source trace |
| Partner capacity registration membership/permission/evidence checks | PASS — source review |
| Partner capability submission membership/permission/compliance/evidence checks | PASS — source review |
| Driver assignment organization/leg/driver/vehicle controls | PASS — source review |
| Exact-leg capacity/custody dispatch gates | PASS — source review |
| Fleet admin AAL2/platform-admin guard | PASS — source review |
| Independent vehicle/document review separation | PASS — source review |
| Full licence/document number least-privilege | REVIEW REQUIRED |
| Runtime positive/negative authorization tests | NOT TESTED |
| Cross-tenant IDOR/BOLA tests | NOT TESTED |
| Concurrent/idempotent replay tests | NOT TESTED |
| Notification fan-out after assignment/trip/POD events | NOT TESTED |

## 6. Required follow-up
1. Trace frontend consumers for the fleet document and eligible-driver RPCs; establish role-based visibility and whether identifiers can be masked.
2. Build isolated Staging negative tests for wrong organization, non-member, wrong role, inactive member, expired compliance, unverified capability, wrong shipment leg, wrong driver, unbound vehicle, expired documents, overweight cargo, stale custody and reused idempotency key.
3. Verify event-to-notification fan-out for partner assignment, driver acceptance, pickup, in-transit, exception and POD review. Assert notification queue status and recipient scoping without sending external messages.
4. Reconcile Production/Staging function grants against intended role matrix. Keep current grants unchanged pending approval.
5. Continue remaining finance/payment/notification SECURITY DEFINER and Edge Function source reviews.

## Safety boundary
All operations in this pass were read-only SQL catalog/source queries. No function was called. No production or staging data, users, grants, policies, functions, secrets, payments, emails or notifications were changed or triggered.

## Readiness decision
Selected source-level partner/driver/fleet controls are encouraging but not runtime verified. Privacy least-privilege and staging grant parity remain open. Phase 00 remains IN PROGRESS; unrestricted onboarding is not certified. NO EVIDENCE = NO PASS.
