# KRIM Page 58 — Inventory Management Review
Date: 2026-11-16

## Canonical route
`public/warehouse/inventory-ledger.html` is the read-only inventory management/ledger view. The older `public/warehouse/inventory.html` is a compatibility redirect to the authenticated warehouse workspace.

## Data and access reviewed
- Requires an authenticated Supabase session.
- Reads warehouse dashboard aggregates through `krim_warehouse_dashboard`.
- Reads inventory rows, facilities and inventory movement history through Supabase queries subject to database RLS.
- Browser-side stock mutation is explicitly disabled; changes must use controlled warehouse task and inventory RPC workflows.
- Inventory and movement queries are each capped at the latest 200 rows; the screen is not a complete historical export.
- Facility and inventory joins are performed locally for display; a missing facility or inventory row does not authorize access to additional data.

## Change made
Commit: `e47ea9bbfe419d7cb35f2416431f1d912a6d55b4`

- Added safe number formatting so malformed quantities/deltas do not render as NaN or break the page.
- Replaced strict ISO conversion with safe local date formatting so malformed movement timestamps cannot abort the entire history render.
- Validated all three query result shapes before rendering.
- Clarified the 200-row limits and changed the badge to “visible stock records” rather than implying a full inventory count.

## Safety boundary
No stock adjustment, reservation, allocation, transfer, receipt, put-away, picking, dispatch or inventory mutation was invoked. No production data was changed.

## Known limitations
- The dashboard summary and the latest-200 inventory rows are different measures; visible row counts must not be interpreted as total SKUs or total stock.
- A zero/empty view can reflect RLS visibility or no eligible warehouse records, not necessarily a globally empty warehouse network.
- The page does not itself prove stock availability for a shipment. Reservation and allocation must use the controlled server-side workflows.
- Prior reviews identified possible interaction between legacy picking tasks and shipment-reserved stock, and inter-facility transfer/cancellation safeguards require complete server-side reconciliation. No production SQL was changed.
- Full facility-scoped user testing and inventory lifecycle E2E remain outstanding.

## Page 58 status
**Read-only inventory display hardened; bounded data scope made explicit. Automated checks pending.** Not production certification.
