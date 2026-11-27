# KRIM Route-Generation Schema Decision Record — 2026-11-27

Status: DESIGN DECISION FOR REVIEW; NOT IMPLEMENTED.
Environment inspected: Staging Supabase project qrpcivhdxobiaofppbkl.
Production was not accessed or changed.

## Verified current schema
- krim_shipment_leg_plans has shipment_id, plan_version, status, activated_at and superseded_at.
- krim_shipment_leg_plan_items has plan_id and per-plan leg_sequence, unique(plan_id, leg_sequence).
- krim_shipment_legs has shipment_id, shipment-wide leg_sequence, and nullable leg_plan_item_id.
- krim_shipment_legs has unique(shipment_id, leg_sequence), plus unique(id, shipment_id).
- krim_shipment_leg_activations has one unique activation per leg_plan_id.
- The leg_plan_item foreign key uses ON DELETE SET NULL.
- The shipment-leg primary key is referenced by numerous execution records; preserving leg IDs is mandatory.

## Recommended target model
Adopt an explicit generation identity that is independent of the plan's local sequence and the operational leg primary key.

Preferred additive foundation:
1. Add a generation identifier to each activated route plan (or a dedicated immutable route-generation parent row if activation lifecycle needs independent status/history).
2. Add route_generation_id to operational shipment legs.
3. Keep leg_sequence as the local ordinal within that generation.
4. Replace the shipment-wide unique sequence constraint with a unique constraint on (route_generation_id, leg_sequence), while retaining a shipment/generation consistency constraint and all existing primary keys.
5. Add explicit generation-to-plan and generation-to-activation relationships, with immutable audit history.
6. Backfill existing operational legs only where a single unambiguous active/legacy plan-item mapping exists. Ambiguous or orphaned rows must be quarantined for manual reconciliation; never guess.
7. Preserve leg_plan_item_id and all existing downstream foreign keys.

## Critical migration caveats
- The current activation routine inserts plan item sequence directly into shipment-wide leg_sequence and reuses the first unlinked leg. It must be replaced atomically before allowing a second generation.
- A constraint swap is not safe until all writers and readers are generation-aware. Use staged additive columns, backfill, validation, compatibility routines, then a controlled constraint transition.
- Custody predecessor lookup must use same shipment_id + same route_generation_id + previous local sequence.
- Delivery finalization must count only legs in the active generation, while retaining history from superseded generations.
- Dispatch, driver assignment, capacity reservations, POD, warehouse, returns, exception, notification and operations consumers must continue to reference the exact immutable leg ID and additionally validate current-generation eligibility where appropriate.
- Do not automatically release/cancel partner assignments or capacity during route replacement unless each transition is independently proven safe and idempotent.
- A generation cannot be superseded once execution evidence exists (dispatch authorization, pickup, transit, accepted custody, POD, warehouse custody or other irreversible operation), except via a separately approved recovery workflow.

## Proposed safe rollout gates
A. Inventory every writer and reader; identify all SECURITY DEFINER and trigger dependencies.
B. Add nullable generation columns/parent structure and indexes only; no behavior change.
C. Backfill existing rows with deterministic mapping and produce zero-ambiguity reconciliation report.
D. Add generation-aware dual-read validation and shadow checks.
E. Replace activation with a locked, tenant-authorized, idempotent generation-aware routine.
F. Update all execution consumers to use exact generation membership while preserving exact leg IDs.
G. Add pre-execution-only replacement and cancellation routines with atomic audit, concurrency protection and no silent reassignment.
H. Run authenticated two-customer/two-partner E2E tests, including concurrency, tenant isolation, capacity, dispatch, custody, POD, warehouse, notifications and rollback.
I. Only after all gates pass, consider production rollout with explicit owner approval.

## Decision
Do not apply a schema migration in this checkpoint. The additive target model is selected as the working design, but implementation is blocked until the complete writer/reader inventory and legacy-row reconciliation strategy are signed off. This avoids a partially migrated system in which current consumers misinterpret historical legs.

## Status
- Current schema/constraints confirmed from Staging catalog.
- Working target model documented.
- Implementation not started.
- Runtime E2E not run.
- Phase 00 remains OPEN — NOT APPROVED.
