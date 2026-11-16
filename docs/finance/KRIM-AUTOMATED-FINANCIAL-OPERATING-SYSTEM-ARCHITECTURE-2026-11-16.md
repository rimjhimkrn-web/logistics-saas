# KRIM Automated Financial Operating System — Target Architecture

**Date:** 16 November 2026  
**Purpose:** Build an automated, auditable finance and monetisation system for KRIM Global Logistics OS.  
**Important:** This architecture targets automation of legitimate earned revenue and financial controls. It cannot guarantee customer demand, partner participation, continuous cash receipts or profit. Commercial growth depends on real transactions, repeat usage, pricing, margins and collection discipline.

## 1. Business model: multiple independent income engines

KRIM should not rely on one commission stream. Build the platform to support these revenue engines, enabling each only after the service is real, contractually defined, legally reviewed and operationally measurable.

| Revenue engine | Payer | Charging basis | Automation trigger | Initial priority |
|---|---|---|---|---|
| Partner referral fees | Logistics partner | Fixed fee or agreed percentage for qualified completed referral | Contract trigger + completion evidence + approval | 1 |
| Customer coordination service | Customer | Explicitly scoped service fee | Accepted service order and defined deliverable | 2, only after legal/tax review |
| Partner software subscription | Partner | Monthly/annual recurring subscription | Active plan, billing cycle, successful collection | 3 |
| Premium partner listing | Partner | Subscription or paid placement | Approved listing + active paid period; clearly labelled | 4 |
| Customer premium workspace | Customer | Monthly/annual subscription | Active paid plan and access entitlement | 5 |
| Enterprise logistics OS licence | Enterprise | Contracted recurring licence / implementation | Signed contract, milestone or billing schedule | 6 |
| API / integration access | Business customer | Usage tier, call volume or recurring plan | Metered usage and approved rate card | 7 |
| White-label platform | Enterprise / network | Setup + recurring licence + support | Contract milestones and service activation | 8 |
| Analytics / intelligence | Eligible business customer | Subscription or report licence | Valid consent, data rights, plan and delivery | 9 |
| Workflow automation services | Business customer | Subscription or scoped project | Contracted workflow enabled and monitored | 10 |

Later possibilities such as financing, insurance distribution, escrow, remittance, custody or credit must not be enabled as KRIM products without licensed providers, legal structure and required regulatory approvals.

## 2. Core automated financial loop

Every revenue engine must feed one common lifecycle:

**Product/contract → customer/partner entitlement → metered or evidenced billable event → pricing snapshot → invoice/receivable → payment provider or bank transfer → verified receipt → balanced ledger posting → tax treatment → reconciliation → profitability dashboard → renewal/retention workflow.**

Each event has a unique source ID and idempotency key. Retries must never create duplicate invoices, receipts, journal entries or entitlements. A payment webhook is evidence to investigate and verify, not by itself proof of bank settlement or earned profit.

## 3. Required finance modules

### A. Revenue catalogue and commercial contracts
- Product/service catalogue with jurisdiction, currency, payer, billing basis, tax classification review state and allowed sales channel.
- Versioned partner/customer/enterprise contracts, effective dates, renewal, cancellation, refund and fee trigger.
- Rate cards and fee schedules with immutable snapshots per transaction.
- Separate freight amounts from KRIM's own fees at every layer.

### B. Revenue event engine
- Referral milestones and evidence validation.
- Subscription cycle generation and proration rules.
- API usage metering with limits and immutable usage records.
- Enterprise milestones and recurring licence schedules.
- Manual adjustments only with reason, evidence, approver and audit event.
- No revenue recognition based on gross shipment value unless KRIM is legally principal and the accounting treatment is explicitly reviewed.

### C. Billing and receivables
- Draft → reviewed → issued → partially paid → paid / overdue / disputed / credited / void states.
- Invoice numbering per legal entity and jurisdiction.
- Correct tax fields only after CA-approved configuration.
- Credit notes, cancellation and refunds linked to original documents.
- Automated reminders and dunning with configurable respectful cadence.
- Customer/partner statement and receivables ageing.

### D. Payment collection and settlement
- Payment provider registry by country/currency and verified merchant eligibility.
- Razorpay for eligible India KRIM fees only after live merchant capability is confirmed.
- Partner-direct freight payment remains outside KRIM checkout and settlement.
- Bank transfer collection supported with reference matching and reviewer workflow.
- Signed webhook verification, event allowlist, replay protection, retry queue, dead-letter queue and reconciliation to provider settlement/bank statement.
- No automatic partner payouts in the initial non-custodial model.

### E. Accounting engine
- One canonical legal entity and finance organisation binding.
- Double-entry journal with immutable posted entries, reversal entries instead of destructive edits, period locks and balanced debit/credit enforcement in the same database transaction.
- Chart of accounts for referral/service/subscription/API/enterprise revenue, receivables, cash/bank, taxes payable, refunds/credits, direct costs, operating expenses and equity.
- Accrual and cash views clearly distinguished.
- Multi-currency transaction and base-currency valuation with documented exchange-rate source/time.
- No posting from untrusted client input.

### F. Bank and settlement reconciliation
- Import or connect bank statements through supported, authorised methods.
- Match invoice/receipt/reference/amount/currency/date; support partial, combined, fee-deducted and unmatched receipts.
- Separate provider capture, provider settlement and actual bank credit.
- Unmatched items enter exception queue; no auto-marking as collected.
- Daily reconciliation summary and period close checklist.

### G. Expenses, cash flow and profitability
- Expense capture, receipt evidence, category, tax review, approver and payment status.
- Vendor/operating cost tracking and recurring commitments.
- Cash runway, receivable ageing, gross margin/contribution, operating expenses, tax liabilities and net profit.
- Unit economics by revenue engine, customer cohort, partner, lane, country and product.
- Forecasts labelled estimates, never actual cash.

### H. Tax and compliance control
- Tax rules versioned by jurisdiction and effective date, but activated only after qualified professional review.
- GST registration status and applicability controls; invoice generation blocked when required tax data/review is missing.
- TDS/withholding and foreign-currency/export checks where applicable.
- Audit trail of advice, reviewer, effective period and configuration changes.
- No claim of tax exemption by software logic.

### I. Recurring revenue retention
- Subscription lifecycle: trial (if offered), active, past_due, grace, suspended, cancelled, renewed.
- Automated renewal notices, payment retries, dunning, downgrade and access entitlement changes.
- Usage and value reporting to reduce churn.
- Partner/customer health, repeat bookings, service quality and support signals.
- No charging without accepted terms and transparent cancellation policy.

### J. Finance control tower
- Revenue by stream: contracted, earned, invoiced, collected, reconciled.
- MRR/ARR only for active recurring contracts, excluding one-off fees and unpaid invoices.
- Gross margin, contribution margin, operating profit and cash balance separately defined.
- Exceptions: failed payment, duplicate webhook, unmatched receipt, overdue invoice, tax review missing, unbalanced journal, disputed referral, partner compliance expired.
- Role-based access, maker-checker approvals, immutable audit trail and tenant isolation.

## 4. Automated workflows

1. **New referral:** capture consent → qualify → route only to approved partner scope → partner accepts → service evidence → fee trigger calculation → reviewer approval → invoice → collection → reconciliation.
2. **Subscription:** signed plan → entitlement → billing schedule → invoice/order → collection → webhook validation → settlement/bank match → journal → renewal/dunning.
3. **API usage:** authenticated metering → rate snapshot → usage aggregation → invoice → collection → journal → usage and margin report.
4. **Enterprise contract:** contract milestone schedule → acceptance evidence → invoice → collection → project cost allocation → margin report.
5. **Expense:** capture evidence → policy validation → approval → payment record → journal → cash forecast.
6. **Month-end close:** bank reconciliation → receivables/payables review → tax review → journal balance check → period lock → management report.

## 5. Automation safety rules

- Do not mix customer freight money with KRIM's own revenue or bank balance.
- Do not represent a prospect, unverified partner or unaccepted quote as operational capacity.
- No client-side writes to finance configuration, journals, receivables, settlements or refunds.
- No single user may approve their own sensitive financial event.
- Every financial mutation must be authorised, idempotent, tenant-scoped, auditable and reversible by a compensating entry.
- Secrets remain in managed secret storage; never commit keys or bank credentials.
- Failed jobs are observable, retryable and quarantined after bounded retries.
- All financial dashboards reconcile to source documents and journal totals.

## 6. Current implementation reality and release blockers

The live schema already contains invoice, payment, ledger, revenue-allocation, tax-rule and referral-related tables. Their existence does not mean the system is operational.

Known findings from the 16 Nov 2026 read-only finance review:
- No completed journal transaction/entry population establishing the accounting loop.
- Finance organisation vs KRIM legal entity binding unresolved.
- Existing revenue recognition can treat customer freight invoice gross value as revenue; unsafe for the partner-direct model.
- Legacy revenue ledger SECURITY DEFINER function is unscoped across finance organisations.
- Finance/partner payable RLS and direct-write controls require remediation.
- Refund tenant-binding and approval-flow defects remain.
- Razorpay merchant eligibility, checkout and settlement readiness remain unverified; checkout remains disabled.
- No verified/contracted partner or completed referral fee receipt has been proven.
- Production migration history does not reconcile with repository migration sources. Exact migration recovery and staging reconstruction are mandatory before production schema/security repairs.

**Release decision:** No production finance DDL, policy/function changes, revenue recognition, freight checkout, automated refunds or partner payouts until migration recovery, isolated staging tests and independent security/finance review are complete.

## 7. Build sequence

### Phase 1 — Foundation and truth
- Recover exact production migration sources and reconcile history.
- Establish canonical legal entity / finance organisation.
- Define KRIM-only chart of accounts and referral-fee accounting.
- Quarantine unsafe legacy finance pathways.
- Create isolated staging and repeatable test data.

### Phase 2 — Core accounting and collections
- Implement balanced journal posting and reversals.
- Implement receivable, invoice, receipt and bank reconciliation lifecycle.
- Add idempotent provider webhook processing and dead-letter recovery.
- Test cross-tenant denial, duplicate events, partial receipts, reversals, currency mismatches and concurrent retries.

### Phase 3 — First monetisation engine
- Enable referral fee contracts, evidence-backed trigger, fee approval, KRIM invoice, collection and reconciliation.
- Complete one real partner/customer referral with actual bank receipt.
- Validate actual contribution after costs and tax.

### Phase 4 — Recurring products
- Partner subscription plans and billing.
- Customer premium workspace plans.
- Enterprise licence/milestone billing.
- API usage metering and billing.
- Entitlement, renewal, dunning, cancellation and retention automation.

### Phase 5 — Financial intelligence and scale
- Multi-country tax/currency configurations with local review.
- Consolidated multi-entity reporting only when legally established.
- Cash-flow forecast, profitability by product/cohort/partner and churn/revenue dashboards.
- Independent penetration, accounting and operational audit.

## 8. Definition of done

The system is not declared complete until:
- Every active revenue stream has a contract, pricing rule, billable event, invoice/receipt path, ledger mapping, tax treatment, reconciliation and refund/credit path.
- All posted journals balance and are immutable.
- Every bank receipt reconciles to a source invoice/contract and unique receipt.
- No customer or partner can access another organisation's financial data.
- Automated renewals and retries do not duplicate charges or entitlements.
- Revenue, cash collection, contribution and net profit reconcile to source records.
- Failure queues, alerts, backups, restore and audit procedures are tested.
- At least one real end-to-end transaction has passed for each enabled stream.
- Continuous income is treated as a commercial outcome to measure, not a software guarantee.

**Current state:** Target architecture documented; implementation is partial and release-blocked. This document does not claim the automated financial system is complete or producing income.
