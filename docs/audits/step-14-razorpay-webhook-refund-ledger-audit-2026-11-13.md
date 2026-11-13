# Step 14 — Razorpay webhook, refund execution, and ledger audit

**Date:** 2026-11-13  
**Environment:** Production Supabase project `ebltviniygljwwseplph` (read-only inspection)  
**Git branch:** `website/global-launch-readiness`  
**Scope:** Deployed `razorpay-webhook`, deployed `execute-razorpay-refund`, their database RPCs, triggers, indexes, and financial-ledger effects.

## Executive result

The deployed refund workflow has meaningful safeguards: authenticated refund execution, AAL2, finance permission and reviewer separation, full-refund-only enforcement, a stable idempotency key, signed provider webhook verification, provider/payment/amount/currency matching, and a provider-reference-anchored refund ledger debit.

However, this does **not** make the existing Razorpay freight-collection system compatible with KRIM's selected partner-direct launch model. The webhook still reconciles KRIM freight payments, creates company-owned payment credits, and records company-owned refund debits. The refund executor can initiate refunds against those KRIM-collected payments after finance approval. These are legacy payment operations and must remain isolated from any future KRIM referral/coordination fee collection.

No code, schema, function, secret, payment, refund, ledger, webhook, or production setting was changed in this audit.

## Deployed webhook findings

- `razorpay-webhook` is ACTIVE, version 28, with JWT verification disabled as expected for a provider webhook. It requires the Razorpay signature and event ID headers, verifies HMAC-SHA256 against the exact raw request body, and rejects invalid signatures.
- Supported events are explicitly allowlisted: `payment.failed`, `payment.captured`, `payment.authorized`, `order.paid`, `refund.created`, `refund.processed`, and `refund.failed`. Unknown events are acknowledged as ignored, not marked processed.
- Webhook events are inserted as unprocessed before reconciliation. A completed duplicate is acknowledged; an unfinished prior event is retried; a concurrent unique-event collision returns a retryable 409.
- Captured-payment reconciliation resolves the canonical KRIM order by Razorpay order ID, verifies amount, currency and captured state, prevents a different payment ID from replacing an already-paid order, and calls the service-role-only `krim_internal_reconcile_razorpay_captured_payment` RPC before finalizing the webhook event.
- The RPC validates paid status, provider, payment ID, INR currency, shipment/customer/quote binding, accepted quote amount, accepted partner assignment, and confirmed capacity reservation. It inserts an idempotent company-owned payment credit in `krim_financial_transactions`.
- `payment.failed` records the failed attempt without downgrading a paid order or closing the order, preserving retry against the same provider order.
- `payment.authorized` is intentionally not treated as paid.

## Refund execution findings

- `execute-razorpay-refund` is ACTIVE, version 6, JWT verification enabled. It independently validates the caller's Supabase session.
- The claim RPC requires AAL2, active finance/platform/operations membership, `finance.manage` or `admin.platform`, that the caller is the approving reviewer, and that requester and reviewer differ.
- The claim RPC locks the refund request and payment order, permits only an approved/pending request, requires a paid Razorpay INR order and an exact full-amount refund, and preserves one stable idempotency key across retries.
- The Edge Function sends the refund to Razorpay with that stable idempotency key. Uncertain/network/non-success responses remain pending rather than being marked failed; the signed webhook is the final status authority.
- Partial refunds are explicitly disabled. Only one refund request per payment order is enforced by a unique index.

## Refund webhook and ledger findings

- Refund events are correlated by the KRIM refund request ID in Razorpay refund notes, or by an already-recorded provider refund ID. The code checks approved reviewer binding, original Razorpay payment ID, full amount and INR currency, and rejects conflicting provider refund IDs.
- A processed refund marks the request processed, conditionally marks the original payment order refunded, and records a company-owned debit in `krim_financial_transactions` with provider reference = Razorpay refund ID.
- A unique partial index on `(provider, provider_reference)` and a unique organization/idempotency-key index protect financial transactions from duplicate inserts. The webhook verifies any pre-existing ledger row matches the expected shipment, organization, type, amount, currency, status, direction and ownership scope.
- The payment-order trigger also synchronizes a private payment transaction mirror. The separate captured-payment RPC writes the canonical financial transaction. The legacy `payments` table has a separate trigger that writes `shipment_financials`; it is not the same accounting path as the current `payment_orders` webhook flow.

## Findings requiring follow-up

1. **Partner-direct boundary remains unresolved at the deployed backend.** The webhook still accepts and reconciles KRIM freight payments and creates company-owned payment credits. The refund executor can still execute refunds for approved historical KRIM payment orders. Hiding checkout UI or disabling order creation in the website is not a server-side guarantee. Keep customer freight checkout disabled and do not use these payment records for partner-direct referral fees.
2. **Refund audit-event duplication is possible on partial webhook retries.** If the refund-request update and audit-event insert succeed but a later payment-order/ledger/finalization step fails, the provider retry can insert another `krim_refund_request_events` row for the same provider event. Financial ledger insertion is idempotent; the refund event timeline does not currently have a demonstrated provider-event uniqueness guard.
3. **Refund event correlation deliberately fails closed.** If a syntactically valid `krim_refund_request_id` note is present but incorrect, the handler does not fall back to provider refund ID lookup. This can require manual reconciliation but avoids silently matching a different request.
4. **No live webhook/refund test was performed.** No customer payment, refund, provider API request, webhook replay, ledger write, or notification was triggered. The audit is source/catalog inspection, not an end-to-end certification.

## Required before commercial launch

- Retain partner-direct customer-to-partner freight payment. Do not activate KRIM freight checkout or use the current freight-payment ledger as a platform-fee ledger.
- Before any separate KRIM fee collection is introduced, obtain CA/legal and Razorpay approval for the precise fee model, create a distinct fee/order/ledger contract, and test it in a non-production environment.
- Add provider-event idempotency to refund request events, preferably a unique provider/event identifier and transactional reconciliation, before relying on refund history as a complete audit trail.
- Perform a controlled test plan in a genuinely isolated staging project with schema parity. The current staging project was previously found empty; do not replay production migrations blindly.
- Keep refunds restricted to authorized finance reviewers and reconcile all historic paid/pending orders before any change to payment functions.

## Verification and safety

- Read-only SQL catalog inspection covered function definitions/privileges, relevant table triggers, and indexes.
- Confirmed the captured-payment reconciliation RPC is SECURITY DEFINER, fixed search path, and not executable by authenticated/anon; it requires service_role in its body.
- Confirmed refund claim/review/submit public wrappers are not SECURITY DEFINER; the private claim/review/submit functions contain the authorization checks described above.
- No production mutations were performed. PR #65 remains draft, open, unmerged and undeployed.
