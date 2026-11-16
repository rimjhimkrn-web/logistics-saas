# KRIM Warehouse Available-to-Promise Transfer Invariant — Source-Level Remediation Specification

**Date:** 16 November 2026  
**Scope:** Static source review of `20261116021000_warehouse_interfacility_transfer_lifecycle.sql` and `20261116026000_warehouse_shipment_inventory_allocation.sql`. No production SQL, schema, data or workflow was changed.

## Finding

**P1 — Inter-facility transfer dispatch can consume stock already reserved for a shipment.**

The reservation function calculates outstanding reservations for the inventory row and rejects a reservation when:

`inventory.quantity - SUM(reserved allocation quantities) < requested quantity`

It locks the inventory row `FOR UPDATE` before calculating that amount.

The transfer-dispatch function also locks the same inventory row `FOR UPDATE`, but only checks `inventory.quantity >= transfer quantity`. It then subtracts the transfer quantity without subtracting active reserved allocations.

Consequently, the two functions serialize on the inventory row but enforce different availability equations. Serialization alone does not preserve the invariant: after a shipment reservation is committed, a later transfer can still remove the reserved quantity.

## Required invariant

For each inventory balance, facility, lot and unit:

`available_to_promise = on_hand_quantity - SUM(quantity WHERE allocation.status = 'reserved')`

Every operation that decreases on-hand stock must preserve:

`new_on_hand_quantity >= active_reserved_quantity`

The calculation must use the same inventory-row lock in reservation, transfer dispatch, and every other stock-decrease path. Reservation creation must also calculate and insert while holding that lock. Pick must atomically consume the allocation and stock; it must not double-count its own reservation as a competing reservation. Release frees only the released reservation.

## Required remediation design

1. In `krim_warehouse_dispatch_transfer`, after locking the source inventory row, calculate the sum of `reserved` allocations for that exact `inventory_id` and reject when `v_source.quantity - reserved_quantity < p_quantity`.
2. Keep the check and stock decrement in the same transaction and under the existing source inventory row lock.
3. Confirm all stock-decrease functions use the same inventory-row lock and invariant. Review generic movement, shipment allocation pick, adjustments, returns, expiry/write-off, transfer, and any administrative correction path.
4. Preserve unit, facility, organization, lot and quality-state checks. Do not aggregate reservations across unlike inventory balances or units.
5. On pick, ensure the exact allocation is locked and that only its own reservation is excluded from the competing-reservation sum (or use an equivalent mathematically correct transition) before decrementing on-hand quantity and changing status to `picked`.
6. Add an explicit concurrency test where reservation and transfer dispatch race for the same balance. The final committed state must never have reserved quantity greater than on-hand quantity.
7. Add tests for two concurrent reservations, reservation vs transfer, pick vs transfer, release vs transfer, duplicate idempotency keys, and a conflicting payload replay.
8. Add a database invariant monitor/report that flags any inventory balance where reserved quantity exceeds on-hand quantity. It should alert; it must not silently repair stock.

## Acceptance criteria

- Two concurrent reservations cannot oversubscribe one inventory balance.
- A transfer cannot move reserved stock even when total on-hand quantity is sufficient.
- A pick consumes exactly its reservation and decrements on-hand stock once.
- Releasing one reservation does not release another allocation.
- Transfer receipt remains on quality hold and cannot become pickable without independent quality review.
- All failure paths leave stock, allocation and transfer rows unchanged.
- Idempotent replays return the original result only when the complete request payload matches.
- Cross-organization, cross-facility, different-lot, different-unit and non-released-stock attempts are rejected.

## Deployment boundary

Migration history is not reconciled. This document is a remediation specification only. Do not edit or replay production migrations, run ad-hoc DDL, or modify deployed functions until the sanitized production schema manifest and migration crosswalk are complete. Implement and concurrency-test the correction in an isolated staging project first, then prepare a forward-only reviewed migration.

## Evidence

- `20261116021000_warehouse_interfacility_transfer_lifecycle.sql`: transfer dispatch locks the inventory row and checks total quantity, but does not account for active reserved allocations.
- `20261116026000_warehouse_shipment_inventory_allocation.sql`: reservation locks the inventory row and subtracts the sum of `reserved` allocations before accepting a reservation; pick and release transition allocation states through controlled RPCs.
- `docs/audits/KRIM-WAREHOUSE-INVENTORY-QUALITY-AND-DISPATCH-HANDOVER-READINESS-AUDIT-2026-11-16.md`: live production warehouse network is empty; the invariant remains a release blocker for warehouse dispatch.

**Status:** Confirmed source-level correctness gap; remediation specified; no production change made.
