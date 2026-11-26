# Phase 04.12 — Assignment Change, Cancellation, Reassignment and Binding Revocation Audit

Date: 2026-11-26  
Scope: Read-only Production/Staging inspection of driver assignment, partner assignment, vehicle binding and trigger surfaces. No row mutations or runtime cancellation/reassignment were performed.

## Executive result

**FAIL — vehicle unbinding is guarded against open assignments, but lifecycle coordination between partner assignments and driver assignments is not demonstrated. Production and Staging also differ in driver-assignment audit trigger wiring.**

## Evidence inspected

- `krim_vehicle_driver_unbind(uuid,text)`
- `krim_vehicle_driver_bind(bigint,uuid,uuid)`
- `krim_assign_driver_to_partner_shipment(bigint,uuid)`
- `krim_driver_accept_assignment(uuid)`
- `krim_driver_assignments` indexes and schema
- Triggers on `krim_shipment_partner_assignments`, `krim_driver_assignments`, `krim_vehicle_driver_bindings` and `krim_vehicles`
- Production and Staging function definitions and trigger catalogs.

## Positive controls

1. Vehicle unbinding requires authentication, `shipment.dispatch` permission scoped to the binding's organization, and a reason of at least five characters.
2. Unbinding locks the active binding row and refuses to revoke it while a matching driver/vehicle assignment is in an open state (`assigned`, `accepted`, `pickup_complete`, `in_transit`, `exception`).
3. Successful unbinding records actor, reason and before/after state in an audit event.
4. Active binding uniqueness is protected by partial unique indexes: one active binding per driver and one per vehicle.
5. Partner assignment changes have triggers for state validation, quote integrity, audit, capacity commitment and capacity release on terminal status.
6. Driver assignment table has unique partner-assignment linkage, preventing duplicate driver assignment rows for the same partner assignment.

## Findings

### F04.12-01 — Partner assignment cancellation/rejection does not visibly reconcile driver assignment (HIGH)

The inspected partner-assignment trigger set validates partner assignment state and audits changes, and releases capacity on terminal status. No inspected trigger or cancellation/revocation function automatically transitions, blocks or invalidates the linked `krim_driver_assignments` row when its partner assignment becomes rejected, cancelled, expired or otherwise terminal.

The driver acceptance function checks that its linked partner assignment is still accepted/active. However, the assignment can become terminal after acceptance. The trip-event path must independently revalidate this linkage at every event; Phase 04.10 found that complete common revalidation was not demonstrated.

### F04.12-02 — Vehicle unbinding is blocked rather than safely reassigned (MEDIUM)

The unbind function refuses to revoke a binding while any open assignment exists. This is a useful safety control, but it means a legitimate vehicle/driver replacement requires a defined operational transition: stop or safely complete the current work, cancel/replace pending work, then revoke and rebind. No atomic reassignment workflow was verified.

### F04.12-03 — Production/Staging driver assignment audit trigger mismatch (HIGH)

Staging has an `AFTER UPDATE OF status` trigger that writes a driver-assignment acceptance audit event when status changes to accepted. Production's inspected trigger catalog did not show this trigger. This is an environment parity gap and creates different audit evidence for the same driver acceptance event.

### F04.12-04 — No dedicated cancellation/revocation RPC surfaced by the targeted catalog search (MEDIUM)

Targeted searches for public functions with cancellation/revocation names related to shipment or driver assignments returned no matching functions. This does not prove that cancellation is impossible; status may be changed through other authorized workflows or generic admin functions. Those callers and grants need tracing before release.

### F04.12-05 — Reassignment, stale assignment and in-transit safety semantics are undefined (HIGH)

The inspected model blocks unbinding while an assignment is open, but no complete state machine was demonstrated for:
- replacing driver/vehicle before acceptance;
- replacing after acceptance but before pickup;
- cancelling after pickup;
- partner assignment terminal transition during transit;
- driver suspension or vehicle document expiry while in transit;
- preserving custody, location and incident history;
- preventing a second active assignment while a previous assignment is being stopped.

A simple cascade cancellation is unsafe once pickup/custody has begun. In-transit changes need a stop-work/incident and controlled handover process, not silent reassignment.

### F04.12-06 — Runtime and authorization tests remain NOT TESTED

No authenticated browser actions, cancellation RPC calls, row updates, RLS negative tests, concurrent reassignments or trip-state simulations were executed. Function/trigger catalog evidence is static and does not prove caller reachability or runtime behaviour.

## Required remediation design (not applied)

1. Define an explicit driver-assignment state machine, including pending, assigned, accepted, pickup-complete, in-transit, exception, completed and cancelled/revoked terminal states, with allowed transitions and actor permissions.
2. On partner assignment terminal transition, atomically block new driver acceptance and future trip events for the exact linked assignment. Before pickup, transition the driver assignment to cancelled/revoked with reason and audit. After pickup, open an incident/stop-work workflow and preserve custody until controlled handover.
3. Add an authorized, idempotent cancellation/reassignment workflow with row locks on partner assignment, shipment leg, driver assignment, vehicle and binding. Require replacement eligibility to pass all current driver/vehicle/route/compliance gates.
4. Keep the existing unbind guard; do not weaken it. Provide a controlled pre-pickup cancellation path that makes the open assignment terminal before unbinding.
5. Add a durable binding reference and binding/version snapshot to each driver assignment; every later event verifies the same binding remains active.
6. Align Production and Staging audit triggers and event schemas, then verify no duplicate audit events.
7. Add automated tests for partner cancellation before acceptance, after acceptance, after pickup, during transit, vehicle revocation, driver suspension, vehicle expiry, duplicate cancel/reassign, two concurrent replacement requests, cross-tenant IDs and event replay.
8. Keep Production untouched until Staging negative/concurrency tests and independent review pass.

## Status register

| Control | Status |
|---|---|
| Permission/reason checks for unbinding | Definition verified |
| Unbind blocked for open assignments | Definition verified |
| Active binding uniqueness | Indexes verified |
| Partner assignment audit/state/capacity triggers | Definition verified |
| Automatic driver assignment reconciliation on partner cancellation | NOT DEMONSTRATED |
| Safe reassignment workflow | NOT DEMONSTRATED |
| In-transit stop-work and custody-preserving handover | NOT DEMONSTRATED |
| Production/Staging driver acceptance audit parity | FAIL |
| Runtime cancellation/reassignment tests | NOT TESTED |

## Change control

Read-only audit. No SQL writes, migrations, grants, status changes, assignment cancellations, reassignments, vehicle unbindings, deployments or Production changes were made.
