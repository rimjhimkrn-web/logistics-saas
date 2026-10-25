# KRIM Global Payment Provider Expansion Plan

**Status:** architecture and activation gates; not a claim that global payment processing is live.
**Decision:** retain Razorpay for eligible India transactions; add providers through a provider-neutral adapter architecture. Do not enable a provider/country/currency combination until commercial eligibility, technical integration, settlement, refunds, reconciliation, and compliance are evidenced.

## Why more than Razorpay is required

KRIM's current capability registry records India/INR as implemented for checkout, but merchant eligibility, settlement, refunds, and FX capabilities are not yet fully verified. The other listed country/currency combinations are planned and checkout-disabled. A currency selector or a provider SDK does not establish that KRIM can lawfully accept, settle, refund, or pay out money in that market.

The existing Cashfree Edge Function names are not working integrations: their deployed handlers return HTTP 410 and say the integration is retired. They must remain disabled until a real, tested adapter replaces them.

## Provider strategy

1. **Razorpay — India launch rail.** Keep as the current India/INR path only, subject to live merchant approval, enabled payment methods, reconciliation and refund/payout proof.
2. **Stripe — candidate, eligibility-gated.** Stripe publishes a global availability list and labels India as Preview. Confirm the actual KRIM legal entity's onboarding eligibility, permitted cross-border sales, settlement account, supported currencies, refunds, and marketplace/payout model before implementation or activation. Do not assume an Indian account can use every Stripe feature.
3. **Adyen — enterprise/global candidate.** Broad local payment method coverage makes it worth a commercial evaluation. Requires provider approval, contracting, technical onboarding and confirmation of country/currency-specific methods and settlement capabilities.
4. **Checkout.com — enterprise/global candidate.** Evaluate for international cards/local methods and local acquiring where KRIM is eligible. Availability of a provider in a market does not by itself mean KRIM is eligible to onboard or settle there.
5. **PayPal — optional complementary method.** Evaluate for eligible cross-border customer payments, not as the primary freight settlement ledger. Confirm India merchant availability, permitted goods/services, transaction limits, disputes, refunds and payout rules before use.
6. **Cashfree — India-focused candidate only if needed.** Existing endpoints are retired stubs, not production adapters. Do not present them as supported or route customer payments to them until implemented and verified.

Provider choices are candidates, not commitments. Final selection depends on legal entity eligibility, total fees, cross-border rules, settlement availability, refund/dispute operations, provider contract terms and integration effort.

## Required provider-neutral interface

The application should call one internal payment service, not provider-specific functions directly from multiple pages.

Suggested internal contract:
- `createPaymentOrder({ quoteId, shipmentId, amount, currency, customerOrganizationId, idempotencyKey })`
- `verifyPayment({ provider, providerOrderId, providerPaymentId, providerProof })`
- `handleProviderWebhook({ provider, rawBody, headers })`
- `getPaymentStatus({ internalPaymentOrderId })`
- `requestRefund({ internalPaymentOrderId, amount, reason, idempotencyKey })`
- `reconcileProviderTransactions({ provider, settlementWindow })`

Every provider adapter must return a normalized status while preserving the provider's original references. The internal order, not browser redirect parameters, is the source of truth.

## Routing rules

Route only when the capability registry says the exact merchant entity, market, presentment currency, provider, and operation are enabled. Never choose a provider solely from the customer's IP address.

Each market/currency/provider combination must record evidence for:
- merchant/legal-entity eligibility;
- checkout and payment methods;
- presentment currency and amount precision;
- settlement currency and settlement account;
- FX and conversion costs, if any;
- full/partial refunds and dispute/chargeback handling;
- webhook signature verification and event idempotency;
- payout/marketplace eligibility, if partners are paid through the provider;
- applicable sanctions, AML/KYC, tax, consumer, data-residency and cross-border rules;
- live provider account approval and test/live environment separation.

If a payment is pending or its status is ambiguous, do not automatically retry with another provider. Reconcile the original provider order first to prevent duplicate charges.

## Ledger and settlement invariants

- Browser success callbacks never establish payment success.
- Verify server-side provider evidence and exact order ID, amount, currency, captured/settled state as applicable.
- A unique provider + provider transaction reference prevents duplicate financial transactions.
- Webhook retries must be idempotent and auditable.
- Payment capture, shipment execution, platform revenue, partner payable, refund, dispute and settlement are separate lifecycle events.
- Never mark a partner payout paid without provider/bank settlement evidence.
- Keep an immutable event/audit trail and reconcile provider statements to the KRIM ledger.
- Never mix currencies or calculate FX from a guessed rate.

## Phased delivery gates

### Gate 0 — Current state and safeguards
- Keep unverified market combinations checkout-disabled.
- Keep retired Cashfree handlers fail-closed.
- Complete Razorpay order/payment/financial transaction reconciliation.
- Add automated tests for wrong amount/currency, mismatched order, invalid signature, duplicate webhook, replay, failed/pending payment, and provider timeout.
- Confirm no legacy payment endpoint can create ledger entries.

### Gate 1 — Provider commercial eligibility
- Confirm the actual KRIM contracting entity, business category, bank account, expected flows and settlement destinations.
- Obtain written provider eligibility and required approvals.
- Compare total processing, FX, dispute, refund and payout costs.
- Store no secret keys in GitHub or frontend code.

### Gate 2 — One additional provider in sandbox
- Implement a dedicated adapter and webhook endpoint.
- Use provider test credentials only.
- Verify amount/currency/order binding, webhook signatures, idempotency, status polling, refunds and reconciliation.
- Run automated negative and replay tests.
- Do not expose checkout to customers until all checks pass.

### Gate 3 — Controlled live activation
- Enable only the approved country/currency/provider rows.
- Start with a controlled, low-risk transaction and verify settlement and refund workflows.
- Reconcile provider reports against KRIM's ledger.
- Add monitoring, alerts, rollback and support procedures before increasing volume.

### Gate 4 — Expand by evidence
- Add local payment methods/currencies only when the same gates pass.
- Review conversion, payment failures, chargebacks, costs and settlement delays.
- Do not describe a market as live merely because its code or registry row exists.

## Source references

- Stripe global availability: https://stripe.com/global
- Adyen payment methods: https://www.adyen.com/payment-methods
- Adyen payment-method documentation: https://docs.adyen.com/payment-methods
- Checkout.com platform and market overview: https://www.checkout.com/

Provider coverage and eligibility change; re-check official terms during onboarding and before activation.

## Registry update — 2026-10-25

The Supabase provider registry now includes planned entries for PayPal, Adyen and Checkout.com, alongside the existing Stripe candidate. The country/currency capability registry also has disabled roadmap rows for these providers across the United States/USD, United Kingdom/GBP, Germany/EUR, United Arab Emirates/AED and Singapore/SGD; additional planned bank-transfer and regional-wallet placeholders are recorded for those markets and India/INR where applicable.

**These are roadmap records, not integrations.** All newly added provider/method rows have `checkout_enabled=false`, `integration_status=planned`, and all eligibility, presentment, settlement, refund and FX verification flags false. They must remain unavailable in customer checkout until the corresponding adapter, merchant approval, secure webhooks, reconciliation, refund flow and automated tests are completed. Razorpay remains the only integrated checkout adapter; its live readiness is also not yet certified.
