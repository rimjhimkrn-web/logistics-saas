# KRIM Payment Status Writers, Legacy Paths and Constraint Audit — 2026-11-11

## Scope and method
Read-only inspection of the production Supabase catalog, table grants, constraints and triggers, plus repository review of the deployed Razorpay webhook source on `main`. This is a static/catalog audit, not a runtime payment test. No DDL, data mutation, live charge, refund or deployment was performed.

## Findings

### 1. Canonical `payment_orders` writers
The production catalog scan identified these database functions referencing `payment_orders`:
- `private.sync_krim_payment_transaction()` — AFTER INSERT/UPDATE mirror trigger; not a source writer.
- `private.krim_refund_request_submit(uuid,bigint,text,uuid)` — creates refund requests, not payment status.
- `private.krim_claim_razorpay_refund_execution(uuid)` — claims an approved refund; does not call Razorpay.
- `public.krim_internal_reconcile_razorpay_captured_payment(uuid,text)` — service-role-only reconciliation; requires the order already be `paid`, exact Razorpay payment ID, bound shipment/customer org/quotes, accepted matching quote, accepted partner assignment and confirmed capacity reservation. It inserts an idempotent financial transaction and rejects conflicting existing ledger entries.
- `public.krim_internal_authorize_shipment_after_payment(bigint,text)` and `public.krim_internal_prepare_payment_for_accepted_quote(bigint)` — legacy `payments` path, described below.

The production `payment_orders` table grants SELECT to authenticated and broad table privileges to service_role. Authenticated has no INSERT/UPDATE grant in the inspected grant list. Therefore Edge Functions using the service-role key are privileged status writers and must enforce all checks themselves.

### 2. Razorpay captured webhook ordering
The deployed `supabase/functions/razorpay-webhook/index.ts` source:
- verifies the Razorpay webhook signature and event identity before processing;
- resolves the canonical KRIM order by the stored Razorpay order ID;
- checks payment ID, integer amount, currency and captured status against the stored order;
- conditionally changes `payment_orders.status` to `paid` using the observed prior status;
- only after that separate database request calls `krim_internal_reconcile_razorpay_captured_payment`;
- returns a retryable 500 if reconciliation fails.

**P0 ordering risk remains:** marking the order paid and inserting the financial transaction are separate requests/transactions. A failed reconciliation can leave an order paid without the corresponding KRIM financial transaction until a retry or manual repair. The webhook's paid-order retry path attempts reconciliation, which is useful, but does not make the initial two-step sequence atomic. A coordinated design should make the paid transition and financial ledger insert one database transaction after all provider evidence has been validated, or use an explicit durable intermediate state/outbox with reconciliation guarantees.

The webhook also handles full refund processing separately: it updates the refund request, changes the payment order from paid to refunded, and records the refund ledger. These are multiple requests and should be tested for partial failure and replay. Partial refunds are explicitly disabled in the refund request function.

### 3. Legacy `payments` path is a second payment domain
Production still contains `public.payments` and these public SECURITY DEFINER functions:
- `krim_internal_prepare_payment_for_accepted_quote(bigint)` inserts a legacy payment row with status `pending`.
- `krim_internal_authorize_shipment_after_payment(bigint,text)` trusts a row whose status is already `paid`, then checks quote status and amount/currency; it does not itself verify provider evidence.
- Existing triggers on `payments` create shipment financial records. The `payment_orders` table has separate notification/financial triggers.

The legacy functions must not be assumed to be part of the modern Razorpay payment proof chain. Their execute grants and all callers need an explicit review before deprecation. The `payments` table has authenticated SELECT and service_role table privileges; the inspected constraints include FKs and primary key but no status CHECK constraint. This leaves a less constrained legacy status domain than `payment_orders`.

### 4. Canonical constraints and triggers
Production `payment_orders` constraints include:
- amount_paise > 0;
- currency fixed to INR;
- provider fixed to razorpay;
- status limited to created, attempted, paid, failed, cancelled, refunded, partially_refunded;
- unique Razorpay order ID and unique Razorpay payment ID;
- FKs to customer, organization, shipment, customer quote and partner quote.

Triggers on `payment_orders` include updated_at, payment-transaction mirror, customer-paid notification and financial synchronization. `payments` has INSERT/UPDATE financial creation trigger. The existing financial triggers are separate from the canonical `krim_financial_transactions` reconciliation RPC and should not be conflated.

### 5. Required next controls
1. Inventory every Edge Function, scheduled job, admin endpoint and external caller that uses service_role to update `payment_orders` or `payments`; the database function scan cannot discover arbitrary client-side REST writes.
2. Inspect EXECUTE grants for the two legacy public SECURITY DEFINER functions and verify they are not exposed to anon/authenticated callers.
3. Consolidate canonical paid/refunded transitions behind narrowly scoped server-only database routines with provider evidence passed as validated inputs and immutable provider references.
4. Make paid transition + financial ledger insertion atomic, or implement durable pending-reconciliation state with bounded retries, alerting and reconciliation dashboard.
5. Add tests for duplicate and concurrent captured events, same-order conflicting payment IDs, amount/currency mismatch, financial insert failure, webhook replay, refund ledger failure, and retry after each partial failure.
6. Decide whether the legacy `payments` domain is retained for an explicitly separate use case or retired only after all callers and historical records are mapped.

## Conclusion
The modern Razorpay webhook validates key provider evidence and the database reconciliation RPC checks shipment/quote/partner/capacity binding. However, the paid-state update and financial reconciliation are not atomic. A parallel legacy `payments` domain also remains in production and must be isolated or retired through a separately reviewed migration. No production change is authorised or applied by this audit.
