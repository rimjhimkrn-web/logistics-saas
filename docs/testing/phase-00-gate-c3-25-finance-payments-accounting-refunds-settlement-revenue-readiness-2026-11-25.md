# Phase 00 Gate C3.25 — Finance ecosystem, payments, accounting, refunds, partner settlement and revenue readiness

**Date:** 2026-11-25  
**Immutable source baseline:** `72d75a18f985ceb09e468839435ee95700e11e46`  
**Method:** Read-only source and migration review, reconciled with prior finance and Production audit evidence. No SQL/RPC, payment-provider API, webhook replay, refund, payout, invoice, ledger posting, reconciliation mutation, bank operation or deployment was executed.

## Executive decision

**FAIL / BLOCKED — NO-GO for KRIM freight collection, automatic commission/split, escrow, partner payouts, KRIM refund execution, tax automation or financial close.**

The safe current commercial model remains **partner-direct / non-custodial**: the customer contracts with and pays the logistics provider directly for freight; the partner performs the logistics service; KRIM may separately invoice only its own properly contracted, evidenced referral/coordination service fee after legal and tax review. KRIM must not describe partner freight funds as KRIM revenue, custody, escrow or settlement.

Finance architecture includes meaningful controls: Razorpay raw-body HMAC webhook validation, provider event IDs, a strict payment-to-shipment/quote/partner/capacity reconciliation RPC, disabled new freight checkout, a gated refund execution endpoint, AAL2 refund review, partner payable evidence gates, double-entry ledger functions and read-only treasury reconciliation views.

However, several serious gaps remain. Most importantly, the freight-collection kill switch is checked by order creation and manual verification but **not by the captured/order-paid webhook path**, which can transition an order to paid and invoke financial reconciliation. Finance control tables also had ordinary organization-member DML exposure in the prior Production audit; approval wildcard matching and dual control are defective; accounting periods do not match the finance organization; ledger duplicate handling is not payload-aware; old payment/webhook records are not reconciled; and tax, invoice, KRIM fee and partner settlement operations have no demonstrated end-to-end activity.

## Scope and source inventory

### Edge Functions reviewed
- `supabase/functions/razorpay-webhook/index.ts`
- `supabase/functions/create-global-razorpay-order/index.ts`
- `supabase/functions/verify-razorpay-payment/index.ts`
- `supabase/functions/execute-razorpay-refund/index.ts`
- `supabase/functions/krim-global-payment-options/index.ts`
- `supabase/functions/krim-payment-capability-status/index.ts`
- Legacy Cashfree handlers: `create-global-cashfree-order`, `verify-global-cashfree-payment`, `cashfree-payment-webhook`

### Finance and accounting migrations reviewed
- `20261017093454_fix_revenue_allocation_idempotency_and_recognition.sql`
- `20261017094013_distinguish_missing_revenue_policy_from_idempotent_retry.sql`
- `20261017120000_enforce_payment_provider_reference_idempotency.sql`
- `20261017133000_enforce_revenue_allocation_idempotency.sql`
- `20261022113000_global_currency_precision_and_payment_capabilities.sql`
- `20261025073323_lock_down_private_payment_registry_rls.sql`
- `20261025073559_revoke_anon_payment_finance_reads.sql`
- `20261105100500_consolidate_finance_and_exception_read_policies.sql`
- `20261105104500_consolidate_marketplace_shipment_finance_read_policies.sql`
- `20261106055441_configure_finance_inr_account_mappings_and_posting_rules.sql`
- `20261106055545_suspend_revenue_recognition_until_tax_split_is_verified.sql`
- `20261107210000_restrict_direct_finance_table_writes.sql`
- `20261107220000_secure_refund_request_workflow.sql`
- `20261107222000_limit_refund_requests_to_unreconciled_paid_orders.sql`
- `20261107230000_initialize_finance_chart_of_accounts_inr.sql`
- `20261115065956_allow_partner_direct_readiness_payment_status.sql`
- `20261115085000_finance_webhook_reconciliation_readonly.sql`
- `20261115151545_block_unallocated_multileg_finance_postings.sql`

### Frontend workspaces inspected
- `app/finance/`: command centre, invoicing, accounts receivable/payable, payment processing, partner settlements, revenue/commission, refunds/disputes, multi-currency, tax compliance, reporting and treasury/audit.
- Related customer/partner billing and payment pages, including checkout, payment history, invoice, refund and settlement views.
- The finance workspace pages are predominantly preparation/read-only or explicitly state that they do not move funds. Refund page text correctly states KRIM refund execution is disabled; revenue/commission page correctly prohibits automatic 10/90 freight splits and says freight remains customer-to-provider.

### Prior audits used
- `docs/audits/KRIM-FINANCE-REVENUE-PAYMENTS-REFUNDS-SETTLEMENT-AND-RECONCILIATION-DEEP-AUDIT-2026-11-16.md`
- `docs/audits/KRIM-FINANCIAL-INTEGRITY-LEDGER-INVOICING-RECONCILIATION-REFUNDS-AND-SETTLEMENT-BOUNDARY-AUDIT-2026-11-16.md`
- `docs/audits/KRIM-FINANCIAL-INTEGRITY-PAYMENT-RECONCILIATION-AND-REVENUE-SEPARATION-AUDIT-2026-11-16.md`
- `docs/audits/KRIM-DISPUTES-CHARGEBACKS-INSURANCE-AND-FINANCIAL-RECONCILIATION-REVIEW-2026-11-16.md`
- `docs/audits/KRIM-FINANCE-DEPENDENCY-AND-ACCESS-REVIEW-2026-11-16.md`
- `docs/audits/KRIM-FINANCE-WORKSPACE-AUTHORIZATION-AND-DATABASE-ADVISOR-FOLLOW-UP-2026-11-16.md`
- `docs/audits/KRIM-P0-FINANCIAL-SECURITY-REMEDIATION-PLAN-RAZORPAY-WEBHOOK-AND-REVENUE-ALLOCATION-2026-11-16.md`
- `docs/audits/KRIM-PRODUCTION-MIGRATION-HISTORY-RECONCILIATION-2026-11-24.md`
- `docs/remediation-pending/2026-11-17-authenticated-direct-write-finance-authorization-remediation.md`

## Positive controls and strengths

1. Razorpay webhook reads the exact raw body and validates HMAC-SHA256 against the configured webhook secret, requires provider event ID, stores event IDs and handles already-processed duplicates.
2. Captured payment processing validates provider payment/order identifiers, amount, currency and captured state before reconciling against a local order.
3. The canonical payment reconciler requires shipment, customer organization, accepted customer quote, partner quote, accepted partner assignment and confirmed capacity binding; it rejects legacy unbound orders rather than inventing links.
4. New KRIM freight order creation checks a server-side `KRIM_FREIGHT_COLLECTION_ENABLED` flag plus a pinned approval version and returns a disabled response by default.
5. Manual payment verification checks the same collection flag for unpaid orders; legacy paid orders without canonical bindings are held for manual review.
6. Refund execution Edge Function checks a separate environment/version approval gate and is disabled under the current partner-direct model.
7. Refund request/review tables are designed with participant-scoped read access, authenticated submitter checks, AAL2 finance review, finance.manage/admin permission and requester/reviewer separation. Refund requests are intentionally full-refund-only until cumulative balance handling exists.
8. Refund webhooks report provider outcomes; they do not initiate provider refunds. Correlation checks approved request, original payment, amount, currency and provider refund ID.
9. Partner payable creation is gated on completed delivery, accepted partner quote/assignment and independently verified POD for the exact shipment/leg.
10. Partner settlement has a treasury-control prerequisite and a separate provider reconciliation concept. The absence of a required partner-funds treasury rule blocks the current settlement path.
11. Ledger posting functions implement debit/credit balancing and account/currency checks; one overload checks an open accounting period.
12. Finance read-only webhook reconciliation is AAL2 platform-admin-only and masks provider identifiers rather than returning full raw webhook payloads.
13. Multi-leg invoice/payable/revenue posting has a trigger that blocks unallocated multi-leg finance writes.
14. Revenue recognition was explicitly suspended until GST output-tax split and invoice subtotal/tax accounting are verified.
15. Legacy Cashfree handlers are retired stubs returning HTTP 410, not active Cashfree payment operations.

These are source/prior-audit observations. They do not prove deployed Edge Function parity, successful live provider operations or a complete financial lifecycle.

## Critical findings

### P0 — Razorpay captured-payment webhook bypasses the freight-collection kill switch

**Evidence:** `create-global-razorpay-order` checks both `KRIM_FREIGHT_COLLECTION_ENABLED=true` and `KRIM_FREIGHT_COLLECTION_APPROVAL_VERSION=2026-11-15-v1`. `verify-razorpay-payment` applies the same check to unpaid orders. The reviewed `razorpay-webhook` validates the provider signature and event, then processes `payment.captured` / `order.paid`, conditionally changes the local payment order to `paid`, and invokes `krim_internal_reconcile_razorpay_captured_payment`. The webhook does not check the freight-collection approval flag/version before paid-state transition and company-owned financial reconciliation.

This is a control inconsistency: disabling new checkout/manual verification does not, in the inspected source, stop a valid delayed/retried captured event from creating a KRIM-owned freight receipt/financial transaction. This is especially important under the current partner-direct model.

**Required remediation:** one shared server-only collection-mode decision must govern order creation, verification and captured-payment webhook processing. With collection disabled, preserve signature validation and durable event capture, but defer/quarantine captured/order-paid events without mutating payment order paid state, KRIM financial transactions, shipment financials or revenue ledger. Quarantine and alert must be durable before acknowledging provider delivery; transient persistence failure must return retryable non-2xx. Keep historical approved refund outcome reconciliation separate. Require explicit user approval, legal/tax/bank/merchant/partner-contract readiness and a new versioned approval before any collection enablement. No live webhook replay or flag change was performed.

### P0 — Finance control and approval tables had ordinary organization-member write exposure

Prior Production audit found RLS enabled but broad `ALL` policies and authenticated INSERT/UPDATE/DELETE grants on:
- `krim_financial_approval_requests`
- `krim_financial_approval_policies`
- `krim_revenue_allocation_rules`
- `krim_revenue_allocations`
- `krim_treasury_control_rules`
- `krim_accounting_posting_rules`
- `krim_accounting_account_mappings`
- `krim_accounting_periods`

The policy predicate was organization access, not finance.manage or a privileged finance role. Ordinary organization membership is not authorization to change financial policies, allocation rules, treasury controls, approval requests, account mappings or accounting periods. A later migration `20261107210000_restrict_direct_finance_table_writes.sql` revokes DML on payment_orders, ledger accounts and reconciliation exceptions, but does not itself prove the eight control tables above were secured. The earlier audit's findings must be revalidated against a reconciled current Production catalog before claiming closure.

**Required remediation:** revoke direct authenticated DML and broad organization-member ALL policies on all finance-control tables; retain only justified tenant-scoped read access. Mutations must use narrowly scoped audited server-side workflows with finance.manage/admin authorization, active membership, AAL2 for sensitive changes, maker-checker independence, immutable events and append-only/reversal patterns for accounting records.

### P1 — Financial approval wildcard currency does not match evaluator

Prior audit found all eight active global approval policies used `currency_code='*'`, but `krim_internal.evaluate_financial_approval` looked up exact `upper(p_currency_code)` and did not interpret `*` as a wildcard. It could return `approval_required/no_active_policy` without an actionable approval request ID, while partner payable preparation expected one.

**Required remediation:** implement deterministic explicit wildcard precedence or currency-specific policy rows; effective dates, scope and uniqueness; ensure every supported currency/scope yields exactly one policy and a valid approval request when required. Do not seed/alter Production policies before migration reconciliation.

### P1 — Partner settlement does not prove dual control or consume an exact approval fingerprint

Prior audit found `krim_internal_authorize_partner_settlement` checks a matching approved request and amount/currency, but does not enforce `requires_dual_control`, a distinct approver versus requester/executor, or consume a one-time action fingerprint bound to payable/beneficiary/amount/currency/action. Seeded policies had `require_dual_control=false`. No treasury partner-funds rule was configured.

**Required remediation:** one-time approval bound to exact payable, source, beneficiary, amount, currency and action fingerprint; separate requester, approver and executor for high-risk settlement; enforce approval expiry and replay/conflicting-payload rejection; reconcile provider/bank confirmation before paid status.

### P1 — Finance organization and accounting period do not align

Prior audit found active accounting posting rules and account mappings under finance organization 21, but the only accounting period was for platform organization 1. The posting overload requires an open period for the same organization. No successful ledger journal posting existed to prove the route.

**Required remediation:** settle the canonical legal/accounting entity model first; align chart of accounts, posting rules, account mappings, periods and transaction ownership to the same approved legal entity. Test open/closed/future period and boundary cases in Staging before real posting.

### P1 — Ledger idempotency does not compare canonical payload on duplicate reference

Prior audit found ledger posting overloads may return an existing transaction when reference/number already exists without comparing immutable organization, amount, currency, debit/credit accounts, source type and source ID. A conflicting retry could be reported as idempotent success.

**Required remediation:** persist deterministic canonical payload hash and compare all immutable posting fields on duplicate reference. Exact match alone is idempotent success; any mismatch is a hard conflict requiring reconciliation. Test concurrent same-payload and conflicting retries.

### P1 — Financial reconciliation is not consistently organization-scoped

Prior audit found legacy `payments` aggregates can be calculated by status/currency/time without consistently filtering requested organization/shipment ownership. No-argument reconciliation scans legacy payments and partner payables globally and may create exceptions with NULL organization; a NULL organization argument can mean all organizations.

**Required remediation:** canonical source of truth must be payment orders and validated financial transactions with explicit legal-entity, shipment and assignment ownership. Require organization for tenant runs; reserve global reconciliation for an explicit privileged platform operation. Every exception must have validated owner or explicit platform-wide scope. Test cross-tenant and mixed currency.

### P1 — Existing payment orders and webhook backlog are unreconciled

Historical Production snapshot:
- Payment orders: 6 (5 created, 1 paid).
- The paid order and five created orders lacked complete customer-organization / KRIM quote / partner quote bindings.
- Legacy `payments`: 4 (2 paid, 2 pending), with no KRIM shipment or quote binding.
- Webhook events: 10; 2 `order.paid` and 2 `payment.captured` remained unprocessed; 6 `payment.authorized` were processed.
- One legacy `partner_payouts` row was marked paid, but no independent bank/provider settlement evidence was established.

These are prior snapshot counts, not refreshed during this gate. They are not proof of lost funds or test-only activity. Do not replay events, bind old payments to shipments by guess, or mark events processed manually.

**Required remediation:** read-only classify each event/order against Razorpay provider dashboard/API records and bank settlement statements; classify test/duplicate/abandoned/captured/unbound/conflict; record exact provider order/payment ID, amount/currency and verified bank status. Use a separately authorized maker-checker recovery process for any correction. Never infer a shipment/quote association.

### P1 — KRIM revenue recognition and fee accounting are not operationally configured

Prior snapshot: zero revenue allocation rules, allocations and runs; zero shipment revenue items; zero ledger journal transactions/entries. Revenue recognition for INR was suspended because invoice total could incorrectly post GST together with service revenue. Partner-direct revenue model requires KRIM's own service fee, not freight GMV, to be the recognized revenue base.

**Required remediation:** signed partner/customer commercial terms, attribution evidence and proof of KRIM service performed; separate KRIM service-fee invoice/receivable; CA-reviewed GST/place-of-supply/tax split; approved effective-dated revenue policy; correct legal entity and double-entry posting. Never auto-deduct a freight commission or recognize partner freight as KRIM revenue.

### P1 — Tax rules, billing profiles and invoice lifecycle are empty

Prior snapshot: zero customer billing profiles, invoices, invoice items/payment applications and tax rules. Tax page is a review worksheet, not a validated tax engine. No invoice/tax automation should be enabled until legal entity, GST registration and CA-approved treatment for KRIM's own service fee, place of supply, invoice numbering, credit note and filing data are established.

**Required remediation:** qualified Indian tax review, approved tax source/rule version/effective dates, legal entity linkage, GSTIN and place-of-supply logic where applicable, taxable value versus GST split, invoice/credit-note sequence, export/zero-rated handling where relevant and test evidence in isolated Staging. Do not use assumed tax rates.

### P1 — Refund UI and backend policy disagree; refund execution remains disabled

The finance refund UI permits a positive amount up to the paid amount; the backend submission function intentionally accepts only full refund and blocks partial refunds pending cumulative refundable-balance logic. Refund request review has useful AAL2/permission/separation controls. The Edge Function for executing refunds is separately disabled by environment/version gate. Provider refund webhooks report outcomes; they do not initiate a refund.

**Required remediation:** make UI full-refund-only with exact paid amount equality or build correctly bounded cumulative partial-refund accounting. Preserve disabled execution unless a separately approved historical KRIM-collected refund is validated. Customer freight paid directly to a logistics partner must be refunded by that contracting provider, not KRIM.

### P1 — No operational partner payable/settlement/payout evidence

Prior snapshot: zero canonical partner payables; one legacy payout row marked paid without independent provider/bank evidence; no canonical payout financial transaction reconciliation. Partner settlement authorization has unresolved approval/dual-control issues and treasury control prerequisite is absent.

**Required remediation:** keep KRIM partner-freight payout/settlement disabled. For a future approved payable, prove delivery/POD and exact partner/leg/amount, independently approved payable, verified beneficiary, provider/bank transfer result, canonical financial transaction and bank statement reconciliation. The current partner-direct model does not require KRIM to hold or pay partner freight.

### P2 — Legacy Cashfree stubs and legacy payment models remain

Cashfree functions remain in repository/possibly deployed function inventory as retired HTTP 410 stubs. Legacy `payments`, `revenue_ledger`, `partner_payouts` and `shipment_requests` models must not be blended with canonical `payment_orders`, `krim_financial_transactions` and `krim_shipments` without verified mapping.

**Required remediation:** preserve history and reconcile dependencies first; then remove obsolete frontend references and retire/deactivate legacy stubs only in an approved change window. Do not delete historical records or secrets as part of this audit.

## Readiness matrix

| Capability | Result | Current boundary |
|---|---|---|
| Razorpay webhook signature/event-ID validation | PARTIAL PASS | Strong source controls; provider delivery/runtime not tested |
| New KRIM freight checkout | BLOCKED by design | Environment/version gate present |
| Captured-payment webhook collection kill switch | FAIL / P0 | Gate absent in webhook path |
| Manual payment verification | PARTIAL PASS | Disabled for unpaid orders when flag off; runtime not tested |
| Canonical payment-to-shipment/quote/partner reconciliation | PARTIAL PASS | Strict source checks; historical orders remain unbound |
| Finance policy/approval table authorization | FAIL / BLOCKED | Prior Production DML exposure; revalidation/remediation required |
| Approval policy currency matching | FAIL / BLOCKED | Wildcard mismatch |
| Partner settlement dual control | FAIL / BLOCKED | No enforced one-time fingerprint/independent execution |
| Accounting entity/period alignment | FAIL / BLOCKED | Finance org and period differ |
| Double-entry ledger | NOT TESTED / BLOCKED | Functions exist; zero journals/entries |
| Ledger duplicate payload integrity | FAIL / BLOCKED | Canonical payload mismatch not detected |
| Tenant-scoped reconciliation | FAIL / BLOCKED | Legacy/global scope ambiguity |
| Existing orders/webhook recovery | FAIL / BLOCKED | Historical unbound records/backlog |
| KRIM service-fee revenue | NOT TESTED / BLOCKED | No allocation/invoice/recognition evidence |
| GST/tax automation | FAIL / BLOCKED | No approved rules/billing profiles; revenue recognition suspended |
| Refund request/review | PARTIAL PASS | Source controls; UI/backend full-refund mismatch |
| Refund execution | BLOCKED by design | Separate environment/version gate |
| Partner payable/settlement | FAIL / BLOCKED | No canonical payable; treasury and dual-control gaps |
| Cashfree | RETIRED / P2 | 410 stubs remain |
| Full financial close | NOT TESTED / BLOCKED | No ledger journals, reconciliation runs or close evidence |

## Required remediation and staging test order

1. Reconcile Production schema and migration history before any finance DDL, grant, policy or function change. The 2026-11-24 audit found 13 duplicate migration-version groups in the repository; do not apply/replay/baseline/squash migrations or invent a workaround. Produce a sanitized schema manifest, migration crosswalk and function/grant inventory first.
2. Fix the webhook kill-switch gap in isolated Staging: when collection is disabled, valid captured/order-paid events must be durably quarantined and alerted without paid-state or company-owned financial mutation; test provider retries, duplicate event IDs, concurrency, persistence failure and delayed captures.
3. Revoke ordinary member DML on all finance policy/control/approval/allocation/treasury/accounting tables and prove negative role/tenant tests.
4. Fix wildcard policy selection and require actionable approval IDs; test every supported currency and policy precedence.
5. Implement one-time fingerprint-bound maker-checker settlement approval with separate approver/executor and verified provider/bank result.
6. Align finance legal entity, accounting period, accounts, mappings and posting rules.
7. Make ledger posting duplicate detection compare canonical payload; test same and conflicting retries and double-entry balance.
8. Redesign reconciliation around canonical payment orders and explicit organization scope; test two tenants and mixed currencies.
9. Reconcile legacy provider orders/webhooks read-only first; no blind replay or manual processed flags.
10. Implement KRIM-only service-fee billing with signed commercial terms, evidence of service, CA-reviewed tax treatment and separate invoices; no freight GMV/10-90 split.
11. Align refund UI with full-refund-only backend; test provider refund outcome correlation and duplicate/conflicting webhook replay in Staging.
12. Only after all prior controls pass, run synthetic end-to-end customer payment → provider reconciliation → ledger → invoice/fee receivable → bank reconciliation → financial close in isolated Staging. No real-money tests.

## Safety and launch boundary

No Production or Staging SQL/RPC, Edge Function deployment, webhook replay, environment-secret change, Razorpay API call, refund, payout, invoice, ledger journal, financial reconciliation mutation, bank transfer or provider action was executed. Historical Production counts are explicitly from prior audits and were not refreshed in this gate.

**Allowed limited pilot model:** customer contracts with and pays a verified logistics provider directly; partner provides the service; KRIM separately invoices only its own contractually agreed and actually performed service fee after legal/tax review. This does not authorize KRIM to collect freight, hold escrow, split funds or pay partners.

**Gate C3.25: FAIL / BLOCKED — NO-GO for KRIM freight collection, automatic 10/90 split, escrow, partner payouts, KRIM refund execution, tax automation or financial close.**
