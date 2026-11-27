# KRIM Route-Generation Compatibility Review — 2026-11-27

## Environment and scope
- Supabase project: `qrpcivhdxobiaofppbkl` (Staging).
- Read-only function/trigger catalog inspection.
- No DDL, DML, or deployment performed in this checkpoint.
- Production untouched.

## Confirmed behavior in core planning functions

### Plan creation
`public.krim_create_shipment_leg_plan(bigint,jsonb,text,jsonb)`
- Locks the shipment row.
- Requires owning customer `shipment.update`.
- Only allows shipment status draft/quoted/confirmed.
- Assigns next plan_version using max(plan_version)+1.
- Plan-item sequence starts at 1 for every plan.
- Uses shipment route endpoints and route connectivity checks.
- No route-generation identity is assigned.

### Plan evaluation
`public.krim_evaluate_shipment_leg_plan(bigint)`
- Only draft/ready plan and pre-execution shipment are evaluable.
- Validates plan item sequence contiguous from 1.
- Checks route connectivity, endpoints, locations, modes, time windows and capacity requirements.
- Rejects another active plan.
- Rejects active shipment-wide opportunities/customer quotes for multi-leg plans.
- If operational legs exist, it permits only one exact canonical unassigned planned leg at sequence 1, with no plan-item link. Any other existing-leg state is a conflict.
- Therefore this is a bootstrap evaluator, not a route replacement evaluator.

### Plan activation
`public.krim_activate_shipment_leg_plan(bigint,text)`
- Locks shipment and plan and uses idempotency records.
- Re-evaluates plan before activation.
- Reuses the one existing canonical first leg by attaching its `leg_plan_item_id`.
- Inserts subsequent legs with plan-local sequence values into `krim_shipment_legs`.
- Marks plan active and records activation mapping/events transactionally.
- Because operational `(shipment_id,leg_sequence)` is unique, a later plan that starts sequence at 1 cannot create a second operational generation while previous leg rows remain. Current evaluator blocks the prior multi-leg rows before activation is reached.

## Confirmed downstream coupling

### Sourcing guards
`private.krim_guard_leg_sourcing_state()` and the opportunity/quote validators:
- Require sourcing rows to point to the exact shipment leg.
- For plan-linked sourcing, require the leg's plan item to belong to the currently active plan.
- Compare plan-item `leg_sequence` directly with operational leg `leg_sequence`.
- Legacy single-leg sourcing has a special canonical route exception.
- These guards do not distinguish active vs historical route generations.

### Dispatch authorization guard
`private.krim_guard_leg_dispatch_authorization()`:
- Loads the one active plan for shipment.
- Requires exact leg, assignment and plan-item mapping.
- Compares plan-item sequence, endpoints, mode, partner and assignment against the operational leg.
- Requires active plan total leg count to equal the count of non-cancelled operational legs.
- The no-active-plan path expects exactly one canonical initial leg.
- This guard is not generation-aware.

### Custody sequencing trigger
`private.krim_require_accepted_custody_before_next_leg_dispatch()`:
- For a multi-leg active plan, next leg transit requires accepted custody from a prior leg whose shipment-global sequence is exactly current sequence minus one.
- It does not scope the prior leg lookup by plan ID or route generation.
- This is a critical cross-generation risk if old and new route rows are ever retained together.

## Trigger inventory highlights
- Shipment-leg status transition has accepted-custody guard.
- Shipment-leg inserts and updates write audit/status history.
- Partner opportunity and quote inserts/updates invoke sourcing guards and plan-link validators.
- Partner assignment insert/update invokes sourcing state, identity, quote integrity, transition, audit, notification, and capacity-release triggers.
- Driver assignment acceptance/status triggers enforce and record execution.
- Capacity reservations have commitment matching, overbooking guard, and commitment counter triggers.
- Route plan and plan-item tables were not in the inspected list of tables with direct operational triggers; activation is function-driven.
- Full trigger inventory for every dependent table and every background worker remains to be completed.

## Architectural conclusion
Adding a `route_generation_id` column alone is unsafe. Current logic embeds shipment-global sequence assumptions in dispatch and custody, and active-plan membership assumptions in sourcing. The activation algorithm and evaluator explicitly support only initial bootstrap, not replacement.

A safe design must:
1. Preserve immutable operational leg IDs and all foreign-key history.
2. Give each plan a stable generation identity; plan ID may serve as generation identity if lifecycle rules make it immutable.
3. Link each operational leg to its generation and enforce generation-local sequence uniqueness, while retaining the old shipment-global sequence as a legacy display/order field only during migration.
4. Update sourcing, assignment, dispatch, custody, driver, warehouse, tracking, exception, SLA and notification readers/writers to resolve the correct generation.
5. Define a single active generation and a terminal/irreversible execution boundary.
6. Replace routes atomically only before any quote/assignment/capacity/dispatch/custody/warehouse/driver execution evidence that would make preservation or release unsafe.
7. Make all status transitions, history events and capacity release behavior explicit and idempotent.
8. Test concurrent plan creation/activation/replacement and ensure no mixed-generation joins.

## Open work
- Inspect remaining database routines in the consumer inventory, including partner award, dispatch, driver, warehouse, tracking, returns and notifications.
- Inspect all relevant frontend/Edge Function consumers; GitHub code search availability/index coverage has not yet established branch-complete search.
- Complete dependent-table trigger and view inventory.
- Design and review the additive generation schema and all routine changes before applying any migration.
- Build realistic isolated fixtures and execute runtime JWT-backed tests.

## Gate
- Core create/evaluate/activate review: PASS (read-only review).
- Sourcing/dispatch/custody guard review: PASS (read-only review).
- Full downstream routine and UI review: OPEN.
- Generation-aware implementation: NOT STARTED.
- Runtime E2E: PENDING.
- Phase 00: OPEN / NOT APPROVED.
