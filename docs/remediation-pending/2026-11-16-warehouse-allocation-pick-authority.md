# Warehouse shipment-allocation pick authority and idempotency hardening

Date: 2026-11-16  
Status: live path inspected; remediation specification only  
Scope: shared inventory movement RPC and shipment-allocation pick RPC

## Confirmed live behavior

The shipment allocation picker locks an allocation row, requires it to be `reserved`, locks its inventory row, and calls the shared movement RPC with:
- movement type: `pick`
- negative quantity: allocation quantity
- reference type: `shipment_allocation`
- reference ID: allocation UUID

It then changes the allocation to `picked` and writes an audit event in the same transaction. This is a useful atomic workflow structure.

However, the shared `krim_warehouse_record_movement` function is also an independently callable SECURITY DEFINER RPC. Its live body accepts `reference_type` and `reference_id` as caller-supplied strings. The function does not independently prove that a supplied shipment-allocation reference identifies a reserved allocation matching the caller's organization, facility, inventory row, shipment, leg, unit and exact quantity.

Therefore, the reference metadata is not itself an authorization boundary. If authenticated execute permission is present, an otherwise authorized warehouse operator may attempt to invoke the shared movement function directly with a forged allocation reference. The exact impact depends on function ACLs and table constraints and must be verified in the grant audit; do not assume the intended picker wrapper is the only caller.

## Additional live idempotency weakness

The shared movement replay comparison checks facility, movement type, quantity delta, SKU, lot, reference type/ID, unit and notes. It does not compare every material field accepted by the request, including item description, storage location and quality status. A reused key with changed values in omitted fields can be treated as an identical replay even though the canonical request changed.

The allocation picker replay path checks for a movement matching organization, idempotency key and exact allocation reference. It does not itself compare the full original pick payload or the notes against the current request. The shared movement replay logic is therefore the decisive replay guard and must compare a canonical payload.

## Required remediation

1. Remove caller authority to create a shipment-allocation movement merely by supplying reference strings.
2. Prefer a private, non-executable-by-client movement primitive. Expose only narrowly scoped public RPCs for ordinary pick, exact shipment allocation pick, transfer and approved receipt workflows.
3. The exact allocation pick authority must independently lock and validate the allocation and inventory and bind organization, facility, inventory ID, shipment ID, nullable/exact leg ID, unit and quantity. It must require status `reserved`, active shipment/leg eligibility and current operator authorization.
4. The exact allocation pick authority must atomically decrement inventory, write one movement, transition the allocation to `picked` and write the audit record. All effects must roll back together.
5. Generic movement/picking must reject `reference_type='shipment_allocation'` and any reserved allocation reference. Generic task picks must be limited to unreserved released quantity.
6. Transfer dispatch must subtract all outstanding reservations after locking the source inventory row before allowing removal.
7. Canonical idempotency must cover every material input: organization, facility, SKU/inventory identity, movement type, quantity, description, lot, unit, storage location, quality status, reference binding and notes. Same canonical payload replays; any difference rejects.
8. Ensure a picked allocation can only replay with its original movement key and canonical payload; no alternate key may be used to represent the same pick.
9. Audit all direct table grants, SECURITY DEFINER functions, triggers, service-role writers and legacy paths. Revoke unnecessary execute privileges only through a reconciled migration and reviewed ACL change.
10. Verify a consistent lock order across allocation and inventory operations. Existing picker locks allocation before inventory; any new path must not invert this order or introduce deadlocks. Use staging concurrency tests.
11. Add constraints/indexes only after checking existing data and migration history. Do not infer production ACLs from a failed or incomplete metadata query.

## Staging tests

- Direct shared movement call with a forged allocation reference rejects.
- A legitimate exact allocation pick succeeds once and records exactly one decrement, movement and allocation transition.
- Reusing the same key and same payload replays.
- Reusing the same key with changed notes, description, storage location, lot, unit, quality or quantity rejects.
- A second key cannot pick an already-picked allocation.
- Generic pick cannot consume outstanding reservations.
- Transfer cannot consume outstanding reservations.
- Concurrent reservation, pick and transfer attempts preserve `on_hand >= outstanding_reserved`.
- Cross-tenant, wrong facility, wrong inventory, wrong shipment and wrong leg bindings reject.
- All failure points roll back inventory, movement, allocation status and audit event.
- Verify RLS, function owner, search_path and execute ACLs for every exposed function.

## Release decision

**NO-GO for production shipment-allocation picking and transfer until the authority boundary, canonical idempotency and reserved-stock invariant are enforced and tested in isolated staging.**

This is not a migration and has not been applied. Production DDL and ACL changes remain blocked by migration-history reconciliation.
