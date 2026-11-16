# Dispatch authorization enforcement — remediation specification

**Date:** 2026-11-16  
**Status:** Read-only production inspection; remediation prepared, NOT applied.  
**Production writes:** None. No dispatch, shipment transition, driver assignment, capacity reservation or tracking event was created or changed.

## Verified dispatch paths

The live database exposes materially different dispatch paths.

### Stronger exact-leg authorization path

`public.krim_authorize_leg_dispatch(bigint,text)`:

- Requires an authenticated user and `shipment.dispatch` permission for the assignment's partner.
- Requires an accepted/active partner assignment with a non-null exact shipment leg.
- Requires that exact leg to be assigned.
- Requires a confirmed `krim_capacity_leg_bindings` row for the same shipment and leg.
- Requires the matching confirmed partner-owned `krim_capacity_reservations` row.
- For ROAD, requires an accepted driver assignment on the exact shipment leg, current driver licence evidence, active verified vehicle and required vehicle documents.
- For later legs, requires accepted custody transfer from the immediately preceding leg.
- Writes a dispatch-authorization record and partner execution event. Authorization is not itself proof that the vehicle physically departed.

This is the intended control path, but its currentness helper, revocation behavior and all callers still require complete dependency/ACL review.

### Weaker shipment-wide legacy path

`public.krim_dispatch_shipment(bigint,text,jsonb)`:

- Selects the first assigned partner leg by sequence.
- Requires accepted assignment and a current abstract partner shipment capacity commitment.
- Rechecks current partner compliance and broad shipment capability.
- Calls the generic shipment transition to `dispatched`.
- Does not require a confirmed exact-leg physical capacity binding, reservation or dispatch-authorization record.
- Does not enforce exact-leg driver acceptance in the inspected body.

This function can therefore bypass the stronger physical reservation and authorization gate if it remains executable.

### Internal assigned-shipment finalizer

`public.krim_internal_dispatch_assigned_shipment(bigint)`:

- Requires an accepted/active assignment, linked quote and exact leg.
- Requires an abstract partner shipment capacity commitment and an accepted exact-leg driver assignment with a vehicle.
- Performs additional driver, vehicle, shipment readiness and operational checks.
- The inspected body still needs full review for exact-leg dispatch authorization and confirmed physical capacity binding requirements before it can be treated as equivalent to the explicit authorization path.

### Other readiness functions

`private.krim_leg_dispatch_authorization_is_current(...)` is used to validate existing authorization replay. Its full body, grants, dependencies and revocation triggers must be included in the final database remediation review. An authorization record must become invalid when its assignment, reservation, binding, compliance, driver, vehicle, corridor or custody prerequisites cease to be valid.

## Required remediation

1. **One mandatory dispatch gate**
   - All authenticated, service-role, internal, trigger, edge-function and scheduled dispatch entry points must converge on one exact-leg readiness predicate.
   - Require an active exact-leg assignment and current quote/partner compliance.
   - Require an approved exact service area, market activation, corridor dossier and current mandatory controls for the leg.
   - Require a confirmed reservation and confirmed binding for the exact shipment, leg, partner, resource, mode, lane, quantity, unit and schedule.
   - Require current exact-leg dispatch authorization. For ROAD, require current accepted driver and verified vehicle evidence; for later legs, require accepted custody transfer from the immediately preceding leg.
   - Reject null or ambiguous leg bindings. Never choose the first leg or infer a default mode.

2. **Retire or harden bypass paths**
   - Correct `krim_dispatch_shipment(bigint,text,jsonb)` to require exact-leg authorization, matching binding and reservation before it can transition any shipment.
   - Correct `krim_internal_dispatch_assigned_shipment(bigint)` to call the same canonical gate and verify the exact authorization record; abstract capacity commitment and driver acceptance are necessary but not sufficient.
   - Review every overload, wrapper, trigger, Edge Function and direct grant that can transition a shipment/leg to dispatched.
   - If a legacy path cannot be safely corrected immediately, revoke its execution grants after dependency review and ensure no privileged caller still depends on it. Do not rely on frontend hiding.

3. **Separate authorization from physical departure**
   - `authorized` means preconditions were satisfied; it does not mean cargo departed.
   - A separate exact-leg departure event must require the active authorization and capture actor, timestamp, assignment, leg, resource/vehicle, seal and evidence where applicable.
   - Only the departure event should advance the exact leg to in-transit. Shipment-wide status should be derived from its leg plan, not from dispatching the first leg.
   - Idempotent replay must compare canonical payload; a changed vehicle, leg, reservation, seal or evidence must not silently reuse an earlier event.

4. **Currentness and revocation**
   - Revalidate the authorization at the moment of departure, not only when it is first created.
   - Revoke/block dispatch when reservation/binding is cancelled or expired, driver/vehicle evidence expires or is revoked, assignment changes, partner compliance becomes stale, corridor controls lapse, or custody is not accepted.
   - Make revocation auditable and ensure revoked authorizations cannot be replayed as current.

5. **Transaction and concurrency**
   - Lock shipment, exact leg, assignment, reservation and binding in a deterministic order.
   - Prevent two assignments or dispatch paths from consuming the same reservation.
   - Ensure authorization, departure event and lifecycle transition either commit atomically or roll back together.
   - Preserve idempotency with canonical payload comparison and explicit conflict errors.

## Required staging tests

- Exact-leg authorization absent, revoked, stale or bound to another assignment: dispatch rejected.
- Missing, expired, cancelled, wrong-partner, wrong-leg or wrong-shipment reservation/binding: dispatch rejected.
- Abstract shipment capacity commitment present but physical reservation absent: dispatch rejected.
- Multiple assigned legs: shipment-wide legacy RPC cannot dispatch the first leg implicitly.
- Null leg/default-ROAD fallback: rejected; no leg creation.
- ROAD without accepted exact-leg driver, current licence, active verified vehicle or mandatory documents: rejected.
- Later leg without accepted custody transfer from immediately previous leg: rejected.
- Expired/revoked partner compliance, service area, market/corridor approval or mandatory control: rejected.
- Authorization valid at creation but reservation, driver, vehicle or compliance revoked before departure: departure rejected.
- Exact departure event advances only the exact leg; shipment-level state follows route-plan rules.
- Concurrent dispatch calls on same reservation: at most one succeeds.
- Identical retry is idempotent; altered payload with same key is rejected.
- Direct invocation of all legacy, internal, privileged and Edge Function paths.
- Permission, tenant isolation, AAL where required, audit events, event ordering and rollback tests.

## Release gate

Do not enable unrestricted dispatch until production migration history is reconciled, every dispatch-capable function and grant is inventoried, canonical function definitions and security properties are reviewed, the remediation is tested on staging, and end-to-end tests prove exact-leg authorization plus physical reservation are mandatory for every dispatch path.

**Operational evidence context:** Earlier read-only audits found zero dispatch authorizations, zero driver assignments, zero trip events and zero confirmed custody transfers. No complete real dispatch journey has yet been demonstrated.


## 2026-11-17 read-only structural and ACL revalidation

The following additional production facts were confirmed after the initial specification. No data or schema was changed.

### Function execution ACLs

The inspected function ACLs are:

| Function | SECURITY DEFINER | Explicit EXECUTE ACL |
|---|---:|---|
| `krim_authorize_leg_dispatch(bigint,text)` | yes | postgres, service_role, authenticated |
| `krim_dispatch_shipment(bigint,text,jsonb)` | yes | postgres, service_role |
| `krim_internal_dispatch_assigned_shipment(bigint)` | yes | postgres, service_role |
| `krim_driver_record_trip_event(uuid,text,text)` | yes | postgres, service_role, authenticated |
| `krim_driver_submit_delivery_pod(uuid,text,text,text)` | yes | postgres, service_role, authenticated |
| `krim_internal_submit_delivery_pod(bigint,text,text,text,jsonb)` | yes | postgres, service_role |
| `krim_admin_review_delivery_pod(bigint,text,text)` | yes | postgres, service_role, authenticated |

The explicit ACL list does not show a PUBLIC grant, but final effective privilege analysis must still account for inherited roles, default ACLs, function overloads and callers. The authenticated dispatch authorization and trip-event functions remain direct API surfaces and must be tested for exact tenant and leg binding.

### Relational constraints observed

- `krim_driver_assignments` has a composite foreign key `(shipment_leg_id, shipment_id)` to `krim_shipment_legs(id, shipment_id)`, which correctly binds a driver assignment to a leg within its shipment.
- Its `partner_assignment_id` is only a single-column foreign key to `krim_shipment_partner_assignments(id)`; there is no composite constraint proving that the referenced partner assignment has the same shipment, leg and organization as the driver assignment.
- `krim_driver_assignments.organization_id`, `vehicle_id`, `user_id` and `partner_assignment_id` are independently referenced. Cross-row equality is currently dependent on RPC logic and must be enforced by a canonical validator/transactional write path.
- `krim_vehicle_driver_bindings` has independent foreign keys to driver user, driver profile, vehicle and organization. The inspected constraints do not by themselves prove that all four references belong to the same organization/profile/user tuple.
- `krim_capacity_leg_bindings` has independent shipment, leg and reservation foreign keys and a unique constraint on `shipment_leg_id`. The listed constraints do not prove that the reservation's shipment, leg and partner organization match the binding and partner assignment. The dispatch RPC performs some of these equality checks, but the schema does not fully encode the tuple.
- `krim_shipment_partner_assignments` has a single-column capacity-binding FK; no listed composite constraint ties the assignment, binding, reservation, shipment, leg and partner organization together.

### Required additional remediation

1. Before adding constraints, run read-only orphan and cross-tenant mismatch inventories for every tuple above; do not assume existing rows are clean.
2. Introduce one canonical private validator for the full tuple: partner assignment ↔ shipment ↔ exact leg ↔ organization ↔ driver assignment ↔ driver profile/user ↔ vehicle ↔ active vehicle-driver binding ↔ capacity binding ↔ reservation.
3. Require the validator on all authenticated and privileged write paths, including assignment creation/acceptance, driver acceptance, vehicle binding/revocation, capacity binding, dispatch authorization, departure, trip events and POD review.
4. After data cleanup and migration reconciliation, add suitable composite unique keys and composite foreign keys (or equivalent declarative constraints) so valid references cannot drift across tenants, shipments or legs. Constraint design must be based on actual column types and business cardinality; do not copy/paste speculative DDL.
5. Recheck binding and driver/vehicle currentness at dispatch and departure under locks. Revoking a vehicle-driver binding or changing the assignment must invalidate any authorization that relied on the old binding.
6. Test direct authenticated calls and service-role/internal paths separately. A frontend membership guard is not sufficient.

### Current release decision

**NO-GO for unrestricted partner dispatch or driver execution.** The stronger authorization RPC is not enough while weaker legacy/internal dispatch paths and incomplete relational tuple constraints remain. Existing frontend pauses remain mitigation only. This revalidation was read-only; no production DDL, grants, assignments, reservations, dispatches, milestones or POD records were changed.
