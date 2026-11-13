# Step 54 — Razorpay historical payment verification, webhook and refund continuity audit

Date: 2026-11-13
Production project: `ebltviniygljwwseplph`
Scope: read-only review of deployed Edge Functions, authorization/reconciliation database routines, payment order summaries and webhook/refund records. No provider calls, mutations, deployment or secret access.

## Deployed functions inspected

| Function | Version | JWT verification | Purpose |
|---|---:|---|---|
| `verify-razorpay-payment` | 24 | Enabled | Authenticated browser-return verification and payment reconciliation |
| `razorpay-webhook` | 28 | Disabled by design | Provider callback; authenticates using raw-body HMAC signature |
| `execute-razorpay-refund` | 6 | Enabled | Authenticated, approved refund execution |

## Payment verification findings

The browser-return verification function:
- Requires a Bearer session and independently calls Supabase `auth.getUser(token)`.
- Finds the local order by provider order ID and `payment_provider='razorpay'`.
- Requires a global KRIM shipment; checks optional direct customer ownership and then active customer-organization access through the shipment.
- Requires quote, partner-quote and customer-organization bindings for non-legacy orders.
- Checks the shipment remains confirmed for new payment verification; same-payment paid retries are treated idempotently.
- Verifies the payment directly with Razorpay, including provider order ID, exact amount, currency and captured status.
- Prevents a paid order being overwritten by a different payment ID.
- Calls the same transactional/idempotent finance reconciliation routine used by the webhook.
- Sends legacy paid orders missing quote/partner/org bindings to manual review rather than silently creating finance records.

No provider API call or customer callback was executed during this audit.

## Webhook findings

The deployed webhook:
- Has `verify_jwt=false`, which is appropriate for a provider callback, but requires `x-razorpay-signature` and `x-razorpay-event-id`.
- Reads the raw body and verifies HMAC-SHA256 with the server-side webhook secret before parsing or processing.
- Stores events in `payment_webhook_events`, whose `event_id` has a database UNIQUE constraint.
- Returns a retryable conflict when concurrent insertion of the same event is detected.
- Does not mark an order paid for `payment.authorized`; captured/order-paid events must match the stored order, payment ID, amount, currency and captured state.
- Uses the shared finance reconciliation routine before marking captured events processed.
- Refund events must match a reviewed KRIM refund request, original Razorpay payment ID, full amount and INR currency. The webhook records provider outcomes; it does not initiate refunds.

These are good core safeguards. The event intake is not a fully atomic claim/worker model: an existing unprocessed event may be retried while another invocation is still handling it. Payment/ledger reconciliation is designed to be idempotent, but the refund request event/audit updates span multiple writes and have no unique constraint shown for a provider event ID. A failure between writes can leave a partial refund reconciliation or repeated audit entries. Recommend a database-transactional webhook processor or a durable inbox with an atomic processing lease and idempotent audit keys before relying on automated refunds at scale.

## Historical production records — important unresolved items

Read-only counts:
- Razorpay payment orders: **6 total**.
- **5** orders remain in `created` status with no stored payment ID.
- **1** order is `paid` with a stored payment ID.
- Refund requests: **0**.
- Webhook events: **10 total** — 6 processed `payment.authorized` events and 4 unprocessed events (2 `payment.captured`, 2 `order.paid`).

The four unprocessed captured/order-paid events are old (15 September 2026). They correspond to two provider order IDs, neither of which matches any current row in `payment_orders`. The handler would return “KRIM payment order not found” and leave those events unprocessed. They may be legacy/test-provider events, but that cannot be assumed from source alone. Do not mark them processed or delete them. Reconcile against Razorpay Dashboard/API records and historical deployment/test evidence; if confirmed test artifacts, document that disposition explicitly.

The six current payment-order rows were created 25–26 September 2026. The one paid order is not linked to any active refund request in the database snapshot. No actual refund workflow has been exercised against production data.

## Refund execution findings

- Edge Function v6 verifies the user session.
- The claim RPC checks AAL2, active finance/platform/operations organization membership, `finance.manage` or `admin.platform`, approving-reviewer identity, requester/reviewer separation, approved/pending status, full-amount INR paid order, and stable idempotency key.
- The function sends the exact amount and request ID to Razorpay with `X-Refund-Idempotency`, reusing the stored key on retry.
- Uncertain provider responses remain `execution_pending`; the signed refund webhook is expected to finalize status.
- Current refund request count is zero, so the live refund execution path has not been exercised end-to-end.

Razorpay's current documentation confirms `X-Refund-Idempotency` for supported refund operations and requires reuse of the same key/request for the same operation. The implementation's use of that header is consistent with the provider contract. Webhook guidance also confirms at-least-once delivery, raw-body signature verification and the unique event ID pattern.

## Readiness decision

**Keep historical verification, signed webhook reconciliation and authorized refund code available. Do not disable these functions as part of stopping new freight checkout.** New checkout can be blocked independently in the order-creation function and payment capability registry, while historical records continue to reconcile.

Before claiming payment continuity is fully verified:
1. Reconcile the four old unmatched captured/order-paid webhook events with the provider's historical records.
2. Add atomic webhook processing/lease and idempotent refund audit-event protection.
3. Exercise payment verification, webhook duplicate/concurrency handling and approved refund execution in a properly restored disposable staging environment. Current staging is empty and not suitable.
4. Confirm no provider API calls are made by any checkout UI after the partner-direct block.

No production data or settings changed. No Razorpay API was called. No refunds were issued. No secrets were read. PR #65 remains unmerged and undeployed.
