# KRIM Physical Fulfilment Integration and Warehouse Control Deep Audit
**Date:** 16 November 2026  
**Scope:** Read-only review of live warehouse/physical-fulfilment record counts and current PostgreSQL RPC definitions for inbound receiving, inventory movements, allocation/picking, inter-facility transfers, custody handover and shipment returns. No RPCs were invoked. No inventory, facility, task, receipt, transfer, return, shipment or partner records were created or changed.

## Executive decision
**NO-GO for real warehouse or physical fulfilment operations.** The production database contains zero approved facilities, inventory balances, receipts, movements, shipment allocations, warehouse tasks, transfers, returns or custody-transfer records. The application has substantial control logic, but there is no live facility or stock base to execute a real fulfilment journey. Two previously identified stock-integrity defects remain visible in current function definitions and require controlled remediation after migration reconciliation.

## 1. Production record baseline
| Physical fulfilment object | Live rows |
|---|---:|
| Warehouse facilities | 0 |
| Inventory balances | 0 |
| Warehouse receipts | 0 |
| Inventory movements | 0 |
| Shipment stock allocations | 0 |
| Warehouse tasks | 0 |
| Warehouse transfers | 0 |
| Shipment returns | 0 |
| Return receipts | 0 |
| Return quality reviews | 0 |
| Multi-partner custody transfers | 0 |
| Custody transfer events | 0 |

This means there is no production evidence of a working warehouse, stock-on-hand, receipt, pick/pack, transfer, reverse-logistics or custody-handover operation. Empty tables are not evidence that the workflow passed an end-to-end test.

## 2. Controls present in the inspected implementation
- Facility review is AAL2-gated, platform-admin authorized, independent from the facility submitter and requires an eligible registered-business organization with verified partner/compliance status and warehouse eligibility.
- Inventory movement RPC requires an active organization member, partner.manage permission, eligible warehouse organization and active approved facility; supports idempotency and blocks negative stock, unsupported movement types and merging different quality states.
- Goods receipt quality review requires a completed source task, independent reviewer, private uploader-owned inspection report and SKU/lot match; released inventory is guarded by receipt-level independent evidence review.
- Shipment allocation locks shipment, leg and inventory; requires active exact-leg assignment, approved facility and released stock; calculates outstanding reservations before allocating.
- Shipment allocation picking requires a reserved allocation, locks inventory and allocation, checks released stock and sufficient balance, then records a linked inventory movement.
- Shipment-linked dispatch handover requires completed picking for the same shipment and exact leg; additional previously inspected trigger guards require picked allocations and private dispatch proof before dispatch authorization.
- Transfer receipt requires a dispatched transfer, authorized destination operator different from the dispatcher, and prevents merging stock into a destination SKU/lot with a different quality state.
- Return receipt requires an authorized return, partner warehouse permission, approved facility and exact manifest reconciliation; received return stock is placed on quality hold for independent inspection.
- Multi-partner custody transfer requires adjacent legs in the same active plan, completed releasing leg, accepted receiving partner assignment, confirmed receiving-leg capacity, exact cargo manifest and uploader-owned private evidence.

These are code-level controls, not verified operating capability. They still require staging negative/positive tests and a real facility/partner onboarding process.

## 3. P1 stock-integrity findings
### P1-A — Transfer dispatch does not account for outstanding reservations
Current `krim_warehouse_dispatch_transfer` locks the source inventory row and checks that total on-hand quantity is at least the requested transfer quantity. It does not subtract outstanding `reserved` shipment allocations before dispatch. A transfer can therefore consume units already committed to shipments and leave available stock below reservations. The source quantity check should use the same locked, reservation-aware available-balance calculation as shipment allocation, and it should reject transfer dispatch if post-transfer on-hand would fall below outstanding reserved quantity.

### P1-B — Generic warehouse task picking can bypass reservation-aware stock availability
`krim_warehouse_transition_task` completes generic `picking_packing` tasks by calling `krim_warehouse_record_movement` with a negative quantity. The shared movement function checks that resulting total inventory does not become negative and that the stock is quality-released, but it does not visibly subtract outstanding reserved shipment allocations before permitting this generic pick. Shipment-linked legacy task completion is blocked by a separate guard and the dedicated shipment allocation pick workflow is reservation-aware; nevertheless, the generic task path remains an alternate negative-stock movement route that may consume committed units. It should be restricted to non-shipment inventory with a reservation-aware available-balance guard, or routed through a dedicated allocation-aware pick routine.

### P1-C — Return receipt NULL validation remains incomplete
`krim_receive_authorized_shipment_return` validates `jsonb_typeof(p_received_items)<>'array'` and `jsonb_array_length(...)` but does not explicitly reject SQL NULL before these expressions. SQL three-valued logic can allow a NULL argument to evade the compound guard and fail later in the function. Add an explicit `p_received_items IS NULL` rejection before any JSON inspection. Staging tests must distinguish SQL NULL, JSON null, empty array, wrong JSON type and malformed manifest values.

## 4. Additional fulfilment verification requirements
- Confirm facility ownership, legal entity, address, operating hours, facility permissions and service scope before activation.
- Validate inbound receipts against shipment, leg, partner handover, manifest quantities, condition, lot/serial identifiers and private evidence.
- Ensure all inventory changes are append-only movement events with immutable references and idempotency; prevent direct client mutation.
- Preserve lot, unit, quality state and storage location; prohibit silent unit conversion and unsafe lot merging.
- Reconcile reservations on every negative stock movement, transfer, cancellation, pick, return and adjustment.
- Make shipment allocation release and picked-stock reversal explicit workflows with full audit history.
- Require maker-checker QC, evidence owner/path validation and reinspection workflow for rejected/held goods.
- Confirm dispatch handover, exact shipment/leg, picked quantities, seal/cargo manifest, carrier acceptance and proof before dispatch authorization.
- Confirm custody acceptance by the receiving partner and exact cargo reconciliation at every multi-partner handoff.
- Return goods must remain segregated on quality hold until independent inspection and disposition.
- Build cycle-count, discrepancy, damaged/lost stock, recall, quarantine and stock reconciliation controls before a live warehouse pilot.
- Validate storage bucket policies and private evidence signed-link authorization across organizations and revoked memberships.

## 5. Recommended implementation order
1. Resolve the two reservation-bypass paths and SQL NULL validation defect in reviewed source/migrations.
2. Do not deploy production fixes until the repository/production migration-history crosswalk and sanitized schema manifest are reconciled.
3. Create a staging-only synthetic warehouse organization, approved facility, test inventory lots and test users with distinct submitter/operator/reviewer identities.
4. Test reservation races, concurrent transfer vs reservation, generic pick vs reservation, retry/idempotency conflicts, SQL NULL/JSON null, negative stock, quality holds, wrong tenant, expired/revoked membership and evidence ownership.
5. Test the full inbound receipt → inspection → release → put-away → shipment allocation → pick/pack → dispatch handover → custody acceptance → delivery/POD path.
6. Test transfer receipt, quality review, return authorization, physical return receipt, inspection and disposition separately.
7. Only after successful staging evidence, onboard a real partner facility and request explicit approval for a narrowly scoped live pilot.

## 6. Change control and release gate
Read-only audit only. No SQL migrations, production DDL, RPC invocation, data mutation, storage upload, shipment or warehouse activity occurred. The market/corridor activation audit found no approved operating market or corridor; partner audit found no verified service coverage or capacity. Therefore even a fully functioning warehouse subsystem would not by itself authorize commercial fulfilment.

**Release status: NO-GO for live warehouse, inventory, transfer, dispatch-handover or returns operations.** Production contains no operational facility/stock evidence, and reservation-aware movement gaps require remediation and staging proof.
