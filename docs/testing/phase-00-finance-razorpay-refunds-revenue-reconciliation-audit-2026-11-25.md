# Phase 00 — Finance, Razorpay, refunds, revenue ledger and reconciliation audit
Date: 2026-11-25
Branch: qa/phase-00-baseline-2026-11-25
Method: read-only SQL inspection of Production and Staging table counts, payment/refund state aggregates, selected public function ACLs, RLS policies and table schemas. No payment/order/refund/payout/reconciliation function was invoked. No provider API, webhook, bank, email or other external side effect was triggered.

## Exact table counts

| Table | Production | Staging |
|---|---:|---:|
| krim_financial_transactions | 1 | 0 |
| krim_ledger_accounts | 14 | 0 |
| krim_ledger_entries | 0 | 0 |
| krim_ledger_transactions | 0 | 0 |
| krim_refund_requests | 0 | 0 |
| krim_financial_reconciliations | 0 | 0 |
| payment_orders | 6 | 0 |
| payment_webhook_events | 10 | 0 |
| payments | 4 | 0 |
| revenue_ledger | 1 | 0 |
| shipment_financials | 1 | 0 |
| partner_payouts | 1 | 0 |
| krim_invoices | 0 | 0 |

Production state aggregates:
- payment_orders: 1 paid, 5 created.
- payments: 2 paid, 2 pending.
- payment_webhook_events: 6 processed, 4 unprocessed.
- partner_payouts: 1 paid.
- revenue_ledger: 1 reconciled.
- shipment_financials: 1 paid.
- refund requests: 0.
Staging has zero rows in all listed financial/payment tables.

These rows may be historical test or operational data; this read-only audit does not establish that any real money moved or that a payout reached a bank. Reconcile provider dashboard/bank evidence before treating status labels as proof of settlement.

## Critical financial consistency gaps

1. **Four webhook events remain unprocessed in Production.** The admin reconciliation listing function can expose masked event/order references and matching order status, but the actual four event payloads were not inspected in this audit and no replay was attempted. Triage each event against the matching payment order and provider dashboard before any processing.
2. **The canonical double-entry ledger is empty in Production:** 14 ledger accounts exist but there are zero ledger transactions and zero ledger entries. A single legacy `revenue_ledger` row and a single `shipment_financials` row do not establish a balanced journal.
3. **Staging financial subsystem is unseeded:** all core finance/payment tables listed above have zero rows, so no realistic reconciliation or refund lifecycle can be executed yet.
4. **Refund lifecycle is untested:** no refund requests exist. Source/ACL review is not evidence of refund provider execution or idempotent completion.
5. **Invoice lifecycle is untested:** no invoices or invoice payment applications exist.
6. **Payout status is not bank settlement proof:** one legacy payout row is marked paid; its bank/provider settlement evidence was not verified. Current finance model previously reviewed describes partner-direct contracting, not KRIM escrow or automatic partner disbursement. Do not represent KRIM as holding freight funds or paying partners automatically without evidence and legal/payment-provider approval.

## Function ACL parity

Selected functions and authenticated EXECUTE state:

| Function | Production | Staging |
|---|---:|---:|
| krim_claim_razorpay_refund_execution | yes | no |
| krim_finance_list_revenue_ledger | yes | no |
| krim_refund_request_review | yes | no |
| krim_refund_request_submit | yes | no |
| Internal financial posting/reconciliation functions | no | no |

The internal functions are SECURITY DEFINER and not directly executable by anon/authenticated, which is consistent with a private orchestration boundary. However, the four client-facing finance/refund functions are granted in Production and not Staging. This is a material environment parity blocker. Do not mirror grants automatically: inspect the complete private implementations, intended Staging callers, AAL/permission checks, provider guards and project isolation before preparing least-privilege changes.

## RLS observations

- `payment_orders` SELECT is scoped to the customer or an active finance organization with finance.view.
- `payments` SELECT is scoped to the owning customer.
- `payment_webhook_events` denies authenticated direct table access.
- `krim_payment_capability_registry` denies anon and authenticated direct access.
- `shipment_financials` denies anon and authenticated direct access.
- `revenue_ledger` has customer-organization/finance read scopes and service-role full access.
- Refund request/event SELECT is scoped to the customer/organization or finance permission.
- Canonical ledger transactions/entries are organization-scoped read-only to authenticated clients.
These are policy-source observations only. No distinct JWT cross-organization read/write tests were run.

## Existing architecture / business-model caution

- Razorpay payment order and webhook records exist in Production, but the exact real-money status was not independently confirmed with Razorpay.
- Legacy functions such as `complete_partner_payout` and `create_partner_payout` rely on the legacy `user_roles` admin role check and legacy shipment tables; these should not be assumed equivalent to the newer KRIM organization/AAL2 permission model.
- Legacy payment triggers can populate `shipment_financials` on a paid event with `partner_cost = 0` and use `ON CONFLICT DO NOTHING`; confirm this cannot create incomplete/incorrect finance rows for KRIM-native shipments.
- Current ledger table counts show no balanced posting evidence, so commission, partner payable, tax, refund and fee calculations must not be considered production-proven.

## Required next gates

1. Reconcile all four unprocessed webhook events read-only against payment orders and Razorpay dashboard records; do not replay until reviewed.
2. Inspect exact payment-order creation, webhook verification, capture reconciliation, refund submit/review/claim/finish, posting event, recovery and reconciliation function bodies in both environments.
3. Build a safe Staging provider sink/mock with project-ref assertion and explicit no-network mode; seed only isolated synthetic organizations/users after approval.
4. Verify amount/currency/signature/order binding, duplicate and out-of-order webhook, wrong payment/order, concurrent capture, partial/full refund, duplicate refund, failure/retry/dead-letter, ledger balance, FX/base-currency, fee/tax, idempotency and reconciliation exception handling.
5. Test finance RLS with customer, partner, finance, operations and admin JWTs, including wrong organization and least privilege.
6. Define KRIM's commercial model clearly: platform commission/service fee invoicing vs partner-direct freight contracting; do not conflate gross freight value, KRIM revenue, GST/tax, partner payable or funds held.
7. Obtain accountant/legal/payment-provider confirmation for GST invoicing, marketplace/intermediary classification, payment aggregation/settlement structure, refund liability and any payout/escrow arrangement before accepting live transactions.

## Decision
Finance/payment/refund/revenue workflows are **NOT VERIFIED for real transactions**. Production contains a small set of financial records, including four unprocessed webhook events, but the canonical double-entry ledger is empty and Staging has no finance seed data. Environment ACL drift remains. No financial or provider action was performed; no real-money movement is claimed.
