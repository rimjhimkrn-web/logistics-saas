# Step 55 — Historical Razorpay event reconciliation and webhook hardening design

Date: 2026-11-13
Production project: `ebltviniygljwwseplph`
Scope: read-only design based on deployed webhook v28, live table metadata/indexes, and the four unmatched historical captured/order-paid events. No production data or schema changes.

## 1. Historical event disposition — do not auto-replay

The four unprocessed events are:

| Provider event | Event ID | Provider order ID | Existing KRIM order match |
|---|---|---|---|
| payment.captured | `TcEpXov9phY1ZH` | `order_TcEpB7Uc1oPUkc` | None |
| order.paid | `TcEpYBhACFa8hz` | `order_TcEpB7Uc1oPUkc` | None |
| payment.captured | `TcHDuryyICLOdc` | `order_TcHDidOsXqFxwn` | None |
| order.paid | `TcHDvIRaDrXO4b` | `order_TcHDidOsXqFxwn` | None |

All were received on 2026-09-15. Their payloads report INR 5,000 (500,000 paise) and captured payment status. Both events for each provider order reference the same provider payment ID. The live `payment_orders` table has six Razorpay orders created on 2026-09-25/26, so neither September 15 provider order has a local row.

### Required manual reconciliation procedure

1. Export the four existing event rows (event IDs, timestamps, event type, provider order/payment IDs, amount/currency/status and payload hash) to the restricted finance evidence folder. Do not export secrets or unrelated payload PII.
2. An authorized finance reviewer independently checks Razorpay Dashboard or provider API history for both provider order IDs and payment IDs, merchant account/mode, amount, currency, capture state, refunds, and settlement.
3. Search historical Git commits, test logs, and deployment records for the source of these provider orders. Determine whether they were test artifacts, legacy KRIM transactions, or genuine external payments.
4. Reconcile any genuine payment to its actual customer/order and bank settlement evidence. If no matching KRIM order exists, do not create a synthetic `payment_orders` row or financial transaction just to clear the webhook queue.
5. Record a signed disposition per event pair: `confirmed_test_artifact`, `confirmed_external_payment_not_KRIM`, `matched_historical_KRIM_order`, or `unresolved_escalated`. Record reviewer, evidence references, date and rationale.
6. Only after a second reviewer approves the disposition should the event be archived/marked handled through a dedicated audited admin procedure. Unresolved events remain unprocessed and visible for manual follow-up.

No provider history was queried and no event row was changed in this audit.

## 2. Current webhook concurrency gap

Current v28:
- Verifies raw-body HMAC and provider event ID.
- Inserts a new event before handling it; event ID has a unique index.
- Returns HTTP 409 for a concurrent duplicate insert, which is a sound retry response.
- But for an existing `processed=false` event, it simply continues processing. There is no atomic claim, processing lease, attempt counter, or stale-worker recovery marker. Two deliveries/retries can therefore process the same unprocessed event concurrently.
- Payment capture reconciliation has a transactional/idempotent finance RPC and a conditional paid-state update, which reduces duplicate-ledger risk.
- Refund handling spans several REST writes (refund request status, ledger, refund event history, webhook processed marker). Those writes are not one database transaction. A failure between writes can leave partially reconciled state; retries may repeat audit side effects.
- `payment_webhook_events` currently has unique `event_id`, `processed`, `processed_at`, `payload`, `event_type`, and timestamps, but no lease/attempt/error columns.
- `krim_refund_request_events` has no provider event ID column or unique idempotency key. `krim_refund_requests.provider_refund_id` is unique; refund requests currently number zero.

## 3. Recommended target design

### A. Durable webhook inbox and atomic claim

Keep the existing `payment_webhook_events` rows as the durable inbox. Add, through a reviewed migration after staging exists:
- `processing_status`: `pending | processing | processed | dead_letter` (backfill from existing `processed` without rewriting payloads).
- `attempt_count` (non-negative, default 0).
- `claimed_at`, `claimed_by` (random invocation UUID), `lease_expires_at`.
- `last_error_code` (bounded code only; never store secrets or full provider responses).
- Optional `payload_sha256` for evidence integrity.

Use a private-schema, tightly permissioned RPC to atomically claim one event:
- Lock candidate row with `FOR UPDATE SKIP LOCKED`.
- Claim only `pending` rows or `processing` rows whose lease expired.
- Increment attempt count, set invocation UUID and lease expiry, return immutable event payload.
- Acknowledge a duplicate only when the row is already `processed`; active lease returns retryable 409/425, expired lease can be reclaimed.
- Finalize/release only when the invocation UUID matches, so an old worker cannot complete a newer worker's claim.
- Set a bounded maximum retry count and move poison/unresolvable events to `dead_letter` for human review; never silently mark them processed.

The webhook should authenticate/signature-check, durably insert-or-find the event, claim it, process it, then finalize using the claim token. Return a retryable response when persistence/processing is incomplete. Keep provider retries as an additional recovery mechanism, not the only one.

### B. Transactional payment/refund reconciliation

For captured payment:
- Preserve exact payment/order/amount/currency/captured-state matching.
- Keep payment-order paid transition conditional and same-payment idempotent.
- Ensure the event's processed state and finance reconciliation outcome are committed together where practical. Existing finance RPC is already transactional; extend/review it rather than duplicating finance logic.

For refunds:
- Move all database state transitions into one private transactional RPC: validate approved request and original payment; bind provider refund ID once; update request status; create the financial ledger entry once; insert audit event with provider event ID; finalize webhook event.
- Add a nullable `provider_event_id` to `krim_refund_request_events` with a unique constraint (or a dedicated idempotency table) so one provider event cannot create duplicate audit history.
- Enforce that a refund request's provider refund ID cannot be rebound to a different payment, amount, or request.
- Keep provider refund initiation separate from webhook outcome recording. The webhook only reconciles; it never initiates a refund.
- Preserve the stable Razorpay refund idempotency key used by the execution function.

### C. Access and data protection

- Keep claim/finalize routines in a non-exposed schema, with explicit `search_path`, minimal EXECUTE grants to service role only, and no browser/client access.
- Do not add public/anon/authenticated policies to payment tables.
- Never log webhook payloads, signatures, payment credentials, full customer PII or provider secrets.
- Keep HMAC validation on exact raw body before any event insert/claim.
- Maintain unique event IDs and unique provider refund IDs.

## 4. Required staging tests before production rollout

The current staging project is empty and production migration history is unreconciled; do not deploy this design yet. Once a disposable schema baseline is safely prepared, test:

1. Valid signature inserts one inbox row and one successful processing result.
2. Invalid signature creates no inbox row.
3. Same event delivered twice concurrently produces one active claim and one reconciliation.
4. Worker crash after claim is recovered only after lease expiry.
5. Old worker cannot finalize after another worker reclaims the event.
6. Two distinct event IDs for the same captured payment create exactly one paid transition and one financial transaction.
7. Wrong amount, currency, order ID, payment ID or non-captured status fails closed and remains retryable/manual-review.
8. Refund event replay creates one provider refund binding, one ledger debit and one audit event.
9. Crash at each refund write boundary leaves either a fully committed transaction or a safe retryable state—never a partial completed refund.
10. Unknown order, missing refund request, duplicate provider refund ID and conflicting payment/refund IDs go to retry/manual review without synthetic finance records.
11. Service-role-only RPC grants, no anon/authenticated execution, and RLS/grants are verified.
12. Historical four events remain untouched throughout the tests.

## 5. Step 55 decision

**Design complete; implementation blocked.** Production contains unmatched old webhook events that require human/provider reconciliation, and the current staging project is empty with unresolved migration-history drift. Do not add columns, indexes, RPCs, update event statuses, or deploy Edge Function changes until a reviewed schema baseline and staging test environment exist.

No production writes, provider API calls, secret access, refunds, event replay, migration, deployment, merge or live payment changes occurred.
