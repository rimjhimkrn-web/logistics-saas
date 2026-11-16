# KRIM Warehouse Inbound, Put-away, Evidence and Inventory Ledger Review — 2026-11-16

## Scope
Reviewed:
- `public/warehouse/inbound-receiving.html`
- `public/warehouse/putaway-storage.html`
- `public/warehouse/damage-exceptions.html`
- `public/warehouse/warehouse-evidence.html`
- `public/warehouse/inventory-ledger.html`

No production task, inventory, evidence or movement RPC was invoked. No files were uploaded.

## Inbound receiving
- Authenticated warehouse access, active organisation memberships and active approved facilities are required.
- Shipment-linked inbound tasks use `krim_warehouse_list_assigned_shipment_legs` and `krim_warehouse_create_linked_inbound_task`.
- Task transitions use `krim_warehouse_transition_task`.
- The UI communicates that no inventory movement occurs until the controlled task is completed.
- Actual stock receipt correctness remains dependent on backend task-transition and inventory movement invariants; do not treat task creation as a stock receipt.

## Put-away and damage exceptions
- Both use authenticated warehouse organisation/facility context, task listing RPC and server-side task creation/transition RPCs.
- These are task workflows, not independent direct inventory mutation interfaces.
- Completion and cancellation effects are backend-defined. Cancellation safety still needs a unified lifecycle implementation, especially for tasks linked to already reserved or picked inventory.

## Warehouse evidence
- Uses a private storage bucket, a 10 MB file-size cap and JPEG/PNG/PDF MIME allowlist.
- Evidence metadata is registered through `krim_warehouse_register_evidence` after upload.
- If metadata registration fails, the page attempts to remove the uploaded object and reports if cleanup also fails.
- Evidence listing and signed preview use dedicated evidence RPC and 60-second signed URLs.
- The page does not claim evidence is independently verified merely because it is uploaded.

## Inventory ledger
- Read-only browser view of inventory, facilities and movement history.
- Uses DOM text nodes for table cell values rather than interpolating database values into HTML.
- No direct inventory mutation is exposed; controlled warehouse task/RPC workflows are required.
- Reads are subject to the database's authenticated row-level access policies.

## Facility and control-centre corrections in this batch
- `db04aa10e80aedcc8f38bc4a9017b350d906cf5f`: escaped organisation and facility data before rendering in facility management, preventing stored HTML injection through partner-controlled fields.
- `23ba76a36cd666dd719ba763173baf03557f13fc`: corrected duplicate/misaligned module numbering in the warehouse control centre.
- `7e3a247f8af2db0907290a0370243fb19b1561ac`: this audit report.

## Verification
Static link audit and production smoke checks were green for the facility rendering and control-centre numbering commits at the time of review. Pages deployment was cancelled by a newer commit, so verify the latest deployment run separately. The latest report commit has its own checks in progress at time of writing.

## Remaining critical warehouse work
1. Server-side null-safe return manifest validation and exact item-index coverage.
2. Prevent legacy picking-task completion from consuming shipment-reserved stock.
3. Safe cancellation orchestration: release unpicked reservations only; use reverse-pick/return flow for picked stock.
4. Staging tests for multi-organisation isolation, duplicate inventory matches, concurrency and direct RPC adversarial inputs.
