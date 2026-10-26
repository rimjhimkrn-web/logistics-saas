# KRIM Logistics — Step 7: Payment & Financial Integrity
Audit date: 2026-10-26
Project: Supabase Production (project ID ebltviniygljwwseplph)

## Status
IN PROGRESS — not approved for live payments. This report records the verified baseline and the evidence still required; it does not claim an end-to-end pass.

## Verified baseline
- Six payment orders have corresponding canonical financial transaction rows.
- No order/transaction status mismatches were found in the prior live audit.
- The one paid order has matching canonical transaction status and provider references.
- Duplicate webhook event IDs are constrained by a database uniqueness rule.
- Deployed Razorpay webhook requires a signature and event ID, validates HMAC against the raw request body, checks expected amount/currency for captured payments, refuses unknown KRIM order references, and avoids downgrading an already-paid order on a failed-payment event.
- Razorpay remains the only enabled checkout provider; Cashfree is retired. Test mode only.

## Exceptions retained without mutation
Four historical webhook rows remain unprocessed and do not match current KRIM payment-order references:
- TcEpXov9phY1ZH — payment.captured — order_TcEpB7Uc1oPUkc / pay_TcEpQ7MxNc6CE2
- TcEpYBhACFa8hz — order.paid — order_TcEpB7Uc1oPUkc / pay_TcEpQ7MxNc6CE2
- TcHDuryyICLOdc — payment.captured — order_TcHDidOsXqFxwn / pay_TcHDpni9KUIexp
- TcHDvIRaDrXO4b — order.paid — order_TcHDidOsXqFxwn / pay_TcHDpni9KUIexp

These must remain exceptions until matched to provider dashboard evidence or another authoritative record. Do not mark processed or delete them merely to clear the queue.

## Reconciliation gap
- One shipment_financials row references legacy shipment ID 14 and reports INR 5,000 customer amount / INR 3,000 partner cost / INR 2,000 platform margin.
- One revenue_ledger row references shipment code SHP-2026-001 and reports INR 12,500 total / INR 11,250 partner payout / INR 1,250 platform commission.
- The relationship between these rows and the canonical payment-order records is not established. No financial row was changed.
- Historical payout/payment statuses are not proof of actual settlement without provider/bank evidence.

## Acceptance tests still required
1. Successful captured test payment: order, canonical transaction, shipment status, ledger allocation, and notifications agree.
2. Failed payment: order becomes failed without falsely marking shipment paid; a later legitimate retry can be handled.
3. Duplicate webhook delivery: no duplicate transaction, ledger allocation, or payout.
4. Concurrent/retried delivery: safe idempotent final state and retryable response when processing is incomplete.
5. Unmatched/incorrect amount/currency/provider order: fail closed and remain auditable.
6. Partner payout: payout is created only from a valid payable/assignment and reconciles to provider settlement evidence.
7. Full database re-check and documented test results.

## Blockers to close Step 7
- Controlled authenticated test payments and webhook retries have not been executed from this environment; no invocation/test harness is available here to safely simulate provider-signed requests against the deployed function.
- The database SQL execution tool was blocked by safety checks during this audit, preventing fresh read-only reconciliation queries.
- Provider dashboard evidence for the four historical events and any actual settlement/payout is not available in this audit context.
- Active approved commercial rate cards are currently zero, so a valid customer booking-to-payment end-to-end test is blocked upstream until Step 3 supplies an approved rate card.

## Safety decision
Do not enable live payments or declare Step 7 complete until the acceptance tests pass and the exceptions/reconciliation are resolved with evidence. No production financial records were modified for this audit.
