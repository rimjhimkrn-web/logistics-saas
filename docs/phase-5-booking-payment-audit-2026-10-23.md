# Phase 5 — Booking & Payment Audit

**Date:** 2026-10-23  
**Phase status:** SOURCE IMPLEMENTATION COMPLETE — AUTOMATED CHECKS AND LIVE ACCEPTANCE PENDING  
**Scope:** Accepted quote → payment eligibility → server-created provider order → provider checkout → server verification → financial reconciliation → verified payment receipt.

## Canonical customer workflow

1. [Global Quote Comparison](../public/shipper/quote-comparison.html)
2. [Payment Readiness](../public/shipper/payment-checkout.html)
3. [Secure Global Checkout](../public/quote-result.html)
4. [Payment Verification Receipt](../public/payment-verification.html)
5. [My Active Shipments](../public/shipper/active-shipments.html)
6. [Customer Payment History](../public/customer-os/customer-services/payment-history.html)

The readiness page is not a payment receipt. The provider's browser callback is not proof of payment. Only a successful server-side verification and a matching financial transaction can be shown as paid.

## Read-only production evidence

Production tables and payment capability settings were inspected read-only:

- `payment_orders`: 5 records in `created` state and 1 in `paid` state.
- `payments`: 2 `paid` records and 2 `pending` records.
- `payment_webhook_events`: 10 records.
- The `IN / INR / Razorpay` capability is marked implemented and checkout-enabled; other inspected currency/provider combinations remain planned and disabled.
- RLS is enabled on payment order, payment, payment webhook, revenue ledger and partner assignment tables.
- Payment order read policy is restricted to the authenticated customer who owns the order. Webhook event table denies authenticated access. Financial transaction reads are organization-scoped.

These counts are not a reconciliation proof. The distinct `payment_orders` and legacy `payments` tables have different record counts and require a controlled reconciliation before asserting all payment history is aligned. No production payment, order, refund, shipment or financial record was created or modified during this audit.

## Implemented in this phase

- Applied the shared `core/krim-global-interface.css` and `krim-global-shell` to Payment Readiness, Secure Checkout and Payment Verification while preserving their existing page-specific components.
- Added Phase 5 static smoke checks for shared interface integration, server-created orders, server verification, captured provider status, currency/amount matching, idempotent financial transaction creation and a safe payment-result route.
- Replaced `public/finance/payment-result.html`'s hard-coded fictional success statement, amount, transaction ID and timestamp with a redirect to the canonical authenticated payment-verification route, preserving query parameters and the hash.
- Kept `create-global-razorpay-order` as the source of order amount and currency; browser fields must not set the amount.
- Preserved HMAC signature verification, independent Razorpay payment lookup, order-ID, amount, currency and captured-status checks, plus unique provider-reference reconciliation.

## Critical safeguards

- Quote accepted ≠ payment order created ≠ payment captured ≠ payment verified ≠ ledger reconciled ≠ shipment operationally activated.
- Do not launch provider checkout without an accepted, positive-value, unexpired quote; an accepted partner assignment; a confirmed shipment; an authorized customer organization; and an enabled provider/currency capability.
- Do not automatically retry a charge when the provider result is ambiguous. Check the original payment order and server receipt first.
- No secret or service-role key belongs in the browser.
- No second payment provider, FX conversion, international currency or local payment method should be enabled until merchant eligibility, presentment, settlement, refunds, fees, disputes, reconciliation and applicable market requirements are verified.
- Refunds, chargebacks/disputes, provider settlement reconciliation and partner payout are separate workflows and are not certified complete by this phase.

## Live acceptance checklist

- [ ] Signed-out customer is sent to sign-in and cannot create a payment order.
- [ ] Customer can open only a quote and shipment belonging to an active authorized customer organization.
- [ ] Invalid IDs, organization mismatch, expired quote, non-positive amount and unsupported currency block checkout.
- [ ] Checkout requires the accepted partner assignment and confirmed shipment state.
- [ ] Server creates/reuses the correct order from the accepted quote amount/currency; duplicate clicks do not create duplicate payable orders.
- [ ] Razorpay receives only the server-created order and server-returned amount/currency/public key ID.
- [ ] Browser callback alone never displays success.
- [ ] Signature mismatch, order mismatch, amount mismatch, currency mismatch, or non-captured provider payment is rejected.
- [ ] Repeated verification of the same provider payment does not duplicate financial transactions.
- [ ] Receipt page independently checks the server status and matching financial transaction.
- [ ] Legacy finance payment-result route redirects to the verified receipt and never displays a fabricated payment success.
- [ ] Failure or timeout prompts status reconciliation before another payment attempt.
- [ ] Customer shipment state and finance records show payment only after server verification/reconciliation.
- [ ] Mobile links work from Quote Comparison → Payment Readiness → Secure Checkout → Payment Verification → shipment/payment history.

## Exit decision

**Phase 5 is not formally closed.** The source changes and static checks do not prove a real end-to-end payment. Do not make a real-money test payment solely to pass this checklist. Use a provider-approved test-mode workflow where the deployed environment and merchant configuration explicitly support it, then verify the order, captured/verified status and financial transaction without creating duplicate charges. Reconcile the existing payment tables before declaring payment history complete.
