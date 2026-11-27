# KRIM Route-Generation Remaining Edge Function and Frontend Inventory Check — 2026-11-27

## Scope
Staging Supabase project `qrpcivhdxobiaofppbkl` Edge Function catalog and source were inspected. GitHub code search was attempted for frontend consumers, but the available code-search endpoint indexes the repository default branch rather than the staging branch; it returned no results for the selected route/driver/dispatch/warehouse/operations queries. Therefore this checkpoint does not claim a complete frontend inventory.

## Edge Function catalog
Five active deployed Staging Edge Functions were listed and source-fetched:
- `global-admin-control` v2 (`verify_jwt=true`)
- `krim-resend-email-worker` v1 (`verify_jwt=false`)
- `owner-testing-authorize` v5 (`verify_jwt=true`)
- `krim-phase00-provision-test-organizations` v2 (`verify_jwt=true`)
- `krim-phase00-test-user-invites` v3 (`verify_jwt=true`)

Text scan of the fetched source found:
- No direct `shipment_leg`, `leg_sequence`, `leg_plan_item_id`, or `route_plan` references in any of the five.
- `global-admin-control` contains limited shipment-level references (`krim_shipments`, `shipment_id`), but no operational leg/generation linkage.
- Other four functions had no direct shipment/leg references in the scan.

This is bounded to the five functions in the current deployed Staging catalog and direct textual identifiers. Indirect RPC behavior, dynamic queries, external services and un-deployed source are not ruled out.

## Frontend inventory limitation
The available GitHub search endpoint indexes the default branch, not the specified staging branch. The queries for shipment leg/route plan, driver trip event, partner assignment dispatch, warehouse handover, operations control tower and public tracking returned no results. These empty results are not evidence that those call sites do not exist. A staging-branch tree/path enumeration or direct fetch of a known complete file list is still required.

## Next required action
Obtain a recursive tree for the exact branch `staging/phase00-env-isolation`, filter all HTML/JS/TS/SQL paths, then scan/fetch route, driver, partner, warehouse, operations, tracking, reporting and notification files. Do not start schema migration until this frontend inventory and database consumer matrix are closed.

## Status
No code or database changes. No migration. Staging-only review. Phase 00 remains OPEN — NOT APPROVED. Production untouched.
