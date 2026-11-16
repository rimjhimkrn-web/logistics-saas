# KRIM Warehouse Picking vs Shipment Reservations — Live Function Integrity Review

**Date:** 16 November 2026  
**Scope:** Read-only review of current production function definitions and checked-in migration source for linked pick-task creation, task completion, inventory movement, and shipment allocation. No production functions, schema, grants, data, or task states were changed.

## Executive finding

**P1 — The legacy warehouse task-picking path can consume stock already reserved for shipment allocations.**

The newer shipment allocation workflow correctly records reserved quantities and calculates available stock as on-hand quantity minus active reservations. However, the older linked pick-task workflow is still callable by authenticated warehouse operators and can later decrement the same inventory balance without checking active shipment reservations.

This is a separate exposure from inter-facility transfer dispatch. Fixing transfer dispatch alone will not close the stock-protection invariant.

## Live production evidence

Read-only catalog inspection confirmed the following current public function definitions and privileges:

| Function | Authenticated EXECUTE | Relevant behavior |
|---|---:|---|
| `krim_warehouse_create_linked_pick_task(...)` | Yes | Creates shipment-linked picking task after an inventory quantity/quality/unit existence check; does not lock or reserve the inventory row. |
| `krim_warehouse_transition_task(uuid,text,uuid,text)` | Yes | On completion of a `picking_packing` task, calls the inventory movement function with a negative quantity. |
| `krim_warehouse_record_movement(...)` | No | Current live ACL denies direct authenticated invocation; task transition invokes it internally. |
| `krim_warehouse_reserve_shipment_inventory(...)` | Yes | Locks the inventory row and checks on-hand quantity minus existing `reserved` allocations before inserting a reservation. |
| `krim_warehouse_pick_shipment_allocation(...)` | Yes | Locks a specific allocation and inventory row, applies the pick movement, and transitions the allocation to `picked`. |

All inspected functions are SECURITY DEFINER with an empty search_path in the live definitions. This review does not constitute a complete security audit of their helper functions or all dependent triggers.

## Confirmed path

### 1. Linked pick-task creation does not reserve stock

The live `krim_warehouse_create_linked_pick_task` definition:
- validates warehouse operator access and exact shipment-leg association;
- checks that a matching released SKU/lot/unit balance exists and has at least the requested quantity;
- performs no `FOR UPDATE` lock on that inventory balance;
- does not calculate outstanding shipment allocations;
- inserts a picking task, not an allocation/reservation.

Therefore multiple open pick tasks may be created against the same apparent stock, and the check is not a durable stock reservation.

### 2. Task completion decrements stock without checking reservations

The live `krim_warehouse_transition_task` definition:
- locks the task row;
- validates task state transitions;
- when completing a `picking_packing` task, invokes `krim_warehouse_record_movement` with a negative quantity;
- does not check whether that quantity is reserved for other shipments;
- does not require or consume a matching row in `krim_warehouse_shipment_allocations`.

The live `krim_warehouse_record_movement` function locks the inventory row and checks that the resulting on-hand quantity is not negative and that quality/unit conditions match. It does not protect the remaining active reservation total. Authenticated users cannot call this movement function directly, but the authenticated task-transition function can invoke it internally.

### 3. New allocation path is stronger but does not close the legacy path

The newer `krim_warehouse_reserve_shipment_inventory` workflow:
- locks the inventory row;
- sums active `reserved` allocations for that inventory ID;
- rejects a reservation if on-hand quantity minus reservations is insufficient.

The newer allocation-pick function locks the allocation and inventory and changes the allocation from `reserved` to `picked` in the same transaction as the stock decrement.

However, the legacy task-completion path can decrement inventory while leaving these allocation rows in `reserved` state. This can make reserved quantity exceed on-hand stock and cause later shipment picks to fail.

## Example failure scenario

- Released stock on hand: 100 units.
- Shipment A has 70 units reserved.
- A legacy picking task for Shipment B is completed for 50 units.
- The legacy task path checks only that the resulting on-hand quantity is not negative, then reduces stock to 50.
- Shipment A still has 70 units reserved.

The resulting state is invalid: 70 reserved units against 50 on-hand units. The database can reach this state even though the reservation function itself correctly protects new reservations.

## Required remediation

1. **Choose one canonical pick model.** Prefer the explicit shipment allocation model for shipment-linked picks. Legacy `picking_packing` task completion must either consume a specific allocation ID or be disabled for shipment stock until it can enforce the same invariant.
2. For non-shipment warehouse picks, require a separately defined, auditable unallocated-stock pick workflow that locks the inventory row and rejects any quantity that would reduce on-hand below active reservations.
3. Enforce the invariant in the lowest-level stock-decrease function as defence in depth, not only in UI or task creation checks.
4. Ensure every stock-decrease path (transfer, task pick, allocation pick, adjustment, return disposition, write-off and administrative correction) shares the same inventory-row lock and availability equation.
5. Ensure allocation pick atomically decrements stock and changes only its own allocation from `reserved` to `picked`; preserve exact unit, lot, facility and organization checks.
6. Add staging concurrency tests for legacy task completion vs reservation, allocation pick vs transfer, two task completions vs one balance, release vs pick, and idempotent replay.
7. Add an invariant monitor for balances where `SUM(reserved allocation quantity) > on-hand quantity`. Alert and investigate; never auto-repair stock or allocations.

## Release decision

Keep warehouse picking, transfer and dispatch promises gated until the legacy task path is reconciled with the allocation model and the shared available-to-promise invariant is enforced and concurrency-tested in staging.

Production currently has zero warehouse facilities, inventory balances, shipment allocations and warehouse tasks in the audited snapshot. This limits immediate live exposure but does not make the code path safe for activation.

## Change-control boundary

The production migration crosswalk remains unresolved. Do not patch deployed functions, apply migrations, change grants, or replay/baseline migrations until the sanitized production schema manifest and semantic migration reconciliation are complete. Implement a forward-only correction in an isolated staging project first.

**Status:** Confirmed from current production function definitions; remediation specified; no production change made.
