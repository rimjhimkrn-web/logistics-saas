# Warehouse reserved-stock invariant and movement-path remediation

Date: 2026-11-16  
Status: production defect confirmed; remediation specification only  
Scope: warehouse inventory movement, shipment allocation picking, generic task picking, and inter-facility transfer

## Executive finding

The live reservation path correctly locks the inventory row and checks:

`on_hand_quantity - SUM(outstanding reserved allocations) >= requested reservation`

However, the shared `krim_warehouse_record_movement(..., 'pick', ...)` path checks only that the resulting physical balance is non-negative. It does not protect outstanding shipment reservations. The generic `picking_packing` task completion path calls this shared function, and the transfer dispatch function also checks only total on-hand quantity.

This creates a confirmed invariant gap: stock already reserved for a shipment can be consumed by an unrelated generic pick or transferred out before the reserved shipment allocation is picked. A later shipment pick may then fail, even though its allocation remains `reserved`.

## Live implementation evidence (read-only inspection)

### Reservation path

`krim_warehouse_reserve_shipment_inventory(bigint,uuid,uuid,bigint,bigint,numeric,uuid,text)`:
- locks the shipment and, when supplied, the exact shipment leg;
- requires an accepted/active partner assignment and an authorized warehouse operator;
- locks the selected inventory row `FOR UPDATE`;
- requires released stock and an active, approved facility;
- sums allocations for that inventory row with status `reserved`;
- rejects unless `inventory.quantity - reserved_quantity >= requested_quantity`;
- inserts the reservation and audit event in the same transaction.

The row lock serializes reservations against other code paths that lock the same inventory row before calculating or changing stock.

### Shared movement path

`krim_warehouse_record_movement(...)`:
- has authenticated membership, permission, facility, quality and idempotency checks;
- locks an inventory row for the matching organization/facility/SKU/lot;
- for a pick, requires released quality and only checks `inventory.quantity + quantity_delta >= 0`;
- does not subtract outstanding `reserved` allocations;
- accepts `reference_type` and `reference_id` as caller-supplied values.

### Shipment allocation pick path

`krim_warehouse_pick_shipment_allocation(uuid,uuid,text)`:
- locks the allocation row and checks operator permission;
- requires allocation status `reserved`;
- locks its inventory row and checks released stock and total quantity;
- calls the shared movement function with `reference_type='shipment_allocation'` and the allocation ID;
- changes allocation status to `picked` after the movement call, in the same transaction.

The current ordering means the allocation is still `reserved` while the movement function runs. A safe central guard must account for the exact allocation being consumed without allowing an ordinary caller to spoof that reference.

### Generic task pick path

`krim_warehouse_transition_task(uuid,text,uuid,text)` calls the shared movement function for generic `picking_packing` tasks using `reference_type='warehouse_task'`. The shared movement function does not establish that this task is shipment-unallocated stock.

### Transfer path

`krim_warehouse_dispatch_transfer(bigint,uuid,uuid,uuid,numeric,text,uuid,text)`:
- locks the source inventory row;
- requires released quality and checks only `source.quantity >= transfer_quantity`;
- decrements stock and records the transfer in one transaction;
- does not account for outstanding reserved shipment allocations.

## Required invariant

For every inventory balance row, all stock-removing operations must preserve:

`on_hand >= outstanding_reserved`

For an unreserved removal (generic pick or transfer):

`on_hand - outstanding_reserved >= requested_removal`

For a shipment-allocation pick:

`on_hand - outstanding_reserved_excluding_this_exact_allocation >= this_allocation.quantity`

The allocation must be the exact row being picked and must match organization, facility, inventory, unit, shipment and leg bindings. No caller-provided reference string alone can grant an exemption.

## Required remediation design

1. Establish one private, non-exposed inventory-decrement authority used by every stock-removing path. It must lock the inventory row first, then calculate outstanding reservations while that lock is held.
2. Ordinary movement and generic task paths must never receive a shipment-allocation exemption. Reject reserved-allocation reference values on the public/shared entry point unless the call is routed through the private exact-allocation authority.
3. The shipment allocation picker must call the private authority with the locked allocation row. The authority must independently load/lock the allocation and verify:
   - status is exactly `reserved`;
   - organization, facility, inventory ID, unit, shipment ID and nullable/exact leg ID all match;
   - quantity is finite, positive and exactly the allocation quantity;
   - shipment and leg are still eligible and assignment linkage remains exact;
   - current operator authorization and released quality remain valid.
   It must atomically decrement stock, record the canonical movement and transition the allocation to `picked`, or otherwise ensure all three happen in one transaction with no externally callable bypass.
4. Generic `picking_packing` completion must be rejected if the task is linked to a shipment or if its requested quantity would consume reserved stock. Shipment-linked picks must use the exact allocation workflow only.
5. Transfer dispatch must, after locking the source inventory row, sum all outstanding reservations and reject unless unreserved quantity covers the transfer. The check and decrement must remain in the same transaction.
6. All inventory-decrement paths, including any legacy/internal/trigger path, must be enumerated and routed through the same invariant. Do not assume these four RPCs are the only writers.
7. Preserve canonical idempotency: same key and same full payload replays; same key with any changed field rejects. A replay must not decrement stock or transition an allocation twice.
8. Define and test a consistent lock order across allocation, inventory, shipment/leg, and transfer operations. Avoid introducing an allocation↔inventory lock inversion. Use deterministic lock order for multi-row operations.
9. Add audit metadata for reserved quantity before/after, unreserved quantity, exact allocation exemption (when applicable), and transfer/pick reference. Do not expose another tenant's allocation metadata.
10. Keep direct table writes blocked for ordinary authenticated users; validate grants, RLS, SECURITY DEFINER ownership/search_path, and execute ACLs for every new private/public function.

## Required verification before release

Run only in isolated staging with synthetic inventory, reservations, tasks and transfers. Do not test by invoking production business functions or mutating production inventory.

- Reserve 7 of 10 units; generic pick 4 must fail; generic pick 3 may succeed.
- Reserve 7 of 10; transfer 4 must fail; transfer 3 may succeed.
- Reserve 7 of 10; exact allocation pick of 7 succeeds once and leaves 3 on hand.
- A different allocation cannot be used as the exemption.
- A different organization, facility, inventory, unit, shipment or leg cannot be substituted.
- A generic task cannot spoof `reference_type='shipment_allocation'`.
- Two concurrent reservations/removals cannot oversubscribe the same inventory row.
- Transfer and reservation racing on the same inventory row preserve the invariant.
- Duplicate identical request replays without a second decrement; conflicting retry rejects.
- Transaction failure at movement, allocation transition or audit insertion rolls back all effects.
- Quality hold/rejected inventory cannot be picked or transferred.
- Confirm all alternate stock writers and privileged/service-role paths obey the same invariant.
- Verify audit history, tenant isolation, RLS, function ACLs, and no unintended public execute grants.

## Release decision

**NO-GO for production warehouse inventory execution until the invariant is enforced across every stock-removing path and the staging concurrency/idempotency suite passes.**

This is not a production migration and has not been applied. Production DDL remains blocked by the unresolved migration-history reconciliation. The document records the verified live behavior and the implementation contract for a later reconciled, reviewed migration.
