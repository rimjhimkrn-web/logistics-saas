# KRIM Financial Ecosystem Integration Audit — 16 November 2026

## Purpose and conclusion

Establish one auditable financial operating architecture across KRIM Marketplace, KRIM OS, KRIM Intelligence and KRIM Network. The objective is sustainable company revenue, positive unit economics, cash discipline and global scalability—not inflated gross transaction volume.

This was a read-only production audit. No production DDL, financial posting, payment activation, refund execution or payout was performed.

Production already contains a meaningful foundation: chart of accounts, accounting periods, posting rules, double-entry ledger tables, invoices, partner payables, financial transaction records, revenue-allocation components, tax-rule registry, payment capability registry, refunds and treasury control rules.

It is not yet an integrated operational financial ecosystem. Core operational tables have zero or near-zero records; revenue-allocation rules and treasury rules are empty; the revenue-recognition posting rule is suspended; the India Razorpay capability row is marked implemented but checkout and settlement remain disabled; and there are two distinct ledger-posting function overloads with different transaction key conventions.

**Do not activate payments, payouts, refunds, revenue allocation or ledger posting until organization mapping, function overloads, accounting controls and end-to-end tests are reconciled.**

## 1. Production snapshot

Approximate live row counts from PostgreSQL table statistics (not certified financial balances):

| Component | Approximate rows |
|---|---:|
| krim_ledger_accounts | 14 |
| krim_ledger_transactions | 0 |
| krim_ledger_entries | 0 |
| krim_accounting_periods | 1 |
| krim_accounting_account_mappings | 5 |
| krim_accounting_posting_rules | 3 |
| krim_invoices / krim_invoice_items | 0 / 0 |
| krim_invoice_payment_applications | 0 |
| krim_partner_payables | 0 |
| krim_financial_transactions | 1 |
| krim_revenue_allocation_rules | 0 |
| krim_revenue_allocation_runs / krim_revenue_allocations | 0 / 0 |
| krim_shipment_revenue_items | 0 |
| krim_customer_billing_profiles / krim_payment_terms | 0 / 0 |
| krim_tax_rules | 0 |
| krim_treasury_control_rules | 0 |
| krim_refund_requests / events | 0 / 0 |
| payment_orders / payments / payment_webhook_events | 6 / 4 / 10 |
| legacy revenue_ledger | 1 |

## 2. Critical integration findings

### F-01 — Finance test organization and platform organization are distinct

- Organization 1: KRIM Global Platform, type platform, default currency INR.
- Organization 21: KRIM Finance Journey Verification, type finance, default currency INR.
- All 14 seeded ledger accounts belong to organization 21.
- The only accounting period returned belongs to organization 1 and covers 1 April 2026–31 March 2027.
- All three posting rules belong to organization 21.

This is a high-priority organization-scope mismatch. Do not copy accounts or rewrite IDs blindly. Establish the intended legal-entity / platform / internal test-organization model and seed a controlled chart of accounts and open period for the correct operating entity through a reconciled migration.

### F-02 — Revenue recognition posting is suspended

The only returned posting rules are for organization 21:
- customer_payment: active.
- partner_settlement: active.
- revenue_recognition: suspended.

Delivered-revenue recognition calls the revenue allocation planner. There are currently no revenue allocation rules, runs or allocation rows. The system can therefore return an awaiting_policy outcome rather than creating a recognized allocation.

Do not turn on revenue recognition until the accounting treatment for KRIM's own referral, coordination, subscription and software income is documented and tested separately from partner freight revenue.

### F-03 — Two overloaded ledger-posting functions exist

public.krim_internal_post_ledger_transaction has two SECURITY DEFINER overloads:

1. Uses transaction_reference, numeric source_id, and idempotency by transaction reference.
2. Uses transaction_number, text source_id, and requires an open accounting period, idempotency by organization + transaction number.

They are not interchangeable. Select and document the canonical posting interface. Internal callers must use an unambiguous signature; execution grants, search paths, transaction balancing, period enforcement, source uniqueness and reversal controls must be verified. No overload was invoked in this audit.

### F-04 — Payment provider capability is not launch-enabled

The payment capability registry contains 45 rows. The India INR Razorpay row is marked implemented, but checkout_enabled=false, merchant_eligibility_verified=false, and settlement_supported=false. Other international provider/country combinations are planned and disabled.

This is consistent with the deliberate partner-direct launch posture. Keep freight checkout and settlement disabled. Any later KRIM fee collection must have its own reviewed commercial contract, tax treatment, merchant eligibility and tested payment lifecycle.

### F-05 — No active revenue allocation policy or treasury controls

- krim_revenue_allocation_rules: 0.
- krim_treasury_control_rules: 0.
- No invoice, partner payable, ledger transaction or ledger entry activity is present in the core new finance tables.

Build policy configuration with approval, effective dates, immutable snapshots, idempotency and audit history. Do not insert speculative percentages or fee rules as production defaults.

### F-06 — Legacy and canonical finance paths coexist

The database contains legacy payments, payment_orders, revenue_ledger, shipment_financials and partner_payouts alongside newer krim_* finance tables and functions. The authoritative source for each financial fact must be documented. Legacy rows must be reconciled and mapped, never silently copied or counted twice.

### F-07 — Finance listing RPC is narrower than a global finance cockpit

krim_finance_list_revenue_ledger checks active membership in an organization of type finance with finance.view, then reads the legacy revenue_ledger. It is not a consolidated ledger, invoice, payable, receivable, cash or multi-currency reporting interface. Preserve its authorization model but do not treat it as the canonical enterprise finance reporting layer.

## 3. Required financial source-of-truth model

| Financial fact | Canonical record |
|---|---|
| Commercial agreement and fee entitlement | Accepted contract / commercial agreement and versioned fee schedule |
| Customer amount owed to KRIM | KRIM invoice / receivable |
| Customer freight amount owed to partner | Partner-issued invoice / partner-direct record; not KRIM revenue |
| Money actually received by KRIM | Provider/bank-confirmed financial transaction plus reconciliation reference |
| KRIM revenue earned | Revenue subledger item linked to enforceable agreement and recognition event |
| Partner amount owed | Partner payable linked to assignment, partner invoice and acceptance evidence |
| Partner funds movement | Partner-direct evidence or licensed-provider-confirmed settlement record; not KRIM cash |
| General ledger | Immutable balanced debit/credit entries in the correct legal entity and accounting period |
| Tax liability | Reviewed jurisdiction-specific tax rule and filed/verified tax record |
| Cash and liquidity | Reconciled bank/provider balances, not invoices or shipment GMV |
| Refund / credit note | Approved refund/credit record linked to original invoice and payment, with provider outcome |
| Investor / valuation metrics | Separate management reporting, never mixed with revenue or cash balances |

### Required accounting separation

- Partner freight GMV is ecosystem transaction volume, not KRIM revenue.
- Partner-direct payments are not KRIM collections, cash, settlement or revenue.
- KRIM recognizes only its own earned contractual fee, subject to applicable accounting and tax review.
- A booking, quote acceptance, invoice issue, payment capture, service completion and revenue recognition are different events.
- Every reversal must be a traceable compensating entry; posted ledger rows must not be silently edited or deleted.

## 4. Target financial domains

1. Commercial monetization: referral, coordination, premium listing, partner subscription, customer premium, SaaS, enterprise LOS, API, white-label, AI intelligence, analytics and integration fees.
2. Billing and collections: contracts, invoices, recurring billing, receivables, payment terms, payment applications, dunning and provider reconciliation.
3. Accounting: legal entities, chart of accounts, journals, double-entry posting, accounting periods, accruals, reversals, trial balance, P&L, balance sheet and cash-flow statements.
4. Partner finance: partner invoices, payable validation, deductions/adjustments, disputes and partner-direct settlement evidence.
5. Treasury: bank/provider accounts, daily cash position, cash forecasts, liquidity reserves, approval limits and dual control.
6. Tax and compliance: India-first tax configuration, GST applicability review, invoice requirements, withholding and later jurisdiction-specific VAT/GST/sales-tax controls.
7. Procurement and expenses: purchase approvals, vendors, expense claims, budgets, reimbursements and cost allocation.
8. Credit and risk: customer credit limits, receivable ageing, fraud signals, bad-debt provisions and risk approvals. Lending/credit products require appropriate licensing/partners.
9. Global finance: currency presentment, functional/base currency, evidenced FX rates, realized/unrealized FX, country-level provider eligibility and entity-level consolidation.
10. Capital and management reporting: fundraising data room, cap table, dilution scenarios, investor reporting and valuation scenarios. Investment/wealth products require appropriate authorization.
11. Financial intelligence: cohort economics, contribution margin, customer acquisition cost, lifetime value, churn, payback period, partner economics and scenario forecasting.

## 5. Twelve monetization engines and controls

Each revenue engine needs a versioned commercial agreement, eligibility gate, price/fee schedule, billing trigger, recognition rule, tax treatment, refund/cancellation policy, ledger mapping and profitability metric.

| Revenue engine | KRIM revenue basis |
|---|---|
| Referral | Agreed fee for a qualifying partner-sourced outcome |
| Coordination | Separately scoped and contracted coordination service |
| Partner subscription | Recurring subscription for eligible partner software/services |
| Premium listing | Paid visibility under transparent listing terms |
| Customer premium | Explicitly contracted premium service |
| SaaS subscription | Workspace / module subscription |
| Enterprise LOS | Enterprise licence and implementation/support fees |
| API access | Metered or tiered API usage |
| White-label | Licence, setup and support fees |
| AI intelligence | Subscription or usage fees for delivered intelligence |
| Supply-chain analytics | Contracted analytics/reporting services |
| Integration/infrastructure | Implementation, connector and infrastructure fees |

Do not create percentage allocations or recognize any stream until commercial terms, accounting and tax treatment are approved.

## 6. Implementation gates

### Gate 1 — Reconcile and stabilize existing finance
- Resolve organization 1 vs 21 scope.
- Map every finance table, RPC, trigger, Edge Function, UI page, permission and provider.
- Select canonical ledger posting function and idempotency key.
- Verify ledger invariants, constraints, RLS policies and grants.
- Reconcile legacy payment/order/revenue rows against provider records.
- Confirm authoritative tables and mark legacy sources read-only where appropriate.
- Add automated financial integrity tests before production changes.

### Gate 2 — Revenue and billing foundation
- Contract / fee schedule registry.
- KRIM fee invoices and receivables.
- Revenue subledger by revenue engine.
- Partner-direct freight records kept separate.
- Credit notes, disputes and cancellation handling.

### Gate 3 — Accounting and treasury
- Correct legal-entity chart of accounts and periods.
- Balanced journal posting with immutable reversals.
- Bank/provider reconciliation.
- Cash forecast, approval matrix and dual control.
- Financial statements and close process.

### Gate 4 — Globalization
- Multi-currency ledger and FX provenance.
- Country/provider eligibility gates.
- Entity-specific tax and invoice controls.
- Consolidated group reporting with intercompany eliminations.

### Gate 5 — Intelligence and capital readiness
- Unit economics and contribution margin by customer, route, partner, product and market.
- Cash runway and scenario planning.
- Investor-grade metrics and data room.
- Capital strategy after real operating traction.

## 7. Mandatory release tests

- Balanced debits equal credits for every posted transaction and currency.
- No posting into closed/future accounting periods.
- Organization isolation and least-privilege RLS.
- Idempotent duplicate webhook, retry and replay tests.
- No cross-currency netting without explicit FX entries and source.
- No duplicate invoice, revenue recognition, payable or payout.
- Provider-confirmed payment and payout reconciliation.
- Refunds and credit notes trace back to original transactions.
- Partner-direct amounts never appear as KRIM cash or KRIM revenue.
- No revenue recognition from quote acceptance or shipment GMV alone.
- Multi-leg allocations reconcile exactly to approved commercial contracts.
- Full audit trail and independent approval for sensitive financial actions.

## 8. Current release posture

**Status: design and audit only; not finance-production-ready.**

- No production schema changes were made.
- No ledger entries or revenue allocations were posted.
- No provider checkout, settlement, payout or refund capability was enabled.
- Historical payment anomalies remain subject to provider reconciliation; do not mark webhook events processed without evidence.
- Supabase migration-history drift remains a blocker to DDL changes. Reconcile migration sources and execution history before any corrective production migration.

## Next engineering task

Create a complete finance dependency map from production: table ownership and row-level security, function overloads and grants, trigger callers, Edge Function callers, frontend routes, legacy-to-canonical data mapping and test coverage. Then produce a reviewed migration plan for Gate 1. Do not perform production DDL until migration history and the organization model are resolved.
