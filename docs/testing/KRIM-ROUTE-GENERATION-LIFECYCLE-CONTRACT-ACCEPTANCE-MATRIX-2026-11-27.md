# KRIM Route-Generation Lifecycle Contract and Acceptance Matrix — 2026-11-27

## Scope and safety
Design-only checkpoint based on read-only inspection of Staging project `qrpcivhdxobiaofppbkl`. No migration, data write, permission change, or production access.

## Confirmed baseline
The following Staging tables currently contain zero rows: shipments, shipment legs, route plans, route-plan items, partner assignments, driver assignments, POD records, tracking events, and partner execution events. Runtime lifecycle tests cannot be performed until controlled fixtures are provisioned.

## Lifecycle contract (proposed; not implemented)

### Identity hierarchy
1. Shipment: commercial/customer request aggregate.
2. Route generation: immutable version of the operational route selected for the shipment.
3. Route plan: immutable planning snapshot belonging to exactly one generation.
4. Route-plan item: generation-local ordered step.
5. Operational shipment leg: durable execution record mapped to exactly one route-plan item and generation.
6. Assignment, driver assignment, capacity binding, tracking event, custody transfer, and POD: each must reference the exact operational leg; where historical attribution is required, also persist or derive the immutable generation identity.

Never delete/reuse operational leg IDs to replace a route. Historical events and evidence remain attached to the original leg and generation.

### Exact-leg state
- Dispatch: only the exact accepted partner assignment, confirmed capacity and accepted eligible driver may dispatch its exact leg.
- Transit: driver event changes only its exact leg; shipment aggregate is recalculated from active-generation leg states under a locked, transactional rule.
- Arrival/POD: verified POD completes only its exact leg after assignment, shipment, partner, generation, active plan item and evidence are revalidated.
- Completion: shipment becomes delivered only when every required item in the active generation maps one-to-one to a completed leg and the generation's completion policy is satisfied.
- Exception/cancellation: retain the exact leg and event history; no silent deletion or cross-generation state propagation.

### Shipment aggregate semantics (proposed)
Shipment status is a projection of the active generation plus shipment-level commercial state; it is not a substitute for leg status.
- requested/quoted/confirmed/assigned remain commercial/workflow states.
- dispatched means the active generation has met the explicitly defined dispatch threshold (must be decided whether all required legs or first dispatched leg; recommendation: do not imply all legs dispatched when only one is).
- in_transit means at least one active-generation leg is in transit and no terminal shipment state overrides it.
- delivered means all required active-generation items are completed and verified.
- exception means an unresolved blocking exception exists for the active generation.
- cancelled means the shipment itself is cancelled through an authorized workflow, not merely because a route generation was superseded.

A deterministic aggregate function must be pure or transactionally locked, idempotent, and generation-scoped. Every transition must be audited with actor, source, generation, exact leg, previous state, new state, and idempotency key.

## Generation replacement gate
A new generation may be activated only while the current generation is still safely replaceable. Block replacement after irreversible execution evidence (dispatch, pickup, transit, custody acceptance, verified POD, or other approved execution event) unless an explicit exception/recovery workflow authorizes it. Replacement must lock shipment and generation, recheck eligibility, preserve old IDs/history, release only eligible unstarted capacity/assignments exactly once, supersede the prior generation, activate the new generation, and write an immutable audit event in one transaction.

## Critical compatibility changes required before implementation
- Remove/retire or rewrite the legacy transit and arrival routines that select the first shipment leg by shipment-wide sequence and perform idempotent returns before exact-leg validation.
- Rewrite dispatch/custody guards to scope predecessor and plan item matching to the same generation.
- Rewrite delivery finalization so historical/superseded legs do not block or falsely satisfy active-generation completion.
- Reconcile all shipment-wide status writes in dispatch, driver trip events, arrival and POD authorization with one aggregate rule.
- Configure or retire `krim_transition_shipment`; the Staging transition catalogue currently has zero rows.
- Update all database functions, triggers, Edge Functions, UI, public tracking, notifications, reporting, warehouse/returns and operations consumers before enabling replacement.

## Acceptance matrix (runtime tests required)
1. Single-leg legacy bootstrap maps to exactly one generation and remains backward compatible.
2. Multi-leg generation creates a one-to-one mapping from each plan item to one durable leg.
3. Dispatch of leg 2 cannot dispatch or mutate leg 1.
4. Transit event for leg 2 changes only leg 2; aggregate follows documented threshold.
5. Custody for leg 2 requires accepted custody from the immediate predecessor in the same generation.
6. POD for leg 2 completes only leg 2; duplicate retries are idempotent after all authorization/linkage checks.
7. Final POD completes shipment only when every required item in active generation has exactly one completed leg.
8. Historical/superseded generation legs neither block nor satisfy current generation completion.
9. Wrong shipment, partner, assignment, leg, plan, item, generation, tenant, or stale driver evidence is rejected.
10. Replacement before execution preserves old leg IDs and history and releases eligible capacity exactly once.
11. Replacement after execution begins is rejected unless authorized recovery path is used.
12. Concurrent replacement/dispatch/POD requests serialize and cannot create split-brain active generations.
13. Direct table writes and anon access remain denied; authenticated reads remain organization-scoped.
14. Public tracking and customer/partner/driver/warehouse/ops UIs show the correct generation history without exposing private evidence.
15. Notifications and audit events are emitted once, with retry and delivery state.

## Implementation decision
Do not create the route-generation migration until the complete database, Edge Function, frontend, trigger, scheduled-job and reporting consumer inventory is closed and a backfill/reconciliation plan is reviewed. Current absence of operational fixtures is a hard runtime verification blocker.

## Status
Design contract documented only. No implementation applied. Phase 00 remains OPEN — NOT APPROVED. Production untouched.
