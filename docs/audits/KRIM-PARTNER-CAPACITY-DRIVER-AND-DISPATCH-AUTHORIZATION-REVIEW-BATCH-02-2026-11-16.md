# KRIM Partner Capacity, Driver and Dispatch Authorization Review — Batch 02
**Date:** 16 November 2026  
**Method:** Read-only live PostgreSQL catalog and function-definition inspection. No RPC was invoked; no production records or schema were changed.

## Executive summary
The reviewed workflows contain meaningful safeguards: active partner membership and permissions for capacity registration/reservation, independent evidence review for capabilities and resources, verified driver/licence/vehicle checks, exact-leg capacity binding, and idempotent dispatch authorization.

One high-priority integrity gap remains in the initial dispatch-authorization path: the function revalidates current partner compliance, route capability and handover only when reusing an existing idempotency key through a helper. The new-authorization path does not visibly call those same current-state checks. It verifies assignment, exact leg, confirmed reservation/binding, and (for road) driver/vehicle evidence, but may authorize dispatch after partner compliance/capability or warehouse handover has become stale. This requires a staging reproduction and safe remediation design after migration reconciliation.

## 1. Partner capability review
Function: `krim_admin_review_partner_capability(bigint,text,text)`

Positive controls observed:
- Authenticated user required; AAL2 required; `admin.platform` permission required for platform organization 1.
- Only pending capability submissions can be decided.
- Approval requires a review note; rejection requires a reason.
- Submitter cannot approve their own capability.
- Partner organization must pass the current compliance helper.
- Coverage country and transport mode must be active.
- One to five evidence files must exist in the private verification bucket and be owned by the original submitting user.
- Hazardous-goods and refrigerated capabilities are explicitly held pending specialist evidence controls.
- Validity dates and weight limits are checked.
- Previous/new state is written to the audit event log.

Assessment: strong independent-review controls in this function. Verify the underlying compliance helper's reviewer/evidence requirements and ensure capability changes invalidate any downstream capacity or dispatch eligibility promptly.

## 2. Capacity resource registration and review
Functions:
- `krim_partner_register_capacity_resource(...)`
- `krim_admin_review_capacity_resource(bigint,text,text)`
- `krim_partner_register_capacity_resource_for_lane(...)`

Positive controls:
- Registration requires authenticated user, active organization membership and `partner.manage`.
- Organization type and current registered-business compliance are checked.
- The transport mode and location must be active; an individually verified partner capability must cover the mode and location country.
- Capacity value must be finite and positive; availability window must be finite, future-dated and ordered.
- Supporting evidence is limited to one to five unique private-bucket files with organization/user path scoping and uploader ownership.
- New resource and availability start as `pending_review` / `unavailable`.
- Approval requires AAL2, platform-admin permission, independent reviewer, current partner compliance, separately approved capability, future availability and valid private evidence.
- Rejection keeps availability unavailable; approved availability is enabled only if its window remains current.
- The lane wrapper validates an active lane and delegates registration to the guarded base function.

Assessment: good staged-verification design. Continue to review exact storage-object owner enforcement and lane/resource origin semantics, but no bypass was established in this batch.

## 3. Capacity reservation
Function: `krim_partner_reserve_shipment_leg_capacity(...)`

Positive controls:
- Requires auth, active partner membership and `shipment.update`.
- Requires accepted/active partner assignment, exact shipment leg and matching partner ownership.
- Requires current partner compliance and verified capability covering route/mode/weight.
- Locks assignment, partner organization, shipment, leg and candidate resources/availability.
- Selects verified, available physical vehicle/weight capacity on the exact active lane and scheduled time window.
- Accounts for overlapping confirmed and unexpired held reservations at both availability and resource levels.
- Uses idempotency keys and prevents reuse across different shipment legs.
- Creates confirmed reservation, exact-leg binding, events and audit record transactionally.

Assessment: robust visible reservation controls. Verify cancellation/expiry/release behavior and concurrency under staging stress tests. The function confirms capacity; it does not itself constitute dispatch authorization.

## 4. Dispatch authorization — high-priority gap
Function: `krim_authorize_leg_dispatch(bigint,text)`

Positive controls on the new authorization path:
- Requires authenticated user and `shipment.dispatch` permission for the assigned partner organization.
- Requires accepted/active exact-leg assignment, assigned leg and non-terminal shipment.
- Locks assignment, leg, shipment, binding and reservation.
- Requires confirmed exact-leg physical capacity binding and partner-owned confirmed reservation.
- For road legs, requires an accepted driver assignment for the exact partner/leg, verified driver, current licence, accepted front/back licence evidence, active verified vehicle, active driver-vehicle binding and current mandatory vehicle documents.
- For later legs, requires accepted custody transfer from the immediately preceding leg.
- Uses organization-scoped idempotency keys and records a partner execution event.

**Gap:** the initial authorization path does not visibly call:
- `private.krim_partner_compliance_is_current(...)`
- `private.krim_partner_capability_covers_shipment_leg(...)`
- `private.krim_dispatch_handover_is_current(...)`
- `private.krim_leg_dispatch_authorization_is_current(...)`

The last helper does enforce current compliance, capability, dispatch handover, confirmed capacity, active exact-leg plan/assignment and accepted custody. However, the authorization function calls it only when returning an existing idempotent authorization. It does not visibly run the helper before inserting a new authorization.

Consequently, a partner whose compliance/capability or handover state changes after capacity reservation may potentially receive a new dispatch authorization using a still-confirmed reservation. This is a **high-priority authorization consistency finding**, not yet a proven exploit. The helper may also have state prerequisites that require careful call ordering.

Required safe verification:
1. In staging, reserve capacity for a valid assignment.
2. Revoke/expire partner compliance or capability, or invalidate handover, before requesting first dispatch authorization.
3. Confirm new authorization is rejected.
4. Repeat with valid state and confirm successful authorization.
5. Repeat with idempotency replay after revocation and confirm the existing authorization is rejected as stale.
6. Verify all checks and authorization insert occur atomically under appropriate locks.

No staging or production test was run here.

## 5. Driver acceptance and dispatchable-driver listing
Functions:
- `krim_driver_accept_assignment(uuid)`
- `krim_list_dispatchable_drivers(bigint)`

Driver acceptance has strong identity and evidence checks:
- Assignment is selected by ID and `user_id=auth.uid()`.
- Active driver membership in the assignment's organization is required.
- Verified driver profile, current licence, accepted front/back licence and identity evidence are required.
- Vehicle must be assigned, verified, active and bound to the driver.
- Mandatory vehicle documents must be present, approved and current.
- Partner assignment, shipment and exact road leg are locked and cross-checked.
- Shipment weight must fit verified vehicle payload.
- Partner capability and approved service-area coverage for pickup are rechecked before acceptance.
- Accepted assignment metadata is actor-bound and repeat acceptance is only returned when metadata matches the same user.

The dispatchable-driver listing requires authentication, `shipment.dispatch`, active registered-business partner status and route capability before listing drivers; it filters for active driver membership and verified profiles/vehicles.

Assessment: positive controls. Recheck current driver licence expiry and all vehicle evidence at the final dispatch authorization boundary, not only when the driver accepts. The dispatch function does check current licence and required vehicle documents for road legs.

## 6. Partner onboarding submission
Function: `krim_submit_partner_onboarding_global_v2(...)`

Positive controls:
- Auth required; validates business identity, country codes, operational category, address, website and evidence count.
- Evidence paths are constrained to the organization/user folder structure.
- Organization membership, active status, partner-type organization and registered-business mode are required.
- Advisory transaction lock serializes onboarding submissions for a user.
- Creates or updates a pending verification case and writes an audit event.

Review note: the function checks that submitted objects exist in the private verification bucket, but the visible query does not compare `storage.objects.owner_id` to the submitting user. The path is constrained to the user's UUID folder and the organization membership is checked, which is a meaningful boundary; nevertheless, explicitly checking object ownership would strengthen the evidence-integrity invariant. Confirm bucket insert/read policies and uploader ownership in a staging test before treating this as a confirmed defect.

## 7. Vehicle verification
Function: `krim_vehicle_finalize_verification(uuid)`

Positive controls:
- Delegates authorization to `public.krim_vehicle_admin_guard()`.
- Vehicle is locked before review.
- Registrant cannot verify their own vehicle.
- A configured mandatory-document requirement profile must exist.
- Every mandatory document must be approved and unexpired.
- Reviewer cannot verify a vehicle containing evidence they submitted.
- Verification state and audit event are updated together.

Assessment: independent reviewer controls are visible. Inspect the guard's exact AAL2 and permission logic and test organization scope in staging.

## 8. Dispatch readiness versus dispatch authorization
The read-only `krim_operations_dispatch_readiness()` definition returns blocker arrays and a `ready_for_authorized_review` state; it is a readiness assessment, not itself authorization. The function includes checks for partner eligibility, warehouse handover, compatible drivers/vehicles, active multi-leg plan item, accepted driver assignment and current exact-leg authorization/capacity/custody. This distinction must remain explicit in UI and operational documentation.

## 9. Required remediation order
1. Resolve the initial dispatch authorization current-state gap in staging first; do not patch production yet.
2. Verify partner compliance/capability/handover invalidation propagation to dispatch authorization and tracking.
3. Test reservation concurrency, overlapping time windows, duplicate idempotency keys, release/rebook and cancellation.
4. Confirm onboarding evidence ownership through storage policies and add an explicit owner assertion if needed.
5. Inspect `krim_vehicle_admin_guard()` and remaining partner/driver/capacity SECURITY DEFINER functions.
6. Only after migration-history reconciliation and sanitized schema manifest, prepare a reviewed migration and deploy through the approved change process.

## 10. Release decision
**NO-GO for unrestricted dispatch.** Partner capability, capacity, driver and vehicle controls show strong components, but the initial dispatch authorization path requires a staging-confirmed current-state gate. No production DDL, policy, grant, function or business record was changed. Finance remains deferred to the final phase.
