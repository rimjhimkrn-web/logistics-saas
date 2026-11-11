# KRIM Booking Lifecycle — Payment Trigger Function Review
Date: 2026-11-11
Branch: `audit/workspace-rls-review-2026-11-11`
Status: READ-ONLY PRODUCTION FUNCTION REVIEW

## Scope
Reviewed production definitions for:
- `private.sync_krim_payment_transaction()`
- `public.notify_customer_payment_paid()`
- `public.sync_financial_after_payment()`
- `public.create_financial_after_payment()`
- Shipment status event, snapshot, audit and history trigger functions.
- Quote creation audit, assignment capacity commitment and partner-rejection quote cancellation functions.

No function was changed or executed as a mutation.

## Findings

### P0 — Payment-order mirror treats paid timestamp as verification evidence
`private.sync_krim_payment_transaction()` mirrors every payment-order insert/update into `private.krim_payment_transactions` using `payment_order:<id>` as its idempotency key. It maps status to a known set (unknown values become `requires_review`) and preserves a previously paid status against later created/attempted/failed/cancelled updates.

However, whenever `payment_orders.status='paid'`, it sets `verified_at = new.paid_at`. The trigger itself does not inspect provider signature verification, provider event identity, payment reference validity or amount/currency matching. Those checks must be guaranteed by every authorised writer that can set the source row to paid. Treating the timestamp as proof is unsafe unless that upstream invariant is demonstrated and direct status-write paths are restricted.

The mirror also overwrites linkage, amount, currency and metadata from the source row on conflict. The booking/payment implementation must preserve immutable payment identity and reject conflicting provider references rather than silently replacing them.

### P0 — Legacy financial creation can insert a shipment-level paid row
`public.create_financial_after_payment()` inserts a `shipment_financials` row when `payments.status='paid'`, with `ON CONFLICT DO NOTHING`. It does not identify a specific payment in the inserted financial row. Correct duplicate protection therefore depends on the actual unique constraints and on there being only one intended shipment-level financial row. Verify constraints and historical duplicate rows before changing or reusing this path.

### P1 — Payment financial synchronisation updates every row for a shipment
`public.sync_financial_after_payment()` changes all `shipment_financials` rows with the same shipment ID when a payment changes to paid. It has no payment/order-specific linkage in the update predicate. If multiple financial rows can exist per shipment, one payment could mark unrelated rows paid. Establish the intended cardinality and unique constraints; do not build SaaS subscription billing on this shipment-finance table.

### P1 — Payment-success notification deduplication is not payment-specific
`public.notify_customer_payment_paid()` only fires on a transition to paid, then searches for an existing notification by user, notification type, title and shipment-related condition. It does not use payment-order ID or provider payment reference. This can suppress a later legitimate payment notification for the same user/shipment, and the NOT EXISTS check is not a concurrency-safe uniqueness guarantee by itself.

The replacement design should use a durable unique event/notification key tied to the payment transaction, or an idempotent outbox row keyed by payment identity. Do not create a parallel notification from a new booking RPC.

### P1 — Shipment status event and audit fan-out is multi-write
A shipment status change writes:
- `krim_events` pending event with a generated UUID;
- `krim_audit_events` status-change row;
- `krim_shipment_status_history` row;
- operational snapshot row.

The trigger functions execute in the same database transaction as the status update. This is useful atomicity, but consumers must handle event delivery retries idempotently. The generated event UUID is unique per trigger invocation; it is not a stable lifecycle idempotency key across an application-level retry that repeats a later valid transition.

### P1 — Quote creation audit records initial state as submitted
`public.krim_log_quote_creation()` writes amount, currency, shipment ID and initial quote status to the audit log on INSERT. A new quote should therefore be created as a non-accepted draft/sent offer; the audit should not imply acceptance before customer acceptance.

### P1 — Assignment acceptance capacity commitment trigger is strict
`public.krim_ensure_assignment_capacity_commitment()` requires positive shipment weight and a linked partner quote matching shipment and partner. It inserts a committed kg-based capacity commitment, then locks and verifies the resulting commitment, including partner, status, quantity and validity. This is a useful invariant. New lifecycle RPCs must rely on this trigger and must not duplicate commitment creation.

The function uses `ON CONFLICT (assignment_id) DO NOTHING`; subsequent validation is essential and currently present. Preserve that validation.

### P1 — Partner rejection trigger only cancels accepted customer quotes
`public.krim_cancel_customer_quote_after_partner_rejection()` runs for offered → rejected assignments, but finds only customer quotes already in `accepted` status and only quote versions in `accepted` status. If the corrected lifecycle keeps customer offers in draft/sent until partner acceptance, this trigger will not close those pending offers. Update the design to cancel the relevant pending quote and presented version, emit an accurate event, and invalidate any associated open payment order.

### P2 — Status snapshots are append-only observations, not a canonical state machine
The snapshot trigger reads current shipment status and current exception/alert counts, then inserts a new snapshot. It does not itself enforce lifecycle validity. Do not use snapshots as a substitute for authoritative shipment/assignment/quote/payment state.

## Required tests before implementation
1. Attempt to set a payment order paid through every writer; prove only verified provider evidence can do so.
2. Duplicate webhook and application retries: one payment transaction, one financial effect, one payment notification per payment identity.
3. Conflicting provider payment IDs, order references, amount or currency: reject and preserve original identity.
4. Multiple financial rows per shipment: prove one payment cannot settle unrelated rows.
5. Rejection/expiry after a draft/sent customer offer: quote and version close; stale payment order cannot verify.
6. Shipment status transition rollback: no partial event/audit/history/snapshot writes.
7. Event/outbox consumer duplicate delivery: idempotent downstream effect.
8. Assignment acceptance creates exactly one matching commitment; duplicate acceptance does not overcommit.
9. Confirm actual constraints and indexes behind `ON CONFLICT DO NOTHING`, notification dedupe and financial row uniqueness.

## Remaining work
- Enumerate every writer of `payment_orders.status` and `payments.status`, including Edge Functions, RPCs, service-role scripts and admin workflows.
- Inspect provider event inbox/replay tables, refund/partial-refund workflows and reconciliation.
- Inspect all consumers of `krim_events` and notification outbox.
- Confirm financial constraints and actual live row cardinalities.
- Inspect quote-version table constraints and all version/event writers.

## Non-actions
Read-only production catalog/function-definition queries only. No DDL, data changes, function deployments, grant changes, payment actions, staging bootstrap or paid resources were performed.
