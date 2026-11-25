# C3.60 — Global financial integrity, payments, revenue, ledger, refunds, settlement and reconciliation readiness

**Programme:** KRIM GLOBAL PLATFORM — AI QUALITY ASSURANCE, SIMULATION & RELIABILITY PROGRAMME  
**Phase:** 00 — Infrastructure Audit  
**Gate:** C3.60  
**Immutable source baseline:** `72d75a18f985ceb09e468839435ee95700e11e46`  
**Audit date:** 2026-11-25  
**Method:** Read-only inspection of immutable Edge Function source, finance migrations, finance workspace pages and dated 16–17 Nov audit/remediation artifacts. No SQL/RPC, payment provider, bank, refund, payout or finance workflow was executed.

## Verdict

**FAIL / BLOCKED — NO-GO for KRIM freight collection, platform fee collection, refunds, partner payouts/settlement, revenue recognition, commercial invoice issuance, or financial close.**

KRIM has meaningful finance foundations: Razorpay HMAC verification, order and payment binding, idempotent financial reconciliation, explicit checkout/verification/refund gates, a double-entry ledger design, refund maker-checker workflow, partner payable prerequisites, currency capability registry and read-only webhook reconciliation.

The most severe current-source defect is that **the Razorpay captured-payment webhook does not enforce the freight-collection kill switch** used by order creation and unpaid-payment verification. A valid captured event can therefore transition an existing local order to paid and create a company-owned freight credit even while the intended partner-direct model keeps new freight collection disabled. This is a P0 release blocker.

The dated finance audits also identified broad organization-member write exposure on finance configuration/approval/allocation records, unprocessed webhook events and open payment orders, legacy financial records inconsistent with the new non-custodial model, and incomplete accounting/reconciliation configuration. No later independent runtime evidence in this gate proves these issues are closed.

## Scope reviewed

- Razorpay order creation, payment verification, captured-payment/refund webhook and refund execution Edge Functions.
- Payment capability, currency, finance access, ledger, posting, reconciliation, refund and multi-leg finance migrations.
- Finance workspaces: payment processing, transactions, revenue/commission, invoicing, refunds/disputes, partner settlements, multi-currency, tax and treasury/audit.
- Dated 16 Nov finance deep audit, financial integrity/payment reconciliation audit, ledger/invoice/refund/settlement boundary audit, customer finance exposure audit, disputes/chargebacks/reconciliation review, P0 webhook remediation plan, and 17 Nov direct-write remediation specification.

## Positive source controls — PARTIAL PASS

1. **New freight order creation is explicitly gated.** `create-global-razorpay-order` requires `KRIM_FREIGHT_COLLECTION_ENABLED=true` and the pinned approval version `2026-11-15-v1`; otherwise it returns a disabled response.
2. **Unpaid payment verification is also gated.** `verify-razorpay-payment` blocks verification of unpaid orders unless the same collection gate is enabled, while retaining a limited idempotent recovery path for already-paid orders.
3. **Payment binding checks are substantial.** The reviewed order/verification flows check Razorpay key mode, currency capability, amount/minor units, partner quote, accepted partner assignment, confirmed capacity binding/reservation and accepted customer quote before collection/verification.
4. **Webhook authenticity and event idempotency exist.** The webhook verifies raw-body HMAC, requires provider event ID, stores events before processing, handles duplicate event IDs and checks provider order/payment ID, amount, currency and captured status.
5. **Captured payment reconciliation is service-role-only and business-bound.** The internal reconciler checks canonical order, shipment, customer organization, accepted quote/partner quote, assignment, capacity reservation and exact INR amount before recording the company-owned financial transaction.
6. **Refund execution is separately gated.** The refund Edge Function is disabled unless a separate legacy-refund flag and version are explicitly enabled. Its claim path requires an approved full INR refund, stable idempotency key and finance approval; provider outcomes are reconciled by signed refund webhooks.
7. **Refund request workflow has maker-checker controls.** Submission is customer-bound and full-paid-only in the later migration; review requires AAL2, active finance/platform/operations membership, finance.manage or admin.platform, meaningful note and requester/reviewer separation.
8. **Partial refund exposure is deliberately constrained.** The later request migration limits eligibility to fully paid, not-yet-refunded orders pending cumulative refundable-balance accounting.
9. **Cashfree is retired at source.** Cashfree endpoints are present in the repository but dated audits report they return HTTP 410 / provider retired; they must not be revived or represented as available.
10. **Revenue recognition has a safety suspension.** The reviewed migration suspends freight revenue recognition pending validated GST output-tax split and invoice subtotal/tax accounting.
11. **Multi-leg finance posting has a hard guard.** A reviewed trigger blocks invoice, payable and revenue allocation writes where leg-level commercial allocation and partner invoicing are not reconciled.
12. **The finance UX largely avoids false operational claims.** Dated audit review found finance pages mostly read-only/preparation-only and explicit partner-direct messaging: customer pays the contracting logistics provider directly; KRIM does not hold or split freight funds.

## P0 — release blockers

### 1. Razorpay captured-payment webhook bypasses the freight-collection kill switch

The immutable baseline `supabase/functions/razorpay-webhook/index.ts` verifies signature/event ID and validates payment/order ID, exact amount, currency and captured status. It then conditionally changes the matching `payment_orders` row to `paid`, calls `krim_internal_reconcile_razorpay_captured_payment`, creates a completed company-owned financial transaction and marks the event processed.

Unlike `create-global-razorpay-order` and `verify-razorpay-payment`, the webhook does **not** check `KRIM_FREIGHT_COLLECTION_ENABLED` or `KRIM_FREIGHT_COLLECTION_APPROVAL_VERSION` before paid-state or financial mutation. This is present in the immutable source reviewed for this gate, not merely a historical snapshot.

**Impact:** a valid delayed/retried captured event for an existing provider order can cause KRIM to record partner freight money as a company receipt even though the current launch model says the customer pays the logistics provider directly and KRIM does not collect freight funds.

**Required remediation:** introduce one shared server-only collection-mode decision used by order creation, verification and captured webhook processing. With collection disabled, captured events must be durably quarantined/deferred with alert/outbox before provider acknowledgement and must not mutate payment order, financial transaction, revenue ledger or shipment financial state. Historical recovery must be a separate operator-authorized, exact-reference, maker-checker path. Preserve legitimate approved refund-outcome reconciliation independently. Test signed captured events while disabled and enabled in isolated Staging. Do not deploy without migration-history reconciliation and explicit approval.

### 2. Finance-control direct-write authorization is not proven safe

The dated 16 Nov finance deep audit found authenticated organization members had direct INSERT/UPDATE/DELETE privileges and broad organization-membership `ALL` policies on sensitive tables including financial approval requests/policies, revenue allocation rules/allocations, treasury rules, accounting posting rules, account mappings and accounting periods. The organization-membership predicate did not require finance.manage or a privileged finance role. It also found settlement authorization did not independently consume a fingerprint-bound approval or prove independent reviewer/executor separation.

The immutable baseline migration `20261107210000_restrict_direct_finance_table_writes.sql` revokes direct DML from payment_orders, ledger accounts and reconciliation exceptions; it does not, by itself, demonstrate closure of the full sensitive-table list above. The 17 Nov remediation artifact likewise records broad direct-write exposure across finance tables. Current deployed grants/RLS were not queried in this gate.

**Required remediation:** reconcile effective table grants, policies, triggers and RPC ACLs for every finance-critical table; revoke client DML where RPC-only is intended; require finance-specific permission, AAL2, tenant scope, maker-checker and append-only correction events. Ordinary customer/partner/driver/warehouse/operations members must not mutate approvals, periods, posting rules, account mappings, treasury controls, allocation policy, posting events or dead-letter queues.

### 3. Historical payment orders and webhook events are unresolved

The dated 16 Nov production audit reported six Razorpay INR payment orders (five `created`, one `paid`), ten webhook events (six `payment.authorized` processed, two `order.paid` and two `payment.captured` unprocessed), and a paid legacy partner payout. Provider/bank status was not independently queried. The paid order lacked complete customer-organization and quote binding in the dated snapshot; the unprocessed capture/order-paid events were not reconciled to exact provider payment/order, accepted quote, assignment, capacity reservation, local financial transaction and bank settlement evidence.

These counts are historical, not current-live claims. They must not be silently treated as test fixtures, replayed, marked processed or discarded.

**Required remediation:** authorized operator must reconcile every open order and unprocessed event against Razorpay dashboard/API and bank statement, establish test/live mode and actual funds movement, bind exact customer/quote/partner/assignment/capacity, classify duplicate/test/failed/actual/conflict and preserve immutable disposition. No webhook replay until that evidence exists.

### 4. Current commercial model and financial ownership are inconsistent in legacy data

The current intended model is **partner-direct / non-custodial**: customer contracts with and pays the contracting logistics provider for freight; partner performs the service; KRIM separately earns an agreed referral/coordination/platform service fee only for services KRIM actually provides. KRIM does not receive, pool, hold, escrow, split, settle or pay out partner freight funds.

Dated audit evidence found legacy shipment financials showing customer payment and partner payout as paid, one legacy revenue ledger row marked reconciled, and one canonical company-owned freight credit, while canonical partner payables/settlements, invoices and journal entries were empty. Those legacy statuses and references do not independently prove provider/bank settlement or valid KRIM revenue.

**Required remediation:** reconcile and classify historical rows as test/legacy/actual using provider and bank evidence. Do not delete or rewrite them without approved accounting adjustment. Remove old 10/90 freight split and partner-payout assumptions from new flows. Freight GMV, partner freight collections and partner payouts are not KRIM revenue. Create a distinct KRIM fee product/order and separate invoice/ledger path only after legal, tax, contract, bank and merchant readiness.

### 5. No end-to-end financial evidence or launch-grade reconciliation

Dated 16 Nov snapshot reported zero canonical ledger transactions/entries, invoices, invoice items/applications, revenue allocation rules/runs/allocations, partner payables, refunds, refund events and reconciliation runs/exceptions. The legacy tables were populated, but they were not a validated current source of truth. No isolated Staging financial lifecycle has been proven.

**Required remediation:** execute isolated Staging end-to-end tests with synthetic identities and provider fixtures only after Phase 03 isolation approval. Evidence must cover payment → canonical transaction → journal → invoice/fee receivable → receipt → reconciliation; refunds and disputes; payable/settlement only if the legal model is deliberately changed.

## P1 — accounting, settlement and operational gaps

1. **Approval currency wildcard mismatch:** dated audit found eight active global approval policies use currency `*`, while the evaluator matches exact uppercased currency. It returns approval_required with no approval_request_id; payable may remain under_review without actionable approval. Revalidate current function and policy data.
2. **Settlement dual control/fingerprint:** dated audit found settlement authorization did not enforce `requires_dual_control`, distinct approver/requester/executor, or consume the exact approval fingerprint. Do not enable payouts until corrected and tested.
3. **Accounting entity/period mismatch:** dated snapshot found active posting rules/mappings for finance organization 21 but the only accounting period for platform organization 1. Ledger posting requiring same-organization open period would fail. Legal-entity and period model needs CA/accounting review.
4. **Ledger idempotency is not fully payload-bound:** dated audit found posting overloads could return existing transaction on reused reference/number without comparing organization, amount, currency, transaction type, source and debit/credit account identities. Conflicting retries must hard-fail.
5. **Reconciliation tenant scope:** dated audit found legacy `payments` totals could be aggregated without requested organization scope and global runs could create exceptions with organization_id NULL. Canonical runs must be legal-entity scoped; global reconciliation must be a separate privileged mode.
6. **Legacy payout path overstates settlement:** legacy `complete_partner_payout` could mark a payout paid from a supplied reference without independent provider/bank verification. Do not use it for current partner-direct operations.
7. **Revenue recognition remains suspended pending tax split:** the reviewed migration explicitly suspends freight revenue posting pending GST output-tax and invoice subtotal/tax validation. Do not bypass this control.
8. **Tax/billing setup absent:** dated audit found zero tax rules and no validated tax automation. Invoice issuance, GST split, place-of-supply, tax invoice numbering, credit notes, withholding/TDS and cross-border tax treatment require qualified CA review and approved rules.
9. **Multi-currency is not global merchant readiness:** dated audit reported 45 provider/country/currency capability rows with checkout disabled and merchant eligibility unverified. Razorpay INR implementation status is not live checkout approval; settlement, refunds and FX capability were false in the India row.
10. **Refunds are not ready for general use:** partial refunds are deliberately rejected; refund execution is gated; provider refund webhook finalization, duplicate/out-of-order events, partial/failed/refunded states, bank settlement and ledger reversal have not been end-to-end tested.
11. **Chargebacks/disputes/insurance are not operationally proven:** evidence, representment deadlines, provider dispute callbacks, reserve/hold, loss allocation and insurer recovery have no verified end-to-end workflow.
12. **Posting queues and dead-letter recovery are unproven:** no demonstrated alerting, operator ownership, retry SLA, idempotent replay, conflict quarantine or financial close evidence.
13. **Bank/merchant capability unverified:** key mode, Razorpay merchant KYC/category approval, settlement bank account, actual bank credits, refund enablement and provider settlement statements were not independently verified. No secrets were read.
14. **Cashfree legacy functions remain in repository:** dated source review indicates endpoints return 410, but deployment parity and absence from all public paths must be checked; do not use Cashfree.
15. **Production migration-history mismatch remains a deployment blocker:** no finance migration or policy change should be applied to Production until migration/schema reconciliation is completed and explicitly authorized.

## Required isolated Staging acceptance tests

- **Kill-switch:** with freight collection disabled, signed `payment.captured` and `order.paid` events must be durably deferred/quarantined, never set payment order paid or create company-owned financial transaction/ledger entries. With approved versioned gate enabled, only exact eligible order/quote/partner/assignment/capacity/amount/currency can reconcile.
- **Webhook security/idempotency:** malformed signature hex/length, wrong signature, missing event ID, duplicate event ID, concurrent delivery, out-of-order authorized/captured/order-paid, unknown order, wrong payment ID, wrong amount/currency, already-paid conflicting payment ID and transient RPC failure.
- **Durable recovery:** deferred event alert/outbox atomicity, operator assignment, age/SLA, exact historical recovery, dead-letter, no blind replay, no acknowledgement before durable handoff.
- **Refund outcomes:** signed created/processed/failed events; exact approved refund request, original payment, amount, currency and provider refund ID; duplicate/conflicting refund ID; partial/over-refund; out-of-order callbacks; atomic payment status, refund event and debit-ledger consistency.
- **Authorization matrix:** direct REST DML denied for ordinary members across finance policies, approvals, mappings, periods, treasury, allocation, ledger, posting events and DLQ; finance viewer cannot mutate; requester cannot approve own request; distinct approver/executor; AAL2; cross-tenant and role-negative tests.
- **Accounting:** same-entity open/closed/future periods; exact double-entry equality; debit/credit account status/ownership/currency; canonical payload fingerprint; conflicting idempotency replay; concurrent duplicate posting; rollback and reversal.
- **Revenue:** prove only contracted KRIM service fee is recognized; partner freight GMV and partner-direct collections never enter KRIM revenue; approved fee agreement, attribution, evidence of service, invoice, GST/tax split and receipt must match.
- **Partner settlement:** keep disabled under current non-custodial model. If later legally approved, test payable source, exact beneficiary/bank reference, dual control, one-time approval fingerprint, provider payout response and independent bank reconciliation. Never trust an admin-supplied transaction string.
- **Reconciliation:** canonical payment order/provider event/financial transaction/journal/invoice/bank statement; organization/legal-entity scope; mixed currencies and periods; unknown/duplicate/unmatched provider events become exceptions.
- **International currency/tax:** capability registry and FX source version/date, minor units, rounding, presentment vs settlement currency, refunds and chargebacks; no unsupported currency can collect.
- Capture signed synthetic payloads, before/after DB rows, journal balance, webhook event disposition, provider sandbox fixtures, audit trail and tenant-negative traces.

## Status

| Area | Status | Basis |
|---|---|---|
| Razorpay order creation gate | PARTIAL PASS | Source checks collection approval version and provider/currency readiness |
| Razorpay payment verification gate | PARTIAL PASS | Unpaid orders gated; binding checks exist |
| Razorpay captured webhook kill switch | FAIL — P0 | Immutable webhook source lacks collection-mode guard |
| Webhook signature/idempotency | PARTIAL PASS | HMAC/event ID/duplicate handling; no adversarial Staging proof |
| Refund request/review | PARTIAL PASS | Full paid-only request and AAL2 maker-checker source controls |
| Refund execution | BLOCKED | Separate environment/version gate disabled |
| Finance control-table authorization | FAIL / NOT REVALIDATED | Dated direct-write exposure; migration does not prove all-table closure |
| Canonical ledger posting | NOT TESTED | Zero canonical transactions/entries in dated snapshot |
| Revenue recognition/tax split | BLOCKED | Explicit suspension until GST/tax split validated |
| Partner payable/settlement | BLOCKED | No proven payable/treasury rule/dual-control/bank settlement |
| Invoices/receivables | NOT TESTED | No invoice lifecycle evidence |
| Multi-currency merchant readiness | BLOCKED | Capability registry disabled/unverified in dated snapshot |
| Provider/bank reconciliation | BLOCKED | Historical orders/events and legacy records unresolved |
| End-to-end finance lifecycle | NOT TESTED | No isolated Staging journey |

## Safety boundary

No Production or Staging SQL/RPC, payment order, provider API, webhook replay, refund, payout, settlement, invoice, journal entry, reconciliation run, bank lookup, notification or deployment was performed. No secrets, payment credentials, raw payment payloads, bank account details or customer identities were read or exported. No synthetic finance users or transactions were created. Dated 16 Nov counts, permissions and provider capability rows are historical evidence, not current-live assertions.

## Exit criteria

Do not enable any KRIM freight collection or settlement. First close the webhook kill-switch bypass with a durable deferred-event design; independently prove finance table DML and RPC authorization; reconcile every historical order/webhook/legacy payment and payout against provider and bank evidence; resolve accounting entity/period, approval and ledger idempotency issues; and validate tax/invoice treatment with a qualified CA. Keep the partner-direct model: customers pay logistics partners directly; KRIM earns only its separately contracted service fee after legal/tax readiness. Complete the full synthetic Staging financial lifecycle and independent regression audit before any commercial financial workflow is enabled.
