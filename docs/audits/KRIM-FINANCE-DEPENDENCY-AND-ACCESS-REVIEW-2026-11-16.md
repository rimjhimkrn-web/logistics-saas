# KRIM Finance Integration Dependency & Access Review — 16 November 2026

## Scope and status

Read-only production catalog and repository review. No production DDL, data writes, ledger postings, payment/refund execution, payouts, or provider configuration changes were made.

This follow-up extends `KRIM-FINANCIAL-ECOSYSTEM-INTEGRATION-AUDIT-2026-11-16.md`. It maps the currently discoverable finance database surfaces, frontend workspace, and key access-control dependencies. It is not a production-readiness certification.

## 1. Finance workspace inventory

The repository contains an authenticated finance workspace under `app/finance/` with pages for:
- dashboard/index;
- accounts payable and receivable;
- invoicing;
- financial reporting;
- multi-currency;
- partner settlements;
- payment processing;
- revenue/commission;
- refunds/disputes;
- tax compliance;
- treasury/audit.

Additional customer, partner, enterprise, and public finance paths exist. The following legacy `public/finance/` pages are redirects to the authenticated app, not independent finance systems: revenue reports and finance dashboard. Do not count legacy redirect pages as operational features.

The existence of a page or route is not proof that its underlying workflow is connected, authorized correctly, or tested end-to-end.

## 2. Database dependency map observed

### Posting configuration and ledger
- `krim_accounting_posting_rules` supplies event-to-account-role rules.
- `krim_accounting_account_mappings` maps debit/credit roles to organization accounts and currency.
- `krim_internal_post_financial_event(bigint,text,numeric,text,text,text,text,text)` looks up an active posting rule and both account mappings, then invokes `krim_internal_post_ledger_transaction`.
- The invoked overload is the text-source overload:
  `krim_internal_post_ledger_transaction(bigint,text,text,text,bigint,bigint,numeric,text,text,text)`.
- This overload checks positive amount, distinct active accounts, matching currency, an accounting period containing the current date, and period status = open; it inserts a transaction, matching debit/credit entries and an audit event.
- The alternate overload
  `krim_internal_post_ledger_transaction(bigint,text,text,text,bigint,bigint,numeric,text,bigint,text)`
  uses a numeric source ID and transaction-reference idempotency, but the inspected definition does not check an open accounting period and does not create the same audit event. Treat this as a legacy/alternate path until every caller is inventoried. Do not call it by ambiguous name; any future approved invocation must use an explicit signature.

### Billing and receivables/payables
- `krim_internal_create_customer_invoice_for_delivered_shipment(bigint)` is an internal invoice-generation path gated on delivered shipment and accepted quote.
- Partner payable creation routines exist for completed/delivered shipments, with separate approval-preparation and reconciliation routines.
- `krim_invoices`, `krim_invoice_items`, `krim_partner_payables`, and `krim_invoice_payment_applications` are distinct records. Client roles have read-only access (or deny policies) in the inspected table ACL/policy snapshot; internal service routines are expected to perform writes.
- Multi-leg invoice/payable/revenue-allocation writes are blocked by a trigger when an active shipment leg plan has more than one leg, pending leg-level allocation and reconciliation. This is a deliberate safety hold, not a feature to bypass.

### Refunds and provider reconciliation
- Refund request submission, finance review, and Razorpay execution claim are separated into privileged functions.
- Refund submission currently allows full refunds only; partial refunds are explicitly blocked pending cumulative balance accounting.
- Finance review and execution require AAL2, finance/platform permission, and requester/reviewer separation. Execution claim requires an already-paid INR Razorpay order and prevents a second provider refund from being created when a provider refund ID already exists.
- The refund claim routine returns an execution payload; it is not evidence that Razorpay has actually refunded funds.
- A finance webhook-list RPC requires AAL2 and platform-admin permission and exposes a redacted event/order reference and reconciliation state.
- Historical unmatched or unprocessed provider events remain a manual reconciliation issue; do not mark them processed or discard them without provider-side proof.

## 3. Access-control finding — high priority

The helper `private.krim_has_organization_access(uuid,bigint)` checks only that:
1. the supplied user ID matches `auth.uid()` (or auth.uid() is null for privileged contexts); and
2. the user has an active membership in an active organization.

It does not check a finance-specific permission or role.

In the live catalog snapshot, these tables have authenticated INSERT/UPDATE/DELETE grants and an ALL-command RLS policy whose USING and WITH CHECK predicates rely only on that active-membership helper:
- `krim_accounting_account_mappings`
- `krim_accounting_periods`
- `krim_accounting_posting_rules`
- `krim_revenue_allocation_rules`
- `krim_revenue_allocation_runs`
- `krim_revenue_allocations`
- `krim_treasury_control_rules`

This means any active member of the relevant organization may be able to directly mutate sensitive accounting configuration, revenue allocation records/runs, and treasury control rules, subject to the listed grants and RLS policy. This is a material least-privilege / separation-of-duties risk. It is not proof of exploitation or of a currently compromised account.

Recommended target control:
- revoke direct client write privileges on these control/financial tables;
- allow writes only through narrowly scoped server-side RPCs or service-role routines;
- require finance.manage (or an explicitly approved dedicated permission) and dual control for high-impact configuration changes;
- make posted ledger transactions, entries, allocation runs/results, and audit records append-only or correction-by-reversal where appropriate;
- add negative tests for ordinary organization member, finance viewer, finance manager, platform admin, anon, and service-role contexts.

**Do not apply an emergency production SQL patch from this report.** Production migration history is materially divergent from the repository. First preserve the current state, inspect the full role/permission model and every caller, recover authoritative migration bodies, then prepare a reviewed, staged remediation with rollback and access regression tests.

Other inspected controls:
- Ledger transaction and entry tables are client read-only in the sampled grants/policies.
- Invoice and partner payable tables are client read-only in the sampled grants/policies.
- Refund request tables have RLS enabled and FORCE RLS.
- Payment webhook events deny authenticated direct access.
- Payment capability registry denies anon/authenticated direct access.
- The above are catalog snapshots; recheck effective privileges (including inherited role membership, SECURITY DEFINER wrappers, views and RPCs) before release.

## 4. Organization scope and accounting-period mismatch remains unresolved

The preceding audit found all 14 seeded ledger accounts and three posting rules under organization 21 (finance verification organization), while the accounting period is under organization 1 (KRIM Global Platform). The canonical text-source posting overload requires an open period for the same organization as the ledger transaction. The organization-21 posting rules therefore cannot safely be treated as production-ready configuration until the legal-entity/organization model and period ownership are reconciled.

Do not copy account IDs or move seeded rows by assumption. Establish the platform operator/legal entity, customer and partner organization boundaries, and internal test organization semantics first.

## 5. Twelve-engine integration matrix

Every monetization engine must resolve to an accepted commercial agreement, versioned fee schedule, eligibility conditions, billing trigger, invoice/receivable, recognition rule, tax decision, refund/cancellation treatment, posting mapping, and contribution-margin reporting.

| Revenue engine | Commercial/billing trigger to design | Primary control |
|---|---|---|
| Referral fees | Contract-defined qualified referral outcome | Evidence of attributable conversion; fee owed to KRIM only |
| Coordination fees | Separately scoped coordination service delivered | Signed scope, service acceptance, liability boundary |
| Partner subscriptions | Active paid subscription period | Entitlement, renewal, cancellation, tax |
| Premium listings | Paid listing period and published eligibility | No pay-to-verify; disclose sponsored placement |
| Customer premium services | Purchased premium feature/service | Entitlement and service delivery evidence |
| SaaS subscriptions | Active seat/usage/term | Metering, proration, renewal, access lifecycle |
| Enterprise LOS contracts | Contract milestone or recurring term | Enterprise order form, SLA and acceptance |
| API access | Metered calls/committed tier | Usage ledger, rate limits, idempotent metering |
| White-label software | License/implementation milestones | IP/license terms, deployment acceptance |
| AI intelligence | Subscription or contracted report/usage | Data rights, model limits, provenance, service terms |
| Supply-chain analytics | Subscription or delivered analysis | Data lineage, privacy, output acceptance |
| Integration/infrastructure | Implementation milestone or recurring integration | Scope, change control, uptime and acceptance |

Do not create default commission percentages or tax rates. Fee values and recognition points must come from signed terms and reviewed accounting/tax policy.

## 6. Source-of-truth boundaries

- Partner freight charged and collected directly by the partner is partner revenue/cash, not KRIM revenue/cash.
- KRIM revenue is only its own contractual fee earned under the relevant agreement and accounting policy.
- Quote acceptance, invoice issue, customer payment, service completion, and revenue recognition are separate events.
- GMV, KRIM revenue, cash, profit, and valuation must be reported separately.
- The initial partner-direct operating model must not route partner freight through KRIM checkout, escrow, settlement, or payout features.
- Lending, insurance distribution, escrow, remittance, or custody remain out of scope unless licensed partners and jurisdictional legal approvals are in place.

## 7. Gate 1 next steps — in order

1. Confirm organization/legal-entity boundaries and resolve organization 1 versus 21.
2. Build an exhaustive function/trigger/Edge Function/frontend caller graph for every financial write.
3. Verify effective table and function privileges, including inherited grants, PUBLIC defaults, views, wrappers and service-role paths.
4. Design and test least-privilege remediation for the seven high-priority write surfaces above.
5. Choose one canonical ledger-posting API and explicitly retire or constrain the alternate overload after caller proof.
6. Reconcile legacy `payments`, `payment_orders`, `payment_webhook_events`, `revenue_ledger`, `shipment_financials`, and `partner_payouts` to provider evidence and canonical `krim_*` records. Do not double-count or delete historical records.
7. Recover authoritative production migration SQL bodies and resolve repository/history drift before DDL.
8. Build isolated staging tests for balanced entries, open-period enforcement, idempotency/concurrency, organization isolation, ordinary-member write denial, dual approval, reversal, webhook replay, refund, and partner-direct separation.
9. Only after all prior checks, implement the signed-contract fee schedule and KRIM-only receivable/revenue flow for the first commercially validated engine (likely referral fee under the current partner-direct model).

## Release posture

Finance integration remains **NO-GO for live-money production use**. This review found meaningful foundations and a high-priority access-control gap; it did not change production or prove a successful end-to-end financial transaction. Continue with read-only dependency mapping and staged design until the blockers above are closed.
