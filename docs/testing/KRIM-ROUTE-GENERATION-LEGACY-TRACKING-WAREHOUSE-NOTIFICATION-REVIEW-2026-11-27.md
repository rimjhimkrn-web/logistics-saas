# KRIM Route-Generation Legacy Tracking, Warehouse and Notification Dependency Review — 2026-11-27

## Scope
Read-only inspection of Staging Supabase project `qrpcivhdxobiaofppbkl`. Reviewed database routines and triggers related to legacy routes, tracking sessions/events, warehouse leg/task lists and shipment notifications. No writes, migrations, or production access.

## Confirmed findings

### 1. Legacy shipment routes remain a separate model
- `krim_shipment_routes` and `krim_route_segments` have active validation and audit triggers.
- Route-segment validation confirms the route exists and validates route/segment locations and transport mode.
- A shipment-leg route-segment validation function checks that a referenced legacy segment belongs to the same shipment.
- This legacy model coexists with versioned `krim_shipment_leg_plans` / plan items and operational `krim_shipment_legs`.
Decision: do not assume legacy route rows can be mechanically converted or joined by shipment ID. A deterministic mapping and conflict report are required before backfill.

### 2. Driver tracking session expiry is assignment-scoped but not leg/generation-scoped
`private.krim_internal_expire_stale_driver_tracking_sessions()` expires an active session when no recent GPS event exists for matching `shipment_id`, `partner_assignment_id`, and tracking-session metadata. The function does not check `shipment_leg_id` or generation identity.
Required: bind the session to the exact assigned operational leg and generation, and expire only against events from that same leg/session. Preserve existing timeout semantics and keep GPS disabled pending legal/consent approval.

### 3. Warehouse assigned-leg list can include historical legs
`public.krim_warehouse_list_assigned_shipment_legs(organization_id,facility_id)` checks authenticated warehouse-operator access, then lists legs assigned to the organization with statuses planned/assigned/in_transit/arrived. It returns shipment ID, leg ID, shipment number, shipment-wide leg sequence and status, but does not join an active route plan or generation.
Required: include generation ID and active/superseded context; ensure operational work queues select only eligible active-generation legs while preserving history in a separate view.

### 4. Warehouse task list joins exact leg but lacks generation context
`public.krim_warehouse_list_tasks` checks warehouse operator access per organization/facility and joins task shipment_leg_id to the exact leg and shipment. It returns leg sequence but no route generation or plan item. Add generation context and reject new execution tasks against stale/superseded legs unless an explicit historical/recovery task type is authorized.

### 5. Notification history is immutable except read state
`krim_sync_in_app_notification_history` stamps delivered/read metadata on insert and prevents authenticated users from changing notification identity, shipment linkage, content, source event, delivery state or timestamps; users may change read state.
This is a useful history invariant. However existing shipment-status notification triggers are shipment-level and deduplicate by user, shipment and title. They do not identify exact leg or route generation. On route replacement or multi-leg progress, shipment-level notifications must be emitted from a single aggregate lifecycle rule; leg-specific alerts should carry exact leg/generation and source-event identity.

### 6. Tracking event audit exists
`krim_tracking_events` has an insert audit trigger. Tracking timeline UI currently has shipment-level reads. Audit event metadata and downstream consumers must retain exact-leg/generation linkage rather than inferring from shipment ID.

## Required changes before migration release
1. Establish one canonical source of route truth and a reconciliation map for legacy routes/segments.
2. Add exact leg and generation linkage to driver tracking sessions and their stale-session expiry routine.
3. Make warehouse leg/task RPCs generation-aware and distinguish active work queues from historical task history.
4. Preserve notification immutability while introducing generation-aware source-event idempotency and a single aggregate shipment-notification rule.
5. Update tracking audit and timeline read paths to separate shipment aggregate from exact-leg events.
6. Backfill only deterministic mappings; quarantine ambiguous legacy route/segment records for manual review.

## Status
Dependency findings documented. No schema or code changes applied. Runtime tests remain blocked by the absence of operational shipment/leg/assignment fixtures. Phase 00 remains OPEN — NOT APPROVED. Production untouched.
