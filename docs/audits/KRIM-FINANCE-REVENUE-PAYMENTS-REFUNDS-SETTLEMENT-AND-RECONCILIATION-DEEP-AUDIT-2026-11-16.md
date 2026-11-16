# KRIM Finance, Revenue, Payments, Refunds, Partner Settlement and Reconciliation Deep Audit

**Date:** 2026-11-16  
**Environment:** Production Supabase and current GitHub main snapshot  
**Scope:** Read-only inspection of finance schemas, data, RLS/ACLs, RPCs, Edge Functions and finance workspace pages  
**Outcome:** Finance infrastructure is partially implemented, but **not ready to enable collection, fee billing, refunds, partner settlement or financial close**. This is a scoped finance readiness decision, not a declaration that the whole KRIM platform is unusable.

## Safety boundary

No payment, refund, payout, settlement, invoice, journal entry, approval, reconciliation or other business operation was executed. No production row, schema, function, RLS policy, storage object, payment provider or secret was changed. All function review was source inspection only.

## Executive summary

KRIM has a substantial finance foundation: Razorpay webhook signature validation, a global payment-order flow, an idempotent payment reconciliation RPC, a full-refund request/review workflow, partner payable controls, accounting mappings, a double-entry ledger implementation and a treasury/reconciliation design.

The current launch model is nevertheless correctly configured as **partner-direct / non-custodial**:
- New KRIM freight checkout is blocked by an explicit server-side environment/version gate.
- Verification of unpaid KRIM freight orders is blocked unless separate approval is enabled.
- Refund execution is blocked unless a separate legacy-refund approval is enabled.
- Cashfree endpoints return HTTP 410 and state that the provider is retired.
- Finance UI text explicitly says customers pay their contracting logistics provider directly; KRIM does not collect freight funds, hold escrow, split freight settlements or automatically pay partners.

The principal blockers are not cosmetic. Finance configuration and approval tables have overly broad organization-membership write policies; financial approval policy lookup does not match the wildcard currency values currently seeded; ledger posting prerequisites do not line up across finance organization IDs and accounting periods; webhook backlog and legacy unbound payments remain; and there is no operational evidence for invoices, ledger posting, partner payable, settlement, tax or fee collection.

## Production data snapshot

| Register | Rows / state |
|---|---:|
| Customer billing profiles | 0 |
| Invoices | 0 |
| Invoice items / payment applications | 0 / 0 |
| Payment orders | 6 |
| Legacy payments | 4 |
| Payment webhook events | 10 |
| KRIM financial transactions | 1 |
| Legacy revenue ledger | 1 |
| Ledger accounts | 14 |
| Ledger transactions / entries | 0 / 0 |
| Revenue allocation rules / allocations / runs | 0 / 0 / 0 |
| Partner payables | 0 |
| Legacy partner payouts | 1 |
| Financial approval policies | 8 |
| Financial approval requests / events | 0 / 0 |
| Treasury control rules | 0 |
| Accounting posting rules / account mappings | 3 / 5 |
| Accounting periods | 1 |
| Financial reconciliation runs / exceptions / exception events | 0 / 0 / 0 |
| Tax rules | 0 |
| Payment capability registry | 45 |

### Payment and webhook state

- Payment orders: 5 are `created`; 1 is `paid`.
- The one paid payment order has no customer-organization binding and no complete KRIM/partner quote binding. The 5 created orders also lack those bindings.
- Legacy `payments`: 2 paid and 2 pending; all 4 have no KRIM shipment binding and no quote binding.
- Webhooks: 6 `payment.authorized` events are marked processed; 2 `order.paid` and 2 `payment.captured` events remain unprocessed.
- The single legacy `partner_payouts` row is marked paid and has a transaction reference and timestamp. This database status alone is not independent proof of bank/provider settlement.
- No production ledger journal entries, partner payables, invoices, refunds, or reconciliation runs exist.

### Provider capability registry

All 45 country/provider/currency capability rows have `checkout_enabled=false` and `merchant_eligibility_verified=false`. Razorpay is marked implemented for INR, but the capability row is not approved for checkout. Other provider/currency combinations are planned, not enabled. This is the correct state until merchant eligibility, settlement account, supported payment method and legal/tax scope are evidenced.

## Positive controls confirmed

1. Razorpay webhook is deployed with JWT verification disabled as appropriate for a provider webhook, but validates the raw-body HMAC signature and requires provider event ID.
2. Webhook event storage is idempotency-aware: completed duplicates are acknowledged; concurrent insert conflicts return retryable 409 rather than false success.
3. New global Razorpay order creation is blocked by `KRIM_FREIGHT_COLLECTION_ENABLED` plus a version pin; the corresponding verification path also blocks unpaid orders unless the same explicit gate is enabled.
4. The service-role-only payment reconciler checks paid order, provider payment ID, shipment, customer organization, accepted customer quote, partner quote, amount/currency, accepted partner assignment and confirmed capacity reservation before recording the financial transaction.
5. New refund submission is full-refund-only; partial refunds are explicitly rejected until cumulative refundable-balance accounting is implemented.
6. Refund review requires AAL2, active finance/platform/operations membership, finance.manage or admin.platform permission, a meaningful note, and reviewer/requester separation.
7. Refund execution has a separate AAL2 finance review gate, stable idempotency key, full INR payment match and provider-webhook finalization. The Edge Function is currently disabled by an explicit environment/version gate.
8. New partner payable creation requires delivered shipment, completed assignment, accepted partner quote and independently verified delivery POD for the exact assignment/leg.
9. Partner settlement authorization requires an active partner-funds treasury control rule and, when configured, a matching financial approval record. No such treasury rule is currently configured, so settlement is blocked.
10. New partner payout reconciliation requires one completed financial transaction matching payable source reference, amount, currency, direction, ownership scope and provider reference.
11. Ledger posting implementation creates equal debit and credit entries, checks account organization, account status and currency, and one overload also checks an open accounting period.
12. Finance UI pages are mostly intentionally read-only/preparation-only. The command centre withholds legacy revenue data pending tenant scoping; partner settlement and payment registers are held; invoices, accounts receivable/payable, revenue/commission, tax and multi-currency pages do not pretend to issue/post/settle anything.
13. Cashfree order creation, verification and webhook endpoints return 410 PAYMENT_PROVIDER_RETIRED rather than executing legacy Cashfree operations.

## Findings and remediation

### P0 — Finance configuration and approval records are writable by ordinary organization members

**Evidence:** RLS is enabled, but the following finance-critical tables have an `ALL` policy using only `private.krim_has_organization_access(auth.uid(), organization_id)`, and authenticated users have INSERT/UPDATE/DELETE table grants:
- `krim_financial_approval_requests`
- `krim_financial_approval_policies`
- `krim_revenue_allocation_rules`
- `krim_revenue_allocations`
- `krim_treasury_control_rules`
- `krim_accounting_posting_rules`
- `krim_accounting_account_mappings`
- `krim_accounting_periods`

This predicate establishes organization access, not finance.manage authorization or a privileged finance role. For example, an ordinary member can directly mutate an approval request or financial policy row in their organization. The partner settlement authorization function reads approval rows by status/amount/currency; it does not call the fingerprint-consuming helper or independently prove that the approval was issued by a separate authorized reviewer. The current absence of partner payables and treasury rules limits present operational exposure, but this is a critical pre-activation control defect.

**Impact:** a non-finance organization member could alter financial configuration, journal mappings, period state, allocation policy or approval records. This undermines separation of duties and can affect later service-role financial processing.

**Required remediation:** remove direct authenticated INSERT/UPDATE/DELETE grants and permissive ALL policies from these finance-control tables. Keep client access read-only where justified and tenant-scoped. Perform policy, accounting mapping, period, allocation and approval mutations only through audited server-side RPCs that require finance.manage/admin permissions, AAL2 where appropriate, independent reviewer identity and immutable approval events. Add staging tests proving a normal customer/partner/driver/warehouse/operations member cannot mutate finance controls.

### P1 — Financial approval policy wildcard currency does not match the evaluator

**Evidence:** all eight active global approval policies use `currency_code='*'`, with zero auto-approval limit and founder approval required. `krim_internal.evaluate_financial_approval` searches for `currency_code = upper(p_currency_code)`; it does not treat `*` as a wildcard. When no policy is found, it returns `approval_required` with reason `no_active_policy`, but no approval_request_id. `krim_internal_prepare_partner_payable_approval` expects an approval request ID when approval is required and moves the payable to `under_review`.

**Impact:** current seeded approval policies are not selected for INR or other currencies. Partner payable approval can be left under review without an actionable approval request. The current treasury configuration also has no partner-funds rule, so the payout path is not operational.

**Required remediation:** implement explicit wildcard matching or seed currency-specific rules; add uniqueness/precedence and effective-date validation; test that every supported currency/scope selects exactly one policy and produces an approval request ID when required. Do not configure production rules until migration reconciliation is complete.

### P1 — Partner settlement authorization does not enforce configured dual control or approval fingerprint

**Evidence:** `krim_internal_authorize_partner_settlement` checks for a matching approved financial approval request and compares amount/currency, but does not enforce `requires_dual_control`, does not verify that `approved_by` is present and distinct from requester/executor, and does not call `krim_internal.consume_financial_approval` to consume the action fingerprint. The seeded financial approval policies currently have `require_dual_control=false`.

**Impact:** the model does not yet demonstrate independent approval and execution separation for partner-fund settlement. This compounds the broad direct-write access to approval rows.

**Required remediation:** make settlement authorization consume a one-time approval bound to the exact payable ID, amount, currency, beneficiary and execution action fingerprint. Enforce a different approver and executor for high-risk settlement, persist the approval and execution actors separately, expire approvals, and reject replay/conflicting payloads.

### P1 — Accounting period is configured for a different organization than the posting rules

**Evidence:** active accounting posting rules and account mappings are for finance organization 21; the only accounting period row is for platform organization 1. The ledger posting overload used by the financial-event posting path requires an open accounting period for the same organization ID. No accounting period for finance organization 21 was found.

**Impact:** the new ledger posting path for the finance organization will fail with `open_accounting_period_missing` until the period is configured correctly. There are currently zero journal transactions and entries, so no successful live posting proves this journey.

**Required remediation:** reconcile the legal/accounting entity model and create the appropriate period under the correct finance entity through an approved migration and audited setup workflow. Test open/closed/future periods and date boundaries in staging. Do not post real transactions to force initialization.

### P1 — Ledger idempotency does not compare a repeated transaction's canonical payload

**Evidence:** both `krim_internal_post_ledger_transaction` overloads return an existing transaction when the transaction reference/number already exists, without comparing the existing transaction's organization, amount, currency, debit/credit accounts, source type or source ID to the new request. The first overload scopes the lookup only by transaction reference; the second scopes by organization and transaction number but still does not compare payload equivalence.

**Impact:** a retry with the same reference but a conflicting amount or account mapping may be reported as idempotent success while preserving the original journal. The caller may believe a different event was posted.

**Required remediation:** persist a canonical payload fingerprint for each posting and compare all immutable fields on duplicate reference. Return idempotent success only for an exact match; otherwise return a hard conflict and require manual reconciliation. Add concurrency and conflicting-retry tests.

### P1 — Financial reconciliation aggregates legacy payments without consistently applying organization scope

**Evidence:** `krim_internal.create_finance_reconciliation` calculates source totals from `public.payments` by status, currency and time range but does not filter those payments by the requested organization or its shipment ownership. The no-argument `krim_internal_run_financial_reconciliation` scans paid legacy payments and partner payables globally and creates exceptions with `organization_id=NULL`. The organization-parameter overload treats NULL as all organizations.

**Impact:** organization-specific reconciliation may compare one organization's ledger with global legacy payment totals and create unscoped exceptions. This can produce false variances and weakens tenant attribution.

**Required remediation:** reconcile from canonical payment-order/financial-transaction sources with explicit legal-entity and shipment/assignment ownership. Require organization ID for tenant runs; separate a deliberately privileged global reconciliation mode. Every exception must have a validated owning entity or a clearly designated platform-wide scope. Test two-tenant isolation and mixed-currency periods.

### P1 — Legacy partner payout completion can mark a payout paid from a supplied reference alone

**Evidence:** legacy `complete_partner_payout` is SECURITY DEFINER and service_role-only, but its body accepts a transaction ID and payout method, marks the `partner_payouts` row paid, and syncs legacy shipment financials. It does not independently verify the provider/bank transaction. The legacy table currently has one paid row with a reference and timestamp, but no independent provider or bank evidence was verified.

**Impact:** legacy status can overstate actual settlement. It is separate from the newer payable → treasury authorization → payout record → financial transaction reconciliation path.

**Required remediation:** keep legacy payout UI and API retired. Do not use legacy paid status as settlement proof. Reconcile the existing record manually against provider/bank statement evidence before relying on it. Any remaining privileged path must require an externally verified provider result and exact payable/source binding.

### P1 — Existing payment orders and webhook backlog are not financially reconciled

**Evidence:** six payment orders exist, five in created state without customer-organization or quote binding; one paid order is missing customer-organization and quote binding. Four legacy payments have no KRIM shipment or quote binding. Eight of ten webhook events remain unprocessed (two order.paid, two payment.captured, six payment.authorized are processed). The strict reconciliation RPC rejects paid orders without shipment, customer organization, both quote bindings, accepted quote and confirmed assignment/capacity.

**Impact:** these records cannot be treated as fully reconciled KRIM shipment revenue or proof of valid commercial execution. The strict reconciler intentionally blocks the legacy paid order rather than fabricating a binding. Unprocessed captured/order-paid events need controlled review before any provider activation.

**Required remediation:** use the Treasury Audit read-only view and a controlled provider dashboard/statement reconciliation to classify each legacy order/event as test, duplicate, abandoned, paid-but-unbound or requiring manual remediation. Do not bind historical payments to shipments by guess. Do not mark events processed manually. Record only verified, approved reconciliation outcomes through the proper audited workflow.

### P1 — Revenue recognition and KRIM fee accounting are not operationally configured

**Evidence:** zero customer invoices, invoice items, shipment revenue items, revenue allocation rules, allocations and allocation runs. The revenue-recognition posting rule is suspended. The finance workspace's Referral & Coordination Fees page explicitly says it is preparation-only and does not calculate/accrue/post fees. The current partner-direct model requires a separate documented KRIM fee agreement and invoice; no evidence of a live fee contract or fee billing profile was found in the reviewed finance registers.

**Impact:** KRIM cannot currently report earned platform/referral/coordination revenue from this system. Freight quote value or partner freight GMV must not be counted as KRIM revenue.

**Required remediation:** define the commercial fee schedule and event of earning in signed partner terms, verify the actual KRIM service/referral evidence, confirm tax treatment with a qualified CA, create a separate KRIM invoice workflow and reconcile actual direct fee collection. Keep freight GMV, carrier collections and partner compensation outside KRIM revenue unless KRIM legally receives and accounts for them under a separately approved model.

### P1 — Tax rules and billing profiles are empty; tax automation must remain disabled

**Evidence:** zero `krim_tax_rules`, zero customer billing profiles, and no invoice records. The tax-compliance page is a browser-only review worksheet, not a tax engine. The payment capability registry does not show verified merchant eligibility or enabled checkout.

**Impact:** the system cannot calculate or represent jurisdiction-specific tax obligations with verified, effective-dated rules. No invoice should be issued from an unreviewed tax assumption. The user's registration/tax status and GST treatment must be confirmed separately with a qualified Indian tax professional.

**Required remediation:** establish the legal entity, tax registrations and place-of-supply/service classification; obtain CA-approved India tax treatment for KRIM's own service fee; seed only reviewed effective-dated rules with source references and approval evidence; test invoice numbering, tax calculation, credit notes, export treatment and filing data. Keep tax calculation and billing disabled until verified.

### P1 — Refund UI permits partial amounts that the backend deliberately rejects

**Evidence:** `app/finance/refunds-disputes.html` allows any positive amount up to the paid order amount. The private refund submission function accepts only an exact full-payment amount and explicitly rejects partial refunds until cumulative refundable-balance accounting is implemented.

**Impact:** users can enter a value that appears valid in the interface but is guaranteed to be rejected by the backend.

**Required remediation:** make the UI explicitly full-refund-only, populate the exact paid amount from the selected order, and validate exact equality before RPC submission. Keep provider execution disabled under the current partner-direct launch model.

### P2 — Cashfree functions remain deployed although retired

**Evidence:** `create-global-cashfree-order`, `verify-global-cashfree-payment` and `cashfree-payment-webhook` are listed ACTIVE but their source returns HTTP 410 PAYMENT_PROVIDER_RETIRED. They do not execute Cashfree operations.

**Impact:** operational clutter and potential confusion in provider configuration, although the inspected handlers are safe retired stubs.

**Required remediation:** remove old frontend references and, after confirming no historical webhook dependencies, delete/deactivate retired functions and secrets through an approved change window. Preserve historical reconciliation evidence.

### P2 — Finance workspace is intentionally incomplete, not falsely presented as operational

**Evidence:** accounts receivable/payable, invoicing, tax, multi-currency and referral-fee pages are preparation-only; partner settlements and payment register hold data pending tenant-specific permission review; the finance command centre withholds legacy revenue reporting; treasury page provides read-only webhook metadata but withholds journal/reconciliation details.

**Impact:** users do not yet have complete receivables, payables, invoicing, settlement, revenue, tax or multi-currency journeys.

**Required remediation:** retain the honest restricted state until tenant-scoped reads and server-side workflows exist. Complete each module with finance-specific authorization and real backend operations only after the underlying controls are corrected.

## Required staging-only test suite

1. Normal organization member cannot INSERT/UPDATE/DELETE finance approval policies/requests, revenue allocation rules/allocations, treasury controls, accounting posting rules/mappings or accounting periods.
2. Finance manager can read only assigned legal-entity records and cannot change privileged policy without separate approval.
3. Approval policy matching supports wildcard or exact currencies, effective dates and deterministic precedence.
4. Missing policy returns a clear blocked result with no dangling payable and no null approval reference.
5. Requester, approver and executor separation is enforced; high-risk settlement requires dual control.
6. Approval fingerprint binds exact payable, amount, currency, beneficiary and action; replay or altered payload is rejected.
7. Partner payable cannot be created without exact assignment, accepted quote, completed shipment and independently verified POD.
8. Partner payable idempotency returns existing only for exact assignment/quote/amount/currency match.
9. Partner settlement cannot proceed without active treasury rule and verified approval.
10. Provider payout status is not marked settled until independently verified provider/bank reference is reconciled to exact payable.
11. Ledger duplicate reference with same payload returns idempotent success; any amount/account/currency/source conflict is rejected.
12. Ledger posting requires correct organization, open accounting period, active same-currency accounts and balanced debit/credit entries.
13. Reconciliation is scoped by legal entity and currency; a tenant run never includes another tenant's payments.
14. Reconciliation exception cannot be closed without evidence, reason and independent reviewer.
15. Razorpay webhook signature failure, malformed payload, oversized body, duplicate event, concurrent delivery and provider retry are tested.
16. Unprocessed payment.captured/order.paid events reconcile to one exact order and one provider payment; conflicting IDs are held for manual review.
17. Legacy payment rows without shipment/quote binding cannot be silently promoted into canonical finance.
18. Refund requests require full paid amount, one request per order, stable idempotency and requester/reviewer separation; no partial refunds until supported.
19. Refund execution remains blocked when partner-direct mode is active; webhook reconciliation never initiates a refund.
20. KRIM fee invoice requires signed agreement, referral/service evidence, approved tax treatment and separate collection; partner freight funds never enter KRIM revenue.
21. Multi-currency tests use explicit provider/currency capability, FX source/time, ledger account, posting rule and settlement support.
22. Tenant isolation and AAL2 are tested across every finance RPC, table, Edge Function and signed document link.

## Remediation sequence

1. **Critical security first:** remove ordinary organization-member write access to finance policies, approval records, treasury controls, allocations, accounting mappings and periods. This requires migration reconciliation before production DDL.
2. Fix wildcard financial approval policy matching and enforce true dual-control/approval consumption.
3. Align finance legal-entity organization, accounting period, posting rules and account mappings.
4. Make ledger idempotency payload-aware and reconciliation tenant-scoped.
5. Classify legacy payment orders, payments, payout row and unprocessed webhooks with provider evidence.
6. Keep new freight checkout, refund execution and partner payout disabled under the partner-direct launch model.
7. Implement the KRIM-only referral/coordination fee invoice and receivables workflow after signed terms and CA-approved tax treatment.
8. Complete staging end-to-end tests, then re-evaluate the finance launch scope.

## Release boundary and launch model

**The finance stack is not ready for KRIM freight collection, automated 10/90 splits, escrow, partner payouts, tax automation, refunds or financial close.** This does not prohibit a carefully controlled, non-custodial partner-direct pilot in which customers contract with and pay verified logistics partners directly and KRIM separately invoices only its own properly agreed service fee after legal/tax review. That limited pilot still depends on real verified partners, approved service coverage, operational delivery evidence, appropriate contracts and applicable registrations.

No new production migration/function changes were applied. The production/repository migration mismatch and pending sanitized schema manifest remain blockers for safe production database remediation. No live payments, refunds, payouts, invoices, journal entries, settlements or provider actions were made.

## Overall conclusion

KRIM has meaningful finance components and several good safety gates. The key work now is **targeted remediation**, not replacing the finance architecture. First fix the finance-table authorization model and approval integrity, then correct accounting policy/period alignment and reconciliation, classify the legacy provider records, and only then implement KRIM's separate service-fee billing. Until those steps are completed and staged, keep collection and payout features disabled.
