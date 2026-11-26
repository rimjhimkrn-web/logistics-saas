# Phase 04.11 — Driver Assignment Creation and Vehicle Allocation Audit

Date: 2026-11-26  
Scope: Read-only Production/Staging inspection of driver dispatch RPCs, assignment table structure and allocation indexes. No runtime mutation or dispatch was performed.

## Executive result

**FAIL — core assignment checks exist, but assignment eligibility, list parity and concurrency protections are incomplete.** Synthetic dispatch remains blocked.

## Live database evidence

Inspected in both environments:
- `krim_assign_driver_to_partner_shipment(bigint, uuid)`
- `krim_list_dispatchable_drivers(bigint)`
- `krim_driver_accept_assignment(uuid)`
- `krim_driver_assignments` columns and indexes
- `krim_vehicle_driver_bindings` indexes

Both environments expose authenticated EXECUTE and deny anon EXECUTE for the three dispatch RPCs inspected. Assignment creation and list function definitions were inspected in both environments.

## Positive controls in assignment creation

`krim_assign_driver_to_partner_shipment`:
- requires authenticated caller with `shipment.dispatch` permission for the accepted partner assignment's organization;
- locks the partner assignment, shipment and shipment leg;
- requires shipment and exact leg assigned to that partner;
- limits registered road vehicles to ROAD legs;
- checks partner verification/compliance, route capability and active service area;
- requires active same-organization driver membership and verified profile;
- requires accepted front/back licence evidence;
- requires an active binding from the selected driver to a verified, active vehicle;
- requires configured mandatory vehicle requirements and approved, unexpired evidence;
- checks positive shipment weight and recognized vehicle payload units/capacity;
- prevents assigning an already-open driver or vehicle by a pre-insert existence check;
- stores exact shipment, leg, partner assignment, driver, vehicle and creator references and emits an audit event.

A unique index exists for one driver assignment per partner assignment. Active vehicle-driver bindings also have unique partial indexes for one active binding per driver and per vehicle. Those are useful integrity controls.

## Findings

### F04.11-01 — Assignment creation accepts incomplete driver evidence (HIGH)

The assignment-creation RPC requires a verified profile and accepted front/back licence documents, but does not check:
- licence expiry is present and in the future;
- accepted identity document.

The later driver-acceptance RPC checks those additional conditions. This creates an avoidable state where KRIM creates an assignment that the driver cannot accept.

### F04.11-02 — Dispatchable-driver listing is inconsistent between environments (HIGH)

The Production `krim_list_dispatchable_drivers` definition inspected filters active membership, verified profile, licence number and accepted front/back licence documents, but does not filter:
- future licence expiry;
- accepted identity evidence;
- active vehicle binding to a verified operational vehicle;
- current vehicle mandatory documents.

The Staging definition inspected includes these additional checks, including active vehicle binding and current vehicle evidence. Therefore, the list is materially stricter in Staging than Production. The list also returns driver records, not a vehicle selection; the allocation RPC selects the bound vehicle.

### F04.11-03 — Driver/vehicle open-assignment check is not concurrency-safe by itself (HIGH)

Assignment creation performs a `NOT EXISTS` check for open assignments for the driver or vehicle, then inserts. The inspected indexes include a unique key on partner assignment and lookup indexes on driver/status and vehicle/status, but no unique partial index enforcing one open assignment per driver and one open assignment per vehicle.

Two concurrent transactions for different partner assignments could both pass the pre-insert check and allocate the same driver or vehicle. The unique active vehicle-driver binding indexes do not prevent concurrent shipment assignments.

### F04.11-04 — Vehicle choice is implicit, not explicit (MEDIUM)

The allocation RPC selects the active vehicle bound to the driver. This is safe only while the one-active-binding invariant is intact and runtime-tested. The RPC does not accept an explicit vehicle ID, which avoids caller-supplied vehicle substitution, but the assignment should record and validate the binding ID/version used at allocation time for auditable traceability.

### F04.11-05 — Existing assignment retry is idempotent but may hide stale allocation (MEDIUM)

When an assignment already exists for the partner assignment, the function returns it if driver, vehicle and shipment/leg/organization references match. It does not visibly require that the existing assignment is still open or that the binding and evidence remain current before returning it. This is safe from duplicate creation but can return a stale/terminal assignment record to a retrying caller.

### F04.11-06 — Runtime and full caller-path verification remain outstanding

No UI-to-RPC browser test, role-negative test, cross-tenant ID test, concurrency test or vehicle/driver revocation test was performed. The source caller chain and end-user response handling still require a dedicated runtime phase.

## Required remediation design (not applied)

1. Use one shared private eligibility predicate for dispatchable-driver listing, assignment creation, driver acceptance and trip execution.
2. At assignment creation require future licence expiry, accepted identity evidence, active same-org membership, current vehicle binding, verified active vehicle, complete mandatory vehicle evidence and payload compatibility.
3. Align Production list logic with the strict Staging eligibility predicate; avoid exposing drivers that assignment creation will reject.
4. Enforce one open assignment per driver and per vehicle under concurrency using transaction-scoped advisory locks or another proven serialization strategy, plus appropriate database constraints where feasible. Define terminal states and re-assignment semantics explicitly.
5. Store the binding ID and a binding/evidence snapshot or version on the assignment; verify it remains current at acceptance, dispatch, pickup and transit.
6. On idempotent retry, verify the existing assignment is still consistent and return a clearly typed state; do not silently treat terminal/stale assignments as active.
7. Add Staging tests for two simultaneous partner assignments targeting one driver, one vehicle, duplicate retries, expired licence, missing identity document, revoked binding, expired vehicle evidence, mismatched leg/partner, over-capacity load, non-ROAD leg, cross-tenant IDs and terminal assignment retry.
8. Keep Production unchanged until code review, migration provenance, Staging negative/concurrency tests and independent security review pass.

## Status register

| Control | Status |
|---|---|
| Authenticated partner dispatch permission | Definition verified |
| Exact accepted partner assignment / shipment / leg linkage | Definition verified |
| Driver active membership and profile at assignment creation | Definition verified |
| Driver licence expiry and identity evidence at assignment creation | FAIL |
| Vehicle binding and vehicle evidence at assignment creation | Definition verified |
| Payload and ROAD-mode checks | Definition verified |
| Production dispatchable-driver list matches strict eligibility | FAIL |
| Staging/Production dispatchable list parity | FAIL |
| Concurrent one-open-assignment enforcement | NOT DEMONSTRATED / FAIL |
| Idempotent retry of terminal/stale assignment | REVIEW REQUIRED |
| Runtime / browser / negative / concurrency tests | NOT TESTED |

## Change control

Read-only audit. No database writes, migrations, grants, test users, invitations, driver assignments, vehicle bindings, shipment changes, deployments or Production changes were made.
