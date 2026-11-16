# KRIM Global Logistics Control Tower and Execution Integrity Audit — 2026-11-16

## Scope and safety
Read-only review of live shipment lifecycle, route and multi-leg planning, partner assignment, capacity, dispatch authorization, tracking, proof of delivery, warehouse handovers, readiness/compliance gates and exception recovery. Inspected production row counts, selected RLS policies/table privileges and operational RPC execution grants. No shipment, route, quote, assignment, capacity hold, dispatch, tracking event, warehouse task, exception or POD was created or changed. No business RPC or production migration was executed.

## Executive result
**Not ready for live end-to-end logistics execution.** KRIM has a substantial operational schema and many guarded RPCs, but production data demonstrates only a very small, incomplete footprint. There are no verified partner assignments, capacity resources/reservations, dispatches, verified PODs or warehouse facilities/inventory. A planned route and a single shipment leg exist, but no active route plan or multi-leg orchestration record exists.

The existing 18 shipment records are not proof of an operational logistics network: 8 are drafts, 3 quoted, 6 confirmed and 1 closed. No active assigned/dispatched/in-transit shipment was present in the snapshot.

## Live production snapshot

| Operational component | Rows |
|---|---:|
| Shipments | 18 |
| Shipment legs | 1 |
| Shipment routes | 1 |
| Route options | 0 |
| Shipment leg plans / plan items | 0 / 0 |
| Capacity resources | 0 |
| Capacity reservations / bookings | 0 / 0 |
| Partner capacity commitments | 0 |
| Shipment partner assignments | 0 |
| Leg dispatch authorizations | 0 |
| Dispatch records | 0 |
| Tracking events | 1 |
| Shipment milestones | 2 |
| POD records | 0 |
| Legacy POD documents | 0 |
| Warehouse facilities / inventory | 0 / 0 |
| Warehouse receipts / tasks / allocations | 0 / 0 |
| Leg custody transfers | 0 |
| Operational exceptions / escalations / timers | 0 / 0 / 0 |

### Shipment status distribution

| Status | Rows |
|---|---:|
| draft | 8 |
| quoted | 3 |
| confirmed | 6 |
| closed | 1 |

The only route row is `planned`. The only shipment leg and route do not demonstrate multi-leg planning, partner custody, dispatch or tracking continuity.

## Important control findings

### 1. Readiness gates are not evidence of execution readiness
- Six shipment readiness-gate rows currently report `ready`, and six compliance-gate rows exist.
- The earlier live audit found zero configured compliance rules and zero recorded compliance checks. Consequently, a `ready` status must not be interpreted as proof that required legal, route, cargo, document or partner checks were performed.
- The readiness and compliance gate tables allow authenticated direct INSERT/UPDATE/DELETE through organization-scoped ALL policies. This creates a material integrity risk: a customer-organization member may be able to mutate gate outcomes rather than relying exclusively on trusted evaluators/reviewers.
- Treat gate rows as untrusted until rule coverage, evidence provenance, reviewer separation and immutable evaluation history are demonstrated.

### 2. Multi-leg custody and dispatch authorization are fail-closed at the table layer
- `krim_shipment_leg_custody_transfers` and `krim_shipment_leg_dispatch_authorizations` have RLS enabled and zero policies; authenticated and anon have no direct table privileges. This is a positive default-deny posture.
- Their controlled SECURITY DEFINER RPCs are present, including `krim_create_leg_custody_transfer`, `krim_respond_to_leg_custody_transfer`, `krim_authorize_leg_dispatch` and `krim_revoke_leg_dispatch_authorization`.
- Function grants show authenticated execution for these RPCs, with no anon execution. That grant inventory alone does not prove correct deployed function bodies, helper permissions, evidence checks or workflow completion.
- No custody transfer or dispatch authorization exists in production.

### 3. Capacity and assignment are not commercially bookable
- Capacity resource, reservation, booking and partner commitment tables are empty.
- The capacity reservation table is SELECT-only for authenticated users; writes are expected to go through controlled functions.
- Partner capacity registration and shipment-leg reservation RPCs exist, but zero live resource/commitment/reservation records means KRIM cannot currently substantiate availability or reserve capacity.
- Do not show a partner as available or a shipment as bookable based solely on directory status, an open opportunity or a draft capacity record.

### 4. Warehouse operations have no live footprint
- Facilities, inventory, receipts, tasks, shipment allocations and transfers are all zero.
- Warehouse allocation reads are party-scoped; direct writes are not granted to authenticated users.
- Existing warehouse RPCs cover task creation, receipt, picking, allocation, evidence and quality review. Their presence is not proof that facilities are verified, inventory is available, reservations are respected or handovers have occurred.
- Carry forward the previously identified P1 invariant: dispatch/transfer must never consume inventory reserved for a shipment. Available-to-promise must be calculated as on-hand quantity minus active reserved allocations, under concurrency-safe locking.
- A warehouse handover must remain blocked until both sides' custody, quantity, condition, seal/discrepancy and evidence records are reconciled.

### 5. Dispatch, tracking and POD are unproven
- Dispatch records and POD records are zero; tracking has one row and milestones have two.
- Driver and vehicle records/assignments were previously found empty. A driver-facing RPC exists to submit POD, while independent verification is a separate privileged operation.
- Do not treat a submitted POD, signature reference or tracking ping as verified delivery. Require evidence ownership, shipment/leg/assignment linkage, recipient details, timestamp, geospatial/source provenance where applicable, independent verification and an immutable audit event.
- Tracking should be append-only, deduplicated/idempotent, timestamped with source and event sequence, and should distinguish carrier-reported from independently verified events.

### 6. Lifecycle and exception recovery
- The configured transition map permits `dispatched -> cancelled`, as well as dispatched/in-transit/delivered to exception.
- A generic cancellation after dispatch is unsafe because it may leave capacity, driver, inventory, custody, partner and customer commitments unreconciled. Post-dispatch cases must use disruption/return/recovery workflows; cancellation should be blocked unless all downstream resources and external commitments are reconciled.
- Exception/escalation/timer tables are empty. Resolver and escalation RPCs exist, but zero live cases means deadlines, notifications, acknowledgement, corrective action and closure have not been operationally proven.
- A successful database state transition must not imply that an external carrier, warehouse, customs broker or customer has been notified or has accepted the change.

## Access and function inventory

| Table | RLS | Authenticated direct access observed |
|---|---:|---|
| `krim_shipments` | on | SELECT only; organization/assignment/operations scoped |
| `krim_shipment_legs` | on | SELECT only; shipment organization scoped |
| `krim_shipment_readiness_gates` | on | SELECT, INSERT, UPDATE, DELETE; organization ALL policy |
| `krim_shipment_compliance_gates` | on | INSERT, UPDATE, DELETE; organization ALL policy; SELECT not granted |
| `krim_capacity_reservations` | on | SELECT only; organization scoped |
| `krim_warehouse_shipment_allocations` | on | SELECT only; party/permission scoped |
| `krim_shipment_leg_custody_transfers` | on | no direct privileges; no policies |
| `krim_shipment_leg_dispatch_authorizations` | on | no direct privileges; no policies |
| `shipment_pod_documents` | on | no direct privileges; no policies |

Authenticated EXECUTE is present on numerous SECURITY DEFINER operational functions, including shipment creation, route-plan evaluation/activation, partner capacity registration, leg assignment/dispatch authorization, custody transfer, driver POD submission, warehouse tasks and exception resolution. No anon EXECUTE was observed for the listed operational SECURITY DEFINER RPCs. Function bodies, helper chains and effective role/permission checks must still be reviewed individually before a production transaction is authorized.

## Priority remediation sequence

1. **P0 — Freeze unsafe lifecycle shortcuts:** block dispatched/in-transit generic cancellation and require disruption/return/reconciliation workflows; retain the existing disabled cancellation UI until the server-side path is proven safe.
2. **P0 — Harden gate integrity:** after migration-history reconciliation, remove ordinary authenticated direct writes to readiness/compliance gates; route evaluations through trusted, audited functions. Establish explicit rule coverage and independent review; never treat an empty-rule evaluation as cleared.
3. **P0 — Reconcile migrations:** production migration history and repository SQL lineage are materially divergent. Do not replay, baseline, squash or apply operational/security migrations until the sanitized production schema manifest has been reconciled with repository source and deployed function definitions.
4. **P1 — Prove exact-leg orchestration:** route plan → verified capability → partner quote → customer award → assignment → capacity reservation → dispatch authorization → dispatch → tracking → custody handover → verified POD. Enforce exact shipment/leg/partner linkage and idempotency at each transition.
5. **P1 — Prove capacity and inventory invariants:** prevent overbooking and double allocation under concurrent requests; enforce capacity expiry and inventory available-to-promise using row locks/unique constraints.
6. **P1 — Prove evidence and custody:** private object ownership, immutable event history, two-party handover acceptance, discrepancies and independent POD verification.
7. **P1 — Prove exception recovery:** detect missed milestones, create escalation timers, assign accountable owners, notify parties with delivery receipts, record actions and reconcile any external carrier/warehouse action before closure.
8. **P2 — Only then run controlled pilot:** one verified partner, one verified lane, one low-risk shipment, human operations oversight, customer/partner confirmation and full evidence review. No hazardous, temperature-controlled, customs-dependent or cross-border shipment until the relevant specialist controls and corridor approvals are proven.

## Release decision
**NO-GO for claiming KRIM is a live, end-to-end logistics execution network or accepting operational bookings/dispatches on the strength of the current production evidence.** A limited, explicitly human-coordinated referral/lead pilot may proceed only within the existing legal/commercial model, with the customer contracting and paying the logistics provider directly and with no unsupported claims about availability, capacity, rates or coverage.

## Verification boundary
This audit used read-only production SQL and repository context. It did not execute any business RPC, create test data, change grants/policies, deploy code or modify migration history. A later integration test must use a separately approved non-production environment or a deliberately isolated pilot transaction after all security and migration gates are closed.
