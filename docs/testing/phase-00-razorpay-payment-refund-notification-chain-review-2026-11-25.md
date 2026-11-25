# Phase 00 — Razorpay payment, refund and notification execution-chain review

**Date:** 2026-11-25  
**Environment inspected:** Production Supabase project (read-only catalog/source review)  
**Code branch:** `qa/phase-00-baseline-2026-11-25`  
**Status:** Source review completed for the selected chain; runtime and provider tests NOT RUN.  
**Safety:** No Edge Function was invoked. No provider API was called. No payment, refund, webhook, notification, email, Telegram or database write was initiated.

## Scope

Reviewed the Production source for:
- `create-global-razorpay-order`
- `verify-razorpay-payment`
- `razorpay-webhook`
- `execute-razorpay-refund`
- `krim-notification-provider-adapter`
- `krim-notification-retry-worker`

Also inspected payment-related SQL functions, payment-order columns and triggers using read-only catalog queries.

## Evidence-based positive findings

1. The Razorpay webhook has JWT verification disabled, which is expected for a provider webhook. Its source requires the Razorpay signature and event ID, verifies HMAC-SHA256 against the raw request body, and rejects invalid signatures before parsing/reconciliation.
2. The webhook allowlists the event types it handles. Unsupported event types are acknowledged as ignored and are not recorded as processed.
3. Webhook event IDs are persisted and used for duplicate detection. A previously processed event is acknowledged as a duplicate; a concurrent duplicate insert that is not yet processed returns a retryable 409.
4. Captured-payment reconciliation matches the provider order ID to the canonical KRIM payment order and checks payment ID, amount in paise, currency and captured status. It uses a conditional status transition and checks for conflicting payment IDs.
5. Captured payment is not acknowledged as fully processed until the internal service-role-only reconciliation RPC returns a financial transaction ID. The SQL function additionally checks that the paid order is bound to the KRIM shipment, customer organization, accepted KRIM quote, partner quote, confirmed assignment and capacity reservation; it records the financial transaction with a provider-reference idempotency anchor.
6. Failed-payment handling does not downgrade an already-paid order. It records the failed attempt and keeps the provider order available for retry.
7. The payment-verification and order-creation Edge Functions have JWT verification enabled and their source validates the Supabase user. The order-creation source checks merchant/currency capability flags before enabling checkout and reuses an existing canonical order where applicable.
8. Refund execution is explicitly fail-closed unless both `KRIM_LEGACY_REFUND_EXECUTION_ENABLED=true` and the exact approval-version secret are present. The current code comments state the partner-direct launch model has refund execution disabled. The endpoint was not called; actual secret values were not inspected.
9. Refund execution source uses an approved database claim, a stable idempotency key, INR/full-amount checks and leaves uncertain provider outcomes pending for reconciliation. Signed refund webhooks verify the approved request, original payment, amount, currency and provider refund ID before ledger reconciliation.
10. Payment-order triggers include customer in-app payment notification and financial-state synchronization. The customer notification trigger runs on the transition to paid and inserts into the in-app `notifications` table. The payment-order trigger inventory also includes the private payment-transaction synchronization trigger.

## Findings / gates still open

### F-01 — Customer payment notice is only proven as an in-app database notification

The reviewed `notify_customer_payment_paid()` trigger inserts a row into `public.notifications`. This proves an in-app notification record path in source, not delivery through email, Telegram, SMS, push, or a user-visible notification center. The external notification outbox/provider path and delivery status must be traced and tested separately. This is a launch gate because KRIM requires reliable journey notifications.

### F-02 — Webhook processing is not yet runtime-proven under retries and concurrency

Source contains event-ID idempotency and a conditional payment state transition, but no signed test fixtures have been submitted. Need controlled staging tests for valid signature, invalid signature, missing event ID, duplicate event, concurrent duplicate, mismatched amount/currency/payment ID, payment.failed after paid, payment.authorized, captured payment, and finance-RPC failure/retry. Do not use production Razorpay credentials or live provider traffic for these tests.

### F-03 — Financial and notification transaction boundary needs runtime confirmation

The source first transitions `payment_orders` to paid and then calls the financial reconciliation RPC. If the RPC fails, the webhook returns 500 and leaves the event retryable; this is a recoverable design in source, but runtime verification must prove a retry completes reconciliation without duplicate ledger entries or inconsistent customer notifications. Confirm the notification trigger's transaction semantics and resulting records under this failure/retry path.

### F-04 — Refund endpoint safety depends partly on secret configuration

The source has two independent environment gates. Their actual Production and Staging values were not inspected, and no secret values should be exposed in reports. Before any refund test, verify only whether the gates are disabled in the isolated test environment, and use provider sandbox credentials. No refund was initiated.

### F-05 — Notification retry worker is a real external-send path

The retry worker uses service-role access and sends queued founder Telegram messages to the configured chat. It authenticates either a long cron secret or a platform-admin user. It is not a harmless dry-run endpoint: invoking it can deliver real messages and claim queue records. It must remain uninvoked until a dedicated staging sink/test chat and isolated secrets are confirmed. Its queue claim/finish RPCs and retry/backoff behavior still require source and runtime review.

### F-06 — Provider adapter includes a live Telegram test action

The notification adapter's email/Resend branch only reports credential availability and explicitly says sending is disabled. Its Telegram `action=test` branch calls Telegram `sendMessage` and sends a founder test message. This is a real external side effect, so it was not called. Any future test requires explicit authorization and confirmation of the destination chat.

### F-07 — CORS policy is broad on provider-facing endpoints

The reviewed Razorpay webhook and payment verification functions return wildcard CORS headers. The webhook is provider-to-server and does not rely on browser CORS for authentication; HMAC signature validation is the primary control. The user-facing verification endpoint uses bearer authentication. Nevertheless, narrow CORS to approved application origins where browser access is intended, after confirming every supported frontend origin. This is a hardening item, not evidence of an authentication bypass by itself.

### F-08 — Production/staging Edge Function parity remains incomplete

The previously inventoried Staging project does not contain the complete Production operational Edge Function set, including the Razorpay order, verification and webhook functions. Therefore the inspected Production source cannot be assumed to be deployed or testable in Staging. Do not copy/deploy functions or secrets without a separately reviewed staging deployment plan.

## Required controlled test matrix

| Test | Expected evidence | Status |
|---|---|---|
| Webhook missing signature | 401; no event row | Not run |
| Invalid HMAC | 401; no event row | Not run |
| Missing event ID | 400; no event row | Not run |
| Unsupported event | ignored; not processed | Not run |
| Valid payment.failed | attempt failure recorded; paid state preserved | Not run |
| payment.authorized | not marked paid | Not run |
| Captured payment with correct order/amount/currency | paid state + one matching financial transaction | Not run |
| Captured payment with wrong amount/currency/order/payment ID | fail closed; no false paid ledger | Not run |
| Duplicate webhook | one financial transaction; duplicate safely acknowledged | Not run |
| Concurrent duplicate | no duplicate financial posting; retry/reconcile behavior recorded | Not run |
| Financial RPC transient failure | event remains retryable; retry repairs state exactly once | Not run |
| Refund disabled gate | endpoint returns disabled without provider call | Not run |
| Refund mismatch/conflict | rejected; no ledger posting | Not run |
| Notification record | exactly one user-bound in-app notification | Not run |
| External notification dry-run/sink | queued, attempted, delivered/failed and retry status evidenced without real recipients | Not run |

## Decision

**Payment source review: PARTIAL PASS.** The reviewed source has meaningful signature, identity, order-binding, amount/currency, duplicate and financial reconciliation controls. This is not a runtime or live-readiness pass.

**Refund execution: CODE-LOCKED BY ENVIRONMENT GATES; actual secret state unverified.** No execution attempted.

**Customer notification delivery: NOT PROVEN.** In-app record insertion is visible in source; external channel delivery, preference/consent rules, retries, dead-letter handling and delivery evidence remain open.

**Production readiness: NOT APPROVED by this review.** No evidence-based sign-off until isolated staging parity, controlled runtime tests, and end-to-end notification delivery tests pass.

## Next actions

1. Review the complete notification outbox schema, claim/finish RPCs, retry schedules, provider adapters and event-to-template mappings.
2. Review the remaining payment/order creation and verification branches, including ownership and quote-binding negative paths.
3. Establish an isolated staging payment simulation using synthetic fixtures only; never call live Razorpay or refund endpoints.
4. Add controlled automated tests and capture database/API evidence for every matrix row.
5. Confirm staging Edge Function deployment parity before any end-to-end test.
