# Step 50 — Legacy payment-provider and partner-direct launch gate audit

Date: 2026-11-13
Scope: read-only inspection of deployed production Edge Function source and the payment capability registry. No endpoint was invoked with a payment, no secrets were read, and no production setting was changed.

## Production findings

### 1. Cashfree order and verification routes are retired
The deployed functions `create-global-cashfree-order` (v13), `verify-global-cashfree-payment` (v15), and `cashfree-payment-webhook` (v14) all return HTTP 410 with `PAYMENT_PROVIDER_RETIRED`. They do not call Cashfree or update payment records. They remain listed as ACTIVE at the platform level, but their current source is a retirement stub.

### 2. Legacy generic payment endpoints are retired
The deployed `create-razorpay-order` (v15) and `process-payment--` (v15) return HTTP 410 retirement responses. They do not create provider orders.

### 3. Canonical Razorpay order creation is not globally disabled
The deployed `create-global-razorpay-order` is ACTIVE (v24; source SHA-256 `bbf1b29fb0ea77483c47020f574c4a2f31306a3be4c9a79cc8a4db4801e1c480`). Source inspection found:
- JWT/user authentication, organization access, confirmed shipment, accepted quote, partner quote and accepted assignment checks;
- provider/currency capability-registry lookup;
- live-key mode requires merchant eligibility, presentment, settlement, refunds and FX capability flags all true;
- INR is allowed by the non-INR currency check when a registry row exists, including test-key mode;
- **no `KRIM_COMMERCIAL_LAUNCH_MODE` / `freight_checkout` environment gate is present in this deployed function source.**

### 4. Production capability registry currently leaves INR Razorpay checkout enabled
Read-only query of `public.krim_payment_capability_registry` returned the India/INR/Razorpay row:
- integration_status = `implemented`
- checkout_enabled = `true`
- merchant_eligibility_verified = `false`
- presentment_supported = `true`
- settlement_supported = `false`
- refunds_supported = `false`
- fx_supported = `false`

Consequences:
- **Live-key checkout is blocked** by the function's live capability check because multiple required flags are false.
- **Test-key INR checkout is not blocked by those live-only checks** if the other order, quote, assignment and access conditions are met.
- This does not match the selected partner-direct launch model, where customer freight payments must go directly to the logistics partner and KRIM should not collect freight.

### 5. Webhook and refund routes
- Razorpay webhook (v28) verifies the HMAC signature and event ID, supports a bounded event list and reconciles captured/paid/refund events. It is intentionally unauthenticated at gateway level for provider callbacks, but validates the provider signature in code.
- Razorpay payment verification (v24) remains active and authenticated, and verifies payment/order linkage and customer ownership before reconciling.
- Razorpay refund execution (v6) remains active and authenticated; it delegates AAL2/finance permission, reviewer separation, payment state and idempotency checks to `krim_claim_razorpay_refund_execution`. It can call the Razorpay refund API after that claim succeeds. It is a privileged operational route, not a checkout route.

## Decision and required action

**Partner-direct launch is not yet technically enforced end-to-end.** Cashfree and legacy generic endpoints are retired, and live Razorpay checkout is capability-blocked, but the canonical INR Razorpay order endpoint still permits the test-key path because its registry row says `checkout_enabled=true`.

Recommended remediation before any public pilot:
1. Set the India/INR/Razorpay capability row to `checkout_enabled=false` through a reviewed, auditable change.
2. Add an independent server-side commercial launch-mode guard to canonical order creation so a future registry mistake cannot re-enable KRIM freight checkout.
3. Ensure the customer UI does not present KRIM-hosted freight checkout in partner-direct mode; customers should receive partner payment instructions directly from the partner.
4. Keep signed Razorpay webhook/verification history available for reconciliation of old orders; do not delete or disable reconciliation blindly.
5. Keep refund execution restricted to authorized finance review and reconcile any historical payments before retiring it.

No production DB update was made because this audit was read-only. The owner must explicitly approve the production checkout-disable change before it is applied. A source-only fix or a database-only toggle alone would not be sufficient without verifying the UI and end-to-end behavior.

## Step 50 verdict

**PAYMENT PROVIDER RETIREMENT PARTIALLY VERIFIED; PARTNER-DIRECT CHECKOUT GATE HAS A TEST-MODE GAP.** Do not open public KRIM-hosted freight checkout. The selected partner-direct model remains the safe launch path, but an audited production disablement and end-to-end UI verification are still required.
