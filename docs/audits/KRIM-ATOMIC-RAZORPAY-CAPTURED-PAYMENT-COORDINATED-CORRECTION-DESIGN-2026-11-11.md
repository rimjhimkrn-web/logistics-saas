# KRIM Atomic Razorpay Captured-Payment Correction — Coordinated Design Review — 2026-11-11

## Decision
Prepare a single service-role-only database transaction as the authoritative paid transition and financial-ledger reconciliation. Do not deploy until the migration and both Edge Function changes have been reviewed and tested together.

## Live implementation revalidated
- Production `razorpay-webhook`: version 28, ACTIVE, JWT verification disabled (provider webhook); validates raw-body HMAC and event ID, then validates provider order/payment identifiers, captured state, amount and currency. For a newly captured payment it directly updates `payment_orders.status='paid'`, then calls the reconciler RPC in a separate HTTP request.
- Production `verify-razorpay-payment`: version 24, ACTIVE, JWT verification enabled; authenticates the user, validates Razorpay checkout signature, fetches the payment from Razorpay, validates order ID, amount, currency and captured status; directly updates `payment_orders.status='paid'`, then calls the same reconciler in a separate request.
- Existing `public.krim_internal_reconcile_razorpay_captured_payment(uuid,text)` locks the order and checks paid status, provider payment ID, shipment/customer/quote binding, accepted customer quote, amount/currency, accepted partner assignment and confirmed capacity reservation. It then inserts or verifies the unique financial transaction. It currently requires the order to be paid before it begins, so it does not make the paid transition atomic.
- Existing reconciliation routine is SECURITY DEFINER, fixed empty search_path, and service_role-only. The direct Edge Function writes use service-role credentials.
- Webhook duplicate-paid path and customer verification retry path call the reconciler again; these must remain idempotent after consolidation.

## Proposed canonical RPC behavior
Retain the existing RPC name and argument signature to reduce client changes:
`public.krim_internal_reconcile_razorpay_captured_payment(uuid,text)`.

Within one Postgres transaction:
1. Require JWT role `service_role`; reject null/blank provider payment ID.
2. SELECT the canonical `payment_orders` row FOR UPDATE and require provider Razorpay, INR, positive amount and a bound shipment, customer organization, customer quote and partner quote.
3. Permit only a safe state transition from `created` or `attempted` to `paid`, or an idempotent replay of `paid`. Reject failed/cancelled/refunded/partially_refunded and all unexpected states. If the row already has a different Razorpay payment ID, reject; never overwrite it.
4. For a new transition, bind the immutable Razorpay payment ID and paid timestamp and update status to paid inside this same transaction.
5. Validate accepted quote and amount/currency; accepted partner assignment; confirmed capacity binding and reservation.
6. Insert the completed payment transaction using the existing unique provider/reference anchor. On conflict, read the existing row and verify every binding/value; any mismatch raises an exception.
7. Return the verified financial transaction ID. Any validation or ledger error raises and rolls back both the status update and ledger insert.

Provider evidence remains the responsibility of the two trusted Edge Function callers before they invoke this routine. The database routine is not a replacement for Razorpay HMAC/checkout signature, provider API lookup, captured status, amount, currency or order-ID checks. Record the event/source evidence in transaction metadata where practical, without storing secrets.

## Required Edge Function changes
### `razorpay-webhook`
- Keep raw-body HMAC verification, event ID deduplication, event payload validation and provider order/payment/amount/currency/captured checks.
- Remove the direct `payment_orders.update({status:'paid', ...})` write.
- Call the canonical RPC for both first-time captured events and same-payment retries.
- Treat a different already-bound payment ID as a conflict; never acknowledge as paid.
- Mark the webhook event processed only after the RPC succeeds. Preserve retryable non-2xx response on database failure.

### `verify-razorpay-payment`
- Keep authenticated user check, checkout HMAC, Razorpay payment API lookup, order-ID/amount/currency/captured checks and existing shipment/quote/assignment/capacity preflight.
- Remove the direct `payment_orders.update({status:'paid', ...})` write.
- Call the same canonical RPC and return success only when it returns the matching financial transaction ID.
- On RPC failure return a retryable response; do not report paid reconciliation success.

## Important design cautions
- The RPC receives a provider payment ID, not cryptographic proof. Only the service-role Edge Functions should execute it. Keep EXECUTE revoked from PUBLIC, anon and authenticated.
- Preserve the existing row lock, unique provider/reference constraint, exact conflict verification and idempotent return behavior.
- Verify that a DB exception rolls back the paid update when any quote/assignment/capacity/ledger check fails.
- Ensure the RPC cannot regress a refunded or partially_refunded order back to paid on late duplicate captured events.
- A webhook and client verification race should serialize on the payment-order row; second caller must observe the same payment ID and return the same transaction, or reject a different ID.
- Do not make shipment status transitions in this RPC. Booking lifecycle remains a separate coordinated change.
- This change does not solve refund atomicity; refund reconciliation needs its own routine and tests.

## Test matrix before deployment
1. Created order + valid provider capture + valid accepted quote/assignment/capacity: status paid and exactly one matching ledger row.
2. Retry same payment ID from webhook and verify endpoint: same transaction ID; no duplicate ledger row.
3. Concurrent webhook and verification for same payment: one paid transition, one ledger row, both safely idempotent.
4. Same order, different payment IDs: one winner; other gets conflict; stored ID never changes.
5. Wrong provider, currency, amount, quote, customer org, shipment, assignment or reservation: RPC fails and order remains pre-paid.
6. Simulated ledger constraint/insert failure: entire transaction rolls back; order does not remain paid.
7. Already failed/cancelled/refunded/partially_refunded order: reject; no state regression.
8. Service role only: anon/authenticated execution denied.
9. Webhook event duplicate after success: acknowledged as processed; duplicate unprocessed event retries safely.
10. Existing paid orders: same-payment financial repair allowed only when all current bindings pass; legacy paid orders missing bindings stay manual-review only.

## Rollout / rollback
- Build one migration that replaces the function and adjusts grants, plus Edge Function changes in the same PR.
- Apply first to isolated staging after schema parity and safe test fixtures exist; run migration, SQL assertions, Edge Function integration tests and concurrency tests.
- Deploy coordinated Edge Functions only after the RPC is available; do not deploy one caller alone.
- Rollback plan: restore both Edge Function versions and the prior RPC definition only if no new state semantics/data have been introduced; otherwise use a forward-fix and reconcile in-flight payments. Do not automatically downgrade paid records.
- Production deployment requires explicit approval and a maintenance/reconciliation window. This document is a design, not executable SQL or an authorization to deploy.

## Status
Design only. No migration file, Edge Function source, database object, payment status, payment, refund, webhook configuration or production setting was changed in this review.
