# KRIM Warehouse Inventory, Reservation, Picking, Transfer and Return Integrity Review
**Date:** 16 November 2026  
**Method:** Read-only live PostgreSQL function-definition, trigger and catalog inspection. No warehouse RPC was invoked and no production inventory, shipment, task or return record was changed.

## Executive summary
Warehouse controls have matured substantially: stock reservations are separate from physical quantity, reservations are locked and checked against available released stock, picks consume stock through controlled movements, reserved allocations cannot be released after picking, legacy shipment-linked task picking is blocked, dispatch handover requires picked allocations and private proof, and QC requires independent review.

Two material workflow-integrity concerns remain:
1. **Transfer dispatch does not subtract or protect outstanding shipment reservations.** It locks the inventory row and checks total quantity, but does not compare the requested transfer quantity with outstanding reserved allocations. It can therefore reduce the physical balance below the quantity already committed to shipment allocations.
2. **Generic (non-shipment-linked) picking tasks can use the shared pick movement path without an explicit reserved-quantity check.** The dedicated allocation pick path is controlled, and shipment-linked legacy picking completion is blocked by a trigger, but the generic task workflow remains a possible path to consume stock already reserved for a shipment. Confirm in staging before remediation.

A previously known NULL-input issue in return receipt validation remains: SQL NULL `p_received_items` can evade the compound validation because SQL three-valued logic treats a NULL IF condition as not true. The downstream flow may fail or create an empty receipt depending on exact argument binding; this must be fixed with explicit `IS NULL` checks and tested in staging. Do not treat it as a confirmed persisted zero-line receipt until reproduced.

## 1. Reservation integrity
Function: `krim_warehouse_reserve_shipment_inventory(...)`

Positive controls observed:
- Requires authenticated user, `partner.manage` and verified warehouse-operator access.
- Locks shipment, exact shipment leg when supplied, and inventory row.
- Requires active shipment/leg and accepted/active partner assignment for the exact organization.
- Requires active, approved facility and independently released inventory.
- Uses advisory lock and organization-scoped idempotency key; conflicting payload replay is rejected.
- Computes outstanding reserved allocation quantity for the inventory row and checks `inventory.quantity - reserved >= requested quantity`.
- Inserts a reserved allocation and audit event without prematurely decrementing physical stock.

Assessment: the core reservation operation is appropriately distinct from physical picking. It uses a shipment-row lock to coordinate with the dispatch-handover guard, which also locks the shipment and existing allocations.

## 2. Controlled allocation picking
Function: `krim_warehouse_pick_shipment_allocation(...)`

Positive controls:
- Locks the allocation and inventory row.
- Requires partner management permission and operator access for the allocation's facility.
- Only reserved allocations can be picked.
- Requires released stock and sufficient physical quantity.
- Calls the shared movement routine, then marks the allocation picked and records an audit event in the same transaction.
- Conflicting replay with a different idempotency key is rejected.

Assessment: the intended reservation-to-pick path is controlled. The remaining concern is alternate movement paths that can consume the same inventory without checking the reserved allocation total.

## 3. Transfer dispatch — P1 integrity finding
Function: `krim_warehouse_dispatch_transfer(...)`

Observed safeguards:
- Requires authenticated operator access to both source and destination facilities.
- Locks the source inventory row.
- Requires released inventory, valid finite positive quantity and sufficient total on-hand quantity.
- Requires both facilities to remain active and independently approved.
- Uses an idempotency key and creates a transfer, decrements source inventory, records movement and audit event transactionally.

**Missing visible invariant:** the function does not calculate or subtract outstanding `reserved` shipment allocations before dispatching the transfer. The source check is effectively `v_source.quantity >= p_quantity`; it does not require `v_source.quantity - sum(reserved allocations) >= p_quantity`.

Potential consequence: if inventory quantity is 100 and shipment allocations reserve 80, a warehouse operator could transfer 30 units because total on-hand is 100. The remaining 70 would be less than the 80 committed to shipment allocations. This is an illustrative arithmetic scenario, not a live record or executed test.

Required staging test:
1. Create test stock and reserve a portion for a shipment.
2. Attempt to transfer more than the unreserved balance but less than total on-hand.
3. Confirm transfer is rejected.
4. Confirm a transfer within the unreserved balance succeeds.
5. Run concurrent transfer/reservation attempts to prove locking prevents race conditions.

## 4. Generic picking task alternate path — P1 staging verification
Functions:
- `krim_warehouse_create_task(...)`
- `krim_warehouse_transition_task(...)`
- `krim_warehouse_record_movement(...)`

Observed:
- Generic task creation permits `picking_packing` tasks that are not shipment-linked.
- Completing a `picking_packing` task calls the shared `krim_warehouse_record_movement` routine with a negative quantity delta.
- The shared movement routine validates movement type, quantity sign, organization/facility/operator and inventory balance, but its inspected body does not visibly calculate outstanding reserved allocations.
- A separate trigger blocks completion of legacy `picking_packing` tasks when both shipment and leg IDs are present, directing shipment-linked picks to the allocation workflow.

Assessment: the trigger protects shipment-linked legacy picking, but does not obviously protect a generic pick task with no shipment linkage from consuming reserved stock. Because the movement routine is not directly executable by authenticated users, the reachable path is the authenticated warehouse task transition.

Required staging test:
1. Create stock and a reserved shipment allocation.
2. Create a generic non-shipment-linked picking task for the same SKU/lot/facility.
3. Complete the generic task.
4. Verify whether it can reduce stock below outstanding reservations.
5. If reproducible, enforce the unreserved-quantity invariant centrally inside the movement routine or a shared locked inventory-debit helper so every debit path inherits the same protection.

## 5. Shipment-linked legacy picking and dispatch handover
Live triggers on `krim_warehouse_tasks` provide positive protections:
- `trg_krim_block_legacy_shipment_pick_task_completion` rejects completion of shipment-linked legacy picking tasks, preventing duplicate movement outside the allocation model.
- `trg_krim_dispatch_handover_requires_picked_allocations` locks the shipment and relevant allocations, requires at least one picked allocation for the exact shipment leg/facility, and blocks handover while any allocation remains reserved and unpicked.
- `krim_guard_dispatch_handover_evidence` requires an exact shipment/leg link and a private, uploader-owned dispatch proof file with permitted MIME type and bounded size before handover completion.
- `krim_warehouse_guard_goods_receipt_quality` prevents a receiving operator from directly marking a goods receipt as released.

Assessment: good defense in depth. Ensure transfer/pick alternate paths preserve the same stock reservation invariant.

## 6. Reservation release and picked-stock handling
Function: `krim_warehouse_release_shipment_allocation(...)`

Positive controls:
- Requires authenticated user, `partner.manage`, and operator access.
- Requires a reason and idempotency key.
- Only `reserved` allocations can be released.
- Picked allocations cannot be released; the function directs them to a controlled reverse-pick workflow.
- Stores releaser, timestamp, reason, idempotency key and audit event.

Assessment: this prevents a reservation from being silently undone after physical pick. A controlled reverse-pick workflow and cancellation orchestration still need end-to-end staging proof.

## 7. Independent inventory quality review
Function: `krim_warehouse_review_inventory_quality(...)`

Positive controls:
- Requires completed goods receipt or damage-exception task.
- Blocks repeated final quality decisions on the same task.
- Reviewer must differ from task creator and completer.
- Requires an existing private inspection report uploaded by someone other than the reviewer, with organization/facility path scope, uploader ownership, allowed MIME type and file-size checks.
- Matches inventory by organization, facility, SKU and lot, locks the inventory row, and checks every receipt movement contributing to the balance has completed goods-receipt evidence and independent review.
- Writes task event and audit event with previous/new quality state.

Assessment: strong maker-checker and evidence controls in the inspected function. Validate concurrency between review, new receipt movement and reservation in staging.

## 8. Inter-warehouse transfer receipt
Function: `krim_warehouse_receive_transfer(...)`

Positive controls observed:
- Requires approved destination facility operator access.
- Requires dispatched transfer state.
- Prevents the same user who dispatched from receiving.
- Locks transfer and destination inventory; uses idempotency key.
- Prevents merging into a destination SKU/lot with a different quality status; unit mismatch is blocked.
- Audit and movement records are written transactionally.

Assessment: independent receiver and quality-state separation are positive controls. Confirm destination facility remains active/approved at receipt time and verify partial receipt/shortage/damage policy (current function appears designed for full transfer receipt).

## 9. Shipment return receipt NULL-validation concern
Function: `krim_receive_authorized_shipment_return(...)`

Positive controls:
- Requires authenticated partner management permission and authorized operator at an active independently approved facility.
- Locks authorized return; requires status `authorized`.
- Uses idempotency key and rejects conflicting receipt replay.
- Reconciles each received item to a unique manifest index and exact authorized quantity/unit/description.
- Creates return stock on quality `hold` and changes return to `inspection_hold`.
- Writes audit event.

**Validation concern:** the initial compound check uses `jsonb_typeof(p_received_items)<>'array'` and `jsonb_array_length(...)` without a separate `p_received_items IS NULL` guard. With SQL NULL, the Boolean expression can evaluate to NULL rather than TRUE, allowing execution to reach later logic. Numeric item parsing also needs explicit missing/NULL checks before arithmetic/comparison. This is a known code-level NULL-validation defect; reproduce with explicit SQL NULL and JSON null in staging, then enforce `p_received_items IS NOT NULL`, `jsonb_typeof(...)='array'`, required keys, and non-null parsed values before inserting any receipt.

No return was received and no malformed input was submitted in production.

## 10. Remediation and test order
1. Add a shared locked invariant for every stock debit: on-hand quantity less outstanding reserved quantity must remain non-negative. Apply to transfer dispatch and generic picking, and audit every other negative movement path.
2. Make inventory debit and allocation reservation serialize on the same inventory row lock; ensure consistent lock order to avoid deadlocks.
3. Reproduce the transfer and generic-pick scenarios in staging with isolated fixtures and concurrent requests.
4. Harden return receipt validation for SQL NULL, JSON null, missing keys, wrong types, duplicate manifest indices, and non-finite/negative quantities.
5. Verify reverse-pick, shipment cancellation, allocation release, transfer cancellation and return inspection/quality-release orchestration.
6. Re-run the full warehouse-to-dispatch path in staging, including picked allocation, dispatch proof, independent handover, dispatch authorization, custody and POD.
7. Only after migration-history reconciliation and sanitized schema manifest, prepare reviewed migrations. Do not patch production directly.

## 11. Release decision
**NO-GO for unrestricted warehouse execution.** Reservation, picking, quality and handover controls are meaningful, but transfer and generic pick paths require staging validation against reserved stock, and return input validation needs hardening. This was a read-only audit; no production DDL, grants, policies, functions or business records were changed. Financial setup remains deferred to the final phase.
