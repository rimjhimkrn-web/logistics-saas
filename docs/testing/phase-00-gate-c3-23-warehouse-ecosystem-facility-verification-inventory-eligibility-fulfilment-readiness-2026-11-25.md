# Phase 00 Gate C3.23 — Warehouse ecosystem onboarding, facility verification, inventory eligibility and fulfilment readiness

**Date:** 2026-11-25  
**Source baseline:** `72d75a18f985ceb09e468839435ee95700e11e46`  
**Method:** Read-only review of warehouse migrations, authenticated workspace source and prior warehouse/inventory audits. No SQL/RPC was executed, no facility/task/receipt/inventory/allocation/transfer/return was created or changed, no evidence was uploaded, and no Production/Staging configuration was changed.

## Executive decision

**FAIL / BLOCKED — NO-GO for live warehouse stock handling, picking, inter-facility transfer, returns or dispatch handover.**

The warehouse ecosystem has meaningful foundations: facility registration is restricted to eligible registered-business warehouse organisations and active partner managers; newly submitted facilities remain inactive pending independent AAL2 platform-admin review; warehouse operator functions check active organisation membership, approved active facility and permission; direct inventory writes are locked down; receipts enter quality hold; independent quality review requires evidence; and a dedicated shipment-allocation pick path exists.

However, prior deep audit identified two P0 reservation-accounting bypasses: inter-facility transfer can remove stock already reserved for shipments, and generic/linked picking can consume stock without consuming the corresponding shipment allocation. Additional return receipt/QC completeness and cancellation risks remain. Historical Production snapshot showed zero facilities, inventory balances/movements, receipts, allocations, warehouse tasks, transfers, returns, quality reviews and dispatch handovers. No real warehouse network or operational execution is evidenced.

## Scope and evidence

### Source inspected
- `supabase/migrations/20261104110654_warehouse_facility_registration_and_review.sql`
- `supabase/migrations/20261104111128_warehouse_end_to_end_task_and_evidence_runtime.sql`
- `supabase/migrations/20261105064301_warehouse_maker_checker_release_gate.sql`
- `supabase/migrations/20261115180000_revalidate_warehouse_inspection_evidence_at_quality_review.sql`
- `supabase/migrations/20261115184000_warehouse_quality_review_all_receipt_contributors.sql`
- `supabase/migrations/20261116021000_warehouse_interfacility_transfer_lifecycle.sql`
- `supabase/migrations/20261116022000_warehouse_transfer_independent_quality_review.sql`
- `supabase/migrations/20261116025000_shipment_return_physical_receipt_and_independent_qc.sql`
- `supabase/migrations/20261116026000_warehouse_shipment_inventory_allocation.sql`
- `supabase/migrations/20261116027000_require_picked_allocations_before_dispatch_handover.sql`
- `supabase/migrations/20261116028000_require_warehouse_handover_before_leg_dispatch.sql`
- Warehouse facility, inbound, shipment allocation and quality-review workspace source under `app/warehouse/staging/`.

### Prior audit evidence used
- `docs/audits/KRIM-WAREHOUSE-FACILITY-AND-CONTROL-CENTRE-AUDIT-2026-11-16.md`
- `docs/audits/KRIM-WAREHOUSE-INVENTORY-QUALITY-PICKING-TRANSFER-RETURNS-AND-DISPATCH-HANDOVER-DEEP-AUDIT-2026-11-16.md`
- `docs/audits/KRIM-WAREHOUSE-FULFILMENT-AVAILABLE-TO-PROMISE-AND-REVERSE-LOGISTICS-INTEGRATION-AUDIT-2026-11-16.md`
- `docs/audits/KRIM-WAREHOUSE-INBOUND-EVIDENCE-INVENTORY-LEDGER-REVIEW-2026-11-16.md`
- `docs/audits/KRIM-WAREHOUSE-ALLOCATION-AND-QUALITY-REVIEW-UI-AUDIT-2026-11-16.md`
- `docs/audits/KRIM-CAPACITY-RESERVATION-AND-WAREHOUSE-INVENTORY-CONTROL-REVIEW-2026-11-16.md`
- `docs/audits/KRIM-WAREHOUSE-INVENTORY-RESERVATION-PICKING-TRANSFER-AND-RETURN-INTEGRITY-REVIEW-2026-11-16.md`

## Positive controls confirmed in source/prior audit

1. **Facility admission:** registration requires authenticated active organisation membership, registered-business organisation, verified/active/compliant warehouse eligibility and `partner.manage`; facility code/name/country/address/timezone inputs are validated.
2. **Pending by default:** a new facility is created with inactive status and `pending_review`; it is explicitly not operational until independent admin approval.
3. **Maker-checker facility review:** prior audit observed AAL2 platform-admin approval, reason requirement, reviewer different from facility submitter and eligible warehouse organisation.
4. **Operator/facility boundary:** warehouse RPC helper checks active member, active registered-business organisation, current compliance, active facility with approved review and partner-management permission.
5. **No direct stock writes:** prior policy review found inventory/movement tables RLS-enabled with scoped reads and no direct authenticated INSERT/UPDATE/DELETE path; stock changes are routed through RPCs.
6. **Receipt and QC separation:** initial receipt cannot release stock; independent quality review requires completed task, reviewer distinct from task creator/completer and private uploader-owned inspection report. Later migrations revalidate object owner/path/MIME/size and require all receipt contributors to meet the review invariant.
7. **Quality-state separation:** receipt/return stock is held; different quality states cannot be merged into one balance. Independent transfer QC is distinct from dispatch/receipt.
8. **Dedicated allocation workflow:** reservation locks shipment/leg/inventory, checks released stock and subtracts active reservations; dedicated allocation pick locks allocation and inventory and consumes the exact allocation transactionally.
9. **Dispatch boundary:** later migration requires picked allocations and warehouse handover before leg dispatch; UI correctly distinguishes warehouse handover from driver dispatch.
10. **UI and evidence hygiene:** facility rendering was corrected to escape partner-controlled values; warehouse evidence uses private storage, registration RPC and short-lived signed previews. These are source/audit findings, not runtime proof.

## Critical findings

### P0 — Inter-facility transfer can consume shipment-reserved stock
Prior deep audit found `krim_warehouse_dispatch_transfer` locks the source inventory row and checks on-hand quantity, but does not subtract active `reserved` shipment allocations before decrementing stock. A transfer can therefore move stock committed to a shipment, leaving allocation rows reserved against insufficient physical balance. This can break a later shipment pick and corrupt available-to-promise semantics.

**Required fix:** one atomic reservation-aware availability calculation under the same inventory row lock. Enforce `on_hand - active_reserved >= transfer_quantity` for every stock-decreasing path, with explicit treatment of partially picked, released, cancelled and expired allocations. Reconcile historical states before enabling the path.

### P0 — Generic/linked picking can bypass shipment allocation consumption
The generic `krim_warehouse_create_task` path validates total released inventory, not unallocated quantity. The linked-pick creator checks shipment leg and SKU/lot/unit balance but does not require a matching reserved allocation. Task completion posts a negative stock movement without consuming the exact allocation. This is a second path around the dedicated allocation-pick control.

**Required fix:** every shipment-linked pick must atomically consume exact allocation rows matching organization, facility, shipment, leg, SKU, lot, unit and quantity. Generic picking must reject stock committed to active reservations. Disable or hard-block unsafe legacy paths until the invariant is enforced server-side.

### P1 — Return receipt manifest validation is not fully defensive
Prior audit found JSON line quantities are cast directly to numeric without first validating JSON type/lexical form. Malformed values may roll back with inconsistent database errors. Validate missing, non-numeric, non-finite, negative, duplicate and out-of-range item indexes with stable errors before mutation.

### P1 — Return quality decision lacks explicit all-lines completeness invariant
The return QC function updates hold inventory rows and checks whether any row changed, but does not explicitly lock and prove exact one-to-one mapping for every receipt item to its expected organisation/facility inventory row, with every row still on hold, before finalizing the return-level decision. Require full cardinality/ownership/state validation and all-or-nothing update.

### P1 — Transfer receive replay is not fully actor-bound
Prior audit found replay checks idempotency key and notes but not the original receiver identity. This may return an idempotent result to another authorized destination operator. Define whether replay is actor-specific or facility-role-shared, persist the complete canonical payload and enforce that contract consistently.

### P1 — Safe cancellation and reverse-pick orchestration remain incomplete
Earlier reviews identified no unified safe cancellation path that releases only unpicked reservations while requiring reverse-pick/return workflow for already-picked stock. A task cancellation must not silently restore inventory or free a shipment commitment after physical handling.

### P1 — Migration history/schema reconciliation is a release blocker
Prior deep audit explicitly states repository and Production migration histories materially mismatch. Do not apply or replay warehouse fixes, baseline/squash migration history or alter Production RPCs until a sanitized schema manifest and full migration crosswalk are reconciled. A source migration file is not proof it is deployed.

### P1 — Facility legal/operational evidence and capacity are not proven
The reviewed facility registration captures address, country, timezone and notes, but this gate did not establish a complete jurisdiction-specific facility licence/lease/occupancy, fire/safety, insurance, operating-hours, handling-class, temperature/security or capacity evidence-and-review pack. A registered/approved facility record alone must not imply every commodity, service or capacity is authorized.

### P1 — No operational warehouse network
Historical Production snapshot recorded zero facilities, inventory balances/movements, receipts, allocations, tasks, transfers, transfer QC, returns, return receipts/QC and dispatch-handover tasks. No warehouse capacity or stock availability can be claimed. Counts were not refreshed during this source-only gate.

### P2 — Evidence integrity and retention are not fully certified
Private bucket, owner/path checks and 10 MB MIME allowlist are positive controls. Byte-level MIME validation, malware scanning, immutable object hash/version, retention/deletion, legal hold, signed URL revocation/cache and complete audit export remain unproven.

### P2 — New warehouse modules are not evidence of enabled operations
Appointment/dock, yard, cycle count, cross-dock, container handling, workforce, capacity planning, performance and alerts surfaces exist. Their presence does not prove live facility devices, dock schedules, workforce records, capacity or alerts. Confirm each module's backend binding and facility-specific operational approval before offering it commercially.

## Readiness matrix

| Component | Result | Evidence boundary |
|---|---|---|
| Facility registration eligibility | PARTIAL PASS | Source inspected; no facility created |
| Facility independent approval | PARTIAL PASS | Prior source audit; no review executed |
| Warehouse operator/facility authorization | PARTIAL PASS | Helper/RPC source; RLS runtime not tested |
| Direct inventory-write restriction | PARTIAL PASS | Prior policy inspection; not freshly queried |
| Inbound receipt and private evidence | PARTIAL PASS | Source/prior audit; no upload or receipt |
| Independent inventory QC | PARTIAL PASS / BLOCKED | Stronger later gates; reviewer/call-path runtime not tested |
| Shipment reservation and dedicated pick | PARTIAL PASS | Prior source audit; concurrency NOT TESTED |
| Transfer reservation accounting | FAIL / BLOCKED | P0 stock-overcommit path |
| Generic/linked picking reservation integrity | FAIL / BLOCKED | P0 allocation bypass |
| Return physical receipt and manifest validation | PARTIAL PASS / BLOCKED | Defensive JSON and exact completeness gaps |
| Return QC all-lines atomicity | PARTIAL PASS / BLOCKED | Exact item-to-inventory invariant incomplete |
| Cancellation/reverse-pick | NOT TESTED / BLOCKED | Safe orchestration not established |
| Dispatch handover gate | PARTIAL PASS | Pick/handover source gates; no execution |
| Facility capacity/legal eligibility | NOT TESTED / BLOCKED | Evidence pack and capacity not proven |
| Live warehouse network | FAIL / BLOCKED | Historical snapshot all operational counts zero |
| Full inbound-to-dispatch/returns E2E | NOT TESTED / BLOCKED | No staged journey executed |

## Required remediation and test order

1. Stop or hard-block transfer dispatch and generic/linked picking paths that do not preserve reserved-stock invariants.
2. Reconcile Production schema/migration history before any proposed SQL fix; prepare a sanitized schema manifest and exact migration crosswalk.
3. Implement one shared reservation-aware available-to-promise invariant across transfer, generic pick, linked pick, adjustment, write-off, cancellation and every other stock-decreasing operation.
4. Bind every shipment pick to exact active shipment/leg allocation(s), and atomically update stock movements, allocation state and audit events.
5. Harden return JSON parsing and validate exact manifest indexes/quantities/units before any physical receipt mutation.
6. Lock and validate all return receipt items and corresponding inventory rows; require exact cardinality, facility/org ownership and hold state before all-or-nothing QC decision.
7. Bind transfer receive replay to the defined actor/payload contract; implement safe cancellation and reverse-pick handling.
8. Define jurisdiction-specific facility evidence and service/commodity/capacity approval before facility activation.
9. In isolated Staging only, test two warehouses/two organisations, wrong facility, wrong operator, reserved stock transfer at below/equal/above unallocated balance, concurrent reserve-vs-transfer, generic and linked pick bypass, duplicate/replayed idempotency keys, partial pick, cancellation after pick, malformed return JSON, missing/duplicate manifest indexes, mixed QC states, reviewer collusion and dispatch before handover.
10. Execute one fully evidenced synthetic lifecycle: facility application → independent approval → inbound task/receipt → private inspection evidence → independent QC release → allocation → exact allocation pick → handover → dispatch authorization; separately test transfer and return lifecycles. No real goods or Production stock.

## Safety boundary

No Production or Staging SQL/RPC, facility registration/review, stock receipt, inventory movement, reservation, picking, transfer, return, QC, handover, dispatch, evidence upload, provider operation or deployment was executed. No test facility or inventory was created. All runtime, concurrency, RLS cross-tenant and migration-reconciliation checks remain NOT TESTED.

## Evidence references

- `docs/audits/KRIM-WAREHOUSE-FACILITY-AND-CONTROL-CENTRE-AUDIT-2026-11-16.md`
- `docs/audits/KRIM-WAREHOUSE-INVENTORY-QUALITY-PICKING-TRANSFER-RETURNS-AND-DISPATCH-HANDOVER-DEEP-AUDIT-2026-11-16.md`
- `docs/audits/KRIM-WAREHOUSE-FULFILMENT-AVAILABLE-TO-PROMISE-AND-REVERSE-LOGISTICS-INTEGRATION-AUDIT-2026-11-16.md`
- `docs/audits/KRIM-WAREHOUSE-INBOUND-EVIDENCE-INVENTORY-LEDGER-REVIEW-2026-11-16.md`
- `docs/audits/KRIM-WAREHOUSE-ALLOCATION-AND-QUALITY-REVIEW-UI-AUDIT-2026-11-16.md`
- `docs/audits/KRIM-CAPACITY-RESERVATION-AND-WAREHOUSE-INVENTORY-CONTROL-REVIEW-2026-11-16.md`
- Warehouse migration files listed in the scope above.

**Gate C3.23: FAIL / BLOCKED. NO-GO for live warehouse stock handling, transfers, returns, picking or dispatch handover.**
