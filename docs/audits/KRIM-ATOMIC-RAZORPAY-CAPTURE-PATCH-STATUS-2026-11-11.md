# KRIM Atomic Razorpay Capture Patch — Implementation Status — 2026-11-11

## Changes prepared on the existing audit branch
- `supabase/functions/razorpay-webhook/index.ts`: removed direct `payment_orders.status='paid'` mutation. Captured/order-paid events now rely on the canonical reconciliation RPC.
- `supabase/functions/verify-razorpay-payment/index.ts`: removed direct paid-state mutation. Provider signature/API checks remain before the canonical RPC. Added a database read-back check after RPC success so the response reflects committed state.
- `docs/sql/krim-atomic-razorpay-capture-reconciliation.review.sql`: prepared the replacement RPC. It locks the order, permits only created/attempted -> paid or same-payment paid replay, binds the provider payment ID, validates quote/assignment/capacity, inserts or verifies the unique financial ledger row, and relies on transaction rollback to undo the paid transition if any check fails. EXECUTE is restricted to service_role.

## Static verification performed
- Re-fetched the updated webhook and verification files from the branch.
- Searched both Edge Function files for direct `status: 'paid'` / `status: "paid"` update payloads: none remain. The verification response still correctly reports the final status as paid after the RPC and read-back.
- Confirmed the SQL patch retains fixed empty search_path, SECURITY DEFINER, service-role JWT guard and explicit grants.
- GitHub workflow lookup for the latest commit returned no PR-triggered workflow runs. No passing CI result is claimed.

## Important deployment gate
This is a code patch on the audit branch, not a production deployment. The SQL file is explicitly review-only, not yet in the migration directory. Staging schema parity is still unresolved, so the SQL has not been executed against staging or production. Edge Functions have not been deployed. No real payment/refund was initiated.

## Required next validation
1. Resolve staging schema parity and apply the RPC only to an isolated staging schema/project with safe fixtures.
2. Run SQL assertions for same-ID replay, different-ID conflict, terminal-state rejection, missing binding rollback and ledger conflict rollback.
3. Run webhook/verification integration tests including concurrent delivery and webhook-first/client-first ordering.
4. Run Deno/typecheck CI for both Edge Functions.
5. Only after all pass, prepare a coordinated production rollout and obtain explicit approval.

## Current status
Implementation patch prepared; static source checks completed; CI, staging execution, integration tests and production deployment remain pending.
