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


## Additional security work in the same implementation branch
- Added `docs/sql/krim-partner-quote-confidentiality.review.sql`.
- The draft removes customer-organisation access from the base `krim_partner_quotes` SELECT policy and restricts full-row access to the owning partner organisation.
- Includes staging assertions and a rollback statement.
- This closes the identified direct-row disclosure path if validated and deployed; customer-facing comparison must continue through the separate customer quote model (`krim_quotes`), not the partner quote base table.
- This policy change has not been executed against staging or production.


## Partner availability implementation draft
- Added `docs/sql/krim-customer-partner-availability-preflight.review.sql`.
- The proposed customer-safe RPC checks authenticated customer organisation access, active origin/destination locations, supported transport mode, currently effective verified capability, partner organisation verification/compliance/lifecycle and weight ceiling.
- It deliberately returns only `no_verified_provider` or `review_required`; it never returns a confirmed match because current capability data does not establish exact end-to-end lane, cargo eligibility and live capacity.
- The response contains no partner names, organisation IDs, rates or internal notes. It creates no shipment, quote, assignment, payment or ledger rows.
- Read-only production baseline: one partner capability, inactive and pending; zero active verified capabilities. Current expected result is `no_verified_provider`.
- Transport mode mapping was aligned to the live catalogue codes (ROAD, RAIL, OCEAN, AIR, WAREHOUSE, MULTIMODAL).
- This remains a review-only SQL draft. It has not been executed, connected to the booking UI, or deployed. Staging validation and exact partner status-value verification remain mandatory.


## Customer quote UI capacity gate
- Updated `public/shipper/quote-comparison.html` so quote acceptance is not enabled unless the linked partner assignment is accepted, its capacity binding is confirmed, and the linked capacity reservation is confirmed.
- Existing accepted-quote checkout readiness now checks the same confirmed binding and reservation, in addition to shipment/quote/assignment/INR/expiry checks.
- Static verification re-fetched the committed file and confirmed both acceptance and checkout paths contain the fail-closed binding/reservation checks.
- Important: this is a customer UI guard only. It is not a security boundary; direct RPC calls could bypass it. The database acceptance RPC must enforce the same conditions before production rollout. No production data or RPC was changed.
