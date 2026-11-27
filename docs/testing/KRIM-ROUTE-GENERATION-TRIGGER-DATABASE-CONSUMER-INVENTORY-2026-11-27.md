# KRIM Route-Generation Trigger and Database Consumer Inventory — 2026-11-27

## Scope
Read-only inspection of Staging Supabase project `qrpcivhdxobiaofppbkl`. Reviewed information_schema triggers on shipments, shipment legs, partner assignments, driver assignments and POD-related execution surfaces, plus database routines/views referencing route and leg identifiers. No database writes or production access.

## Trigger inventory — verified

### Shipments
The shipment table has active triggers for:
- Corridor compliance and market activation before insert/update.
- Shipment readiness enforcement.
- Shipment status event emission, audit, and status history.
- Shipment-wide dispatch blocking for multi-leg shipments.
- Initial shipment-leg creation on insert/update.
- Dispatch capacity confirmation.
- Shipment terminal-state guard and capacity release.
- Warehouse handover requirement before shipment dispatch.
- Shipment creation in-app event and audit.
- Delivery update audit and operational snapshot refresh.

Generation-aware review is required for shipment-wide dispatch blocking, initial-leg creation, readiness, status aggregation/history, terminal/capacity release, warehouse handover, and operational snapshot refresh. These are not all necessarily broken; each must be explicitly classified and tested against active-generation semantics before schema activation.

### Shipment legs
Active triggers include:
- Accepted-custody-before-next-leg-dispatch guard.
- Leg creation and change audit.
- Route-segment audit.
- Leg status history.
- Location, route-segment, shipment-link and transport-mode validation.

The custody predecessor guard is already known to use shipment-wide sequence and must become same-generation predecessor logic. Audit/history should preserve generation identity once introduced.

### Partner assignments
Active triggers include:
- Quote cancellation after partner rejection.
- Capacity commitment synchronization.
- Leg sourcing state guard.
- Partner assignment identity and status-transition guards.
- Assignment audit and in-app event emission.
- Delete blocking.
- Quote integrity.
- Partner quote response evidence.
- Capacity release on terminal assignment and pre-dispatch terminal synchronization.

These must preserve exact leg and generation linkage; replacement should release only eligible unstarted commitments and assignments, exactly once, without rewriting historic assignment records.

### Driver assignments
Active triggers include:
- Acceptance audit.
- In-app assignment event.
- Status event.
- Driver assignment acceptance guard.

These should retain exact-leg and generation references in emitted audit/notification metadata.

## Views and routine inventory limitation
A catalog text scan was run for route and leg identifiers. It is useful for discovery but is not a complete dependency proof: dynamic SQL, JSON-key references, external clients, scheduled jobs, and source not deployed in the database are outside this scan. No view-level compatibility claim is made from an empty/partial result set.

## Required migration impact checklist
Before adding a generation key:
1. Add generation identity and immutable plan-item-to-leg mapping with safe backfill.
2. Update all shipment and leg triggers listed above, preserving existing compliance, readiness, capacity, warehouse and audit invariants.
3. Update partner and driver assignment guards/events to pin exact generation.
4. Update custody predecessor lookup to same-generation ordered predecessor.
5. Update dispatch and POD completion checks to active generation only.
6. Update operational snapshot, tracking and customer/partner/driver/warehouse/ops reporting.
7. Verify no bypass through direct DML, SECURITY DEFINER routines, service role, triggers or jobs.
8. Run transactional concurrency, idempotency, tenant isolation, and rollback tests.

## Status
Inventory checkpoint documented. No schema migration or trigger change applied. Operational fixtures remain absent, so runtime verification is pending. Phase 00 remains OPEN — NOT APPROVED. Production untouched.
