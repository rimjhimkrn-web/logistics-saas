# KRIM Customer and Finance Frontend Payment Exposure, Checkout Entry-Point and Commercial Claim Audit — 2026-11-16

## Executive decision
**NO-GO for live freight checkout or financial collection.** The inspected public customer journey is substantially aligned with the current partner-direct model: checkout entry points lead to clear guidance, not a payment form; customer payment verification is read-only; historical payment history is labelled legacy; and partner/customer settlement links are redirected or retired. No active customer-facing payment form or frontend call to create a new Razorpay order was found in the inspected paths.

This is a static source review of repository pages and scripts, plus read-only deployed Edge Function inventory. No browser session was launched, no payment UI was submitted, no RPC or Edge Function was invoked, no provider was contacted, and no production data or schema was changed. Static review is not a browser/role-based functional test.

## 1. Positive controls — customer payment journey

### Partner-direct checkout guidance
- `public/shipper/payment-checkout.html` is a guidance page, not a checkout form. Its title/description and visible content state that the contracting logistics provider issues its invoice and receives freight payment directly.
- It explicitly says KRIM does not currently collect freight charges, create new customer freight-payment orders or settle partner freight funds.
- It does not accept payment details or launch a payment gateway.
- It instructs customers to verify provider legal identity, accepted quote, currency, service scope, invoice and beneficiary before paying.
- It warns that the page does not create a payment order, mark a shipment paid, verify provider bank details, provide escrow or split settlement, or guarantee provider performance.

### Main quote-result entry point
- `public/quote-result.html` explicitly says KRIM freight checkout is disabled and routes to the partner-direct guidance page.
- It states no new KRIM freight payment orders are created and does not initiate or retry payment.
- The legacy payment verification route is kept separate for a previously created KRIM payment only.

### Customer workspace navigation
- `public/customer-os/assets/customer-workflow.js` sends the Payments navigation item to `public/shipper/payment-checkout.html`, not to a gateway or payment-order creation form.
- Billing-related quick actions route to the secured billing workflow and caution that pending payment must not be treated as completed.
- Customer invoice records are described as KRIM-visible records only; the provider remains responsible for issuing freight invoices under the partner-direct model.

### Payment verification
- `public/payment-verification.html` is a read-only recovery page for an existing payment order. It requires an authenticated user and payment-order/shipment/quote references, then calls `krim-payment-verification-status`.
- The page does not accept payment details, create an order, or mark a payment as paid.
- Its success state requires the authenticated server response to confirm both the paid order and matching completed Razorpay financial transaction.
- It states that new freight payments are arranged directly between customer and contracting provider.
- `public/finance/payment-result.html` redirects to this verification page and explicitly removed sample/pre-filled success displays.

### Quote acceptance and booking
- `public/customer-os/assets/quote-operations.js` has `PARTNER_DIRECT_BOOKING_ACCEPTANCE_ENABLED = true`. This enables acceptance of a quote only after the page verifies a matching accepted/active partner assignment; it calls `krim_accept_global_quote` and checks the exact returned quote.
- The success message distinguishes quote acceptance from final operational readiness and dispatch, and explicitly says freight payment is direct between customer and provider.
- Quote acceptance is not a payment event, booking dispatch, payment verification or KRIM receipt. Keep these states separate.

## 2. Customer and partner settlement entry points are redirected or retired
- `public/customer/settlement.html` and the canonical customer OS settlement route redirect to partner-direct payment guidance.
- `public/billing/escrow-settlement.html` and `public/enterprise/escrow-settlement.html` redirect to the same partner-direct guidance; they do not expose a live escrow or settlement workflow.
- `public/partner/settlements.html` is partner-direct payment guidance, not a payout screen.
- Legacy `public/partner/finance-settlements.html`, `public/partner/payment-disputes.html`, `public/partner/freight-invoices.html` and `public/partner/invoice-generation.html` are retired/redirected to the authenticated Partner Workspace because they lacked verified database-backed workflows.
- Finance public routes for bank accounts, payment gateways, refunds, payment history and transaction details mostly redirect to the authenticated Finance Workspace or terms. These redirects do not themselves establish a working bank, payout or refund service.

## 3. Historical finance workspace is explicitly read-only
- `app/finance/index.html` labels the workspace controlled access and read-only. It explains the partner-direct model and that historical revenue records do not establish new KRIM freight collection.
- The workspace labels invoice, payment and settlement panels as live database queries and warns that payment is not payout.
- `app/finance/payment-processing.html` presents a read-only payment-order register and warns a provider payment reference is not proof of settlement or bank payout.
- `app/finance/partner-settlements.html` explicitly says the partner payable register is temporarily unavailable while partner-only visibility and finance-role authorization are corrected; it does not display or initiate payouts.
- `public/finance/treasury-dashboard.html` explicitly marks its prior data as demo/not connected and retires the static demo dashboard.
- Customer payment history is labelled legacy, read-only and user-scoped; it says new freight payments are made directly to the provider and do not appear there.
- Customer invoice register states that provider freight invoices are issued directly to the customer and that the KRIM register is not a consolidated provider invoice ledger.

## 4. P1 — Legacy navigation and wording still create avoidable confusion
The redirects and retired pages are safer than fake transaction forms, but the large number of legacy billing/settlement URLs can still make the platform appear to offer services it does not yet operate.

Recommended cleanup, without deleting historical records:
1. Keep one canonical payment-guidance route and make all old checkout/settlement/escrow links clearly redirect to it.
2. Add a consistent visible notice to all retired billing pages: “Not available for new freight payments. Customer pays the contracting logistics provider directly.”
3. Do not use the words “escrow”, “settlement”, “partner payout”, “refund processed” or “payment completed” as a service claim unless that specific capability is approved, connected and evidenced.
4. Keep Finance Workspace available to authorised finance users for historical audit only; label every panel as historical/read-only/operationally unavailable where appropriate.
5. Ensure customer and partner support forms distinguish a payment dispute with KRIM from a dispute with an independent logistics provider. KRIM must not promise to reverse a provider's direct bank transfer.
6. Clarify that KRIM's own referral/coordination fee, if introduced later, is a separate commercial service and not the freight charge. Do not add a payment button for that fee until contract, tax, bank, merchant and invoice controls are approved.

## 5. P1 — Public customer invoice and refund wording needs precise scope
- The customer invoice register shows KRIM-visible invoice records, while provider freight invoices are issued by the contracting provider. It should never imply KRIM issues the provider's freight invoice.
- Customer refund guidance is informational. It must not imply KRIM can refund funds paid directly to a partner. The responsible contracting provider and the actual payment recipient should be stated for each case.
- The general refund/cancellation policy must distinguish (a) unaccepted quote withdrawal, (b) provider-direct freight payment/refund, and (c) any historical payment collected by KRIM. These are different responsible parties and payment rails.
- Historical KRIM-collected payments should use the existing authenticated verification and controlled refund-review path only; no new freight refund execution should be enabled under the partner-direct launch model.

## 6. P0 backend control remains open — frontend does not close the webhook gap
The frontend routes do not expose a new payment form, but this does **not** close the P0 backend issue in the preceding financial audit:
- `razorpay-webhook` remains deployed active, version 28, with `verify_jwt=false` as expected for a provider webhook.
- `create-global-razorpay-order` remains deployed active, version 25, `verify_jwt=true`.
- `verify-razorpay-payment` remains deployed active, version 25, `verify_jwt=true`.
- The webhook still lacks the same freight-collection kill-switch check used by order creation. A valid provider capture event for an existing open order may still trigger paid-state/financial posting while new checkout is disabled.
- Frontend hiding or redirecting a button is not a security boundary. The server-side webhook containment plan remains P0 and must be implemented/tested before any financial release.
- Do not disable the webhook endpoint itself: provider delivery and historical refund/payment event reconciliation require a deliberate controlled design. Do not replay existing unprocessed events.

## 7. Test coverage and limitations
Static checks performed:
- Inspected customer checkout guidance, quote-result route, customer workspace navigation, quote acceptance logic, payment verification/result routes, customer payment history and invoice pages, customer/partner settlement routes, escrow redirects, public finance redirects, finance workspace entry pages, and relevant deployed payment Edge Function inventory.
- Confirmed that the inspected customer-facing checkout route does not expose a form or payment gateway.
- Confirmed that the inspected verification route calls the authenticated status function and does not mutate payment status from the browser.
- Confirmed that quote acceptance uses a server RPC and keeps payment/dispatch separate.

Not performed:
- No live browser test or mobile viewport test.
- No authenticated role/tenant tests for customer, partner, finance or enterprise.
- No click-through test of every legacy redirect.
- No RPC/Edge Function invocation, payment-provider API request, webhook replay, payment, refund, payout or bank operation.
- No deployment or production configuration change.

## 8. Release decision
**NO-GO for live KRIM freight checkout, escrow, split settlement, partner payout or new refund execution.**

The public customer payment journey is substantially safe at the static-source level: it routes to partner-direct guidance and read-only verification. The remaining critical risk is backend webhook handling, not a visible customer payment button.

## 9. Next remediation order
1. Complete the P0 Razorpay webhook kill-switch containment and durable event quarantine design from the prior remediation plan.
2. Reconcile all existing payment orders and unprocessed captured/order-paid events against provider and bank evidence; do not replay.
3. Consolidate/label legacy payment and settlement routes so users cannot mistake redirects for live services.
4. Run staging browser tests for customer, partner and finance roles, including direct URL access and mobile navigation.
5. Keep KRIM's own separate service-fee collection in the final financial phase only, after legal/tax/bank/contract approval and explicit user authorisation.

## Change boundary
Repository source review and read-only deployed Edge Function inventory only. No code, production settings, Edge Function deployment, environment secret, database grant, policy, migration, financial record or provider transaction changed. Production/repository migration-history mismatch remains unresolved; no production DDL or migration is authorised.
