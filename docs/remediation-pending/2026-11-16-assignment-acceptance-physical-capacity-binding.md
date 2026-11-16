# Partner assignment acceptance and physical capacity binding — remediation specification

**Date:** 2026-11-16  
**Status:** Prepared from read-only production function inspection; NOT applied.  
**Production writes:** None. No assignments, reservations, commitments, shipment legs or tracking events were created or changed.

## Functions and verified behavior

The live partner acceptance path includes `public.krim_internal_finalize_partner_assignment(bigint)` and a partner-facing acceptance RPC (the exact public signature and full ACL must be confirmed during migration/dependency reconciliation).

The acceptance implementation inspected:

1. Validates the assignment is offered, checks response deadline, quote validity, quote/shipment/partner binding, capability coverage, partner registration and current compliance.
2. For a shipment without an explicit leg binding, it selects the first shipment leg. If no leg exists, it creates a new leg using a service-tier-derived mode, defaulting to ROAD.
3. Marks the partner assignment accepted and updates/creates a shipment leg.
4. Writes a tracking event and audit event in the same transaction.
5. The trigger `krim_ensure_assignment_capacity_commitment()` creates a `krim_partner_shipment_capacity_commitments` row on acceptance. It uses total shipment weight in kg and validates that the abstract commitment is current and matches the partner.
6. The internal finalizer requires that abstract commitment before marking a shipment or leg assigned.

## Key distinction: commitment is not physical reservation

The trigger-created row is a partner-level shipment weight commitment. It does not, by itself, bind a real vehicle/resource, time window, lane, capacity availability row or `krim_capacity_reservations` record.

The database also contains a separate capacity reservation model:

- `krim_partner_capacity_availability`
- `krim_partner_capacity_commitments`
- `krim_capacity_reservations`
- `krim_capacity_leg_bindings`
- `krim_capacity_leg_binding_events`

The assignment trigger currently does not create or verify a corresponding reservation/binding from that model. The current finalizer's readiness count joins the abstract shipment commitment, not a live physical capacity reservation. Therefore the UI/database status can represent an accepted and assigned provider commitment without proving a specific resource has been reserved for the exact leg and service window.

## Additional exact-leg risk

The acceptance path's fallback to the first leg, or creation of a default ROAD leg when no leg exists, is not a safe substitute for an authoritative customer-requested transport mode and reviewed route plan. It can bind a partner acceptance to a leg that was not explicitly selected by the customer or approved as part of a route plan.

This fallback must not be used for new commercial operations. Existing historical rows require a read-only impact inventory before any remediation.

## Required corrective design

1. **Require authoritative leg binding**
   - Every commercial partner offer/assignment must reference an existing shipment leg or an explicitly approved leg-plan item.
   - Require exact shipment, leg, partner, origin, destination, transport mode and route-plan version equality.
   - Reject acceptance if leg is null, missing, ambiguous, unplanned, already assigned to another provider, or inconsistent with the customer's requested mode.
   - Remove implicit first-leg selection and implicit default-ROAD leg creation from the commercial acceptance path.
   - Do not synthesize legs from service-tier labels.

2. **Separate commercial acceptance from operational readiness**
   - Partner may accept a commercial offer only when the quote is current, exact-leg scoped, compliance-current, service-area approved, and market/corridor controls pass.
   - The accepted offer must remain `accepted_pending_capacity` (or equivalent) until an exact physical resource reservation is atomically bound.
   - Do not mark the shipment leg `assigned`, mark shipment `assigned`, or expose dispatch readiness before the required reservation and operational controls are satisfied.

3. **Bind physical capacity atomically**
   - Resolve a verified active resource/availability row compatible with exact partner, mode, lane, capacity unit, quantity and schedule.
   - Serialize on the canonical availability/resource/commitment row(s) using a deterministic lock order.
   - Recalculate remaining capacity after active reservations, bookings, commitments and utilization under lock.
   - Create one reservation for the exact shipment and leg, then one binding linking that reservation to the same shipment/leg and availability/commitment.
   - Store the resource, unit, quantity, schedule, source evidence and idempotency payload. Do not accept a generic kg weight as a vehicle reservation unless the resource capacity is explicitly expressed in a compatible unit and its load constraints are checked.
   - Enforce one active binding per assignment/leg where business rules require it; reject overbooking and concurrent races.

4. **Idempotency and lifecycle**
   - Identical retries return the same reservation/binding only when canonical payload, partner, exact leg, amount, unit, schedule and resource are identical.
   - Conflicting retries fail without changing the original reservation.
   - Quote expiry, offer rejection, customer cancellation, assignment cancellation and reservation expiry must release or cancel the reservation exactly once with an auditable reason.
   - Dispatch requires the exact active binding/reservation and exact-leg dispatch authorization; an abstract partner shipment commitment is not sufficient.
   - Reassignment must release/transfer the old binding under a controlled transaction before a new provider can consume capacity.

5. **Legacy path containment**
   - Audit all public and internal functions, triggers, edge functions and grants that can create, accept, finalize, activate or dispatch assignments.
   - Correct or retire the first-leg/default-ROAD fallback and any legacy path that can mark a shipment assigned without exact physical capacity binding.
   - UI controls alone are not a security boundary. Database grants and SECURITY DEFINER entry points must be reconciled.

## Required staging tests

- Assignment with no leg: reject; do not create a leg.
- Assignment with multiple legs and no exact leg ID: reject; do not select first leg.
- Requested mode conflicts with leg/quote/plan: reject.
- Exact leg accepted with valid quote/compliance/approved corridor but no capacity: remain pending capacity; no dispatch readiness.
- Exact resource available and compatible: one reservation and one binding created atomically.
- Inactive/unverified resource, wrong lane/mode/unit, insufficient capacity or out-of-window resource: reject.
- Two concurrent acceptances competing for final resource capacity: no overbooking.
- Identical retry: same binding; changed resource/quantity/unit/time/leg with same idempotency key: reject.
- Rejection, quote expiry, customer cancellation and reassignment: reservation released once; audit events preserved.
- Direct invocation of all legacy acceptance/finalization/dispatch RPCs.
- Tenant isolation, role permissions, audit trail, rollback on failure and exact-leg authorization.

## Release gate

Do not enable assignment acceptance or dispatch as unrestricted operational flows until migration history is reconciled, canonical function definitions and grants are reviewed, the corrective migration is staged, concurrency tests pass, and verified resource/capacity evidence exists.

**Production evidence context:** Prior read-only operational audit found zero accepted assignments, zero active capacity reservations and zero dispatch authorizations. This is not proof that the schema is ready; it means no live operational journey has yet demonstrated this control end to end.
