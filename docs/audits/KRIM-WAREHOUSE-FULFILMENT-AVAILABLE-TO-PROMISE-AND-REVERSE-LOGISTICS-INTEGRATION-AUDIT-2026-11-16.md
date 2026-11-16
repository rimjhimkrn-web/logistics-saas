# KRIM Warehouse Fulfilment, Available-to-Promise, Stock Movement and Reverse Logistics Integration Audit
**Date:** 16 November 2026  
**Scope:** Read-only production data/catalog and authoritative RPC review across warehouse facilities, inbound receipts, stock ledger, shipment reservations, picking, inter-facility transfer, return authorization/receipt, quality review and shipment handover; source review of warehouse workspace entry/allocation/returns. No warehouse RPC was invoked. No warehouse or shipment record was changed.

## Executive decision
**NO-GO for live warehouse fulfilment or stock custody certification.** KRIM has a substantial warehouse control plane: approved facility gates, verified business eligibility, private evidence, atomic movement RPCs, shipment-leg allocation, independent quality review, inter-facility transfer receipt, return inspection hold and separate leg-to-leg custody. But production has zero warehouse facilities, stock, receipts, movements, allocations, tasks, transfers, returns, evidence or custody records. Real-world warehouse operation is therefore unproven.

Two source-level integrity defects remain:
- **P1 available-to-promise breach:** transfer dispatch checks on-hand stock but does not subtract active shipment reservations. A transfer can consume stock already committed to a shipment.
- **P1 null return-receipt payload:** the return receipt RPC tests jsonb_typeof(p_received_items) <> 'array' without explicitly rejecting SQL NULL. PostgreSQL three-valued logic means a NULL predicate does not make an IF condition true. A NULL array can evade the combined validation; if the authorized manifest is empty/NULL-compatible, a receipt header can be created with no reconciled item lines.

A further idempotency consistency gap exists in the generic movement RPC: replay comparison omits some business-relevant inputs, including quality status, item description and storage location. A changed request may be accepted as a replay rather than rejected as a conflicting payload. It does not apply a second movement, but weakens conflict detection and audit clarity.

## 1. Live production evidence
All following operational tables returned zero rows at audit time:

| Record | Rows |
|---|---:|
| Facilities | 0 |
| Inventory balances | 0 |
| Goods receipts | 0 |
| Inventory movements | 0 |
| Shipment allocations | 0 |
| Warehouse tasks / task events | 0 / 0 |
| Warehouse evidence | 0 |
| Inter-facility transfers | 0 |
| Transfer quality reviews | 0 |
| Shipment returns | 0 |
| Return receipts / receipt items | 0 / 0 |
| Return quality reviews | 0 |
| Leg-to-leg custody transfers / events | 0 / 0 |

There is no production proof of inbound receipt, storage, put-away, cycle count, reservation, picking, transfer, return, inspection, dispatch handover or carrier custody. Empty tables do not establish that workflows are broken, but they do mean they have not been demonstrated with real operations.

## 2. Strong controls found in the current backend
### Facility and operator eligibility
- Facility registration and independent administrator review are separated.
- Facility use requires active status and approved review status.
- Warehouse operators are checked against organization membership, permissions, warehouse eligibility and facility scope.
- The allocation workspace filters organizations to registered businesses with current verification/lifecycle/compliance and an active verified warehouse capability or warehouse organization type.
- Reviewed operational tables expose scoped read policies; no direct authenticated write policies appeared. Writes are routed through RPCs.

### Stock receipt and movement
- Generic inventory movement is restricted to receipt and pick movement types; direct transfer, return, adjustment and dispatch movement types are rejected.
- Movement keys are locked and idempotent; stock balance rows are locked before changing quantities.
- Negative stock and non-finite/zero quantity changes are rejected.
- SKU/lot balances cannot be merged across different units or quality states.
- Picking is permitted only from released stock.
- Movement records and audit events are written transactionally with inventory changes.

### Shipment reservation and picking
- Reservation requires an accepted/active partner assignment; exact-leg reservation validates the shipment leg and its partner.
- The RPC locks the shipment, exact leg (when provided), then the inventory row.
- Only released stock at an active, approved facility can be reserved.
- Reservation uses available quantity = on-hand minus the sum of active reserved allocations.
- Allocation idempotency checks organization, facility, inventory, shipment, exact leg and quantity.
- Pick locks allocation and inventory, requires reserved status and released stock, posts a negative stock movement and changes the allocation to picked in the same transaction.
- A second pick with a different key is rejected; matching replay requires the prior movement reference.

### Inter-facility transfer and quality
- Transfer requires authorized operators at both facilities, active/approved facilities, released source inventory, finite positive quantity, matching unit and idempotency payload.
- Transfer dispatch and receipt are distinct. Destination receipt must be performed by a different operator from the dispatcher.
- Destination stock is created/merged only in quality hold; a different existing quality state blocks merging.
- An independent reviewer, distinct from dispatcher and receiver, must provide private reviewer-owned image/PDF evidence and a reason before a final quality decision.
- Quality review is single-decision/idempotent and updates destination stock with an audit event.

### Customer returns
- Return request, partner authorization, physical receipt and independent quality review are separate.
- Receipt validates each received line against the authorized manifest by index, quantity, unit and description.
- Returned goods enter inventory with quality status hold.
- The return moves to inspection_hold; a separate reviewer decides released/hold/rejected with private evidence.
- Returned goods are not immediately made available for a new shipment.

### Shipment handover and custody
- Warehouse handover and shipment-leg custody paths require picked allocations/private dispatch proof and separate receiving-party acceptance for later-leg custody.
- These controls connect warehouse handling to the multimodal shipment chain, but zero live records mean the full chain is not proven.

## 3. Finding WH-01 — P1: inter-facility transfer can consume shipment-reserved stock
The reservation RPC locks the inventory row and checks:
on_hand_quantity - SUM(quantity WHERE allocation.status = 'reserved') >= requested_quantity.

The transfer-dispatch RPC also locks the source inventory row, but checks only:
on_hand_quantity >= transfer_quantity.

It then decrements on-hand stock without subtracting active reservations. The two paths serialize on the same inventory row but use different availability equations. After a shipment reservation commits, a later transfer can remove the reserved quantity while still passing its total-on-hand check.

This is confirmed from current production function definitions and matches the existing remediation specification:
docs/architecture/KRIM-WAREHOUSE-AVAILABLE-TO-PROMISE-TRANSFER-INVARIANT-REMEDIATION-SPEC-2026-11-16.md.

**Required invariant:** for every exact inventory balance, facility, lot and unit, on-hand quantity must remain greater than or equal to active reserved quantity after every committed stock-decreasing operation. Transfer dispatch must subtract active reservations under the same inventory-row lock and reject if available-to-promise is insufficient. Review every other decrease path for the same invariant. Do not patch production until migration reconciliation is complete.

## 4. Finding WH-02 — P1: return receipt payload NULL is not rejected explicitly
The current return receipt RPC checks return/facility/idempotency presence, jsonb_typeof(p_received_items) <> 'array', and array length bounds. It does not first assert p_received_items IS NOT NULL. In PostgreSQL, comparisons involving NULL yield NULL; an IF condition that evaluates to NULL is not true. Thus a SQL NULL array can evade the intended combined predicate. If the authorized return manifest is also empty/NULL-compatible, the function can insert a receipt header and advance the return to inspection hold without any receipt items.

The UI rejects a missing/empty manifest, but the database RPC is authoritative and must independently reject it. Require explicit non-null JSON array validation and non-null/non-empty manifest validation before inserting the receipt. Assert received-item count exactly equals the validated manifest count. Add direct-RPC staging tests with SQL NULL, JSON null, empty array, non-array object, duplicate indexes and missing indexes. No RPC was invoked to test this finding.

## 5. Finding WH-03 — P2: generic movement idempotency does not compare the complete request
The generic movement RPC replay branch compares facility, movement type, quantity delta, SKU, lot, reference, unit and notes. It does not compare every original request field, notably item description, storage location and requested quality status. A retry with the same idempotency key but changed omitted fields can be treated as a replay rather than a conflicting payload.

The function returns the prior movement and does not apply a second stock change, so this is not a duplicate-stock mutation. The idempotency contract should compare a canonical fingerprint of all business-relevant inputs (organization/facility/SKU/lot/unit/quantity/type/quality/reference/storage/description/notes) and reject any mismatch. Apply the same complete-payload principle across receipt, task, return, transfer and allocation APIs.

## 6. Finding WH-04 — P1: physical operation sequence is not evidenced end-to-end
The application exposes modules for facility management, inbound receiving, goods receipt, put-away, ledger, allocation/picking, dispatch/handover, returns/transfers, damage exceptions, quality, evidence, performance and notifications. The workspace navigation is clear, and the allocation page binds reservation to a visible accepted shipment leg and released inventory. But zero operational records exist across all these stages.

Required first-pilot evidence:
1. One verified warehouse partner and independently approved physical facility.
2. Facility address/timezone/capabilities, opening hours, dock/yard and handling restrictions.
3. Real inbound appointment/arrival and shipment/leg association.
4. Receipt with manifest reconciliation, seal/condition evidence and independent quality decision.
5. Put-away into an identifiable bin/location and traceable SKU/lot/unit balance.
6. Cycle count/adjustment with maker-checker evidence and full movement history.
7. Shipment-specific released stock reservation against an accepted exact leg.
8. Pick/pack reconciliation and packaging/handling-unit identity.
9. Dispatch handover with carrier identity, proof and custody acceptance.
10. Exception path for shortage, damage, overage, mismatch, failed pickup and rejected receipt.
11. Return authorization, physical return receipt, inspection hold and independent disposition.
12. Transfer dispatch, independent receipt and third-party quality release.

Until this exists, dashboards and performance indicators must show “no operational data” rather than imply service coverage or performance.

## 7. Finding WH-05 — P1: inventory model does not yet prove physical traceability depth
The live core inventory table is keyed around organization/facility/SKU/lot, quantity, unit, storage location and quality state. No production evidence establishes unique package/pallet/handling-unit identity, serial number, expiry/FEFO, temperature chain, hazardous segregation, customs-bond status, seal lifecycle, bin-level capacity or labor/device scans.

Some richer warehouse pages exist in the repository, but do not infer that a feature is backed by production schema or connected integrations. For general cargo, SKU/lot may be sufficient for a tightly scoped pilot if explicitly defined. Pharma, food, dangerous goods, high-value, bonded or temperature-controlled freight requires additional controls and validated integrations before acceptance.

## 8. Finding WH-06 — P1: no real warehouse partner or facility coverage
Prior partner-network audit found no approved active warehouse capability or service-area coverage. Current warehouse production tables show zero facilities and zero inventory. A warehouse module does not mean KRIM has a warehouse network. Do not advertise storage, fulfilment, cross-docking, cold-chain, bonded warehousing or nationwide coverage until exact partner/facility/service scope is independently verified and approved.

## 9. Required staging-only test matrix
1. Concurrent reservation vs reservation for the same inventory balance.
2. Reservation vs transfer dispatch; reserved stock must remain on hand.
3. Pick vs transfer dispatch; no double consumption or oversubscription.
4. Release one reservation while another remains active.
5. Duplicate allocation/pick/transfer/receipt key with identical payload.
6. Same idempotency key with changed quantity, lot, unit, quality, reference, description or storage location must fail.
7. Direct generic movement attempts for transfer, return, adjustment, dispatch and negative receipt must fail.
8. SQL NULL, JSON null, object, empty array, duplicate/missing/out-of-range return manifest indexes must fail before receipt insert.
9. Return manifest quantity/unit/description mismatch must rollback the entire transaction.
10. Receipt/transfer cannot merge stock with a different unit or quality state.
11. Transfer receiver differs from dispatcher; reviewer differs from both.
12. Evidence from another user/org/path, wrong MIME, oversized or missing file must fail.
13. Facility deactivation/review revocation between task creation and execution must block the action.
14. Cross-tenant organization/facility/inventory/shipment/leg IDs must fail.
15. Failed transaction leaves balance, allocation, transfer/return and audit state unchanged.
16. Handover requires picked exact-leg allocation and current private dispatch proof.
17. Later-leg dispatch requires accepted prior custody transfer.
18. Cycle count, damaged stock, expiry and write-off preserve available-to-promise.
19. All operational pages handle empty data, partial query failures and pagination honestly.
20. Performance tests cover concurrent operators and large inventory/ledger volumes.

None of these staging tests was executed.

## 10. Remediation and release sequence
1. Fix available-to-promise for every stock-decreasing path in isolated staging; add concurrency regression tests.
2. Add explicit fail-closed NULL/manifest validation to return receipt and verify rollback in staging.
3. Add complete canonical request fingerprints to all idempotent warehouse write RPCs.
4. Review lock order consistently across shipment, allocation, inventory and transfer operations to prevent concurrency deadlocks.
5. Confirm independent maker-checker identity and current authorization at the moment of receipt, pick, handover and quality release.
6. Define pilot cargo scope and physical traceability; do not claim temperature/hazardous/bonded capabilities without controls and evidence.
7. Onboard one real warehouse partner and facility; verify documents, service areas, insurance, handling capabilities, capacity and operating hours.
8. Run complete staging and then tightly controlled real pilot with signed procedures, incident escalation and customer/partner agreements.
9. Activate performance analytics, SLA claims and broader marketplace coverage only after warehouse operations are proven.

## 11. Change control
Read-only review only. No warehouse RPC, write, provider integration, storage upload, task, reservation, inventory movement, return, transfer or custody action was executed. No production schema/function/policy was modified.

The repository/production migration-history mismatch and sanitized schema-manifest gate remain unresolved. Do not apply ad-hoc DDL or replay/alter migrations until reconciliation and explicit authorization.

**Release status: NO-GO for live warehouse fulfilment, inventory commitments, transfer and return certification.** Backend controls are promising, but two source-level integrity defects and a completely empty live warehouse network prevent operational signoff.
