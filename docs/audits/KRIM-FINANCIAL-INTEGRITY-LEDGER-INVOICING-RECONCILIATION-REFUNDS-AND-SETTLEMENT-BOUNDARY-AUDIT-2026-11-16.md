# KRIM Financial Integrity, Invoicing, Ledger, Reconciliation, Refund and Settlement Boundary Audit — 2026-11-16

## Executive decision
**NO-GO for enabling KRIM freight collection, payouts, refunds, split settlement, invoice issuance as a commercial service, or financial production workflows.** The production database has accounting/payment scaffolding and Razorpay controls, but the evidence is incomplete and internally inconsistent. Most importantly, the deployed Razorpay webhook does not enforce the same freight-collection kill switch as the order-creation and payment-verification endpoints. A valid captured-payment webhook for an existing order can still transition it to paid and invoke financial posting while the current partner-direct launch model says KRIM must not collect freight funds.

This is a read-only assurance audit. No payment provider was contacted, no webhook replayed, no payment/refund/payout/reconciliation RPC invoked, no invoice or ledger entry created, no credentials/secrets read, and no production data or schema changed.

## 1. Live production evidence

| Financial object | Rows / state |
|---|---:|
| Payment orders | 6 (5 `created`, 1 `paid`) |
| Legacy `payments` | 4 (2 `paid`, 2 `pending`) |
| Razorpay webhook events | 10 (6 `payment.authorized` processed; 2 `payment.captured` unprocessed; 2 `order.paid` unprocessed) |
| KRIM financial transactions | 1 completed payment credit, company ownership |
| Legacy revenue ledger | 1 row, `reconciled` |
| Legacy shipment financials | 1 row, status `paid`; customer payment `paid`; partner payout `paid` |
| Ledger accounts | 14 active |
| Ledger transactions / entries | 0 / 0 |
| Invoices / invoice items / applications | 0 / 0 / 0 |
| Financial accounts | 0 |
| Partner payables / settlements | 0 / 0 |
| Refund requests / refund events | 0 / 0 |
| Reconciliation runs / exceptions | 0 / 0 |
| Financial posting events / dead-letter rows | 0 / 0 |
| Revenue allocation rules / runs / allocations | 0 / 0 / 0 |
| Financial approval policies | 8 |
| Approval requests / approval events | 0 / 0 |
| Treasury control rules | 0 |
| Monitoring alerts | 0 |

The six `payment_orders` are all Razorpay INR orders and are shipment-bound; the available records include five still in `created` state and one `paid`. The provider's current order/payment status was not queried. The database alone cannot establish whether the orders used test or live credentials, whether funds actually settled, or whether the paid rows are test fixtures. These records must be reconciled before any future activation.

The ten webhook event rows include four captured/order-paid events still marked unprocessed. These may be retryable historical test events or unresolved production events; their status must not be silently reset or assumed harmless. No event replay was attempted.

The legacy `shipment_financials` row says the customer payment and partner payout are both paid, while the current partner payable and settlement tables are empty. This is not proof of a real partner payout. It is an inconsistency that requires source/provider/bank evidence and classification as test, legacy, or actual before the record is used in reporting. The one `revenue_ledger` row marked reconciled likewise does not prove provider-to-bank settlement.

## 2. P0 — Deployed Razorpay webhook bypasses the freight-collection kill switch
The canonical `create-global-razorpay-order` Edge Function checks both:
- `KRIM_FREIGHT_COLLECTION_ENABLED === "true"`
- `KRIM_FREIGHT_COLLECTION_APPROVAL_VERSION === "2026-11-15-v1"`

Without both values, new freight orders are rejected with HTTP 503. The `verify-razorpay-payment` endpoint also blocks verification of an unpaid order unless the same gate is enabled, while allowing idempotent recovery of an order already recorded as paid.

**The deployed and repository `razorpay-webhook` does not check either kill-switch variable.** After verifying the provider signature and matching provider order ID, payment ID, amount, currency and captured status, it:
1. conditionally changes the local `payment_orders` row to `paid`;
2. invokes `krim_internal_reconcile_razorpay_captured_payment`;
3. creates a completed `krim_financial_transactions` credit with `ownership_scope='company'`;
4. marks the webhook processed.

That internal RPC requires service role and validates the paid order, accepted quote, partner quote, accepted assignment, confirmed capacity binding/reservation and exact INR amount. Those are valuable integrity controls, but they do not replace the missing business-level freight-collection kill switch. A provider can still deliver a valid capture event for one of the existing open orders while the order-creation UI/API is disabled.

**Impact:** KRIM could record a partner-direct freight payment as a KRIM company receipt, contrary to the chosen non-custodial launch model. The four unprocessed capture/order-paid webhook records and five open payment orders make this an immediate release blocker until each is reconciled.

**Required remediation:** add a server-side collection-mode guard to the webhook before any paid-state or ledger mutation, while retaining a separate, narrowly scoped and auditable historical reconciliation path for already-captured payments. Test that a signed captured event cannot mutate a local order or ledger while collection is disabled. Do not deploy a fix until migration/source reconciliation and explicit production-change authorisation.

## 3. Payment capability registry correctly blocks checkout
The India/INR Razorpay capability row is `integration_status=implemented`, but:
- `checkout_enabled=false`
- `merchant_eligibility_verified=false`
- `presentment_supported=true`
- `settlement_supported=false`
- `refunds_supported=false`
- `fx_supported=false`

All other provider/country/currency combinations reviewed remain planned and disabled. This means the registry itself does not approve live checkout or settlement. The order-creation function additionally checks key mode and requires all merchant, presentment, settlement, refund and FX flags before live checkout. Do not change the registry to enable checkout merely because credentials exist or a test payment succeeded.

The actual Razorpay key mode, merchant KYC/category approval, settlement account, bank settlement and refund capability were not independently verified in this read-only review. No secrets were read.

## 4. P1 — Existing open payment orders need provider-side reconciliation
Five payment orders remain `created`. The order-creation function prevents replacement checkout when an existing open order is unresolved or its amount/currency conflicts, which is a positive safeguard. However, a local `created` state does not establish that the provider order is expired, cancelled or no longer payable.

Before public launch:
- reconcile every open local order against the Razorpay dashboard/provider API through an authorised operator;
- establish test/live mode, provider order state, amount/currency, customer, quote and provider payment history;
- cancel/expire provider-side orders where supported and authorised;
- preserve an immutable reconciliation record and ensure retries cannot create a second payable order;
- investigate the one local paid order and four paid legacy payment rows against provider transaction IDs and actual bank settlements.

No provider API call or dashboard action was performed.

## 5. P1 — Four captured/order-paid webhook events are unprocessed
The database has two `payment.captured` and two `order.paid` webhook records with `processed=false`. The handler stores a signed event before processing and leaves it retryable when a matching financial transaction cannot be reconciled. This is safer than falsely acknowledging success, but there is no demonstrated operator queue, alert, recovery SLA or completed reconciliation for these four events.

Do not replay them until each event has been matched to:
- exact local payment order and provider order;
- provider payment ID, captured status, exact amount and currency;
- accepted quote and partner quote;
- accepted assignment and confirmed capacity reservation;
- local financial transaction and idempotency reference;
- provider settlement statement and bank credit, if settlement actually occurred.

An authorised operator must classify each as duplicate, test event, failed/incomplete or real captured payment and record the evidence. Never mark an event processed manually just to clear the queue.

## 6. P1 — Legacy split/revenue records conflict with the current non-custodial model
Legacy tables still represent a single customer amount, partner cost, platform margin, platform commission and partner payout. One `shipment_financials` row currently says both customer payment and partner payout are paid; one `revenue_ledger` row is marked reconciled. Yet there are zero partner payables, zero settlements, zero bank/financial accounts and zero current invoice or payout records.

The newer canonical financial transaction table has one completed payment credit with `ownership_scope='company'`. This is exactly the kind of company-owned freight receipt that the current partner-direct model must not create for new transactions.

**Required remediation:** classify and reconcile historical rows as test/legacy/actual; remove old 10/90 split and partner-payout assumptions from new commercial workflows; never use freight GMV, partner freight collections or partner payout as KRIM revenue. KRIM's own referral/coordination/platform fee must be separately contracted, invoiced and accounted for only after legal/tax/bank readiness. Do not delete or rewrite historical financial records without a documented accounting adjustment and approval.

## 7. P1 — Revenue-allocation tables permit organisation members to write financial rules
The three tables `krim_revenue_allocation_rules`, `krim_revenue_allocation_runs` and `krim_revenue_allocations` have RLS enabled, but authenticated users have direct INSERT, UPDATE and DELETE table privileges. Their only reviewed authenticated policy is `org_isolation_all`, which checks organisation membership/access, not a finance-specific permission, AAL2, maker-checker approval or immutable accounting role. Thus an ordinary active organisation member may be able to create or alter allocation data inside their organisation.

All three tables currently contain zero rows, so no existing allocations were found. Empty tables do not make the write policy safe.

**Required remediation:** remove broad direct authenticated DML and expose only narrow finance-authorised server-side operations with AAL2, finance-specific permissions, immutable event history, independent approval and strict organisation/beneficiary/source checks. Do not change grants/policies until migration reconciliation and explicit authorisation.

By contrast, `shipment_financials` has authenticated DML table grants but the reviewed authenticated RLS policy is explicitly `USING(false)` and `WITH CHECK(false)`; direct writes should therefore be denied by RLS. Preserve that deny posture until the legacy table is retired safely.

## 8. Ledger and double-entry controls — useful foundations, not operationally proven
The ledger has 14 active accounts but zero ledger transactions and zero entries. The internal ledger-posting functions require positive amounts, distinct debit/credit accounts, active same-organisation accounts and matching currency. A newer overload also requires an open accounting period and writes an audit event.

However, two posting-function overloads treat an existing transaction reference/number as idempotent without visibly comparing the full incoming payload (amount, currency, transaction type, source and debit/credit account identities) with the original transaction. A conflicting retry may be returned as successful idempotency instead of rejected as a fingerprint conflict. This needs a full-payload fingerprint and immutable source binding before the ledger is relied on.

No live double-entry balancing, trial balance, period close, reversal, FX revaluation, bank reconciliation or financial-statement test was run. The empty ledger entries mean the architecture is not certified.

## 9. Invoices, revenue recognition and partner settlement — incomplete
There are no customer or partner invoices, invoice items, invoice-payment applications, partner payables or settlements. The invoice and receivable functions exist but have no live lifecycle evidence. There are zero finance accounts and zero treasury control rules.

The partner-settlement authorisation function requires an approved payable, active `partner_funds` treasury control rule and (when required) a matching financial approval; it then changes the payable to `scheduled`. No active treasury control rules or payables exist, so the reviewed path should fail closed. This function is an authorisation/scheduling step, not proof of a provider payout. The partner payout reconciliation function requires a matching completed provider payout transaction and reference, but no such records exist.

No bank account, payment rail, payout provider, bank statement ingestion or independent bank reconciliation has been verified. A ledger status of `reconciled` is not a substitute for an external bank/provider statement match.

## 10. Refund controls — code is gated, no refund evidence exists
The deployed `execute-razorpay-refund` function requires both `KRIM_LEGACY_REFUND_EXECUTION_ENABLED=true` and approval version `2026-11-15-v1` before initiating a provider refund. Its database claim function is intended to enforce AAL2, finance permission, reviewer separation, full amount and payment state; the function then uses a stable idempotency key. The webhook validates the provider refund ID, original payment ID, full amount and currency, approved request and records the financial debit.

This is a useful fail-closed design for legacy refunds, but zero refund requests/events exist and no end-to-end test has been run. The approval secret values were not inspected. Do not enable refund execution for new freight flows under the current partner-direct model. Historical platform-collected refunds must be reconciled individually and only with explicit approval.

## 11. Provider retirement and legacy endpoints
- `create-razorpay-order` and `process-payment--` are active deployed stubs that return HTTP 410 and identify themselves as retired.
- Cashfree create-order, verify-payment and webhook endpoints remain deployed as active stubs returning HTTP 410. They do not initiate Cashfree operations in the inspected source, but should be removed/disabled only after route/dependency checks and explicit authorisation.
- The canonical Razorpay order and verify functions are the only current checkout path reviewed. Their guards do not solve the webhook bypass above.
- No Cashfree credentials or provider calls were used.

## 12. Reconciliation and monitoring gaps
There are zero reconciliation runs, exceptions, financial posting events, dead-letter rows or monitoring alerts. The internal reconciliation routines reviewed primarily scan legacy `payments` and partner payables against internal ledger/financial transaction records; they do not demonstrate a completed provider-to-bank reconciliation for the canonical `payment_orders` flow. No external provider settlement statement or bank feed was imported.

Before finance can be called production-ready, implement and evidence:
- provider order/payment/refund/settlement statement ingestion with signature/source provenance;
- canonical payment-order to provider transaction matching;
- exact amount/currency and fee/tax/chargeback variance handling;
- bank statement to provider payout reconciliation;
- double-entry posting and immutable reversal/correction records;
- unprocessed webhook/ledger event alerting, retries, DLQ ownership and operator runbooks;
- independent review and period-close controls;
- RPO/RTO, backup and restore proof for financial records.

## 13. Staging acceptance tests — not run
1. With freight collection disabled, create-order endpoint rejects before any provider call.
2. With freight collection disabled, signed captured/order-paid webhook cannot mutate payment order or ledger.
3. Paid-order recovery path only accepts the exact same provider payment ID and matching financial transaction.
4. A provider event with wrong order, payment ID, amount, currency or capture state is rejected and remains retryable.
5. Duplicate concurrent webhook deliveries create exactly one financial transaction and one processed event.
6. Conflicting payment IDs for an already-paid order trigger manual reconciliation, never overwrite.
7. Every open local order is reconciled against provider state before retry or cancellation.
8. Payment order, accepted quote, partner quote, assignment, capacity binding and reservation match exact shipment/customer/partner/amount/currency.
9. Legacy 10/90 or company-owned freight ledger paths are blocked for the partner-direct launch model.
10. KRIM own service fee is a separate invoice/receivable from partner freight.
11. Revenue allocation DML is denied to ordinary organisation members and requires finance permission/AAL2.
12. Reused ledger idempotency reference with any changed financial field is rejected as a conflict.
13. Debits and credits balance by transaction and currency; cross-currency entries require approved FX evidence.
14. Invoice totals, tax, credits, payments and outstanding balances reconcile exactly.
15. Partner payout is impossible without verified payable, independent approval, treasury rule and confirmed provider/bank payout.
16. Refund request, reviewer separation, full-amount check, provider idempotency and signed webhook are enforced end to end.
17. Provider settlement statement and bank statement reconcile to canonical payment and ledger records.
18. Webhook/DLQ failures generate operator alerts and are recoverable without duplicate posting.
19. Cross-tenant finance/ledger/invoice/refund/settlement data remains isolated.
20. Backup and restore drill preserves financial history and audit events.

All tests remain unexecuted. No payment, refund, payout, invoice, ledger, reconciliation or provider operation was initiated.

## 14. Release decision and remediation order
**NO-GO** for financial collection, split settlement, partner payouts, refunds, live invoicing or commercial finance operations.

Priority:
- **P0:** close the Razorpay webhook kill-switch bypass; ensure existing open provider orders cannot be paid/reconciled through a disabled launch path; reconcile the four unprocessed captured/order-paid events and one paid order.
- **P1:** investigate and classify all historical payment/revenue/split rows; reconcile actual provider and bank evidence; do not count these as KRIM revenue.
- **P1:** remove broad organisation-member DML on revenue allocation tables and require finance-specific AAL2/approval.
- **P1:** enforce full-payload idempotency on ledger posting and reconcile canonical payment orders, provider statements and bank settlement.
- **P1:** verify invoice, payable, refund, settlement and finance approval workflows in staging.
- **Final financial phase only:** after the user explicitly authorises it, business bank/accounting/tax/legal readiness and executed agreements, implement KRIM's own service-fee invoicing/collection. Keep partner freight funds outside KRIM.

## Change boundary
Read-only review of production tables, row counts/status groupings, grants, RLS policies, function definitions, deployed Edge Function source and repository source. No DDL/DML, migration, RPC invocation, webhook replay, provider API call, payment/refund/payout, bank action or credential read. Production/repository migration-history mismatch remains unresolved; do not apply/replay/baseline/squash migrations or corrective production DDL until schema-manifest reconciliation and separate authorisation.
