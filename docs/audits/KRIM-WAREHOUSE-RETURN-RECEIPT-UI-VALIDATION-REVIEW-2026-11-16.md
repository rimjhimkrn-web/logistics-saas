# KRIM Warehouse Reverse Logistics Return-Receipt UI Safeguard Review — 2026-11-16

## Scope
Reviewed `app/warehouse/reverse-logistics.html` and the legacy `public/warehouse/returns-rma.html` route. No production business RPC was invoked and no return, receipt, inventory or transfer was created or modified.

## Findings
- The legacy returns-RMA route redirects to the authenticated reverse-logistics workspace; it is not a separate workflow.
- The canonical page uses authenticated organization membership, active approved warehouse facilities, partner-specific facility filtering, idempotency keys and dedicated RPCs for transfer dispatch/receipt, return authorization/decline, physical return receipt and independent return quality review.
- Physical return receipt is submitted through `krim_receive_authorized_shipment_return`.
- A previously recorded production function review found a high-severity SQL NULL-validation defect in that RPC: NULL/non-array manifest input can bypass a PL/pgSQL IF guard written with nullable comparisons, potentially allowing a receipt header with zero items. The required server-side correction remains blocked until production migration history is fully reconciled.
- The browser handler previously iterated `r.item_manifest || []` without requiring a non-empty valid manifest. An empty or malformed manifest could therefore reach the vulnerable RPC from the UI.

## Correction
Commit `1d1658bb044baf6e48c9ee73c69506bafbffdece` updates the browser handler to:
- Require an actual array containing 1–100 manifest lines.
- Require every line to have a non-empty description and unit and a finite positive quantity.
- Require a non-empty received SKU of at most 100 characters.
- Build one received line per manifest line and verify count and unique manifest indexes before submission.
- Abort locally before calling the RPC when validation fails.

This is a defense-in-depth UI safeguard only. It does **not** fix the production database function vulnerability and does not make the receipt workflow safe against direct RPC calls or hostile clients.

## Verification status
- Source update committed. Static link audit, production smoke checks and Pages deployment are triggered by the commit; final results must be checked.
- No real receipt/return operation was performed.
- Full fix still requires a null-safe server-side validation, exact manifest-index coverage, processed-count equality, and staging tests for SQL NULL, JSON null, empty array, object, duplicate/missing indexes and valid manifests. Production DDL remains blocked pending migration reconciliation.

## Other warehouse notes
- The goods-receipt page creates shipment-linked tasks and invokes task transitions. Earlier production review found the legacy picking task completion path can consume stock without subtracting active shipment reservations. Do not use the legacy pick-task path to fulfil reserved stock until that invariant is fixed.
- Stock-movement and returns-RMA legacy URLs are redirects; the canonical reverse-logistics workspace is the source page for transfers and returns.
