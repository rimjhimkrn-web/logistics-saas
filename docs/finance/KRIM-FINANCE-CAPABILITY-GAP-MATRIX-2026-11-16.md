# KRIM Finance Capability Gap Matrix — 16 November 2026

**Scope:** Read-only inventory of selected live production finance tables and release implications. Counts are point-in-time row counts across the queried tables, not a statement of completeness, correctness, revenue or cash balance.

## 1. Live data inventory

| Production table | Rows | What this establishes | What it does not establish |
|---|---:|---|---|
| `krim_customer_referrals` | 0 | No referral records currently stored here | No evidence of qualified/completed referrals or earned referral fees |
| `krim_invoices` | 0 | No invoice records in this table | No KRIM receivables or invoice-backed revenue |
| `krim_invoice_items` | 0 | No invoice line items | No billable KRIM service evidence |
| `krim_invoice_payment_applications` | 0 | No payment applications | No invoice collection reconciliation |
| `krim_ledger_accounts` | 14 | A chart-of-accounts-like structure exists | Not proof of an operational accounting ledger |
| `krim_ledger_transactions` | 0 | No posted transactions in this table | No journal-backed revenue, expense, cash or profit |
| `krim_ledger_entries` | 0 | No journal lines in this table | No balanced double-entry activity |
| `krim_revenue_allocation_rules` | 0 | No allocation rules stored here | No active, controlled revenue allocation configuration |
| `krim_revenue_allocation_runs` | 0 | No allocation runs | No completed allocation workflow |
| `krim_revenue_allocations` | 0 | No allocation rows | No supported platform/partner revenue allocation |
| `krim_tax_rules` | 0 | No tax-rule rows in this table | No approved tax configuration or tax compliance |
| `payment_orders` | 6 | Payment-order records exist | Not proof of successful capture, settlement, bank credit or KRIM income |
| `payment_webhook_events` | 10 | Webhook event records exist | Not proof every event is processed, reconciled or settled |

Counts were obtained from live production using aggregate COUNT queries on 16 November 2026. No row-level customer, payment or provider data was exposed in this inventory.

## 2. Capability assessment

### Present as structural foundations
- Payment-order and webhook event tables.
- A ledger-account catalogue.
- Invoice, invoice-item and payment-application table structures.
- Revenue allocation and tax-rule table structures.
- Referral record structure.

### Not demonstrated as operational
- Contract-to-billable-event generation.
- Invoice issuance for KRIM's own services.
- Invoice-linked, provider/bank-verified receipt.
- Balanced journal transaction and entry posting.
- Bank/provider settlement reconciliation.
- Expense capture and approval.
- Tax configuration approved by a qualified professional.
- Subscription plans, recurring billing cycles and entitlements.
- Automated MRR/ARR, contribution margin or net profit based on reconciled books.

A table existing with zero rows is a schema capability, not a functioning workflow. Likewise, payment orders and webhook events are not revenue.

## 3. Revenue recognition truth model

Every KRIM revenue stream must be independently identifiable and traceable:

1. **Contracted:** an executed agreement defines payer, scope, fee, trigger, currency, tax responsibility, refund/cancellation and effective dates.
2. **Earned:** objective delivery/acceptance evidence satisfies the contract trigger.
3. **Invoiced:** a legally appropriate KRIM invoice is issued against an immutable price/fee snapshot.
4. **Collected:** provider/bank evidence confirms receipt by the correct KRIM legal entity.
5. **Reconciled:** receipt is matched to invoice, fees, currency, settlement and bank statement.
6. **Recognised/accounted:** approved accounting policy determines recognition timing and balanced journal entries are posted.
7. **Profitable:** direct costs and allocated operating costs are considered under a documented margin definition.

These states must not be collapsed into a single `paid`, `reconciled` or `revenue` flag. A captured payment is not necessarily bank-settled cash; a paid customer freight invoice is not automatically KRIM revenue.

## 4. Non-custodial initial model

For the initial partner-direct model:
- Customer freight contract and freight invoice belong to the logistics partner.
- Customer pays that partner directly.
- KRIM must not collect, hold, split, escrow or settle partner freight funds.
- KRIM may invoice only its own separately contracted referral/coordination/software service when the service is genuinely delivered and legal/tax review permits.
- Partner referral compensation is not earned merely because a lead exists, a quote is issued or a shipment is marked paid.
- No payout, freight checkout or gross-shipment-value revenue recognition is authorised.

## 5. Missing product capabilities to design

| Capability | Minimum safe implementation | Release gate |
|---|---|---|
| Commercial catalogue | Versioned products, fee basis, jurisdiction, payer and tax review state | Commercial/legal review |
| Referral billing | Consent, attribution, partner acceptance, completion evidence, fee snapshot, maker-checker | Partner agreement and tax review |
| SaaS billing | Separate subscription domain, plan/price versions, billing cycles, payment attempts, server-side entitlements | Merchant eligibility, contract and tax review |
| Enterprise/API billing | Signed scope, usage/milestone evidence, rate snapshot, invoice and acceptance | Contract and data-rights review |
| Expense management | Vendor, category, evidence, approval, payment status and journal link | Expense policy and controls |
| Receivables | Invoice issue, due dates, partial receipts, credit notes, ageing and disputes | Legal invoice/tax configuration |
| Collections | Provider capture, settlement and bank-credit states; retry/dead-letter and exception queues | Provider and bank reconciliation tests |
| Accounting | Canonical legal entity, balanced journal, period locks, reversals and audit | Recovered migration lineage and staging proof |
| Tax | Jurisdiction-specific reviewed configuration and evidence of professional approval | CA/legal sign-off |
| Profit reporting | Revenue less attributable costs, expenses and tax provisions, reconciled to ledger | Verified source data and closed period |

## 6. KPI definitions — do not publish unsupported numbers

- **Contracted fees:** value of signed, active fee commitments; not earned revenue.
- **Earned fees:** contract-triggered fees with accepted delivery evidence; not necessarily invoiced.
- **Invoiced revenue:** KRIM-issued invoices net of credit notes, reported separately from earned fees.
- **Collected cash:** funds evidenced as credited to KRIM's bank/provider balance, net of reversals and provider fees as appropriate.
- **Reconciled collections:** collected cash matched to invoice and settlement/bank evidence.
- **MRR:** normalised recurring value of active, non-cancelled subscriptions; excludes one-off fees, unpaid invoices and freight GMV.
- **ARR:** MRR × 12, only where recurring contracts are active and the calculation policy is documented.
- **Contribution margin:** recognised KRIM revenue less directly attributable service/provider/partner costs.
- **Operating profit:** recognised income less direct costs and operating expenses under the approved accounting basis.
- **Cash runway:** available unrestricted KRIM cash divided by a defined average net cash burn; never infer from ledger revenue alone.

Dashboards must display source period, currency, accounting basis, reconciliation status and last successful refresh. Forecasts must be visually and semantically distinct from actuals.

## 7. Priority and release decision

1. Recover production migration sources and reconcile schema lineage; reconstruct isolated staging.
2. Establish the canonical KRIM legal entity and finance-organisation mapping.
3. Trace and quarantine unsafe legacy payment-to-margin/revenue paths.
4. Build a dedicated KRIM service-fee/referral billing lifecycle before any wider monetisation.
5. Build subscription billing as a separate bounded domain, not by repurposing freight payment tables.
6. Implement balanced journal, receipt/settlement reconciliation, expenses and tax controls.
7. Validate tenant isolation, permissions, maker-checker, idempotency, concurrency, reversals and period close in staging.

**Release decision:** Current production data does not demonstrate a functioning automated financial operating system. No new production finance DDL, payment activation, revenue recognition, refund execution, partner payout or profit reporting is authorised by this inventory. This document is a read-only assessment; no production data or schema was changed.
