# KRIM Route-Plan Replacement — Design Gate (2026-11-27)

## Decision
Do not implement route-plan replacement by deleting shipment legs, reusing their IDs, rewriting their plan-item links, or resetting `leg_sequence`. Existing execution and commercial records reference shipment-leg IDs. Preserve those IDs and their history.

## Verified Staging facts
- `krim_shipment_leg_plans` already stores `plan_version`, lifecycle status (`draft`, `evaluating`, `ready`, `active`, `superseded`, `cancelled`), and `superseded_at`.
- `krim_shipment_leg_plan_items` has per-plan `leg_sequence` values.
- `krim_shipment_legs` has a unique constraint on `(shipment_id, leg_sequence)`, plus `leg_plan_item_id` referencing a plan item.
- Current activation/evaluation logic permits only an exact, unassigned, planned, unlinked single existing first leg as a legacy bootstrap case. Other existing leg sets block activation.
- Current sourcing guard verifies that each plan-linked operational leg matches an item in the currently active plan, including the same `leg_sequence`.
- Shipment legs are referenced by partner opportunities, partner quotes, partner assignments, driver assignments, capacity reservations/bindings, dispatch authorizations, custody transfers, warehouse operations, tracking, notifications, exception bridges and other records. Several references use RESTRICT semantics.
- Route-plan status values exist for superseded/cancelled, but no controlled supersession/cancellation routine was found.
- Staging currently contains zero route plans and zero shipment legs, so runtime migration safety cannot be demonstrated against real fixture data.

## Why a simple cancellation RPC is unsafe
Cancelling an old plan does not free the shipment-wide unique `(shipment_id, leg_sequence)` values. New plans restart their item sequence at one. Reusing old leg rows would rewrite historical identity and break audit semantics; deleting them is blocked by or risks violating downstream foreign-key history. A new route generation therefore needs an explicit operational identity model, not only a plan status transition.

## Required target model before implementation
1. Keep route-plan version and plan-item sequence as immutable planning identity.
2. Introduce a distinct immutable route-generation identity for activated operational legs (or an equivalent explicit mapping). Do not overload the current shipment-wide `leg_sequence` to mean both within-plan sequence and historical identity.
3. Preserve every old shipment-leg ID and all foreign-key references. Superseded/cancelled generations remain queryable and auditable.
4. Update every consumer of leg ordering, leg-to-plan matching, sourcing, partner assignment, capacity, driver dispatch, custody transfer, POD, tracking, warehouse, ETA/SLA, notifications, exceptions, and customer/partner/driver UI to use the correct generation and within-generation sequence.
5. Permit replacement only before any irreversible execution evidence exists: no dispatch authorization, pickup, in-transit movement, accepted custody transfer, POD, completed leg, active driver execution, or non-releasable warehouse operation.
6. In one transaction, lock the shipment and current active plan; validate owner `shipment.update` (or a separately reviewed AAL2 `admin.platform` intervention); validate no active commercial sourcing/quotes that would be orphaned; safely release only eligible pending capacity and assignment reservations through existing terminal workflows; mark old plan/generation cancelled or superseded; create/activate the new generation; write immutable plan and operational audit events; enforce one active plan per shipment.
7. Make the operation idempotent and concurrency-safe. A failed replacement must leave the previous active plan and all existing assignments/capacity untouched.
8. Provide a controlled admin exception/recovery path with reason, reviewer, affected-record snapshot, and notifications; never silently cancel an in-execution leg.

## Tests required before enabling replacement
- Legacy single-leg bootstrap remains compatible.
- Multi-leg activation creates a consistent generation and every leg maps to exactly one active plan item.
- Replacement before sourcing preserves old leg IDs and references while the new generation becomes the only active generation.
- Replacement is rejected after quote/assignment/driver/dispatch/custody/POD/warehouse execution starts.
- Capacity reservations are released exactly once and counters reconcile.
- Two concurrent replacement attempts cannot create two active plans or duplicate generation sequences.
- Customer A cannot view or mutate Customer B plans or legs.
- Anonymous and direct table writes remain denied.
- Event history, tracking, customer/partner/driver workspaces and notifications show both historical and current generations correctly.

## Current gate
- Authenticated route-plan RPC EXECUTE grants: applied and verified in Staging.
- RLS-scoped SELECT grants for route-plan history: applied and verified in Staging.
- Runtime JWT-backed customer E2E: pending.
- Route-generation schema and replacement workflow: not implemented.
- Production: untouched.
- Phase 00: OPEN / NOT APPROVED.
