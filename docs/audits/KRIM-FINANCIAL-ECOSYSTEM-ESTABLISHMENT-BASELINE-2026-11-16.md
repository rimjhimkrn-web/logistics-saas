# KRIM Financial Ecosystem Establishment Baseline
**Date:** 16 November 2026  
**Scope:** Read-only review of the live Supabase financial schema, selected grants/RPC execution privileges, and the previously agreed partner-direct commercial model.  
**Project:** `ebltviniygljwwseplph`

## Executive decision

**Financial ecosystem status: NOT ESTABLISHED for live commercial use.** The platform contains substantial finance-related schema and workflow infrastructure, but the existence of tables, RPCs, payment-provider code, or UI pages does not establish that KRIM has a verified bank account, an active merchant account approved for the intended fee flow, a compliant tax/invoice setup, a tested bookkeeping process, or real collected revenue.

This review made **no production writes**, did not invoke business RPCs, did not create invoices/payments/refunds/settlements, and did not change financial configuration.

## Commercial model to preserve

Initial operating model:
1. Customer contracts with and pays the logistics partner directly for freight.
2. KRIM separately contracts for and earns its own referral, introduction, platform, or coordination service fee, where actually provided and agreed.
3. KRIM records only its own earned income and associated taxes/expenses.
4. Partner freight collections and freight GMV are not KRIM revenue.
5. No freight pooling, escrow, custody, automatic split, partner payout, or freight-value commission is enabled for the initial model.

This model is **not automatically GST-exempt**. Classification, place/time of supply, registration threshold/compulsory registration, invoicing, TDS/TCS and marketplace/intermediary obligations require review by an Indian CA/tax professional against the actual contracts and service flow.

## Live database evidence (read-only)

Exact row counts returned during this review:

| Area | Table | Rows |
|---|---|---:|
| Transactions | `krim_financial_transactions` | 1 |
| Invoices | `krim_invoices` | 0 |
| Chart of accounts | `krim_ledger_accounts` | 14 |
| Ledger transactions | `krim_ledger_transactions` | 0 |
| Ledger entries | `krim_ledger_entries` | 0 |
| Posting events | `krim_financial_posting_events` | 0 |
| Posting dead-letter queue | `krim_financial_posting_dlq` | 0 |
| Reconciliations | `krim_financial_reconciliations` | 0 |
| Reconciliation exceptions | `krim_financial_reconciliation_exceptions` | 0 |
| Refund requests | `krim_refund_requests` | 0 |
| Settlements | `krim_settlements` | 0 |
| Revenue allocation rules | `krim_revenue_allocation_rules` | 0 |
| Revenue allocation runs | `krim_revenue_allocation_runs` | 0 |
| Revenue allocations | `krim_revenue_allocations` | 0 |
| Shipment revenue items | `krim_shipment_revenue_items` | 0 |
| Tax rules | `krim_tax_rules` | 0 |
| Payment orders | `payment_orders` | 6 |
| Payment webhook events | `payment_webhook_events` | 10 |

These counts do not establish that any payment is a genuine customer transaction or that KRIM has earned revenue. The six payment orders and ten webhook events require a separate safe, metadata-only classification before any commercial reliance. The single financial transaction likewise must not be treated as verified revenue without source, counterparty, bank settlement, contract, invoice and accounting evidence.

## Security and control findings

1. `krim_financial_posting_events` and `krim_financial_posting_dlq` have RLS enabled, but the live grants include direct authenticated INSERT, UPDATE and DELETE. Previous policy review found organization-scoped authenticated ALL policies. Financial posting/recovery records must not be directly mutable by ordinary organization members. This is a **P0 hardening candidate**.
2. `krim_revenue_allocation_rules` also has authenticated INSERT, UPDATE and DELETE grants. No allocation rules or runs currently exist. Do not activate or populate these for freight splits under the partner-direct model.
3. The selected internal posting, reconciliation and partner-settlement RPCs are not executable by anon/authenticated and are executable by service_role, which is the expected direction for privileged internal posting. Keep these service-only paths disabled from business use until their semantics and migration lineage are reconciled.
4. `krim_refund_request_submit` and `krim_refund_request_review` are executable by authenticated users. This review did not invoke them. Confirm their internal authorization, ownership, AAL, reviewer independence, idempotency and payment-provider execution separation before enabling refunds.
5. Authenticated users have SELECT on selected invoice, settlement, shipment-revenue and payment-order tables. Confirm row-level organization isolation and ensure that only KRIM-owned service invoices/revenue are exposed in the initial commercial model.
6. Legacy freight financial structures and functions remain present. Their presence must not be interpreted as authorization to collect freight, calculate freight commission, split customer payments, recognize freight revenue, or pay partners.

## Establishment gates

### Gate A — legal and tax
- Retrieve and review the actual GST rejection order/ARN and any REG-03/REG-04 notices.
- Determine whether a fresh GST application, appeal/clarification, or non-registration launch is appropriate.
- Obtain written CA advice on KRIM's actual partner-direct contracts and fee invoices, including GST classification, threshold/compulsory registration, TDS/TCS and marketplace/intermediary obligations.
- Do not represent the business as GST-exempt without that advice.

### Gate B — business banking
- Confirm a dedicated business bank account is opened in the correct proprietorship/trade-name configuration.
- Verify account-holder/trade-name acceptance, IFSC, settlement destination, bank proof and bank statement access.
- Do not store full bank credentials or account numbers in public repository files or frontend code.

### Gate C — KRIM-owned revenue
- Define the service actually delivered by KRIM, contracting party, fee basis, timing of earning, cancellation/refund rules and evidence of completion.
- Use written partner/customer terms and separately agreed fee schedule.
- Keep partner freight amount, partner payment evidence and KRIM fee as separate records.

### Gate D — invoicing and bookkeeping
- Approve a CA-reviewed chart of accounts and accounting basis.
- Create invoice numbering, tax fields, credit-note/debit-note, receipts, expense vouchers and document retention process.
- Ensure invoice issuer and tax treatment reflect the real supplier and contract.
- Establish monthly bank reconciliation and supporting-document checks.

### Gate E — payment collection
- Verify Razorpay merchant KYC, approved business category, live mode, settlement bank account, refund policy, webhook secret, duplicate-event handling and actual settlement statement.
- Restrict the payment product to KRIM's own lawful service fees at launch.
- Do not use payment links/orders to collect freight on behalf of partners unless separately reviewed and expressly approved by legal/tax and the provider.

### Gate F — accounting integrity and access
- Reconcile migration history before any production DDL or privilege/policy change.
- Remove direct authenticated mutation rights from financial posting/recovery data through a reviewed, forward-only migration after reconciliation.
- Enforce maker-checker for sensitive finance operations, append-only audit history, idempotency, balanced journal entries, immutable source references and period close.
- Validate organization-level isolation and role permissions for all finance read paths.

### Gate G — live acceptance tests
Only after Gates A–F are complete, run controlled low-value tests for KRIM-owned fee collection using a real approved merchant account, with explicit authorization. Verify order creation, signature/webhook validation, idempotency, payment capture, provider settlement into KRIM's bank, invoice/receipt, ledger posting, bank reconciliation and refund handling. Never use a real freight transaction or partner payout as a test.

## Immediate next action

The legal/tax gate is first. Obtain the GST rejection order and any portal notices. Redact PAN, Aadhaar, personal address, phone, email, ARN and other identifiers before sharing. The actual rejection reason is required to choose a safe next step; do not submit another GST application based on guesswork.

## Release decision

**Not approved for live commercial payment collection or finance production readiness.** Continue only safe, non-production documentation and code review until legal/tax, banking, merchant onboarding, finance security and migration reconciliation gates are evidenced.
