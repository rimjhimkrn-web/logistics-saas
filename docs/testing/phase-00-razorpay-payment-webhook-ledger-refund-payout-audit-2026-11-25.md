# Phase 00 — Razorpay, payments, webhooks, ledger, refunds and partner payout audit

**Date:** 2026-11-25  
**Repository:** `rimjhimkrn-web/logistics-saas`  
**Supabase environments:** Production `ebltviniygljwwseplph`; Staging `qrpcivhdxobiaofppbkl`  
**Method:** Read-only PostgreSQL catalog, table grants/RLS, unique-index, trigger and aggregate-count inspection. No payment or webhook function was invoked; no provider request was sent.

## Executive result

**BLOCKED — payment/financial operations are not ready for unrestricted real transactions.**

Production has a live Razorpay payment data footprint, but evidence of complete end-to-end reconciliation is absent. There are four webhook events still marked unprocessed, zero entries and zero transactions in the newer double-entry ledger, zero refund requests/events, and only one legacy partner payout row marked paid. A paid database status is not bank settlement proof. Staging payment tables inspected are empty, so it is not yet a usable payment integration test environment.

The strongest positive controls are service-role-only direct table access for payment orders, payment rows, webhook event records and payout rows; unique provider IDs and event IDs; one-open-order-per-quote uniqueness; refund idempotency/one-per-payment uniqueness; and server-side Razorpay reconciliation functions that explicitly require service_role.

## 1. Live Production financial data snapshot

| Area | Live count / status | Interpretation |
|---|---:|---|
| `payment_orders` | 6 | 5 created, 1 paid; all provider = Razorpay |
| `payments` | 4 | 2 paid, 2 pending |
| `payment_webhook_events` | 10 | 6 processed, 4 unprocessed |
| Unprocessed webhook types | 2 `order.paid`; 2 `payment.captured` | Must be investigated and reconciled |
| `revenue_ledger` | 1 | Legacy/simple revenue record exists |
| `krim_ledger_accounts` | 14 | Accounts configured |
| `krim_ledger_transactions` | 0 | No double-entry transactions |
| `krim_ledger_entries` | 0 | No debit/credit entries |
| `krim_financial_transactions` | 1 | Separate legacy financial transaction record |
| `krim_refund_requests` / events | 0 / 0 | Refund workflow has no live evidence |
| `partner_payouts` | 1 paid | Legacy payout record only; bank settlement not proven |
| `krim_financial_approval_requests` | 0 | No live approval workflow evidence |
| `krim_financial_reconciliation_exceptions` | 0 | No exception records; does not prove reconciliation passed |

Staging counts for the corresponding payment orders, payments, webhook events, revenue ledger, payout, ledger accounts/transactions/entries, refunds and approval requests are zero in the inspected tables.

No payment payload, card/bank detail, customer PII or webhook body was selected in the count queries.

## 2. Positive security and integrity controls

### PAY-01 — Payment tables are server-write-only
Production RLS is enabled on the inspected payment tables. Direct table grants for `payment_orders`, `payments` and `payment_webhook_events` are service_role-only; authenticated users have no direct write grants. Payment order SELECT policy is scoped to the customer user or finance-view permission. Legacy payments SELECT policy binds `customer_id=auth.uid()`. Webhook event policy explicitly denies authenticated access.

**Assessment:** Good least-privilege baseline for provider-controlled financial state. Preserve server-only writes; do not add direct client grants to make frontend workflows easier.

### PAY-02 — Duplicate/idempotency constraints exist
Unique constraints/indexes include:
- `payment_orders.razorpay_order_id`
- `payment_orders.razorpay_payment_id`
- One open order per `krim_quote_id` while status is created/pending
- `payment_webhook_events.event_id`
- `payments.idempotency_key` (non-null)
- `payments.quote_id` (non-null)
- Refund: one request per payment order, unique idempotency key and unique provider refund ID
- Revenue allocation run idempotency keys and unique allocation references
- Webhook delivery ID and endpoint/event uniqueness

These are valuable database backstops. They do not prove that every webhook handler and provider retry path handles unique violations safely or returns an idempotent success response.

### PAY-03 — Razorpay reconciliation RPC is service-role guarded
The inspected `public.krim_internal_reconcile_razorpay_captured_payment(uuid,text)` SECURITY DEFINER function checks the JWT role is `service_role`, locks the payment order, verifies provider is Razorpay, paid status, exact Razorpay payment ID, shipment and customer organization before posting. Its search_path is pinned to an empty path and object references are schema-qualified.

**Assessment:** Strong intended server-only boundary in the function body. Runtime invocation and webhook-to-RPC wiring remain NOT TESTED.

### PAY-04 — Refund workflow has independent review/step-up controls in inspected functions
`private.krim_refund_request_review` and `private.krim_claim_razorpay_refund_execution` require authenticated identity and AAL2. The execution claim requires an approved review record and checks reviewer identity. Refund request table has unique constraints for one request per payment order, idempotency key and provider refund ID.

**Assessment:** Good control design visible in the inspected function definitions. The full function bodies, reviewer permission mapping, maker-checker edge cases, RPC ACLs and Razorpay refund execution handler still require a dedicated line-by-line review and negative tests. No refund records exist to demonstrate operation.

### PAY-05 — Payout and financial state triggers are present
Production has triggers on payment orders and payments for payment-transaction synchronization, notification and financial synchronization. Legacy partner payouts have payout-paid notification and shipment financial synchronization triggers. Multi-leg revenue allocation tables also have guards blocking unallocated writes.

**Assessment:** Triggers exist, but they do not substitute for verified provider settlement, ledger balancing or notification delivery.

## 3. Release-blocking findings

### PAY-06 — Four webhook events remain unprocessed
**Severity: HIGH / P0 reconciliation gate**

The Production event table has 10 unique event IDs; six are processed and four are not. The unprocessed set comprises two `order.paid` and two `payment.captured` events.

The event types are overlapping lifecycle notifications, so the count does not establish four distinct customer payments. It does establish that the durable webhook inbox is not fully drained. Do not mark these events processed manually or replay them blindly.

**Required safe investigation:** correlate each event ID to the corresponding payment order/provider payment ID using a read-only reconciliation job; compare amount/currency/order state; determine whether event was superseded, duplicate, transiently failed or permanently failed; then use the approved idempotent replay/reconciliation path. Preserve raw event evidence and audit trail. No webhook payload was read in this audit.

### PAY-07 — Double-entry ledger is not operationally evidenced
**Severity: CRITICAL / P0**

Production has 14 ledger accounts but zero `krim_ledger_transactions` and zero `krim_ledger_entries`. The single legacy `revenue_ledger` row and one `krim_financial_transactions` row are not equivalent to a balanced double-entry ledger.

**Release consequence:** do not represent the platform as having proven automated accounting, commission recognition, partner payable posting, refund reversal or financial close. Before taking real customer money at scale, demonstrate that every successful capture generates exactly one balanced transaction (debits = credits per currency), with a stable source reference, idempotency, immutable entries and reconciliation to provider settlement.

### PAY-08 — Finance approval/control direct-write exposure remains unresolved
**Severity: CRITICAL / P0**

As documented in the preceding live RLS audit, Production grants authenticated INSERT/UPDATE/DELETE on financial approval/control tables and their policies primarily establish organization access rather than finance-specific permission, step-up authentication and independent approval. This can bypass the intended finance workflow. This payment audit confirms those approval tables have no live request rows; absence of rows is not a control.

**Required remediation:** revoke broad direct authenticated writes; make event/posting/DLQ/monitoring records service-only; route approval transitions through narrowly scoped, permission-checked, AAL2 and maker-checker RPCs. Requires a separately reviewed change plan and explicit authorization. No grants or policies were changed here.

### PAY-09 — Staging payment environment is empty
**Severity: HIGH / P0 test-readiness**

All sampled payment/ledger/refund/payout tables are empty in Staging. Production has existing records. The prior staging migration/grant parity gaps also remain. Do not test with live provider money or Production data. First establish an isolated staging provider account/webhook secret, seeded synthetic fixtures and a complete schema/grant baseline.

### PAY-10 — Payout status is not provider settlement evidence
**Severity: HIGH / P1**

The legacy `partner_payouts` table has one row with status `paid`, but no evidence in this read-only catalog/count pass proves bank transfer settlement, provider confirmation, beneficiary ownership or reconciliation. A separate newer payable/reconciliation path exists. Avoid mixing legacy payout rows with new payable/ledger records until a canonical source of truth and migration/transition rules are documented.

### PAY-11 — Payment lifecycle duplication across legacy and newer models
**Severity: HIGH / P1**

The live schema contains parallel payment/revenue representations: `payments`, `payment_orders`, `revenue_ledger`, `shipment_financials`, newer `krim_financial_transactions`, `krim_ledger_transactions/entries`, `krim_partner_payables`, `partner_payouts`, and newer refund request tables. Triggers bridge some legacy records into financial state. Without a canonical lifecycle map, a payment can be captured in one model while another ledger/payout model remains stale.

**Required action:** define the canonical payment aggregate and authoritative state machine. Document which records are immutable source events, operational projections, legacy compatibility views and accounting books. Add reconciliation assertions across all representations.

## 4. Specific test cases — NOT RUN

Only synthetic test data and an isolated Razorpay test-mode account may be used after Staging is approved.

1. Order creation: wrong customer, wrong organization, unaccepted quote, amount/currency tampering and stale quote are rejected.
2. Provider order creation timeout: retry with same idempotency key returns the same logical order and does not duplicate.
3. Webhook signature: invalid signature, missing signature, malformed body, wrong secret and replay are rejected or quarantined.
4. Duplicate event ID: second delivery causes no duplicate payment, ledger transaction, notification or shipment activation.
5. Out-of-order events: `order.paid`, `payment.authorized` and `payment.captured` cannot regress or falsely advance payment state.
6. Amount/currency/order mismatch: capture is quarantined; shipment is not activated.
7. Two different payment IDs for one order: only the correct captured payment is reconciled; conflict is quarantined.
8. Provider timeout after successful capture: retry reconciliation safely discovers prior result and does not double-post.
9. Ledger: debit equals credit per transaction and currency; all accounts belong to correct organization; immutable entries; unique source/idempotency.
10. Refund: wrong user/org, non-finance user, AAL1, creator self-approval, expired request, amount above refundable balance and duplicate request are rejected.
11. Refund execution: provider timeout and repeated webhook do not duplicate refunds; refund is linked to original payment; ledger reversal is exact.
12. Partner payout: only verified payable with approved amount and eligible partner is payable; duplicate payout reference is rejected; settlement confirmation reconciles to bank/provider evidence.
13. Payout failure/return: state and ledger reverse/recover correctly; partner notification only after verified settlement.
14. Chargeback/dispute: event is captured, frozen/escalated and reconciled without overwriting original payment.
15. Cross-tenant reads: customer and finance users cannot see other organizations' payments, refunds, payouts or ledger entries.
16. Reconciliation job: missing/late events, duplicate provider IDs, amount mismatch and unprocessed events generate actionable exceptions and retry safely.

All 16 tests remain **NOT TESTED**.

## 5. Required remediation order

1. **P0:** Investigate the four unprocessed webhook events using a controlled read-only reconciliation report; do not blindly replay.
2. **P0:** Close finance direct-write authorization gap (previous RLS report).
3. **P0:** Establish isolated Staging payment fixtures and Razorpay test-mode provider credentials/webhook endpoint.
4. **P0:** Complete double-entry posting and prove balanced/idempotent postings for capture, commission, partner payable, refund and reversal.
5. **P1:** Complete source audit of Razorpay Edge Functions: signature verification, raw-body handling, secret retrieval, amount/currency matching, event deduplication, retry behavior and provider timeout handling.
6. **P1:** Choose canonical payment, ledger and payout models; document legacy compatibility and prohibit ambiguous dual writes.
7. **P1:** Prove partner payout settlement against external bank/provider evidence before displaying paid.
8. **P2:** Add CI catalog checks for payment-table grants/RLS, unique indexes, function ACLs and ledger invariants.

## Evidence and safety statement

- Live read-only PostgreSQL catalog, RLS, grant, unique-index, trigger and aggregate count queries on Production and Staging.
- No payment/webhook/refund/payout/ledger function invoked; no provider HTTP request, Razorpay dashboard action, bank transfer, refund, email, notification, Storage operation, SQL DDL/DML, migration or policy/grant change.
- No webhook payload or payment personal/financial details were selected.
- All runtime tests above remain **NOT TESTED**. No release approval is implied by this source/catalog audit.
