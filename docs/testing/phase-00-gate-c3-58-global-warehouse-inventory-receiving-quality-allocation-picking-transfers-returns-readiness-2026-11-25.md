# C3.58 — Global warehouse, inventory, quality, allocation, picking, transfers and returns readiness

**Programme:** KRIM GLOBAL PLATFORM — AI QUALITY ASSURANCE, SIMULATION & RELIABILITY PROGRAMME  
**Phase:** 00 — Infrastructure Audit  
**Gate:** C3.58  
**Immutable source baseline:** `72d75a18f985ceb09e468839435ee95700e11e46`  
**Audit date:** 2026-11-25  
**Method:** Read-only review of immutable migration source, warehouse workspace entry pages and dated 16 Nov audit artifacts. No warehouse RPC, SQL mutation or runtime journey executed.

## Verdict

**FAIL / BLOCKED — NO-GO for real warehouse receiving, stock commitments, picking, transfers, returns, or dispatch handover.**

KRIM has a substantial warehouse control design: independently approved facilities, restricted inventory writes, evidence-backed receipt/QC, quality-state separation, shipment allocation, a dedicated allocation-pick RPC, independent transfer/return quality review and exact-leg dispatch handover. However, two critical alternate paths can consume stock already reserved for shipments: inter-facility transfer dispatch and generic/linked picking. This breaks the authoritative available-to-promise invariant. There is also no operational warehouse base or completed end-to-end evidence in the dated production snapshots, and some receipt/return replay and completeness controls require further hardening.

## Scope reviewed

- Warehouse workspace pages: control centre, facility management, inbound receiving, goods receipt, put-away/storage, damage exceptions, inventory ledger, shipment allocation, picking/packing, quality review, dispatch handover, reverse logistics/transfers, evidence, alerts, dock/yard, cycle counting, cross-docking, container handling and capacity planning.
- Migrations for warehouse core operations, atomic stock movements, direct-write lockdown, facility approval, receipt/task runtime, evidence ownership, task idempotency, quality maker-checker, mixed-quality lot prevention, linked shipment receipt/pick/pack/handover, exact-leg allocation, inter-facility transfers, transfer QC, return authorization, physical return receipt and independent return QC.
- Dated 16 Nov warehouse deep audits covering stock reservation, task picking, transfer, QC, returns, available-to-promise and dispatch handover.

## Positive source controls — PARTIAL PASS

1. **Facility registration and approval are separated.** Facility review is designed for authorized AAL2 platform administrators, includes a reason and independent reviewer, and checks eligible registered-business warehouse organization status. Facility operation requires active and approved status.
2. **Direct inventory mutation is restricted.** Reviewed inventory/movement tables have RLS and scoped read access; direct authenticated insert/update/delete policies were not present in the dated source audit. Writes are intended to pass through controlled RPCs.
3. **Receipt does not automatically release stock.** Goods receipt and inspection tasks are distinct. Quality review requires completed receipt/damage work, a different reviewer from task creator/completer, and uploader-owned private inspection-report evidence.
4. **Quality states are kept separate.** Receipt movements do not merge into an existing SKU/lot balance with a different quality state. Returned stock and transfer-received stock enter hold pending independent review.
5. **Shipment allocation has an explicit reservation ledger.** Allocation requires accepted/active partner assignment, active approved facility, released inventory and exact shipment/leg binding where supplied. It locks inventory and calculates outstanding reserved quantity before allocation.
6. **Dedicated allocation picking is atomic in the intended path.** The allocation-pick RPC locks allocation and inventory, requires a reserved allocation and released sufficient stock, records the negative movement and marks the allocation picked in one transaction. Replay is intended to avoid a second movement.
7. **Warehouse handover is distinct from dispatch.** Linked handover is scoped to shipment and leg; later dispatch guards require picked allocations, no remaining reservations, completed warehouse handover and private dispatch proof.
8. **Inter-facility receiving is a separate custody step.** Transfer dispatch and receipt are distinct; destination receiving requires an authorized operator different from the dispatcher, and destination inventory is held pending independent quality review.
9. **Return authorization and physical receipt are separated.** Customer return requests are linked to completed shipment/leg and assigned partner; partner acceptance is explicit. Physical receipt checks each line against the authorized manifest and creates distinct held return lots.
10. **Transfer QC has independent reviewer and evidence controls.** Reviewer must differ from dispatcher and receiver; evidence must be private, reviewer-owned, path-scoped and bounded by MIME/size; final quality decision updates destination stock and transfer status.
11. **Warehouse evidence and task replay received later hardening.** Source migrations add uploader ownership checks, idempotency payload comparisons, unit consistency and quality-review checks across receipt contributors. These source controls still need runtime regression tests.

## P0 — release blockers

1. **Inter-facility transfer can consume stock already reserved for shipments.** In the immutable baseline, `krim_warehouse_dispatch_transfer` locks the source inventory row and checks `source.quantity >= requested quantity`, then decrements on-hand. It does not subtract active `krim_warehouse_shipment_allocations.status='reserved'`. A transfer can therefore make on-hand fall below shipment commitments. This directly violates `available_to_allocate = released_on_hand - active_reserved_allocations`.
2. **Generic and shipment-linked task picking can bypass allocation consumption.** Generic `krim_warehouse_create_task` validates total released stock, not unreserved stock. `krim_warehouse_create_linked_pick_task` checks released SKU/lot/unit/quantity but does not require a matching active shipment allocation. Completing the task calls generic `krim_warehouse_record_movement` with a negative pick, rather than consuming the exact allocation. The dedicated allocation-pick RPC is safer, but the task route is a second stock-decrement path. A pick can consume units committed to another shipment while its allocation remains reserved.
3. **No complete warehouse operation has been proven in isolated Staging.** No evidence in this gate shows facility approval → inbound receipt → inspection → independent release → put-away → shipment reservation → exact allocation pick → pack → handover → dispatch; or transfer dispatch → receipt → independent QC; or return authorization → physical receipt → independent QC.
4. **No operational warehouse foundation is established by the dated production evidence.** The 16 Nov deep audit reported zero approved facilities, inventory balances, receipts, movements, allocations, warehouse tasks, transfers, returns, return receipts, return QC and custody records. These are historical counts, not current-live assertions. They show that operational readiness had not been demonstrated at that snapshot.
5. **Alternate write paths remain a material risk.** The generic movement function, generic task completion, linked-pick task completion, direct DML, legacy RPCs, privileged jobs and admin paths need a complete current caller/grant matrix. The reviewed source has multiple stock-decrement paths, and there is no exhaustive evidence that every path enforces the same reservation-aware availability invariant.

## P1 — integrity, lifecycle and operational gaps

1. **Transfer receipt replay is not fully actor-bound.** Dated audit found the replay branch checks idempotency key and notes but does not compare the current caller with the original receiver. Stock is not moved twice, but the replay response is not bound to the original actor. Define whether replay is actor-specific or shared across authorized destination operators, and persist/compare the canonical payload accordingly.
2. **Return receipt JSON validation is not defensive enough.** The receipt RPC checks top-level JSON array shape/length and then casts each line quantity directly to numeric. Malformed lexical values can raise avoidable database errors; explicitly reject SQL NULL, JSON null, wrong field types, nonnumeric/nonfinite values, missing/duplicate/out-of-range indexes and malformed lines before casts.
3. **Return QC needs a complete all-lines invariant.** The reviewed return quality path should lock all receipt items and linked inventory rows, prove exact item-to-inventory cardinality and ownership, require every expected balance still on hold, and update all rows plus return status atomically. Partial or mixed-state review must fail closed.
4. **Generic movement replay payload must remain canonical.** The dated available-to-promise audit found replay comparison omitted business-relevant fields such as quality status, item description and storage location. Later source migration adds unit and notes checks, but the full canonical request/response contract still needs explicit review and tests for every field.
5. **Task transition idempotency does not replace stock reservation checks.** Later migration compares new status and notes on replay; that improves conflicting retries but does not make a generic negative movement allocation-aware or protect reserved stock.
6. **Reservation release/cancel lifecycle needs a full transition matrix.** Test pre-pick release, post-pick reversal policy, shipment/leg cancellation, assignment revocation, facility suspension, partial pick, duplicate release and replay. Availability must be restored exactly once without increasing on-hand or reopening already-picked quantities.
7. **Partial damage and quality segregation are limited.** The inspected model has one quantity and a quality state per SKU/lot balance. A partial-damage event may hold the entire balance; no complete split-lot/partial-quantity disposition workflow was proven. Do not claim separate damaged/quarantined quantity accounting unless implemented.
8. **Put-away is whole-lot oriented.** The dated audit found task logic expects the inventory row quantity to equal task quantity and updates the full matching row's storage location. Partial put-away or split-location handling needs an explicit supported limitation or audited quantity-split ledger.
9. **Transfer dispatch/receive concurrency and reconciliation need proof.** Test simultaneous shipment allocation vs transfer, concurrent transfers, source/destination movement matching, destination quality hold, replay after timeout and rollback after mid-transaction failure.
10. **Return manifest and physical receipt edge cases need proof.** Validate exact manifest cardinality, source lot, SKU, quantity, unit, description, duplicate indexes, extra/missing lines, partial returns policy, wrong facility, wrong organization and duplicate receipt.
11. **Facility and evidence revocation need downstream propagation.** A facility suspended after task creation or a private evidence object deleted/replaced before QC/handover must block subsequent operations. Validate facility status again at every mutation, not only at task creation.
12. **Inventory model needs explicit unit and lot lineage.** No silent conversion is allowed; test normalized SKU/lot uniqueness, unit consistency, lot split/merge prohibition across quality states, serial/expiry/batch fields where required and movement reference integrity.
13. **Warehouse operational functions are broader than verified automation.** Dock appointments, yard gates, cross-docking, container handling, workforce/shift management, capacity planning, cycle counts, damage workflows and alerts have pages, but no complete authoritative runtime workflow or worker evidence was executed.
14. **Tenant confidentiality and role separation are not runtime verified.** No two-organization negative tests for inventory, facility, supplier, allocation, transfer, return, inspection evidence, worker notes or shipment manifests were run. Verify operator vs supervisor vs QC reviewer vs platform admin and maker-checker separation.
15. **Handover is not dispatch authorization.** A completed warehouse handover is only a warehouse custody checkpoint; it does not itself authorize carrier dispatch, prove physical departure or assign a driver.

## Required isolated Staging acceptance tests

- Verify facility registration, private evidence ownership, AAL2 independent approval, rejection/resubmission, expiry/suspension and tenant denial.
- Create receipt with valid and invalid manifests; test SQL NULL, JSON null, wrong JSON types, malformed quantity, NaN/infinity, zero/negative, duplicate SKU/lot, unsupported unit and duplicate idempotency.
- Prove receipt creates pending/held stock only; same reviewer as creator/completer/uploader must be denied; independent QC with missing/wrong-owner/oversized evidence must be denied.
- Test mixed-quality receipt into existing same SKU/lot; it must not merge. Test lot split, partial damage, quarantine and disposition policy.
- Reserve released inventory concurrently for two shipments; total reserved must never exceed on-hand. Verify exact shipment/leg/facility/SKU/lot/unit binding.
- Attempt inter-facility transfer with active reservations: transfer quantity above unreserved balance must fail. Race allocation against transfer under contention; exactly one operation may consume each available unit.
- Attempt generic picking against any reserved stock; reject. Attempt linked shipment pick without exact matching allocation; reject. Require exact allocation consumption and atomic picked transition for every shipment pick path.
- Test same-key/same-payload replay, same-key/different-payload conflict, timeout after commit, duplicate task completion and concurrent pick/transfer/reservation.
- Test pre-pick release, cancellation, partial pick, post-pick reversal policy and duplicate release; assert on-hand, reserved, picked and available equations after every step.
- Test transfer dispatch/receipt with different operators, wrong tenant/facility, changed receiver, replay actor/payload, destination hold and independent QC with complete evidence.
- Test return authorization, exact manifest receipt, malformed JSON, missing/extra/duplicate lines, source lot, wrong unit/quantity/description, wrong facility and receipt replay.
- Test return QC with missing/mixed/non-hold inventory row; entire decision must roll back. Require independent reviewer and reviewer-owned private evidence.
- Test facility suspension, partner membership revocation, evidence deletion, task expiry and direct DML/legacy RPC/job bypass attempts.
- Capture browser traces, RPC inputs/outputs, before/after inventory balances, allocation rows, movement ledger, evidence object metadata, audit events and concurrency/replay results.

## Authoritative stock accounting invariant

For each organization, facility, SKU, lot and unit:

`available_to_allocate = released_on_hand - SUM(active reserved allocations)`

- Held, pending, rejected or damaged stock is not allocatable.
- Every shipment pick consumes the exact allocation and reduces on-hand in one transaction.
- Generic picks may not consume reserved stock.
- Transfers may move no more than available-to-allocate and must reconcile source/destination movements.
- Cancellation/release restores allocatable availability exactly once; it does not add physical stock.
- Return/transfer receipts enter held stock and become allocatable only after independent QC.
- Every mutation is idempotent against a canonical business payload and produces durable movement/audit lineage.

## Status

| Area | Status | Basis |
|---|---|---|
| Facility registration and independent approval | PARTIAL PASS | Source gates exist; no runtime facility approval |
| Goods receipt and inspection evidence | PARTIAL PASS | Source controls exist; no real receipt journey |
| Independent quality release | PARTIAL PASS | Maker-checker and evidence gates exist; no runtime negative suite |
| Inventory movement/direct-write restriction | PARTIAL PASS | Controlled RPC design; alternate negative movement paths remain |
| Shipment allocation/reservation | PARTIAL PASS | Exact allocation and on-hand-minus-reserved check |
| Dedicated allocation pick | PARTIAL PASS | Atomic intended path; competing generic/linked task bypass remains |
| Inter-facility transfer | FAIL | Dispatch does not subtract active shipment reservations |
| Generic/linked shipment picking | FAIL | Can decrement stock without consuming exact reservation |
| Return authorization/receipt | PARTIAL PASS | Manifest and held-lot design; validation/QC completeness needs proof |
| Transfer/return QC | PARTIAL PASS | Independent evidence/reviewer controls; no Staging E2E |
| Put-away/partial damage/split locations | BLOCKED | Whole-lot model and partial-damage semantics incomplete |
| Warehouse handover | PARTIAL PASS | Exact-leg picked allocation and proof gates; not dispatch authorization |
| Complete warehouse operation | NOT TESTED | No isolated Staging journey or retained evidence |

## Safety boundary

No Production or Staging SQL/RPC, facility registration, receipt, stock movement, reservation, pick, transfer, return, QC decision, evidence upload, handover, notification, provider call or deployment was performed. No secrets or personal customer/warehouse records were read. No synthetic users were created. The 16 Nov operational counts and audit findings are historical snapshots; current live status was not queried.

## Exit criteria

Do not enable live warehouse operations until transfer dispatch and all generic/linked pick paths enforce the same reservation-aware stock equation under row locks; exact allocation consumption is mandatory for shipment picking; return JSON/QC and transfer replay invariants are hardened; facility/evidence revocation and all alternate caller/grant paths are verified; and full receipt-to-dispatch, transfer and return journeys pass isolated Staging concurrency, retry, tenant-isolation and rollback tests.
