# KRIM Warehouse → Inventory → Quality → Picking → Dispatch Handover Audit

**Date:** 2026-11-16  
**Environment:** Supabase production, read-only inspection  
**Repository:** `rimjhimkrn-web/logistics-saas`  
**Decision:** **NO-GO for live warehouse execution** until the P0/P1 findings below are remediated and staging concurrency/replay tests pass.

## Scope and method

Inspected production table definitions, selected RPC definitions, row-level security policies, live row counts, and the current warehouse picking/dispatch-handover frontend callers. No business RPC was invoked. No production rows, schema, functions, policies, or storage objects were changed.

Reviewed workflows:
- facility approval and warehouse operator eligibility;
- inbound receipt, goods receipt, inspection evidence, independent QC release;
- stock movements and quality states;
- shipment reservation, allocation picking and generic/linked picking tasks;
- inter-facility stock transfer, receipt and independent transfer QC;
- damaged stock exceptions and return receipt/QC;
- dispatch handover task linkage and dispatch authorization boundary.

## Production evidence: operational records are empty

| Record class | Current rows |
|---|---:|
| Warehouse facilities | 0 |
| Inventory balances | 0 |
| Inventory movements | 0 |
| Warehouse receipts | 0 |
| Shipment inventory allocations | 0 |
| Warehouse tasks | 0 |
| Warehouse task events | 0 |
| Inter-facility transfers | 0 |
| Transfer quality reviews | 0 |
| Shipment returns | 0 |
| Return receipts / receipt items | 0 / 0 |
| Return quality reviews | 0 |
| Dispatch-handover tasks | 0 |
| Shipment-leg dispatch authorizations | 0 |
| Legacy shipment dispatch rows | 0 |

These counts establish that there is no live warehouse execution history to validate. They do not establish that the workflows are functionally ready.

## Positive controls confirmed

1. **Facility approval:** platform-admin review requires AAL2, platform-admin permission, a reason, a reviewer different from the facility submitter, and eligible registered-business warehouse organisation status.
2. **No direct inventory writes:** inventory and movement tables have RLS enabled and only a scoped authenticated SELECT policy in the inspected policy set; no authenticated INSERT/UPDATE/DELETE policies were found. Mutations are routed through RPCs.
3. **Receipt quality gate:** initial goods receipt cannot mark stock released. Independent quality review requires a completed goods-receipt/damage task, reviewer different from task creator and completer, and uploader-owned private inspection-report evidence.
4. **Quality-state separation:** receipt movements cannot merge into an existing SKU/lot balance with a different quality status. Return receipts create a distinct return lot on hold.
5. **Shipment allocation:** reservation requires an assigned/accepted partner, approved active facility, released inventory, and checks existing reserved quantity under an inventory row lock.
6. **Dedicated allocation pick:** `krim_warehouse_pick_shipment_allocation` locks the allocation and inventory, consumes the allocation quantity, and marks the allocation picked in the same transaction.
7. **Transfer receiving:** receiving requires a different operator from the dispatcher, and destination inventory is held pending independent quality review.
8. **Dispatch separation:** frontend explicitly tells the operator that warehouse handover completion is only a warehouse custody checkpoint, not shipment dispatch or driver assignment.

## Findings

### P0 — Stock can be overcommitted when a transfer moves reserved inventory

**Evidence:** `krim_warehouse_dispatch_transfer` checks `v_source.quantity >= p_quantity`, then subtracts the transfer quantity from the source balance. It does not sum or subtract active `krim_warehouse_shipment_allocations.status='reserved'` before allowing the transfer.

**Impact:** stock reserved for one or more shipments can be transferred away. The source balance can fall below the sum of active reservations. A later allocation pick may fail for insufficient stock, or the inventory ledger may report physically unavailable reserved stock as committed.

**Required remediation:** under the same inventory row lock, calculate active reserved quantity and reject any transfer where `on_hand - reserved < transfer_quantity`. Define and test the exact handling for partially picked, released and cancelled allocations. Reconcile historical reservation states before enabling the corrected path.

### P0 — Generic and shipment-linked picking can consume stock reserved for another shipment

**Evidence:** `krim_warehouse_create_task` validates a generic `picking_packing` task against total inventory quantity and quality state, but not against active reservations. `krim_warehouse_create_linked_pick_task` likewise checks released quantity and unit but does not require a matching shipment allocation. On task completion, `krim_warehouse_transition_task` calls `krim_warehouse_record_movement` with a negative pick. That movement function checks total quantity and quality state but does not protect the reserved balance.

The separate allocation-pick RPC does consume an explicit allocation and marks it picked. The generic/linked task completion route is therefore a second path around that allocation control.

**Impact:** an operator can complete a generic or shipment-linked pick without consuming the corresponding reservation. That pick can reduce stock underneath other shipments' reservations, while those allocations remain marked reserved. The current picking page uses the linked-task route; the linked task creator does not bind the pick to an allocation.

**Required remediation:** make every shipment pick consume one or more exact matching allocation rows atomically, and reject generic picking against any stock that is reserved. Enforce shipment/leg, SKU, lot, unit, quantity and allocation identity server-side. Do not rely on frontend checks or a later handover check.

### P1 — Transfer source stock reduction is not reservation-aware

This is the same underlying defect as the P0 overcommit finding, but affects transfer ledger correctness independently: the transfer dispatch records a negative movement and decrements on-hand stock without a reservation-aware availability calculation. A transfer may be correctly recorded while breaking shipment commitments. Fix together with the P0 transfer gate.

### P1 — Transfer receive idempotency is not fully payload-bound

**Evidence:** on an already-received transfer, `krim_warehouse_receive_transfer` checks the receive idempotency key and receive notes, but does not compare the caller identity against the original receiver in the replay branch. The initial receive path correctly rejects the dispatcher as receiver.

**Impact:** a different authorized destination operator who knows the transfer receipt key and notes can receive the replay response. This does not repeat the stock movement, but the replay response is not bound to the original actor. Treat this as an auditability and idempotency-contract weakness.

**Required remediation:** persist/compare the complete canonical receive payload and original actor on replay, or explicitly document that authorized facility operators share receipt idempotency scope. Keep replay response semantics consistent with that choice.

### P1 — Return receipt JSON numeric parsing is not defensive

**Evidence:** `krim_receive_authorized_shipment_return` validates the top-level array and line count, then casts each line's `quantity` directly to numeric. It does not first validate the JSON field's lexical numeric shape/type. Invalid values will error and roll back the transaction, so this is not evidence of a successful bad-stock write, but it creates avoidable failure paths and weak API error consistency.

**Required remediation:** validate JSON types and numeric input with a safe parser before casting; reject missing, non-numeric, non-finite, negative, duplicate or out-of-range manifest indexes with stable validation errors. Add adversarial JSON tests.

### P1 — Return quality review needs an explicit all-lines completeness invariant

**Evidence:** `krim_review_shipment_return_quality` updates receipt-item inventory rows whose current quality state is `hold`, then checks whether any row was updated. The receipt workflow currently creates a unique return lot per manifest index and holds it, which is a strong baseline. However, the reviewer does not explicitly assert that every receipt item maps to exactly one inventory row in the expected facility/organization and that every mapped balance is still on hold before finalizing the return decision.

**Impact:** future changes, partial data corruption or an unexpected quality-state mutation could allow a return-level decision to be recorded while not all associated inventory rows receive the same decision.

**Required remediation:** lock and validate the complete receipt-item set, assert exact item/inventory cardinality and ownership, require every inventory row to be on hold, then update all rows and the return status atomically. Reject partial or mixed-state review.

### P1 — Linked pick task creation is not allocation-bound

**Evidence:** `krim_warehouse_create_linked_pick_task` verifies the assigned shipment leg and sufficient released SKU/lot/unit balance, but does not require an active reserved allocation for that shipment/leg with matching inventory and quantity. The warehouse picking UI invokes this RPC. Task completion later removes inventory through the generic movement helper.

**Impact:** a shipment-linked pick task can be created and completed without consuming its reserved allocation, reinforcing the P0 bypass.

**Required remediation:** replace the linked task's free-standing stock check with exact allocation selection and atomic allocation consumption. A task may be a work instruction, but it must not become a second independent stock-decrement mechanism.

### P2 — Inventory model has a single quantity plus quality state, not separate damaged/quarantined quantities

**Evidence:** `krim_warehouse_inventory` exposes a quantity and one `quality_status` field; damaged/hold/rejected state is represented as a quality state, not as distinct quantity buckets. Damage exceptions set matching SKU/lot inventory to hold.

**Impact:** the model can safely prevent held stock from being picked, but cannot report available, reserved, damaged, quarantined and rejected quantities as independent sub-balances within one lot. A partial-damage event may put the entire matching balance on hold; there is no evident partial-quantity damage split in the inspected schema/RPC path.

**Required remediation:** define an explicit lot-splitting/partial-damage workflow and stock equation. Do not simply add a second reserved counter unless it is transactionally derived from allocation rows.

### P2 — Put-away is whole-lot only

**Evidence:** task creation and completion require the matching inventory row quantity to equal the task quantity, and update the full matching row's storage location. Partial put-away/split-location handling is not supported by the inspected RPC.

**Impact:** operational limitation for mixed-bin or split-pallet workflows; not necessarily a safety defect for the current narrow use case.

**Required remediation:** either document whole-lot put-away as a deliberate initial limitation or implement audited quantity splits with movement lineage and location-level balances.

### P2 — Dispatch handover is a checkpoint, not dispatch authorization

**Evidence:** the handover frontend checks that at least one allocation is picked and none remain reserved before allowing task creation. Backend task completion checks for a completed picking task linked to the same shipment and leg. The separate dispatch authorization table is empty, and the UI itself states that handover completion does not dispatch the shipment or assign a driver.

**Impact:** users must not interpret a completed warehouse handover as a legally/operationally authorized dispatch. Exact vehicle/driver/partner assignment and dispatch authorization remain separate gates.

**Required remediation:** preserve the distinction in UI labels, customer status, audit events and APIs. Before dispatch, require the independent exact-leg dispatch authorization, confirmed capacity binding/reservation, eligible driver/vehicle evidence and required custody evidence.

## Stock accounting contract required before release

For each inventory lot, facility and unit, define the authoritative equation:

`available_to_allocate = released_on_hand - active_reserved_allocations`

- Held, pending, rejected or damaged stock is not allocatable.
- A pick must atomically reduce on-hand and transition the exact allocation from reserved to picked.
- A release/cancellation must transition the allocation and restore availability exactly once without increasing on-hand.
- A transfer must not move more than available-to-allocate; source and destination movements must reconcile to the same transfer.
- A return receipt must enter a distinct held lot; only independent QC can release it.
- Never add reserved quantity to on-hand. Reservations are commitments against on-hand, not additional physical stock.
- Every mutation must be idempotent on a canonical payload and produce a durable movement/audit event.

## Required staging-only verification suite

No production business RPC should be used as a test. Build isolated staging fixtures and test:
1. Two concurrent reservations against the same lot; only the total within available stock succeeds.
2. Transfer against a lot with active reservations; transfer above unreserved stock is rejected.
3. Generic pick against reserved stock; rejected.
4. Linked shipment pick without exact matching allocation; rejected.
5. Exact allocation pick; on-hand decreases once and allocation becomes picked once.
6. Replayed pick with same key/payload; no second movement. Same key with different allocation/quantity; rejected.
7. Concurrent pick and transfer; row/advisory locking prevents negative or overcommitted stock.
8. Partial allocation release/cancel and repeat; availability restored exactly once.
9. Receipt with pending/hold/rejected state; cannot be picked before independent QC.
10. Reviewer is creator/completer/evidence uploader; QC rejected.
11. Transfer dispatch and receive; receiver differs from dispatcher; destination enters hold.
12. Transfer quality review with missing, wrong-owner, oversized or reused evidence; rejected.
13. Return receipt with malformed numeric, duplicate index, missing line, extra line, mismatched unit/description and non-finite quantity; all rejected with no partial commit.
14. Return QC with one inventory row missing or no longer held; entire review rejected.
15. Dispatch handover without all required picked allocations, with remaining reservation, or with wrong shipment leg; rejected.
16. Tenant isolation, revoked membership, facility approval revoked mid-session, idempotency collisions and rollback after a forced mid-transaction error.

## Remediation order

1. **P0:** make transfer reservation-aware and remove generic/linked pick stock-decrement bypasses.
2. **P1:** bind linked pick tasks to exact allocation consumption and harden transfer receive replay.
3. **P1:** harden return receipt JSON validation and return QC completeness.
4. **P2:** formalize damaged/partial-damage and split-location lot accounting.
5. Add staging fixtures and run the full concurrency, retry, tenant-isolation and rollback suite.
6. Re-run warehouse frontend/backend contract checks and production read-only counts.
7. Only then reassess the warehouse dispatch handover gate.

## Release boundary and migration blocker

This audit is read-only. No production DDL/RPC remediation was applied. The repository and production migration histories remain materially mismatched; the sanitized schema-manifest workflow and full migration crosswalk are still required before any production schema/function change. Do not patch live RPCs, apply/replay migrations, or baseline/squash history until that reconciliation is complete.

## Overall decision

**NO-GO for live warehouse stock handling, transfers, returns, picking or dispatch handover.** The strongest controls are present—facility approval, private evidence, independent QC, direct-write restrictions and dedicated allocation pick—but the transfer and task-pick routes can bypass reservation accounting. All operational warehouse tables are currently empty, so no live execution evidence exists.
