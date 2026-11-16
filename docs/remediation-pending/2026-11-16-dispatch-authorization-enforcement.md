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
