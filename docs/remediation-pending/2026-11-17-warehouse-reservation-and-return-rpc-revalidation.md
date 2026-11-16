# Warehouse reservation and return RPC — read-only production revalidation

**Date:** 2026-11-17  
**Status:** Read-only inspection of live SECURITY DEFINER function bodies and explicit ACLs.  
**Production writes:** None. No stock, reservations, tasks, transfers, returns or schema were changed.

## Confirmed live function surfaces

The following functions are SECURITY DEFINER and explicitly executable by `authenticated` (as well as service_role and postgres), unless noted:
- `krim_warehouse_reserve_shipment_inventory(bigint,uuid,uuid,bigint,bigint,numeric,uuid,text)`
- `krim_warehouse_pick_shipment_allocation(uuid,uuid,text)`
- `krim_warehouse_dispatch_transfer(bigint,uuid,uuid,uuid,numeric,text,uuid,text)`
- `krim_warehouse_create_linked_pick_task(bigint,uuid,bigint,bigint,text,text,text,text,numeric,text,text,text,uuid)`
- `krim_receive_authorized_shipment_return(uuid,uuid,jsonb,uuid,text)`

`krim_warehouse_record_movement(bigint,uuid,text,numeric,text,uuid,text,text,text,text,text,text,text,text)` is SECURITY DEFINER but its explicit ACL lists only postgres and service_role. This is a useful restriction; callers must still be inventoried because authenticated workflows invoke it through privileged functions.

## 1. Reservation logic: useful controls

The reservation RPC:
- locks the shipment and inventory row;
- requires warehouse partner permission and operator access to the approved facility;
- checks an exact leg when supplied and requires an accepted/active partner assignment for that exact leg;
- requires released stock and checks existing reserved allocations before reserving;
- uses an idempotency key and records an audit event.

However, shipment_leg_id is nullable in the function contract. When null, it falls back to shipment-wide partner assignment existence. For multi-leg shipments this can create an allocation that is not tied to a specific leg. The earlier dispatch/warehouse specs prohibit this ambiguity; require exact leg for all multi-leg shipments and reject null leg unless a single-leg shipment is positively proven.

## 2. Pick allocation: reservation invariant is not enforced at final decrement

The pick-allocation RPC locks the allocation and inventory rows and requires the allocation to be reserved. It checks released quality and `inventory.quantity >= allocation.quantity`, then calls the generic movement function to decrement stock.

The generic movement function checks only that the resulting total inventory quantity is non-negative. It does not compute outstanding reservations or ensure that the pick is consuming exactly the allocation's reserved quantity while preserving other allocations. A generic pick path can therefore consume stock reserved for other shipments if it is reachable with a suitable reference.

The canonical invariant must be:
`on_hand >= outstanding_reserved` after every stock-removal operation, except that the exact allocation being picked may be atomically released/consumed as part of that same transaction. Lock the inventory row and all relevant allocation rows in one deterministic order; validate the allocation's inventory/facility/org/leg tuple before decrement.

## 3. Transfer dispatch: confirmed reservation bypass

The transfer RPC locks source inventory and checks:
- source and destination facility operator access;
- both facilities remain active and approved;
- source inventory belongs to the selected organization/facility;
- released quality, valid unit and sufficient total quantity;
- idempotent payload replay.

It then directly subtracts `p_quantity` from `krim_warehouse_inventory.quantity`. It does **not** sum outstanding reserved shipment allocations or protect stock committed to other shipments. This is a direct path around the reservation invariant.

Transfer dispatch must either reject any quantity above unreserved available stock (`on_hand - outstanding_reserved`) or atomically transfer/rebind the exact reservations with full destination and shipment-leg integrity. Until then, the UI pause is necessary but not sufficient because the authenticated SECURITY DEFINER RPC remains callable.

## 4. Linked pick task creation: not a physical reservation

The linked pick-task RPC checks exact shipment/leg/partner organization, warehouse operator access, idempotency and that a matching released inventory row has total quantity at least the requested quantity. It does not create or consume a shipment allocation, nor subtract outstanding reservations from available quantity.

It creates a task marked `released`. A task is not proof that stock has been reserved for that shipment. Task creation must be linked to an existing exact allocation or reserve the stock atomically; available quantity must exclude all other outstanding reservations.

## 5. Return receipt: SQL NULL manifest validation remains fail-open

The live return-receipt RPC validates:
`jsonb_typeof(p_received_items) <> 'array' OR jsonb_array_length(p_received_items) < 1 ...`

When `p_received_items` is SQL NULL, `jsonb_typeof(NULL)` and `jsonb_array_length(NULL)` are SQL NULL. In PL/pgSQL, an IF condition evaluating to NULL is not TRUE, so the guard can be bypassed. If the authorized manifest is an array, the loop over received items executes zero times, yet the function can create a receipt and move the return into `inspection_hold` with no physical lines reconciled.

The existing proposal `docs/remediation-pending/2026-11-16-shipment-return-receipt-json-validation.md` already records this P0 issue. The fix must explicitly require `p_received_items IS NOT NULL`, JSON array type, bounded non-zero length, non-null array manifest and full prevalidation of every item before any receipt or inventory write.

## 6. Required remediation sequence

1. Keep transfer dispatch and generic pick execution disabled until the reservation invariant is enforced in every writer.
2. Require exact shipment leg for multi-leg allocations; no shipment-wide fallback.
3. Add a canonical locked stock-removal helper that checks unreserved availability and, for allocation picks, consumes exactly one validated allocation.
4. Route transfers through the same invariant or require atomic reservation transfer.
5. Make pick tasks require a matching exact allocation; never treat task creation as capacity reservation.
6. Add explicit SQL NULL and JSON null/type validation for return manifests and prevalidate all lines before writes.
7. Inventory all direct RPC callers, edge functions, service-role paths, grants, triggers, and table DML privileges.
8. Before adding constraints or changing functions, reconcile production migration history and inspect data for over-reserved stock, duplicate allocations, orphan receipts, zero-line receipts, and shipment/leg mismatches.

## Required staging tests

- Two allocations compete for the same stock; only the quantity remaining after reservations can be picked/transferred.
- Exact allocation pick consumes only its own reservation and leaves other reservations covered.
- Generic pick and transfer attempts that would violate `on_hand >= outstanding_reserved` fail.
- Multi-leg shipment with null leg is rejected; wrong leg/partner/org rejected.
- Linked pick task without exact reserved allocation rejected.
- Return received-items SQL NULL, JSON null, object, empty array, oversized array, duplicate index, missing index, wrong manifest values all reject with no writes.
- Idempotent retry and conflicting retry; concurrent picks/transfers/reservations; facility deactivation race; tenant isolation; audit completeness and rollback.
- Test authenticated direct calls and service-role paths separately.

## Release decision

**NO-GO for live warehouse picking, transfer dispatch and physical return receipt** until every stock writer preserves the reservation invariant, return JSON validation is fail-closed, exact leg linkage is enforced and staging/concurrency tests pass. No production DDL, grants or operational data were changed.
