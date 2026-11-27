# KRIM Route-Generation Lifecycle Writer and Trigger Risk Review — 2026-11-27

Environment: Staging Supabase project qrpcivhdxobiaofppbkl. Read-only inspection. Production untouched.

## Scope
Inspected current Staging definitions of route/dispatch/custody guards, initial-leg creation, driver trip event, legacy transit/arrival routines, POD submission/authorization, and relevant triggers. This checkpoint identifies compatibility risks; it does not change database code.

## Critical findings

### 1. Legacy shipment transit routine is not generation-safe
public.krim_internal_start_shipment_transit(bigint):
- Locks partner assignment and shipment, but selects the first leg by shipment_id ordered by shipment-wide leg_sequence.
- It does not select the leg through the exact assignment's shipment_leg_id.
- It changes shipment status to in_transit and changes that first leg to in_transit.
- For a multi-leg shipment, this can update the wrong leg when invoked for a later-leg assignment.
- Direct EXECUTE is denied to anon/authenticated in the inspected privilege snapshot, but server-side call chains still need full inventory. Treat this routine as unsafe for multi-leg execution until changed or formally retired.

### 2. Legacy shipment arrival routine is not generation-safe
public.krim_internal_arrive_shipment(bigint):
- Selects the first shipment leg by shipment_id and shipment-wide leg_sequence, rather than the assignment's exact shipment_leg_id.
- Updates that selected leg to arrived and emits tracking, partner-execution and audit events against it.
- A later-leg assignment could therefore record arrival against the first leg.
- Direct EXECUTE is denied to anon/authenticated in the inspected privilege snapshot. Server-side callers remain unverified.

### 3. Driver trip event is exact-leg linked but shipment status is global
public.krim_driver_record_trip_event(uuid,text,text):
- Resolves driver's assignment, linked partner assignment, exact shipment leg and shipment; verifies exact-leg dispatch authorization.
- Writes the in_transit event against the exact leg.
- It also changes shipment status from dispatched to in_transit on the first driver's in_transit event, regardless of which route leg is moving.
- This is acceptable only if shipment-level in_transit is explicitly defined as “at least one leg has started” and remains a shipment aggregate. That aggregate definition and multi-leg event ordering must be explicit in generation design and tests.
- It does not call the legacy start/arrival routines in the inspected function body.

### 4. Dispatch authorization guard counts all non-cancelled legs
private.krim_guard_leg_dispatch_authorization():
- For active multi-leg plan, validates exact plan-item/leg/partner/assignment linkage.
- Compares plan.total_legs with the count of all non-cancelled shipment legs, not legs scoped to a route generation.
- Once old generations are preserved as immutable history, this count will include historical legs and can reject valid dispatches in the new active generation.
- Must be generation-scoped before replacement/supersession is enabled.

### 5. Sourcing guard is active-plan scoped but not generation-keyed
private.krim_guard_leg_sourcing_state():
- Validates opportunities, quotes and offered assignments against exact shipment leg.
- For plan-linked legs, validates membership in active plan and compares plan-item sequence to operational leg sequence.
- It has no route-generation identity today. New generation semantics must update sourcing and assignment identity in the same release.

### 6. Custody predecessor guard is shipment-wide sequence based
private.krim_require_accepted_custody_before_next_leg_dispatch():
- Finds predecessor by same shipment and leg_sequence = NEW.leg_sequence - 1.
- Requires accepted custody transfer between predecessor and current leg's partners.
- It does not constrain predecessor to the same route generation. With preserved historical generations, sequence collisions or prior-generation custody could be considered unless explicitly generation-scoped.

### 7. Initial-leg trigger preserves any existing shipment leg
public.krim_ensure_initial_shipment_leg():
- Creates a canonical unplanned sequence-1 leg only when no leg exists for shipment.
- This is legacy bootstrap behavior; it does not distinguish active vs superseded generations.
- New route activation must not interpret an old generation's leg as a valid bootstrap leg.

## Trigger map highlights
- krim_shipments: initial-leg creation, shipment readiness, shipment-wide multi-leg dispatch block, dispatch-capacity confirmation, warehouse handover, terminal guard, capacity release, status/audit/history/snapshot and in-app events.
- krim_shipment_legs: custody-before-next-leg, leg creation/change/status history, route segment/location/transport validation.
- krim_shipment_partner_assignments: exact-leg sourcing guard, assignment identity/status/quote integrity, audit, in-app and response evidence events, capacity release.
- krim_shipment_leg_dispatch_authorizations: exact-leg authorization identity and warehouse-handover guards.
- Current trigger inventory contains no route-generation-specific trigger because schema has no generation identifier.

## Staging data snapshot
At inspection time: shipments 0; active route plans 0; superseded route plans 0; shipment legs 0; legs with plan item 0; partner assignments 0; driver assignments 0; POD records 0; tracking events 0. Zero rows means no operational fixture exists for lifecycle mutation tests; it does not prove runtime correctness.

## Required implementation order
1. Complete every application/Edge Function/trigger/RPC caller inventory for legacy transit and arrival routines.
2. Decide shipment-level aggregate semantics versus leg-level lifecycle semantics.
3. Implement guarded exact-assignment-leg transit/arrival flow; legacy shipment-wide routines must fail closed for multi-leg assignments or be retired after callers migrate.
4. Introduce immutable route-generation identity while preserving old operational leg IDs and downstream foreign keys.
5. Update dispatch count, custody predecessor, sourcing, POD, delivery finalization, warehouse, returns, operations and finance guards to scope to one active generation.
6. Add atomic plan supersession/replacement only before irreversible execution evidence, with locking, idempotency, capacity release and audit.
7. Build isolated multi-tenant fixtures and execute positive/negative JWT-backed E2E tests before opening route-generation feature.

## Status
- Legacy transit/arrival routine risk: CONFIRMED.
- Exact-leg driver event path: CONFIRMED (static function-body review only).
- Dispatch and custody generation-scoping gaps: CONFIRMED.
- Route-generation schema: NOT IMPLEMENTED.
- Runtime E2E: NOT RUN; no shipment/leg/assignment/POD fixtures exist.
- Phase 00: OPEN — NOT APPROVED.
