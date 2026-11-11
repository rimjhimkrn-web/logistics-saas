# KRIM Payment Status Writers — Razorpay Edge Function and RPC Audit
Date: 2026-11-11
Status: READ-ONLY PRODUCTION REVIEW

## Canonical Razorpay components inspected
Production Edge Functions:
- `razorpay-webhook` — ACTIVE, version 28, JWT verification disabled as expected for provider webhook; performs its own HMAC verification.
- `create-global-razorpay-order` — ACTIVE, version 24, JWT verification enabled.
- `verify-razorpay-payment` — ACTIVE, version 24, JWT verification enabled.
- `create-razorpay-order` — ACTIVE, version 15, retired endpoint returning HTTP 410.
- `process-payment--` — ACTIVE, version 15, retired endpoint returning HTTP 410.

The two legacy endpoints are deliberately retired; do not re-enable them or route clients to them.

## Razorpay webhook: verified provider-event path
The active webhook:
1. Requires POST, configured server secrets, `x-razorpay-signature` and `x-razorpay-event-id`.
2. Reads the raw request body and computes HMAC-SHA256 using `RAZORPAY_WEBHOOK_SECRET`; compares signatures with a constant-time byte comparison.
3. Parses JSON and accepts a finite event allowlist: payment.failed, payment.captured, payment.authorized, order.paid, refund.created, refund.processed, refund.failed.
4. Stores provider event ID/type/payload in `payment_webhook_events` with `processed=false`. A previously processed event is acknowledged as duplicate; a concurrent duplicate insert receives retryable HTTP 409.
5. For captured/order-paid events, looks up the exact local order by Razorpay order ID and checks payment ID, integer amount, currency and provider entity status='captured'.
6. Uses a conditional status update on the observed prior status to set `payment_orders.status='paid'`, provider payment ID and paid timestamp.
7. Calls `krim_internal_reconcile_razorpay_captured_payment` and does not acknowledge success until a matching financial transaction exists.
8. Marks the webhook event processed only after the reconciliation path succeeds.
9. Does not treat payment.authorized as paid.

This is the canonical provider verification route found in this review. A valid HMAC alone is not considered sufficient; the code also checks exact order/amount/currency/captured state.

## Critical ordering defect — P0
The webhook marks `payment_orders.status='paid'` at lines 651–662 of the active source, then calls the financial reconciliation RPC at lines 693–705.

The RPC additionally requires:
- accepted customer quote matching shipment, customer org, partner quote, amount and INR;
- accepted partner assignment;
- confirmed capacity leg binding;
- matching confirmed physical capacity reservation.

If any of those gates fails after the order was set to paid, the function returns HTTP 500 and leaves the local order in paid state while the webhook event remains unprocessed. This is a financially real payment that is not fully reconciled to KRIM's financial ledger. Retrying the webhook can recover after prerequisites are repaired, but the current implementation does not make the status transition and ledger reconciliation one atomic transaction.

Required correction: use one service-role-only transactional database RPC that locks the payment order, validates provider-verified evidence recorded by the webhook, validates the accepted quote/partner assignment/capacity, writes or confirms the financial transaction idempotently, and commits paid state plus reconciliation outcome atomically. If provider event evidence must first be persisted, use a separate immutable verified-event inbox and an explicit pending-reconciliation state; never label a payment fully reconciled until the transaction commits.

Do not solve this by weakening the capacity/quote checks or by allowing generic client writes to paid status.

## Additional concurrency/idempotency finding — P1
The webhook inserts the event row as unprocessed before doing work. Concurrent delivery with the same event ID receives HTTP 409 so Razorpay can retry. This is safer than falsely acknowledging a concurrent unprocessed event, but two different provider event IDs for the same payment/order can still race through the conditional order update. The function has a recovery read, but the complete workflow should be serialized by locking the payment order inside the transactional reconciliation RPC.

The already-paid duplicate branch invokes the financial reconciliation RPC before comparing the stored payment ID with the incoming payment ID. The RPC itself compares the stored provider payment ID and fails closed, so no conflicting payment is accepted; nevertheless, move the explicit ID conflict check before the RPC for clarity and to avoid unnecessary attempted reconciliation.

## Other payment writers / legacy functions
Production function inventory found:
- `public.krim_internal_prepare_payment_for_accepted_quote(bigint)`: creates a legacy `payments` row in pending state. It is not the canonical Razorpay payment-order path and should not be wired into new global booking flow without separate review.
- `public.krim_internal_authorize_shipment_after_payment(bigint,text)`: checks a legacy `payments` row is paid and matches accepted quote amount/currency; may set transaction ID and paid timestamp. It does not itself verify a provider signature or check partner capacity.
- `public.krim_internal_activate_shipment_after_verified_payment(bigint)`: checks a legacy `payments` row is paid and quote matches; transitions draft → quoted → confirmed. It does not independently check accepted partner assignment or confirmed physical capacity. Do not use it as the new global booking activation path.
- `public.krim_internal_reconcile_razorpay_captured_payment(uuid,text)`: service-role-only reconciliation RPC; verifies paid order, provider payment ID, INR amount/quote match, accepted assignment and confirmed capacity reservation/binding, then idempotently creates a `krim_financial_transactions` record keyed by provider/reference. This is the strongest current downstream financial gate, but its checks cause the ordering issue above when called after a paid-state update.
- `public.krim_internal_post_customer_payment_to_ledger(bigint)`: posts a legacy paid `payments` row to the finance ledger. Must not be run in parallel with other ledger-posting paths without idempotency and unique-key review.

## Refund path observations
The active Razorpay webhook processes refund events against an approved KRIM full-refund request, checks original payment/order ID, amount and INR currency, and updates order status to refunded on refund.processed. The customer refund RPC currently permits full refunds only; partial refunds are disabled pending cumulative balance and provider reconciliation. The separate refund execution function claims an approved request and prevents a second provider refund ID from being created. Keep refund processing separate from initial payment verification and regression-test refund webhook retries.

## Readiness and limitations
- The source for `razorpay-webhook` was inspected fully for payment.captured/order.paid handling.
- The active create-order and verify-payment source files were retrieved; this audit did not exhaustively re-review every line of both files. Their existing gates include customer authentication, org access, confirmed shipment, accepted quote, accepted assignment and capacity binding/reservation.
- The DB function inventory is static source inspection; it does not enumerate direct SQL writes from all external deployment scripts, service-role clients or dashboard operators.
- Need inspect every deployed Edge Function for references to `payment_orders`/ `payments`, source-controlled copies and caller inventory, and inspect constraints/unique indexes and actual open payment orders before designing cutover.

## Non-actions
Read-only production function and Edge Function source retrieval only. No database writes, function deployments, secret access, provider API calls, payments, migrations, staging bootstrap or paid resources were performed.
