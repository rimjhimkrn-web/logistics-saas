# KRIM Warehouse Stock Movement, Return Receipt and Reservation Release Audit — 2026-11-16

## Scope
Read-only inspection of live production function definitions and grants for warehouse stock movements, shipment allocations, warehouse task completion/cancellation, shipment return authorization/receipt, and shipment status transitions. No business RPCs were executed; no rows, schema, grants, functions, or operational state were changed.

## Verified controls
- Direct authenticated execution of `krim_warehouse_record_movement` is denied. The function only accepts receipt and pick movement types; direct adjustment, dispatch, transfer, and return movement types are explicitly disabled.
- Negative stock is rejected; picking requires released inventory and a matching unit.
- The canonical shipment-allocation reserve function locks the inventory row and subtracts active reserved allocations before creating a reservation.
- The canonical allocation pick function locks the allocation and inventory, then marks the allocation picked after recording the movement.
- The reservation-release RPC requires partner management permission, verified warehouse operator access, a reason and idempotency key; it only releases rows still in reserved state. Picked allocations cannot be released through this path.
- Return requests require customer shipment-update permission and an eligible delivered shipment or completed leg. Partner response is permission-checked and status-gated.
- Physical return receipt requires an authorised return, partner warehouse permission, an active independently approved facility, and item-by-item manifest reconciliation. Returned stock is received into a separate return lot on quality hold rather than being made immediately available.

## Confirmed production defect: nullable return-item array can bypass validation
Live function: `krim_receive_authorized_shipment_return(uuid,uuid,jsonb,uuid,text)`.

The initial guard uses:
```sql
jsonb_typeof(p_received_items) <> 'array'
OR jsonb_array_length(p_received_items) < 1
OR jsonb_array_length(p_received_items) > 100
```

When `p_received_items` is SQL NULL, each expression can evaluate to NULL rather than TRUE. In PL/pgSQL, an IF condition that evaluates to NULL does not enter the error branch. The later manifest-length comparison can also evaluate to NULL, allowing the function to insert a receipt header, process zero items, and move the return to `inspection_hold` without any receipt-item rows.

**Severity:** High — the function can record a physical receipt workflow state without any declared items being received. This is a data-integrity and audit-evidence defect; it is not evidence that the return is actually physically received.

**Required correction after migration reconciliation:** use an explicit null-safe guard such as `p_received_items IS NULL OR jsonb_typeof(p_received_items) IS DISTINCT FROM 'array' OR jsonb_array_length(p_received_items) NOT BETWEEN 1 AND 100`; also assert after the loop that the processed line count equals the manifest length and that every manifest index is represented exactly once. Add staging tests for SQL NULL, JSON null, empty array, object, duplicate indexes, missing indexes, and valid full manifest.

## Previously confirmed reservation-integrity blocker remains
The legacy shipment-linked picking task path still bypasses the allocation reservation workflow:
- `krim_warehouse_create_linked_pick_task` checks available quantity but does not lock inventory or reserve it.
- `krim_warehouse_transition_task` completes a `picking_packing` task by calling the low-level movement function directly, without requiring or consuming a matching allocation.
- The low-level movement function prevents negative on-hand quantity but does not subtract active reservations before a pick.
This permits a legacy pick to consume units already reserved for another shipment. See `KRIM-WAREHOUSE-PICK-TASK-RESERVATION-INTEGRITY-REVIEW-2026-11-16.md`.

## Reservation release / cancellation boundary
The explicit allocation release RPC is a safe reserved-only operation, but the inspected warehouse task transition does not itself release a linked reservation when a task is cancelled. The task schema/path inspected does not establish a canonical allocation link on the task, so automatic release cannot safely be inferred. Before activation, define one canonical cancellation orchestration that locks the shipment/task/allocation in a consistent order, releases only unpicked reservations, and requires a reverse-pick/return workflow for already picked stock. Test retries and concurrent pick/cancel races in staging.

## Disposition
- Do not enable warehouse picking, transfers, return receipts, stock adjustments, or reservation-dependent dispatch until the legacy pick path and null-safe return receipt validation are fixed and concurrency-tested.
- No production SQL change was made. The production migration history and repository migration files remain unreconciled; do not apply or replay a corrective migration yet.
- This report is based on live function definitions and grants at audit time. It is not a substitute for staged functional tests or proof of the full operational lifecycle.
