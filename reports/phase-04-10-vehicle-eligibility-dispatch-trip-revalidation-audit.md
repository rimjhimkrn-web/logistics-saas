# Phase 04.10 — Vehicle Eligibility Through Dispatch and Trip Events

Date: 2026-11-26  
Scope: Read-only audit of Production and Staging database function definitions, access patterns and trigger wiring. No runtime user journey was executed.

## Executive result

**FAIL — vehicle eligibility is checked at driver-assignment acceptance, but is not demonstrably revalidated at every later execution boundary.** Synthetic dispatch testing and real vehicle/driver onboarding remain blocked.

## Evidence reviewed

Live database definitions inspected in both Supabase environments:
- `krim_vehicle_driver_bind`
- `krim_vehicle_driver_eligible_vehicles`
- `krim_driver_accept_assignment`
- `krim_driver_record_trip_event`
- `private.krim_leg_dispatch_authorization_is_current`
- `public.krim_internal_evaluate_shipment_readiness`
- Dispatch-authorization guard triggers on `krim_shipment_leg_dispatch_authorizations`.

The driver-acceptance function definition in Production checks:
- authenticated assignment belongs to the driver;
- active driver membership;
- verified driver profile, future licence expiry and accepted front/back licence plus identity documents;
- linked vehicle is verified, active and bound to this driver;
- mandatory vehicle requirement set exists and every required vehicle document is approved and not expired;
- partner assignment, shipment/leg, ROAD mode, capacity and partner service-area/capability eligibility.

The vehicle-binding function also checks verified/active vehicle, mandatory evidence, verified driver, future licence and accepted driver documents.

## Findings

### F04.10-01 — Revalidation gap after assignment acceptance (HIGH)

The inspected `krim_driver_accept_assignment` checks vehicle status, active binding and mandatory vehicle evidence at acceptance time. The inspected `krim_driver_record_trip_event` does not repeat those vehicle/binding/document checks before pickup or transit. Its exact-leg dispatch authorization check applies only when an active multi-leg route plan exists.

**Risk:** after acceptance, a vehicle can become suspended, a binding can be revoked, or a required document can expire/reject without a corresponding vehicle-specific gate being visibly re-evaluated by the trip-event function.

### F04.10-02 — Single-leg path has weaker dispatch revalidation (HIGH)

Trip-event code invokes `private.krim_leg_dispatch_authorization_is_current` only for active multi-leg shipments. The single-leg branch instead relies on shipment and leg status. The live authorization-current helper checks exact-leg authorization, partner assignment, partner compliance/capability, capacity reservation, warehouse handover and custody, but the helper does not itself join the driver assignment to an active vehicle binding or re-check vehicle evidence.

**Risk:** the execution invariants differ between single-leg and multi-leg flows. A single common fail-closed execution gate is needed.

### F04.10-03 — Eligibility listing is not identical to binding requirements (MEDIUM)

The inspected eligible-driver listing checks verified profile, active membership, licence front/back and no active binding, but does not filter future licence expiry or accepted identity evidence. The final bind function checks those conditions, so the UI can present candidates who are rejected at bind time.

### F04.10-04 — Dispatch authorization trigger does not prove vehicle eligibility (HIGH)

The inspected authorization guard enforces activated route-plan item/partner/leg matching, active verified compliant partner, current capability and ROAD mode. A separate handover trigger checks warehouse handover, stock allocations and private dispatch proof. Neither inspected trigger definition demonstrates a driver/vehicle binding or current vehicle-document check.

### F04.10-05 — Runtime and cross-environment parity remain unproven

No browser journey, authenticated RPC invocation, synthetic assignment, expiry simulation, binding revocation, vehicle suspension or cross-tenant negative test was run. Production and Staging function/trigger surfaces are not assumed equivalent from this static inspection alone.

## Required remediation design (not applied)

1. Create one private, fail-closed execution predicate for an exact driver assignment + shipment leg + partner organization + vehicle.
2. Re-check at assignment acceptance, dispatch authorization, pickup and every transit event:
   - active same-organization driver membership and verified profile;
   - licence remains valid and required driver evidence remains accepted;
   - active binding still matches the assigned driver and vehicle;
   - vehicle remains verified and operationally active;
   - complete, current, approved mandatory vehicle evidence;
   - current country/category requirements exist and are active;
   - vehicle payload/capacity and route/mode eligibility;
   - partner verification/compliance/capability and exact-leg authorization;
   - applicable shipment compliance and customs clearance for the exact leg.
3. Apply equivalent gates to single-leg and multi-leg shipments. Missing requirement configuration, unknown jurisdiction, expired/revoked evidence or missing vehicle binding must block execution.
4. Revoke or suspend future assignments when binding/evidence becomes invalid; do not silently rewrite an in-progress trip. Define a safe exception/stop-work procedure for a vehicle already in transit.
5. Align eligible-driver and eligible-vehicle listing predicates with the final bind predicates to prevent false-positive UI choices.
6. Add audit events and reason codes for each denial and each eligibility transition.
7. Build isolated Staging tests for expiry between acceptance and pickup, revocation between pickup and transit, vehicle suspension, driver licence expiry, missing requirement rules, single-leg and multi-leg parity, cross-tenant IDs, replay and concurrency.
8. Keep Production untouched until migration provenance, security review, Staging parity and negative tests pass.

## Status register

| Control | Status |
|---|---|
| Vehicle/driver checks at binding | SOURCE/DB DEFINITION VERIFIED; runtime NOT TESTED |
| Vehicle/driver checks at assignment acceptance | SOURCE/DB DEFINITION VERIFIED; runtime NOT TESTED |
| Vehicle/binding/document recheck at pickup | FAIL / NOT DEMONSTRATED |
| Vehicle/binding/document recheck at transit | FAIL / NOT DEMONSTRATED |
| Common single-leg/multi-leg execution gate | FAIL |
| Eligible-driver list parity with bind checks | FAIL |
| Dispatch trigger includes current vehicle evidence | NOT DEMONSTRATED |
| Production/Staging end-to-end parity | NOT VERIFIED |
| Synthetic user/dispatch testing | BLOCKED |

## Change control

Read-only audit only. No SQL writes, migrations, grants, test identities, invitations, vehicle bindings, assignments, dispatch authorizations, deployments or Production changes were made.
