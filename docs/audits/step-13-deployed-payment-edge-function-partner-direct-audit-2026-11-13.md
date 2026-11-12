# KRIM Customer Journey — Step 13: Deployed Payment Edge Function Audit

**Audit date:** 2026-11-13  
**Disposition:** **PARTNER-DIRECT MODEL CONFLICT IDENTIFIED — PAYMENT CHECKOUT MUST REMAIN DISABLED.**

## Production Edge Function inventory

Read-only listing of active production Edge Functions identified the following relevant endpoints:

- `create-global-razorpay-order` — active, JWT required.
- `verify-razorpay-payment` — active, JWT required.
- `razorpay-webhook` — active, JWT not required (provider webhook).
- `create-razorpay-order` — active, JWT required; deployed body is a legacy refusal/stub directing callers to canonical Razorpay checkout.
- `process-payment--` — active, JWT required; deployed body is a legacy refusal/stub.
- `create-global-cashfree-order`, `verify-global-cashfree-payment`, `cashfree-payment-webhook` — active, with deployed bodies acting as refusal stubs directing callers to Razorpay.
- `execute-razorpay-refund` — active, JWT required; separate refund surface requiring its own role and ownership audit.

Other listed functions were not reviewed in this payment-specific pass.

## Critical finding: canonical Razorpay flow is still a KRIM freight collection flow

The deployed `create-global-razorpay-order` source:
1. Authenticates the customer and verifies shipment organization access.
2. Requires shipment status `confirmed`.
3. Loads an `accepted` KRIM customer quote.
4. Requires a linked partner quote and an `accepted` partner assignment.
5. Requires a confirmed capacity binding and matching capacity reservation.
6. Checks provider/currency capability registry and creates/reuses a Razorpay order for the quote amount.

The deployed `verify-razorpay-payment` source:
1. Authenticates the user and loads the exact KRIM payment order.
2. Rechecks shipment, accepted quote, partner assignment and capacity reservation.
3. Verifies Razorpay HMAC signature and independently queries Razorpay payment status.
4. Proceeds through the KRIM payment-order/revenue-recording flow.

These checks may be useful for a future KRIM-collected payment model, but they do **not** implement the currently approved partner-direct launch model. The current model requires the customer to pay the logistics partner directly and KRIM to collect only its separately agreed partner referral/coordination fee, subject to CA review. KRIM must not collect the partner's freight charge or represent that the customer owes freight payment to KRIM.

The website launch gate and hidden checkout UI do not by themselves prove the deployed Edge Function cannot be called directly. JWT authentication is not commercial-model authorization.

## Required action — do not deploy a payment change yet

1. Keep all customer-facing KRIM freight checkout entry points disabled.
2. Inspect the remainder of the order-creation and verification functions, webhook processing, refund function, revenue ledger writes, and payment status callbacks.
3. Trace every frontend/Edge Function call to these endpoints and every payment table mutation.
4. Decide with CA/payment provider whether KRIM will ever collect a separate platform fee. Do not reuse freight payment records for a referral fee.
5. For partner-direct launch, remove/deny new customer freight-order creation and verification through the public API path using a tested, explicit launch-mode gate. Preserve historical webhook and payment reconciliation for existing records; do not disable or rewrite historical payment processing blindly.
6. Audit Razorpay webhook signature, event idempotency, payment/order/customer/quote binding and replay handling independently.
7. Audit `execute-razorpay-refund` authorization and ensure KRIM does not issue partner freight refunds.
8. Keep Cashfree refusal stubs until dependencies and historical reconciliation are complete; do not delete functions or secrets as part of this audit.
9. Provision staging with migration parity and run controlled non-production tests before any production change.

## Safety boundary

This step retrieved the production function inventory and read deployed Edge Function source only. No functions were deployed or disabled; no payment order, refund, webhook, secret, ledger, migration, database grant, merge or website deployment was changed. No test payment was initiated.

## Exit decision

**Step 13 audit complete; partner-direct commercial launch remains blocked until deployed payment endpoints enforce the agreed model.** Do not claim that KRIM can accept and withdraw global freight payments or that the payment system is commercially ready. Razorpay merchant eligibility, settlement bank, fees, refunds, tax treatment and actual settlement remain separately unverified.
