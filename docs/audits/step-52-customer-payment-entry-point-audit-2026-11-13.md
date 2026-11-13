# Step 52 — Customer payment entry-point and routing audit

Date: 2026-11-13
Branch: website/global-launch-readiness
Scope: customer-facing source audit and partner-direct UI correction. No production database, provider, secret, deployment or live payment action.

## Pages and routes reviewed

- `public/shipper/payment-checkout.html`
- `public/shipper/spot-approvals.html`
- `public/quote-result.html`
- `public/shipper/quote-comparison.html`
- `public/customer-os/index.html`
- `public/customer/payment-history.html`
- `public/customer-os/customer-services/payment-history.html`
- `public/finance/payment-result.html`
- `public/finance/payment-verification.html`
- `public/finance/payment-gateways.html`
- Customer quote-acceptance/detail/booking pages and customer workflow navigation scripts.

## Corrections

1. `public/shipper/payment-checkout.html`
   - Removed the Razorpay/provider capability-status invocation and all provider-specific checkout readiness language.
   - Changed the page into a partner-direct confirmation step.
   - It now validates the accepted quote, shipment, customer organization, partner assignment and positive amount only.
   - The continue action is enabled only when those record checks pass and routes to partner-direct guidance. No payment order is created.

2. `public/shipper/spot-approvals.html`
   - Removed the stale “secure checkout” and server-created payment order claims.
   - The accepted-quote action now points to partner-direct payment guidance.

3. `public/quote-result.html`
   - Removed the remaining currency/provider capability lookup from the customer quote guidance path.
   - Quote amount/currency are now informational only; a valid quote is not treated as checkout eligibility.
   - The page retains a hard-blocked payment button and no order-creation invocation.

4. `public/customer-os/index.html`
   - Reworded the payments service tile to describe partner-direct payment guidance and historical records.

## Static verification after re-fetch

| Page | Order-creation invocation | Payment capability invocation | Misleading active-checkout copy |
|---|---:|---:|---|
| `public/shipper/payment-checkout.html` | 0 | 0 | None found |
| `public/shipper/spot-approvals.html` | 0 | 0 | None found |
| `public/customer-os/index.html` | 0 | 0 | None found |
| `public/quote-result.html` | 0 | 0 | None found |
| `public/finance/payment-gateways.html` | 0 | 0 | None found |

Razorpay references remain on quote-result and payment-gateways only as historical/technical adapter context; they do not invoke an order or provider checkout.

## Limits and remaining backend risk

This was a focused static audit of the customer quote/payment path, not a formal exhaustive scan of every page, mobile app, authenticated route, direct API call or Edge Function. Static source checks do not prove browser behavior or production behavior.

Most importantly, Step 50's backend risk remains: the deployed `create-global-razorpay-order` Edge Function lacks an independent commercial launch-mode gate, and the production INR/Razorpay capability registry row has `checkout_enabled=true`. A user who can satisfy backend quote/assignment checks may potentially call the Edge Function directly, even though the current customer UI no longer invokes it.

Production enforcement still requires explicit owner approval and a reviewed change plan. No production settings, data, Edge Functions or provider configuration were changed in this step.

## Step 52 verdict

**CUSTOMER QUOTE/PAYMENT ROUTES REVIEWED AND ALIGNED WITH PARTNER-DIRECT GUIDANCE IN PR #65. BACKEND DIRECT-INVOCATION RISK REMAINS OPEN.** PR #65 remains unmerged and undeployed.
