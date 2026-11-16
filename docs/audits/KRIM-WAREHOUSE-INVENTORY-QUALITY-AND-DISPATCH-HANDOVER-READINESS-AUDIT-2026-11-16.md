# KRIM Warehouse, Inventory, Quality and Dispatch-Handover Readiness Audit — 2026-11-16

## Scope and method
Read-only review of live production warehouse tables, RLS/table privileges, and selected warehouse RPC definitions. This complements the prior capacity/inventory review and dispatch currentness addendum. No warehouse facility, receipt, stock item, allocation, task or transfer was created; no production business RPC was executed.

## Live production counts
| Object | Rows |
|---|---:|
| Warehouse facilities | 0 |
| Inventory balances | 0 |
| Goods receipts | 0 |
| Inventory movements | 0 |
| Shipment stock allocations | 0 |
| Warehouse tasks | 0 |
| Task events | 0 |
| Inter-facility transfers | 0 |
| Warehouse evidence | 0 |
| Transfer quality reviews | 0 |
| Return quality reviews | 0 |

There is no live warehouse operating history from which to demonstrate receipt-to-stock-to-pick-to-handover performance.

## Access-control findings
All nine inspected warehouse tables have RLS enabled. Authenticated users have SELECT but no direct INSERT, UPDATE or DELETE privileges on:
- facilities
- inventory
- inventory movements
- receipts
- shipment allocations
- tasks and task events
- transfers
- evidence

The inspected SELECT policies are scoped to eligible organisation membership, approved active facility, warehouse operator access, or the shipment parties' permissions as appropriate. Mutations are routed through controlled functions rather than direct table writes. This is a strong least-privilege foundation.

## Function-level controls verified

### Facility approval
The administrator review function requires authentication, AAL2 and platform-admin permission; locks the facility; accepts only pending review; prevents the facility creator from reviewing their own submission; and, before approval, requires an active registered-business organisation, verified partner status, eligible lifecycle/compliance and warehouse eligibility. It records reviewer, timestamp, reason and audit event.

### Goods receipt task
The linked goods-receipt task function requires an eligible warehouse operator, shipment and exact shipment leg, finite positive quantity, destination location, and an existing completed inbound receipt linked to the same shipment/leg. It does not allow the initial receipt task to release stock. It uses an idempotency key and checks the full replay payload.

### Inventory movement
The generic movement function:
- Allows only receipt and pick movement types; rejects direct dispatch, transfer, return and adjustment movements.
- Requires an eligible registered-business warehouse organisation, partner.manage permission and an active approved facility.
- Uses idempotency and advisory locks, then locks the matching inventory balance.
- Rejects negative stock, unit mismatch, and merging a receipt into a lot with a different quality state.
- Allows picks only from released stock.

### Allocation picking
The pick-allocation function requires an authorised warehouse operator, locks the allocation and inventory, accepts only a reserved allocation, requires released stock and sufficient quantity, writes a pick movement and marks that allocation picked. The stock movement and allocation transition occur within one database transaction.

### Evidence registration
Warehouse evidence registration requires an operator, supported evidence type, organisation/user/file path, and an owned object in the private warehouse evidence bucket. It checks JPEG/PNG/PDF MIME type and 1–10 MB file size, then writes the evidence row and task event.

### Transfer receiving
The receive-transfer function requires authorised access to the destination facility, a dispatched transfer, and a receiver different from the dispatcher. It locks the transfer, uses idempotency, rejects unit mismatches and prevents merging into an inventory lot with a different quality state. New received stock enters on hold rather than released.

## Important unresolved inventory invariant

### P1 — Inter-facility transfer dispatch must account for reserved shipment stock
The earlier inventory review identified that transfer dispatch can decrease source stock without subtracting active shipment allocations from available-to-promise. A warehouse can therefore transfer away stock already reserved for a shipment. Later picking can fail despite the original reservation having succeeded.

Row locks alone do not solve this: the transfer workflow and reservation workflow must calculate against the same invariant while holding the same inventory-row lock.

Required invariant:
`available_to_promise = on_hand_quantity - SUM(active reserved allocation quantities)`

Every non-allocation stock-decrease path must reject a decrease greater than available-to-promise. Picking must consume its own allocation atomically; releasing an allocation must free only that allocation. Validate inventory ID, facility, lot, unit and quality state consistently. Confirm the exact transfer-dispatch implementation and all other stock-decrease paths in staging before a migration is prepared.

## Other required staging tests
1. Concurrent reservations against the same lot and simultaneous reservation/transfer/pick.
2. Duplicate idempotency key with identical and conflicting payloads.
3. Receipt with missing/incorrect shipment leg, quality hold, rejected quality, duplicate reference and partial quantities.
4. Independent inspection report and second authorised reviewer; creator cannot approve own inspection.
5. Quality-state separation across lots and transfers; no unsafe merges.
6. Transfer source/destination organisation/facility boundaries, dispatch/receive separation, receiver identity and retry.
7. Return intake, inspection, disposition and restock; returned goods never automatically become released.
8. Shipment allocation must be linked to the correct shipment/leg and partner/facility authority.
9. Dispatch handover must require all exact shipment allocations picked, verified warehouse handover evidence, and current leg dispatch authorization.
10. Cancellation, reassignment, reservation expiry and allocation release must reconcile stock and prevent stranded reservations.
11. Facility suspension or partner compliance expiry must block new warehouse operations and safely handle existing reservations/tasks.
12. Physical stocktake variance and adjustment require an independently authorised, evidenced review path; generic direct adjustment remains blocked.

## Release decision
The warehouse schema and controlled RPC design have useful security boundaries, and the inspected tables deny direct authenticated writes. However, the live database has zero facilities, zero inventory and zero warehouse execution records. There is no operational warehouse network demonstrated.

The reserved-stock/transfer invariant remains a P1 correctness gap from the earlier review. Keep warehouse dispatch and commercial shipment promises gated until the invariant is fixed through reconciled migrations and concurrency-tested in staging, then run a controlled pilot with a genuinely verified facility.

No production changes were made.
