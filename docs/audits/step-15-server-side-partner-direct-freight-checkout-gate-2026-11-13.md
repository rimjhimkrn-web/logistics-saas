# Step 15 — Server-side partner-direct freight checkout gate

**Date:** 2026-11-13  
**Environment inspected:** Production Supabase `ebltviniygljwwseplph` (read-only)  
**Implementation:** GitHub branch `website/global-launch-readiness` only  
**Commit:** `ca5334a5dfe88343b396108243a13f640e435969`

## Change made in source control

Added a fail-closed commercial-model gate to `supabase/functions/create-global-razorpay-order/index.ts`:

- The endpoint returns HTTP 410 with code `PARTNER_DIRECT_FREIGHT_CHECKOUT_DISABLED` unless `KRIM_COMMERCIAL_LAUNCH_MODE` is explicitly set to `freight_checkout`.
- A missing or unknown environment value therefore disables new KRIM freight order creation.
- The refusal response is `Cache-Control: no-store`.
- The guard runs before authentication, database reads, and Razorpay API calls.
- The explicit freight-checkout override is retained only as a controlled future configuration; do not set it for the selected partner-direct model.

This closes the direct Edge Function order-creation path at source level, not merely the browser UI.

## Critical pre-existing payment orders discovered

Read-only production aggregation returned:

| Provider | Status | Currency | Count | Face value |
|---|---|---:|---:|---:|
| Razorpay | created | INR | 5 | ₹1,40,000 |
| Razorpay | paid | INR | 1 | ₹35,000 |

The five `created` orders date from 25–26 September 2026. They are existing KRIM Razorpay orders, not new orders created by this task. The aggregate does not prove that all five Razorpay provider orders remain payable, nor that funds were received. The single paid order is historic and must remain available for financial reconciliation/refund obligations.

## Important limitation — not yet safe to declare checkout fully disabled

The source gate prevents new order creation once deployed, but it does **not** invalidate provider-side Razorpay orders already created. A customer with an existing Razorpay order ID may still be able to pay it directly. Before enabling partner-direct commercial operations, the five outstanding orders must be individually reconciled against Razorpay and either confirmed/captured or cancelled/expired with provider evidence. Do not bulk-cancel, assume they are unpaid, or modify their database status without provider verification and authorization.

## Why verification and refunds remain enabled

- `verify-razorpay-payment` remains available to reconcile an already-created historical order if a captured payment needs verification. Its server-side checks require exact order/payment, amount, currency, shipment, accepted quote, partner assignment and capacity binding.
- `razorpay-webhook` remains available as the provider's signed reconciliation channel. Disabling it could strand a genuine historical payment or refund.
- `execute-razorpay-refund` remains available for eligible historical paid orders under finance/AAL2 controls. Disabling it could obstruct legitimate customer refunds.
- These functions are not authorization for KRIM to resume collecting new freight payments under the partner-direct model.

## Deployment and testing status

- The source change is committed on the working PR branch only.
- It has **not** been deployed to Supabase.
- No environment variable or secret was changed.
- No Edge Function was invoked, no Razorpay API request was made, and no payment/refund/order/ledger row was changed.
- No production migration or database mutation occurred.
- PR #65 remains draft, open, unmerged and undeployed.
- This is a source-level correction, not proof that the production endpoint currently rejects calls. Production enforcement begins only after reviewed deployment.

## Next required work

1. Build a safe reconciliation register for all six existing Razorpay orders, including provider order/payment/refund status, exact amount, customer/shipment/quote binding, and settlement evidence.
2. Obtain explicit authorization before any provider-side cancellation/refund or production deployment.
3. Deploy and test the gate only after review, using a non-production environment with schema/config parity.
4. Separately audit refund timeline idempotency and close the duplicate-event risk identified in Step 14.
