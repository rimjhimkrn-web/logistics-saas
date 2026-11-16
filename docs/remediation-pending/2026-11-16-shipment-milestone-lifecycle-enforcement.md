# Shipment milestone lifecycle and exact-leg transition enforcement

**Date:** 2026-11-16  
**Status:** Read-only production inspection; remediation specification prepared, NOT applied.  
**Production writes:** None. No shipment, leg, trip event, tracking event, POD or assignment was changed.

## Production findings

### 1. Driver trip events enforce dispatch authorization only for multi-leg shipments

`public.krim_driver_record_trip_event(uuid,text,text)`:

- Authenticates the driver and locks their own driver assignment.
- Requires active driver membership.
- Requires non-null shipment, leg and partner-assignment links.
- Confirms partner assignment matches shipment, exact leg and organization, and is accepted/active.
- Locks the exact leg and shipment.
- For active multi-leg plans only, calls `private.krim_leg_dispatch_authorization_is_current(...)` before pickup/transit and restricts the events to ROAD.
- For single-leg shipments, the inspected function does not call that exact-leg authorization/currentness helper.
- Pickup requires accepted driver assignment and shipment dispatched/in-transit for single-leg; leg may be assigned or in-transit.
- Transit requires prior pickup; then directly updates the leg to `in_transit` and, for single-leg shipments, shipment to `in_transit`.
- Delivery is correctly excluded from driver trip events and reserved for verified POD authorization.

**Critical gap:** single-leg pickup/transit can bypass the exact-leg dispatch authorization and physical reservation gate. This remains exploitable even if the multi-leg guard is strong.

### 2. Driver event replay is not canonical-payload idempotency

The pickup and in-transit replay branches return the existing assignment when an event of that type exists. They do not compare the replay's notes or a caller-supplied idempotency key/canonical payload. The exception path can be recorded repeatedly and has no caller idempotency key in this signature.

Required behavior: retries must identify the same event and compare canonical payload; conflicting retries must fail rather than silently return an earlier assignment.

### 3. Generic shipment transition table blocks operational milestones

Current live rows include:

- `assigned -> dispatched`: disallowed.
- `dispatched -> in_transit`: disallowed.
- `in_transit -> delivered`: disallowed.
- Commercial transitions such as `confirmed -> assigned` and `quoted -> confirmed` are allowed with permission checks.

This is directionally appropriate: operational milestones should not be made generally available through a generic status RPC. However, the driver trip event function directly updates shipment/leg statuses, and separate dispatch/POD functions also update them. Those specialized writers must enforce the same authoritative readiness rules.

### 4. Generic transition function is not a complete operational authorization boundary

`public.krim_transition_shipment(bigint,text,text,jsonb)` checks the configured transition table, then checks `krim_has_permission(auth.uid(), customer_organization_id, required_permission)`, updates shipment status and writes history/audit events. The function's permission model is customer-organization based. It should not be treated as a substitute for partner/driver exact-leg authorization, physical reservation, custody, POD or operational evidence.

No evidence was obtained that every direct update, trigger, service-role helper and legacy status writer is routed through one canonical lifecycle gate.

### 5. Delivery authorization is stronger but must remain the sole completion path

`public.krim_internal_authorize_delivery(bigint,uuid)` validates the POD-to-partner-assignment shipment, leg and partner tuple, requires verified POD, active assignment, exact leg in transit and active route-plan item for multi-leg. It updates the leg/assignment, calculates completion across the route plan and emits tracking, partner execution and audit events.

Keep driver trip events from directly setting delivered/completed, and ensure every alternate POD/review/admin path reaches this same exact-leg authorization logic only after independent evidence verification.

## Required remediation

1. **Make exact-leg dispatch authorization mandatory for all ROAD pickup/transit events**
   - Remove the multi-leg-only conditional around current dispatch authorization.
   - Require a current authorization for the exact shipment, leg, partner assignment and partner organization for both single- and multi-leg.
   - The currentness predicate must prove the confirmed physical reservation and binding, active assignment, current compliance/capability, driver/vehicle prerequisites and (for later legs) accepted predecessor custody.
   - Reject stale/revoked authorization even on replay. Authorization alone is not proof of departure.

2. **Separate event semantics and state transitions**
   - Pickup may be recorded only after dispatch authorization and a valid pickup/handover condition.
   - In-transit may be recorded only after pickup and a valid exact-leg departure condition.
   - The exact leg may move to `in_transit` only from an allowed pre-transit state, with actual departure time recorded once.
   - The shipment-level state should be derived from the active leg plan; a single-leg update must not overwrite terminal, cancelled, exception or inconsistent state.
   - Driver event RPC must never set shipment or leg to delivered/completed. Only independent verified POD and the canonical delivery authorizer may do so.

3. **Canonical event idempotency**
   - Add a caller-generated idempotency key (or equivalent immutable event identity) to pickup, transit and exception recording.
   - Store canonical payload hash/fields including assignment, user, event type, exact leg, event time policy, notes, seal/evidence/resource identifiers.
   - Identical retry returns the original event; same key with changed payload fails.
   - Prevent multiple pickup/transit milestones for the same driver assignment unless a separately modelled correction/reversal workflow authorizes it.
   - Exception retries must not create duplicate events or duplicate escalation effects.

4. **One lifecycle authority**
   - Inventory every function, trigger, edge function, service-role path and table write that changes shipment or leg status.
   - Generic `krim_transition_shipment` must remain limited to configured commercial/admin transitions and must not be used to bypass operational milestones.
   - Specialized dispatch, pickup, transit, custody, POD and delivery functions must call shared predicates and write status history/audit records consistently.
   - Direct authenticated table updates must not permit users to bypass those RPCs; verify grants and RLS policies rather than assuming.

5. **Multi-leg route integrity**
   - Pickup/transit requires the exact active route-plan item and assignment tuple.
   - A later leg cannot start before accepted custody transfer from the immediately preceding leg.
   - Shipment remains active until every required plan item is materially completed; cancelled or skipped legs require explicit authorized route-plan revision, not status shortcuts.
   - Event ordering and timestamps must be monotonic and attributable to the exact leg.

6. **Concurrency and audit**
   - Use deterministic locks across shipment, leg, partner assignment and driver assignment.
   - Ensure event insertion, status update, tracking event and partner execution event are atomic.
   - Keep tracking/notification delivery separate from event creation; a tracking row or queued notification is not proof of customer delivery.
   - Record actor, exact leg, authorization ID, reservation/binding IDs and source evidence in audit metadata.

## Required staging tests

- Single-leg shipment with abstract capacity commitment but no physical reservation/binding: pickup and transit rejected.
- Single-leg shipment with no exact-leg dispatch authorization: rejected.
- Multi-leg and single-leg with stale/revoked authorization: rejected.
- Exact authorization but driver assignment belongs to another leg, shipment or partner: rejected.
- Driver assignment not accepted by the authenticated driver: rejected.
- Pickup before dispatch, transit before pickup, duplicate pickup, duplicate transit and out-of-order event: reject or return only a payload-identical idempotent result.
- Same idempotency key with changed notes, leg, assignment, event type, seal or evidence: conflict.
- Exception event replay and concurrent retry: one canonical event.
- Driver attempts to write delivered/completed event: rejected.
- Generic shipment transition attempts dispatched/in_transit/delivered: rejected regardless of permission.
- Direct table update and every legacy/service-role/edge path: denied or routed through canonical gate.
- Multi-leg second leg before accepted custody: rejected.
- Exact final leg after verified POD: only canonical delivery authorizer can complete shipment.
- Concurrent pickup/transit and status transitions: consistent event order and atomic rollback.
- Tenant isolation, authorization revocation between page load and write, audit and tracking integrity.

## Release gate

Do not enable live execution until production migration history is reconciled, every shipment/leg status writer and grant is inventoried, single-leg and multi-leg paths both require exact-leg authorization and physical reservation, and staging proves the full pickup → transit → independently verified POD → delivery journey.

**Operational evidence context:** Earlier audits found zero driver assignments, zero trip events, zero dispatch authorizations and zero verified POD records. This lifecycle has not been demonstrated end to end in production.
