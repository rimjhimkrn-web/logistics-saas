# KRIM Financial Integrity, Payment Reconciliation and Revenue Separation Audit — 2026-11-16

## Scope and safety
Read-only audit of production payment, webhook, payout, invoice, refund, financial transaction, revenue ledger and shipment-finance records; relevant database functions and triggers. No payment, refund, payout, webhook replay, ledger posting, reconciliation, or other business function was executed. No production data or schema was changed. Provider references, customer identities and payment payloads were not exported into this report.

## Live production inventory

| Financial object | Rows |
|---|---:|
| Razorpay payment orders | 6 |
| Legacy payments | 4 |
| Payment webhook events | 10 |
| Partner payouts (legacy table) | 1 |
| Refund requests | 0 |
| KRIM invoices | 0 |
| Invoice items | 0 |
| Invoice payment applications | 0 |
| Canonical financial transactions | 1 |
| Canonical ledger transactions | 0 |
| Canonical ledger entries | 0 |
| Legacy revenue ledger | 1 |
| Shipment financial summaries | 1 |
| Customer referrals | 0 |
| Financial reconciliations | 0 |
| Reconciliation exceptions | 0 |
| Financial posting events | 0 |
| Financial posting dead-letter rows | 0 |

## Status-level observations

- Payment orders: 5 `created`, 1 `paid`; all six use Razorpay and INR.
- Legacy payments: 2 `paid`, 2 `pending`; currency_code is null on the inspected rows.
- Webhooks: 6 `payment.authorized` processed; 2 `order.paid` unprocessed; 2 `payment.captured` unprocessed.
- Partner payout: 1 row marked `paid`.
- Refund requests: none.
- Canonical financial transaction: 1 completed payment credit.
- Legacy revenue ledger: 1 row marked `reconciled`.
- Shipment financial summary: 1 row marked paid / paid.

The presence of test-like or historical records does not prove real customer collections, real provider payouts, or KRIM revenue. No provider dashboard/bank settlement evidence was independently accessed.

## Integrity checks

### P1 — Unprocessed payment-capture webhooks
Four webhook events remain unprocessed: two `order.paid` and two `payment.captured`. The current aggregate check found four unprocessed webhook rows without a matching payment order using the available order-ID extraction paths. One paid payment order has no processed webhook event under the inspected matching rule.

This is a reconciliation exception, not proof that funds were lost or that the provider failed. Webhook matching must account for event-specific Razorpay payload shapes and payment/order relationships. Do not blindly replay events. First reconcile each provider event against Razorpay order/payment records and the corresponding internal order, then process idempotently with an auditable disposition.

### P1 — Legacy payment model is disconnected from current payment orders
The four legacy `payments` rows have no join to the six `payment_orders` through `razorpay_order_id` in the current snapshot. Legacy payment currency is null. The legacy table and canonical Razorpay payment-order model must not be combined in dashboards or reports as if they were one reconciled source of truth.

### P1 — Legacy revenue ledger references no canonical shipment
The one `revenue_ledger` row's shipment reference does not match any `krim_shipments.id`. This is likely legacy or differently keyed data, but cannot be counted as validated current shipment revenue without a source mapping and accounting evidence. Its `reconciled` status alone is not sufficient proof of a complete reconciliation.

### P1 — Legacy partner payout path is unsafe for the new non-custodial model
The old `create_partner_payout(bigint)` function reads partner assignment and shipment financial data from legacy `shipment_requests`, then creates a row in legacy `partner_payouts`. The legacy `complete_partner_payout` function allows an admin-role check and marks the payout paid from a supplied transaction reference; it also updates `shipment_financials`. These functions do not prove an external bank/provider payout occurred. They are not aligned with KRIM's current non-custodial referral/coordination model and must not be used to pay partner freight or to imply that KRIM holds or settles partner funds.

The newer canonical payable reconciliation routines require a payable already settled/paid and a provider reference, then verify matching completed partner-payout financial transaction details. These internal routines are not an authorization to initiate payouts and are not evidence of a real provider settlement in the current zero-row canonical payable/posting state.

### P1 — Finance posting queues are empty, but no double-entry ledger activity exists
Canonical ledger transaction and entry counts are zero; posting event and dead-letter counts are also zero. This is not necessarily a defect while the system has no validated commercial activity, but it means double-entry posting, retries, dead-letter recovery and reconciliation have not been demonstrated with real end-to-end transactions.

### P2 — Invoice and refund workflows are foundations, not operational evidence
No invoices, invoice lines, invoice payment applications or refund requests exist. The refund workflow reviewed previously is full-refund-only and gated by finance/platform AAL2 approval and a provider execution claim. The execution claim returns provider details for an external Razorpay action; it does not itself prove the provider executed or settled the refund. Provider webhook and bank reconciliation remain required.

## Revenue ownership and non-custodial policy

KRIM's initial model is:
1. Customer contracts with and pays the logistics partner directly for freight.
2. Partner performs the physical logistics service.
3. KRIM separately earns a documented referral/coordination fee for a service it actually provides.
4. KRIM does not receive, pool, hold, escrow, split, settle or pay out partner freight funds.

Therefore:
- Freight GMV and partner freight collections are not KRIM revenue.
- Partner freight cost and partner payout are not KRIM revenue or a KRIM payable under the initial model.
- Only an agreed KRIM service/referral fee, supported by a signed agreement, referral attribution, evidence of service, invoice and collection, may be recognized as KRIM revenue.
- Tax treatment, GST registration/invoicing and accounting policy require qualified CA review; this model is not automatically GST-exempt.
- Razorpay payment collection should remain disabled for partner freight unless the business model and regulatory/legal approvals are deliberately changed. If used later for KRIM's own service fee, use a separately identified KRIM fee product/order, not the partner freight quote total.

## Security and control observations

- The legacy `create_partner_payout` and `complete_partner_payout` SECURITY DEFINER functions are not executable by anon/authenticated in the inspected effective privilege check, but they remain legacy privileged code and should be removed or quarantined only through a reconciled migration after dependency review.
- Finance posting and payout internal routines are not publicly executable in the inspected grant snapshot.
- Earlier review found authenticated users can directly mutate/delete `krim_financial_posting_events` and `krim_financial_posting_dlq` rows under organization-scoped ALL policies. These require direct-write revocation and worker/authorized finance-only access after migration reconciliation.
- Refund execution remains separate from refund approval and requires provider-side confirmation and subsequent reconciliation.
- Never treat a UI success message, admin-supplied transaction string, processed webhook flag, or legacy `reconciled` status alone as proof of money movement.

## Required staging and reconciliation tests
1. Match each Razorpay event to exactly one order/payment using event-specific payload parsing; unknown/mismatched references are quarantined.
2. Duplicate webhook deliveries produce one payment and one canonical financial transaction.
3. Out-of-order authorized/captured/order-paid events cannot downgrade a paid order or create duplicate postings.
4. Amount, currency, provider order ID, provider payment ID, customer org and shipment/quote binding all match before marking paid.
5. A paid state requires a provider-captured payment and verified webhook signature, not merely order creation or authorization.
6. Failed, partial, reversed and refunded payment states are idempotent and reconcile to provider records.
7. Reconciliation detects unmatched internal rows and unmatched provider rows without guessing a join.
8. Legacy payments and revenue rows are mapped or explicitly quarantined; null currency and legacy shipment references cannot be silently accepted.
9. Partner freight is paid directly to the partner under the current model; KRIM cannot create partner freight payout instructions or mark freight as KRIM-collected.
10. KRIM fee referral attribution requires an active written agreement, defined fee basis, qualifying event, evidence, approved tax treatment, invoice and collection.
11. Double-entry ledger postings balance by currency, entity, ownership scope and source; idempotency prevents duplicate posting.
12. Refund approval and provider execution are distinct states; only provider-confirmed refund is marked completed.
13. Bank/provider settlement statements reconcile independently to captured payments and refund/payout references.
14. Finance posting queues cannot be modified directly by ordinary organization members; worker actions are auditable and recoverable.

## Release decision
**Do not enable live freight collection, split settlement, partner payouts or automatic revenue recognition.** The current non-custodial referral model is the safer initial operating design, subject to CA/legal review and real partner agreements.

The live system has payment-order and webhook foundations, but contains unprocessed capture events, disconnected legacy payment/revenue data, a legacy payout record, no canonical double-entry ledger entries, no invoice/refund activity, and no reconciliation run. No production financial activity should be inferred from these rows until source evidence is reconciled.

Migration history remains materially divergent between repository and production. Do not patch production finance tables, triggers, grants or functions until the schema export manifest is decrypted and reconciled, and all changes are delivered as reviewed migrations with staging tests.
