# Phase 04.13 — Shipment Lifecycle State Machine Audit

Date: 2026-11-26  
Scope: Read-only Production and Staging catalog inspection of shipment transition function, status trigger wiring, lifecycle event/history tables and related execution controls. No shipment rows were changed and no lifecycle events were simulated.

## Executive result

**FAIL / NOT READY.** The database has a centralized shipment transition function and multiple readiness/audit triggers, but its execution is service-role-only in both environments. The transition matrix contents, browser caller chain and end-to-end event semantics were not fully verified in this pass. Production and Staging trigger parity is not exact.

## Evidence

### Central shipment transition function

Both environments contain:
`public.krim_transition_shipment(bigint,text,text,jsonb)`

Inspected definition shows it:
- locks the target shipment row `FOR UPDATE`;
- reads the current status;
- looks up an allowed from-status/to-status pair in `krim_shipment_status_transitions`;
- checks the configured permission through `krim_has_permission`;
- enforces a reason when configured;
- updates shipment status;
- writes status-history and audit data.

ACL inspection in both environments:
- authenticated EXECUTE: **NO**
- anon EXECUTE: **NO**
- service_role EXECUTE: **YES**

This function therefore is not a direct browser-callable authenticated RPC. A trusted server-side caller must be identified and verified before claiming the UI can transition shipments.

### Shipment and leg trigger wiring

Production inspected:
- shipment trigger count: 13
- leg trigger count: 9
- driver-assignment trigger count: 0

Staging inspected:
- shipment trigger count: 14
- leg trigger count: 9
- driver-assignment trigger count: 1

Both environments include shipment readiness enforcement, status event emission, status history, status audit, operational snapshot refresh, dispatch capacity guards, corridor/market activation guards and leg status history. Staging additionally has a shipment warehouse-handover guard and a driver-assignment acceptance audit trigger in the inspected trigger set. Production lacks those two trigger entries.

## Findings

### F04.13-01 — Central transition RPC is not available to authenticated browser role (HIGH)

The transition function is service_role-only in both environments. No verified Edge Function or trusted backend caller was traced in this pass. If the browser calls it directly, the call is denied; if an Edge Function calls it, that function's caller authentication, tenant scope, permission checks and audit actor propagation must be verified.

### F04.13-02 — Production/Staging trigger parity differs (HIGH)

Staging has an additional warehouse-handover-before-shipment-dispatch trigger and a driver-assignment acceptance audit trigger. These are absent from the inspected Production trigger catalog. Identical shipment status changes may therefore have different enforcement and audit effects across environments.

### F04.13-03 — State machine coverage is not yet proven (HIGH)

The transition function consults a data-driven transition matrix, but the allowed transition rows, terminal-state rules, actor permissions, role scope and reason requirements were not successfully retrieved as a bounded result in this pass. It is not safe to assert the complete lifecycle graph is correct.

### F04.13-04 — Booking, quote, partner assignment, driver assignment, leg and shipment states are separate models (MEDIUM)

The schema contains separate status/event structures for booking requests, quotes, partner assignments, driver assignments, shipment legs and shipment-wide status. No single end-to-end consistency proof was performed. A valid transition in one object may leave dependent objects stale unless explicit transactional reconciliation exists.

### F04.13-05 — Duplicate/replay event guarantees remain unverified (MEDIUM)

The database contains shipment event receipt and event-sequence structures, but their unique constraints, event-idempotency behaviour, out-of-order handling, duplicate receipt semantics and retry outcomes were not proven in this pass.

### F04.13-06 — Delivery proof and completion linkage remains unverified (HIGH)

The catalog includes delivery proof/evidence and shipment status history structures. The precise rule that prevents completion without accepted proof of delivery, receiver identity, timestamp, location and exception handling was not verified. No claim of end-to-end POD enforcement can be made.

### F04.13-07 — Runtime lifecycle testing not performed

No booking, quote acceptance, shipment creation, partner assignment, driver acceptance, pickup, transit, POD, completion, cancellation, invalid transition, duplicate event or cross-tenant test was executed. Existing live data was not mutated.

## Required remediation / verification plan

1. Retrieve and review every transition matrix row and prove no forbidden transition is enabled; explicitly define terminal states and permitted reopen/exception paths.
2. Trace every caller of `krim_transition_shipment`. Require a trusted server gateway with verified JWT, tenant-scoped authorization, least-privilege service-role use, explicit actor identity, request idempotency and audit propagation. Never expose service-role credentials to browsers.
3. Reconcile Production/Staging trigger differences through migration provenance and code review; do not simply copy triggers without understanding safety semantics.
4. Define a cross-object lifecycle contract for booking → quote → partner assignment → driver assignment → leg → shipment → POD → completion, including transactional updates and compensation/exception handling.
5. Prove unique event IDs, idempotent receipt, duplicate suppression, out-of-order rejection/queuing and sequence locking under concurrency.
6. Require verified POD and accepted delivery evidence before shipment completion; define failed delivery, partial delivery, damage, refusal and return paths.
7. Test invalid status transitions, unauthorized actors, cross-tenant shipment IDs, repeated requests, concurrent transitions, cancellation before/after pickup, duplicate/out-of-order events, stale driver/vehicle, missing customs clearance and missing compliance checks in isolated Staging.
8. Preserve partner-direct customer payment model; do not enable KRIM freight collection or partner payouts.
9. Keep Production unchanged until migration provenance, Staging parity and independent negative/runtime tests pass.

## Status register

| Control | Status |
|---|---|
| Shipment transition function exists | VERIFIED |
| Row lock on shipment transition | VERIFIED IN DEFINITION |
| Allowed transition matrix consulted | VERIFIED IN DEFINITION |
| Reason requirement supported | VERIFIED IN DEFINITION |
| Authenticated direct RPC access | DENIED in both environments |
| Trusted server-side caller | NOT TRACED |
| Complete transition matrix correctness | NOT VERIFIED |
| Production/Staging trigger parity | FAIL |
| Booking-to-shipment cross-object consistency | NOT VERIFIED |
| Event idempotency / ordering | NOT VERIFIED |
| POD-before-completion rule | NOT VERIFIED |
| Runtime lifecycle tests | NOT TESTED |

## Change control

Read-only audit only. No SQL writes, migrations, grants, status changes, booking/quote/assignment creation, POD uploads, notifications, deployments or Production changes were made.
