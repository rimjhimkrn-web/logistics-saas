# KRIM Warehouse — Atomic Inventory Movements

Updated: 2026-10-24

## Implemented

- Supabase migration `20261024090000_krim_warehouse_atomic_inventory_movements` applied successfully.
- Database RPC: `public.krim_warehouse_record_movement`.
- The RPC checks for an authenticated user, an active warehouse/fulfilment organization membership, an active facility within that organization, a valid movement type, a non-zero quantity delta, and a caller-supplied idempotency key.
- The stock balance update and append-only movement insert happen in one database transaction. A failed movement rolls back the inventory update.
- A transaction-scoped advisory lock serializes updates for the same organization, facility, SKU and lot. Stock cannot be reduced below zero.
- Idempotency key uniqueness prevents the same request from being applied twice. The UI retains the key after uncertain errors and prevents clearing the form until the same request can be retried.
- Warehouse RLS policies now require active membership in an active warehouse/fulfilment organization for facility, receipt, inventory and movement access. Movement table grants remain SELECT/INSERT only.
- Inventory Ledger now submits stock changes through the RPC, refreshes live balances, and displays the latest append-only movement history.
- Direct client INSERT/UPDATE/DELETE privileges on inventory balances and movement audit rows have been revoked. Authenticated clients can read these rows under RLS; stock writes must go through the atomic RPC.

## Supported movement types

`receipt`, `putaway`, `pick`, `dispatch`, `adjustment`, `return`, `transfer`.

Receipt and return deltas must be positive; pick and dispatch deltas must be negative. The UI asks for a positive quantity and converts pick/dispatch to negative values. Adjustment and put-away can use the direction selector.

## Verified so far

- Migration application returned success.
- Supabase catalog query confirmed the RPC exists as SECURITY DEFINER with the expected signature.
- Supabase catalog query confirmed RLS is enabled on all four warehouse tables; facility, receipt and inventory each have one policy, while movement records have a SELECT policy.
- Privilege checks confirmed authenticated users have SELECT but not INSERT/UPDATE on inventory, SELECT but not INSERT on movement history, and EXECUTE on the RPC.
- GitHub commits:
  - Migration: `65b0f964199ee3e9d089ef98d163f7ce959591ef`
  - Inventory movement UI: `ca77744b8e0b8fb170d3029225c1a8cc2d7cecf4`
  - Retry and success-message handling: `716b1f718a559d1e9e925761a869ce87c7572808`
  - Inventory form and handler cleanup: `9b2bf7a9aa5362c34191a269d0033315146fb316`
  - Live workflow copy and status: `59a0cd80352f1b401318157ea0ab9e31de3f0810`
  - Movement history table: `a6770778de76de4f0d412432d91c2eccc6142f1c`
  - Restrict direct balance writes migration: `e7645b7d492edaa23e20f0ba4f7b2251b349b7a4`

## Still required before operational approval

- Run a live authenticated positive movement test using a real authorized warehouse account and facility.
- Run a negative test proving a non-warehouse account cannot read or write warehouse records.
- Test insufficient-stock rejection, idempotent retry, concurrency, quality holds and physical count reconciliation.
- Latest code commit smoke checks, static link audit and Pages deployment are pending; previous checks passed for the preceding code revision.
- Confirm the latest GitHub static audit, production smoke checks and Pages deployment complete successfully.
- Picking, packing, dispatch, returns and transfers still need complete end-to-end operational journeys, not just inventory balance changes.
- No stock data was fabricated and no test movement was inserted as part of this implementation.
