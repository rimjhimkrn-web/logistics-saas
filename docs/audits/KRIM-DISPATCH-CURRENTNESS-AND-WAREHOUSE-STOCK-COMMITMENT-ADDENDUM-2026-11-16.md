# KRIM Dispatch Authorization and Warehouse Stock Commitment Addendum — 2026-11-16

## Scope
Read-only inspection of the live dispatch authorization function, its currentness predicate, and warehouse stock reservation, pick, transfer, and movement functions. No production RPCs or mutations were performed.

## Latest CI
For commit `f992fdfffcb8e06d4d9c47f5773aac650111df1c`, all three checks completed successfully:
- KRIM static link audit: success (`43800369015`)
- KRIM production smoke checks: success (`43800368978`)
- GitHub Pages deployment: success (`43800368579`)

These checks are repository/website checks and do not execute live dispatch or warehouse transaction scenarios.

## Dispatch authorization controls observed
- Authorization requires authenticated user, accepted/active exact-leg partner assignment, and `shipment.dispatch`.
- Leg and assignment are locked; leg must be assigned and shipment non-terminal.
- Requires confirmed capacity binding and confirmed partner-owned reservation for the exact shipment, leg and partner.
- Road dispatch requires accepted driver assignment, active driver membership, verified driver, current licence, accepted front/back evidence, active verified vehicle and current mandatory vehicle documents.
- Subsequent legs require accepted custody transfer from the immediately preceding leg.
- Dispatch authorization writes a distinct authorization record and event that explicitly states physical departure must be recorded separately.
- Existing authorization retry is accepted only when the currentness predicate still validates the authorization.

## High-priority dispatch currentness concern
The private `krim_leg_dispatch_authorization_is_current` predicate joins an active shipment leg plan with `p.total_legs > 1` and requires a matching plan item. This predicate is called when an existing authorization is replayed and when downstream currentness is checked.

**Potential defect:** a legitimate single-leg shipment has no qualifying multi-leg plan under this predicate, so its previously created authorization may be treated as stale on retry or by downstream checks, even if its assignment and capacity reservation remain valid. This is a source-level compatibility concern; no production shipment was altered or used to reproduce it.

**Required resolution:** define one canonical currentness predicate that supports both:
1. single-leg shipments with a valid assigned leg and no multi-leg handover plan; and
2. multi-leg shipments with an active exact plan, plan-item linkage, assignment binding and required custody chain.

Add staging tests for single-leg road, single-leg non-road, two-leg and three-leg routes, retries, revoked authorization, changed plan, reassignment, released capacity and custody-transfer revocation. Do not patch production before migration reconciliation.

## Warehouse stock commitment — refined finding
- Shipment allocation reservation locks the inventory row and calculates unallocated stock as on-hand quantity minus all `reserved` allocations for that exact inventory row.
- Shipment picking locks the allocation and inventory row, checks released quality and sufficient on-hand quantity, then posts a negative pick movement.
- Warehouse transfer dispatch locks the source inventory row and checks on-hand quantity, but does not subtract outstanding reserved shipment allocations before reducing the balance.
- The generic movement function restricts callers to receipt/pick movement types and prevents negative on-hand balances, but does not independently enforce unallocated-stock accounting for the transfer path.

**Confirmed source-level gap:** transfer can consume quantity already reserved for shipment allocations. The row lock serializes operations but does not make the transfer's quantity check reservation-aware. This can leave a previously reserved allocation unpickable.

**Safe design direction:** while holding the same inventory row lock, calculate:
`available_to_promise = on_hand_quantity - SUM(quantity WHERE allocation.status = 'reserved')`
and reject transfer/other non-allocation consumption above that amount. Picking should consume the matching allocation and stock in one transaction; allocation release should free only its own reserved quantity. Every other stock-decreasing workflow must use the same shared invariant. Validate exact inventory ID, lot, unit, facility and quality status. Add concurrent staging tests for allocation-vs-transfer, allocation-vs-pick, two transfers, release-vs-transfer, retries and duplicate keys.

## Other warehouse controls observed
- Direct movement API accepts only receipt/pick; transfer, return, adjustment and direct dispatch movement types are explicitly disabled.
- Movement function requires active eligible warehouse organisation, active member with `partner.manage`, approved active facility, finite nonzero quantity, idempotency and row/advisory locks.
- Transfer dispatch requires approved operators at both facilities, released source stock, sufficient on-hand quantity, active approved facilities and idempotency.
- Receipt and subsequent quality review remain separate, with received stock held pending independent evidence-based review.

## Next actions
1. Reconcile the migration crosswalk before any production DDL/function change.
2. In staging, implement/test the shared available-to-promise invariant across all stock-decreasing operations.
3. Correct/test dispatch currentness for single-leg and multi-leg shipments.
4. Verify the dispatch handover predicate, capacity revocation lifecycle, and all downstream dispatch gates.
5. Keep real freight dispatch gated until verified partners, evidence and operational tests exist.
