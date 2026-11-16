# KRIM Warehouse Allocation and Independent Quality Review UI Audit — 2026-11-16

## Scope
Reviewed:
- `app/warehouse/allocation.html`
- `public/warehouse/quality-control.html`
- `public/warehouse/inventory.html` (legacy redirect)

No production business RPCs were invoked and no inventory, allocation or quality decision was changed.

## Shipment Inventory Allocation
**Status: connected authenticated workflow.**
- Reads assigned shipment legs and released inventory visible under database policies.
- Uses dedicated reserve, pick and release RPCs.
- Reservation form validates positive quantity against the displayed balance; backend reservation logic remains authoritative and accounts for active allocations.
- Pick action requires explicit confirmation; release requires a reason.
- Earlier live production review confirmed the canonical allocation reserve/pick/release RPCs lock relevant rows and enforce reservation lifecycle. This is the preferred shipment allocation path.
- The separate legacy goods-receipt/picking task completion path remains unsafe for reserved stock until its reservation-consumption invariant is corrected.

## Independent Quality Review
**Status: server-authorized workflow; ambiguous client-side inventory matching corrected.**
- Requires authenticated session.
- Loads completed goods-receipt/damage-exception tasks, inventory and inspection-report evidence.
- Hides review when the task creator/completer is the current user or when the required inspection report is missing.
- The browser previously selected the first inventory row matching organisation, facility, SKU and lot. If multiple inventory rows shared those attributes, it could attach a quality decision to an arbitrary inventory ID.
- **Correction:** the page now counts matching inventory rows. If more than one match exists, it displays an ambiguity warning and offers no quality-review action. Exactly one match is required for the review form to appear.
- The backend RPC remains responsible for independent-review authorization and inventory state transitions.

## Legacy Inventory route
`public/warehouse/inventory.html` is a noindex redirect to the authenticated warehouse workspace, not an independent inventory implementation.

## Changes
- `839158ade6e3582cd5300ed0ecd14f6806c0673e` — prevent quality decisions when task-to-inventory matching is ambiguous.
- `1d1658bb044baf6e48c9ee73c69506bafbffdece` — validate return manifest before physical receipt RPC submission.

## Verification
- Changes committed; GitHub production smoke, static-link audit and Pages deployment are triggered. Check final results before treating the batch as green.
- No production inventory/quality operations were performed.
- Source review does not replace authenticated browser tests, RLS cross-organization tests, concurrency tests or direct RPC adversarial tests.

## Remaining warehouse blockers
1. Fix the server-side NULL-safe manifest validation and exact item coverage in the return receipt RPC after migration reconciliation.
2. Prevent the legacy picking task path from consuming stock reserved by shipment allocations; use canonical allocation pick workflow.
3. Implement safe cancellation orchestration that releases only unpicked allocations and requires reverse-pick/return handling for already-picked stock.
4. Validate all role and facility boundaries in staging, including multi-organization users and duplicate SKU/lot records.
