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


## Additional live database verification (2026-10-26)
Fresh read-only queries were successfully run after the initial audit:
- All six canonical transaction rows match their payment-order amount, currency, and Razorpay order reference.
- Five orders are still `created`; one order is `paid` for KRIM shipment 15 (INR 35,000 / 3,500,000 paise). Its transaction is `paid`, provider order/payment references match, and `verified_at` is present.
- KRIM shipments 10–15 currently show `confirmed`; this status alone is not evidence that their payment and financial allocation chain is reconciled.
- The historical `shipment_financials` row for legacy shipment 14 has `krim_shipment_id = NULL`, customer amount INR 5,000, partner cost INR 3,000, and platform margin INR 2,000.
- The only legacy `partner_payouts` row is INR 3,000, marked `paid`, with transaction reference `TEST-PAYOUT-002`, legacy shipment 14, and no KRIM shipment link. This is test-labelled historical data, not evidence of a real payout.
- The only `revenue_ledger` row is shipment reference `SHP-2026-001`, INR 12,500, partner payout INR 11,250, commission INR 1,250, marked `reconciled`. It does not map to the current KRIM shipment numbers 10–15 on the evidence inspected.
- Therefore the paid INR 35,000 order for shipment 15 has a matching canonical transaction, but the reviewed legacy ledger/payout records do not prove a complete linked financial lifecycle for it.

## Final gate decision
Database consistency checks for the six order/transaction pairs pass. The full Step 7 acceptance criteria do not pass: the four historical events remain unmatched, ledger/payout lineage is not proven, and provider-signed success/failure/duplicate/retry tests have not been executed. Do not modify historical statuses to make these checks appear green. This is a real blocker requiring provider evidence and a controlled test session, not a documentation-only issue.


## Automated regression coverage update (2026-10-26)
Added Step 7 static regression assertions to `scripts/krim-production-smoke.mjs` for raw-body signature handling, constant-time signature comparison, failed-payment no-downgrade, conditional captured-payment transition, conflicting paid-payment protection, webhook finalization, retryable concurrent delivery, and unsupported-event fail-closed behavior.
- Regression-guard commit: `955ebbe1e2b3b7876c56e866372ff199148d51e5`
- Follow-up assertion correction: `f9319a862992c8f2dad35451d6dfc7a4549e6245`
- GitHub Actions smoke workflow: **PASS** on `f9319a862992c8f2dad35451d6dfc7a4549e6245` — https://github.com/rimjhimkrn-web/logistics-saas/actions/runs/40259864259
This passing workflow is source-level regression coverage only; it does not simulate Razorpay-signed webhook deliveries or prove settlement/reconciliation.


## Latest CI confirmation (2026-10-26)
The current main-branch commit `46132fce08f76642320796e3c450186e5dd2274b` passed the **KRIM production smoke checks** workflow (run `40259901363`) and the **KRIM static link audit** workflow (run `40259901351`). The Pages build/deployment workflow (run `40259900829`) also completed successfully. The smoke job explicitly passed both `scripts/krim-production-smoke.mjs` and `scripts/krim-complete-static-audit.mjs`.
These are repository/source checks and successful Pages deployment only. They do not replace provider-signed webhook delivery tests, settlement evidence, or approved rate-card-backed booking-to-payment testing.


## Fresh follow-up audit — 5 November 2026

### Current production snapshot (read-only)
- `payment_orders`: 6 total — 5 `created`, 1 `paid`; all six use Razorpay and INR. The five created orders (shipments 10–14) have Razorpay order IDs but no payment IDs. The paid order is shipment 15 for INR 35,000.
- `krim_financial_transactions`: 1 row. It matches the paid order for shipment 15 at INR 35,000 / INR 35,000 equivalent, provider Razorpay and payment reference `pay_TgZLYhQF6oenEG`; its canonical transaction status is `completed` while the checkout order status is `paid`. This is the expected semantic mapping, not a duplicate transaction.
- `payment_webhook_events`: 10 total — 6 processed and 4 unprocessed. The four historical unprocessed events listed above remain unmatched. No event was modified.
- `krim_inbound_webhook_events`: 0.
- `krim_partner_payables`: 0. Legacy `shipment_financials`, `partner_payouts` and `revenue_ledger` each still contain one row, but their shipment references do not establish a canonical relationship to shipment 15. No historical financial rows were altered.
- Direct authenticated table policies on payment orders and financial transactions are SELECT-only; financial tables have RLS enabled. Payment-order unique constraints protect Razorpay order/payment IDs and one open order per quote. Financial transaction provider-reference and idempotency indexes are unique.
- Capability registry: India/INR/Razorpay is marked implemented with checkout enabled for the sandbox path, but merchant eligibility, settlement, refunds and FX are not verified. All other country/provider/currency combinations remain planned and checkout-disabled. The deployed order-creation function blocks live-key checkout until those capabilities are evidence-backed and approved.

### Edge Function state
- Razorpay webhook remains ACTIVE (v15), `verify_jwt=false` as required for provider delivery, but verifies the Razorpay signature over the raw request body, requires an event ID, deduplicates events, validates captured amount/currency, fails closed on unknown order references and protects paid orders from failed-event downgrades.
- Global Razorpay order creation remains ACTIVE (v15), requires a signed-in customer, accepted customer quote, accepted partner assignment, confirmed capacity binding and matching confirmed capacity reservation. It checks key mode and blocks live checkout while merchant eligibility, settlement, refunds and FX remain unverified.
- `verify-razorpay-payment` was found to re-check accepted quote/assignment but not the capacity reservation, unlike order creation. Updated the deployed function to v13 and committed source at `supabase/functions/verify-razorpay-payment/index.ts` (commit `eb81cb5296b917dda36a274baa4a035626d4edff`). It now requires the exact assignment's confirmed capacity binding and matching confirmed reservation before verifying any unpaid order. Migration is not required; this is Edge Function code.
- Legacy `create-razorpay-order`, `process-payment--`, Cashfree order/verification and Cashfree webhook endpoints remain deployed as ACTIVE names but their current function bodies return HTTP 410 with `PAYMENT_ENDPOINT_RETIRED` / `PAYMENT_ENDPOINT_RETIRED`-style codes. They are not active checkout paths; do not mistake their ACTIVE deployment status for an enabled provider.
- No provider secret values were read, no live/sandbox payment was initiated, no webhook was replayed, and no payout was attempted.

### Current decision
Step 7 remains **IN PROGRESS / NOT LIVE-APPROVED**. The source-level capacity-verification gap is corrected. The four unmatched historical events, five old created orders, legacy ledger lineage, absent payable rows, and unverified live merchant/settlement/refund/FX evidence remain blockers. The approved rate-card/partner/capacity chain and controlled signed test events are also required before launch. Do not turn on live checkout or alter unmatched historical events to force a green status.

- Extended `scripts/krim-production-smoke.mjs` with static regression assertions requiring `verify-razorpay-payment` to re-check the accepted assignment's exact capacity binding and matching confirmed reservation, including fail-closed error codes. This ensures the newly fixed verification gate is covered by future CI runs.


### Additional reconciliation and finance UI follow-up — 5 November 2026
- Inspected the four unprocessed webhook rows without changing them. They form two old event pairs (`payment.captured` + `order.paid`) that reference provider order IDs absent from the six current canonical `payment_orders` records. One pair carries a legacy shipment-14 note, but the canonical shipment-14 payment order has a different provider order reference. The historical rows therefore cannot safely be auto-attached to the current canonical order or transaction. They remain quarantined/unprocessed pending provider-dashboard evidence and a documented manual reconciliation; no event was replayed, marked ignored, or deleted.
- The five old `created` payment orders were created in September and have no payment IDs. Their provider orders may still exist or have been expired externally; no automatic cancellation or state rewrite was attempted.
- Added read-only, RLS-scoped data registers to `app/finance/payment-processing.html` (payment orders) and `app/finance/partner-settlements.html` (partner payables). These show only rows returned by current Supabase policies, escape displayed values, show unavailable errors distinctly from zero rows, and add no financial write paths. Both page scripts pass JavaScript syntax validation.
- CI passed static-link audit and production smoke checks for commit `6c5b943df63550a1a8f1b5c0b0b49a1d610ca63f`; the follow-up finance-register commit and combined head are awaiting final CI/deployment completion.
