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


## 8. Frontend-to-backend connectivity check

A direct source scan of all 12 authenticated finance pages found:
- `app/finance/index.html` calls `krim_finance_list_revenue_ledger` (legacy `revenue_ledger`) and `krim_has_permission`.
- `app/finance/refunds-disputes.html` calls refund submission and review RPCs.
- `app/finance/treasury-audit.html` calls the finance webhook-event listing RPC.
- The other nine pages (accounts payable, accounts receivable, invoicing, financial reporting, multi-currency, partner settlements, payment processing, revenue/commission, and tax compliance) currently use a session/active-membership check and client-side review-preparation forms; the scanned files contained no direct financial RPC or Edge Function invocation and no direct read from the canonical invoice/ledger/payable tables.
- The review forms explicitly say they do not save or execute a financial action. They are operational guidance/preparation shells, not live finance modules.

This is a major product-integration gap: twelve navigable modules exist, but most are not connected to their intended data/workflows. The finance home also presents legacy revenue-ledger data rather than a consolidated canonical financial view.

Implementation order should be: fix least-privilege access and org scope first; then wire read-only invoice/receivable/payable/ledger views with server-side authorization; then implement the first KRIM-only fee invoice and reconciliation flow. Do not convert preparation forms into write forms until the backend contract and negative authorization tests exist.


## 9. Organization and role model — deeper verification

A second read-only pass inspected the actual organization records, memberships, role assignments, role-permission mappings, posting rules, accounts, and accounting periods.

### What the records establish

- Organization 1 is the active platform organization, legal name `KRIM Logistics`, display name `KRIM Global Platform`, INR, Asia/Kolkata.
- Organization 21 is a separate active organization named `KRIM Finance Journey Verification`, type/code `finance`, INR, with no country or market assigned.
- All 14 INR chart-of-account rows and all three posting rules belong to organization 21.
- The single open accounting period (1 April 2026–31 March 2027) belongs to organization 1.
- Organization 1 and organization 21 have different active memberships. The finance verification organization has a finance-manager role assignment; the platform organization has platform-admin/superadmin assignments.
- The finance-manager role has `finance.view` and `finance.manage`; the customer-user role also currently has `finance.view`. This permission is broad and should be reviewed for customer-facing visibility boundaries. A generic finance permission must not expose platform-wide financial data; all read RPCs need organization and record ownership scoping.

### Revised interpretation

This is not simply a missing accounting-period row in an otherwise unified entity. The chart and posting rules appear to have been seeded under a separately named finance-journey verification organization, while the platform organization has its own accounting period. The data does not establish that organization 21 is the legal operating entity for KRIM. Treat organization 21 as a test/verification tenant until an authorized business/legal-entity decision explicitly states otherwise.

Do not move the 14 accounts, 3 posting rules, or accounting period between organizations. Do not create a new period under organization 21 or copy its chart into organization 1 merely to make the posting function return success. First document whether the sole proprietorship KRIM Logistics is represented by organization 1 as the legal entity, with organization 21 retained only for isolated verification. Then confirm whether accounting periods, charts, invoices, tax registrations, bank accounts, and provider merchant accounts all bind to that same legal entity.

### Additional role/permission concerns

- Customer-user currently carries `finance.view`. Confirm that this permission only enables the customer's own invoices/payments and never platform revenue, partner payables, treasury, or general ledger data.
- Finance-manager is assigned in the verification organization, not automatically in the platform organization. Do not infer that the platform's owner/admin has a finance-manager assignment or that the test tenant is a production finance team.
- The current membership-only RLS policies remain too broad for sensitive finance configuration even though the presently observed test tenant has a finance-manager member. Security must be safe for future ordinary members, not only today's membership snapshot.

## 10. Canonical posting path — exact call chain

The inspected `krim_internal_post_financial_event(bigint,text,numeric,text,text,text,text,text)` is SECURITY DEFINER and selects an active posting rule and account mappings for the supplied organization and currency. It then calls the text-source overload:

`krim_internal_post_ledger_transaction(bigint,text,text,text,bigint,bigint,numeric,text,text,text)`

That is the overload that requires an open period for the same organization and creates the transaction entries/audit event. The numeric-source overload remains an alternate path and must not be used for new callers until its period, audit, and idempotency behavior is brought to parity or it is formally retired after dependency analysis.

Before any new financial RPC is exposed:
- assert caller has `finance.manage` for the exact organization (or a narrowly defined system-only capability);
- assert source record belongs to that organization;
- validate approved event type and contract/tax policy;
- lock/idempotently reserve the transaction number and source key against concurrent retries;
- verify debit/credit accounts share organization and currency;
- require an open period and prevent future/closed-period posting;
- persist an audit trail and actor/approval context;
- use compensating reversal entries rather than editing posted entries.

No production changes were made as part of this deeper verification.


## 11. Cross-tenant financial data exposure review — critical findings

A focused inspection of the actual RLS predicates and SECURITY DEFINER reporting RPCs found several additional risks. These are policy-level findings; authenticated-user exploitability still requires controlled staging tests with representative accounts.

### CRITICAL — legacy revenue reporting RPC is not organization-scoped

`krim_finance_list_revenue_ledger(integer)`:
- permits a caller if they have `finance.view` in any active organization whose type is `finance`;
- then returns rows from the entire legacy `revenue_ledger` table, with no organization/customer filter;
- exposes total amount, platform commission, partner payout, currency and shipment reference.

A finance user in one tenant may therefore receive another tenant's/global revenue records through this SECURITY DEFINER RPC. The current function should be treated as a cross-tenant exposure risk. Remove it from customer/partner-facing surfaces immediately through application routing/configuration if possible, while preserving forensic evidence; do not attempt an unreviewed production SQL change. The replacement must require an explicit organization scope, verify the caller's finance permission for that exact organization, and filter every returned record to that scope.

### HIGH — refund requests/events have broad finance visibility

RLS for `krim_refund_requests` and `krim_refund_request_events` grants visibility to any active member who has `finance.view` in any active organization. The predicate is not tied to the refund's owning/customer organization or the reviewer's authorized finance organization. This can expose refund amounts, reasons, provider refund IDs/status and review notes across tenants.

Replace with two distinct scopes:
- customer/partner participant access only to their own request and permitted event fields;
- finance reviewer access only when the caller has an explicit finance role in the owning legal entity/platform finance organization and the request is within that organization's responsibility.

### HIGH — partner payable policy may disclose partner economics to customers

The `krim_partner_payables` read policy allows either:
- membership in the payable's partner organization; OR
- membership in the shipment's customer organization.

The second branch exposes payable rows, including partner gross/net amounts, adjustments, approval/settlement timestamps and hold reason, to the customer organization. This is not appropriate by default: partner commercial terms and payout status are not automatically customer-visible. Customer views should expose only the customer's own invoice/approved customer-facing charges and explicitly shareable shipment status, never partner payable economics. Partner users should see only payables belonging to their own partner organization; finance reviewers need an explicit finance scope.

### HIGH — invoice policy is permissive across multiple relationship columns

The `krim_invoices` read policy accepts membership/finance.view through any of organization_id, customer_organization_id, supplier_organization_id, or partner_organization_id, plus a special finance-organization branch. The correct audience depends on invoice_type and issuer/recipient role. A single OR policy risks exposing supplier/partner/customer invoice details to parties who are related to the shipment but are not entitled to that invoice.

Split invoice visibility by invoice type and party:
- customer invoice: only the issuing KRIM legal entity finance team and the billed customer organization;
- partner/supplier invoice: only the issuing partner/supplier and the billed legal entity/authorized finance team;
- platform internal invoice: only platform finance/admin as legally appropriate.
Do not infer invoice access from shipment participation alone.

### HIGH — customer finance permission is broader than its intended product meaning

The `customer_user` role currently has `finance.view`. That is not inherently unsafe if every query is correctly record-scoped, but it is too coarse as a global finance capability. Prefer distinct permissions such as customer.billing.view, partner.payables.view, finance.ledger.view, finance.reconciliation.view, finance.manage, and finance.refunds.review, each paired with strict organization and record scope. Do not grant customers platform-wide finance capabilities.

### Other observations

- `payment_orders` is scoped to the customer user or a finance-organization member; the finance branch is not explicitly bound to the payment order's customer organization. Review for cross-tenant visibility.
- `payments` is currently scoped to `customer_id = auth.uid()`, which is a narrow user-owned read path.
- `payment_webhook_events` denies authenticated direct access; its listing RPC requires AAL2 and `admin.platform` on organization 1 and returns masked provider references. This is a stronger control pattern, though the hard-coded organization ID should be replaced with a reviewed platform-entity setting once the entity model is resolved.
- `krim_ledger_transactions` and `krim_ledger_entries` are read-only for authenticated clients in the inspected grants, but the current RLS helper grants organization-member read access. Confirm whether every member should see the full ledger; normally only finance roles should.
- `shipment_financials` has authenticated table grants but explicit deny-all RLS policies for authenticated and anon. This is currently fail-closed at the row-policy layer; remove unnecessary client grants in the eventual reviewed migration.
- `krim_invoice_payment_applications` denies authenticated and anon direct access and is service-role-only, which is an appropriate pattern for payment allocation internals.

## 12. Remediation priority and verification plan

P0 — stop broad legacy revenue report access:
1. Remove/disable the legacy global revenue report from user navigation and client access paths pending a scoped replacement.
2. Verify no customer/partner UI calls it and no public API route re-exports its result.
3. Preserve logs and current function definition for incident review.

P1 — close cross-tenant RLS scope gaps:
1. Refund requests and events: scope finance reviewer to exact legal entity; participant access only to own records.
2. Partner payables: remove customer-organization read branch; define partner and finance scopes.
3. Invoices/payment orders: define issuer/recipient policy by invoice type and record ownership.
4. Ledger: finance-only read access, organization scoped.

P2 — permission model:
1. Split generic `finance.view` into audience-specific billing and finance permissions.
2. Retain `finance.manage` only for explicitly authorized finance managers/platform finance.
3. Require AAL2 and independent reviewer for sensitive refund/payout/treasury actions.
4. Enforce least privilege in both RLS and SECURITY DEFINER functions; RLS alone is not sufficient when RPCs bypass it.

P3 — staging tests:
- Customer A cannot read Customer B invoices, payment orders, refund requests, ledger or partner payables.
- Customer cannot read partner payable amount, hold reason or payout state.
- Partner A cannot read Partner B payables/invoices/refunds.
- Partner cannot read customer invoices or platform revenue.
- Finance manager of legal entity A cannot read legal entity B's ledger/revenue/refunds.
- Finance manager cannot mutate chart, periods, posting rules, allocation policies or treasury rules without finance.manage and required second approval.
- Platform admin access is explicitly scoped and audited.
- Anonymous access denied.
- SECURITY DEFINER RPCs tested separately because they can bypass table RLS.
- Verify direct table grants, inherited role membership, views, RPCs, Edge Functions and exports.

## Current incident posture

No unauthorized access was demonstrated in this review, and no production data was changed. However, the global revenue RPC and broad refund/payable/invoice policies warrant a **P0/P1 security remediation before finance features are exposed to external customers or partners**. If these routes are currently available to external authenticated users, treat this as a potential data-exposure incident: preserve logs, restrict access through a safe reversible application control, and conduct a formal review before claiming containment.


## 13. Immediate application-layer containment applied

To reduce exposure while database remediation is pending, the finance command-centre frontend at `app/finance/index.html` was updated:
- removed its call to the unscoped `krim_finance_list_revenue_ledger` SECURITY DEFINER RPC;
- replaced the revenue table with a clear temporary security-review hold message;
- removed the legacy revenue RPC from the page's concurrent data-load path;
- retained the existing invoice, settlement and payment-order reads unchanged.

Repository commit: `7fc4ea6a7c2b5427add9ab2dd94708348687fdaf`.

Post-commit source verification confirmed:
- legacy revenue RPC call absent from the page;
- explicit temporary hold message present;
- three remaining read queries remain in place.

This is **repository/source-level containment only**. It is not yet confirmed deployed to GitHub Pages, does not revoke the database RPC, and does not close the other RLS gaps. Verify the deployed page and restrict/replace the database RPC through a reviewed migration after migration-history recovery.


## 14. Refund workflow RPC review and temporary frontend containment

Additional inspection of the SECURITY DEFINER refund routines found:

- `private.krim_refund_request_submit` checks that the payment order is paid, requires a full refund (partial refunds disabled), validates requester ownership by user or active customer-organization membership, and prevents duplicate requests/idempotency-key reuse. This is a useful baseline control.
- `private.krim_refund_request_review` requires AAL2, a finance/platform/operations membership, `finance.manage` or `admin.platform`, a meaningful note, and prevents the requester from reviewing their own request.
- However, the review routine does **not** verify that `p_finance_organization_id` is the organization responsible for the refund request or that the refund's customer/legal entity is within that finance organization's scope. A finance manager in one tenant could potentially review a request belonging to another tenant by supplying their own authorized finance organization ID. Treat this as a critical cross-tenant authorization flaw in the RPC itself, independent of the RLS issue. Direct authenticated RPC invocation remains possible until a reviewed database remediation revokes or replaces it.

Temporary frontend containment committed in `app/finance/refunds-disputes.html`:
- eligible paid payment orders are now restricted to `customer_id = current session user`;
- refund request register is restricted to `customer_user_id = current session user`;
- finance review desk is hidden pending a properly scoped reviewer workflow;
- customer refund request submission remains available for the signed-in user's own paid orders.

Repository commit: `a9b8cd638717bcaff62bf26f9e559624ff21f256`.

Post-commit source verification confirmed the two user filters are present, the review desk is hidden, and the customer submission RPC remains connected. This is frontend containment only: the review RPC remains callable directly by authenticated users with its existing grants. It is not a database fix and deployment has not been verified.

### Required database remediation for refund review

The replacement review RPC must derive the permitted legal entity/platform scope from the request row and an approved relationship map, not trust a caller-supplied organization ID by itself. It must:
1. lock and load the refund request;
2. resolve the payment order and owning customer organization;
3. verify the reviewer has the required permission in the exact authorized finance organization responsible for that legal entity;
4. reject unrelated finance organizations even when the reviewer is otherwise a finance manager;
5. preserve AAL2, maker-checker, audit event, idempotency and status-transition constraints;
6. test cross-tenant denial with two independent finance tenants.

Do not attempt this production DDL until the original migration history and organization/legal-entity mapping are reconciled.


## 15. Customer invoice register: authorization and query-scope correction

### Database finding

The `krim_invoices` SELECT policy uses a broad OR across:
- any active finance organization where the user has `finance.view`;
- `organization_id`;
- `customer_organization_id`;
- `supplier_organization_id`;
- `partner_organization_id`.

The policy does not bind the allowed relationship column to `invoice_type`. This means a user authorized through one relationship can potentially read invoices belonging to a different commercial party/role. The related `krim_invoice_items` policy inherits access from `invoice.organization_id`, so it also depends on correcting the parent invoice visibility model.

### Customer page correction committed

Two customer invoice surfaces were tightened at the application query layer:

1. `public/customer-os/customer-services/invoices.html`
   - obtains the signed-in user's active organization memberships;
   - resolves active organizations and only accepts customer/shipper/enterprise organization types;
   - queries only `invoice_type = 'customer'`;
   - filters by `customer_organization_id IN (the user's active customer organization IDs)`;
   - no longer filters only on the generic `organization_id` field.

   Commit: `25a9116a1600c025b8193c5a7d55bb6d31b6aa63`.

2. `public/shipper/invoices.html`
   - obtains active organization memberships for the signed-in user;
   - queries only customer invoice records addressed to those organizations;
   - filters legacy `payments` to `customer_id = current session user`, matching the existing own-payment RLS policy.

   Commit: `2a9f587397e4a6739eea3ee152be98f28b39df2b`.

### Important limitation

These frontend filters reduce accidental exposure through these two pages, but they do not repair the broad database RLS policy. A caller can query Supabase directly, and other frontend/API routes may still use the table. No production DDL or grants were changed. The pages have not yet been verified on the deployed GitHub Pages site or tested with separate customer/partner/finance accounts.

### Invoice workflow backend observation

The internal customer-invoice creation function is SECURITY DEFINER and service-role-only by its inspected ACL. It requires delivered shipment status, an accepted quote, a completed partner assignment and independently verified delivery POD before issuing a customer invoice. It writes a customer invoice for the quote amount and currently sets tax_amount to zero. Do not treat this as a production-ready tax invoice: tax rules, legal supplier/issuer, place-of-supply, GST/VAT applicability, numbering, credit-note treatment and approved fee/tax configuration must be reviewed before enabling invoicing. This also reinforces that the customer freight invoice is not KRIM referral revenue under the partner-direct model.

### Next required controls

- Replace broad invoice RLS with invoice-type + issuer/recipient authorization.
- Make invoice-item access inherit the exact authorized parent invoice scope.
- Add a dedicated customer invoice read RPC or secure view with explicit organization argument validated against auth.uid membership and allowed customer role.
- Separate supplier/partner invoices from customer invoices.
- Test customer A/B, partner A/B and finance entity A/B with direct PostgREST table queries and all page/API routes.


## 16. Partner payable isolation review and temporary UI containment

### Database exposure confirmed

The authenticated SELECT policy on `krim_partner_payables` currently allows a row when either:
- the user has active organization access to `partner_organization_id`; OR
- the user has active organization access to the shipment's `customer_organization_id`.

The second branch exposes partner commercial economics to the customer organization. Fields on the table include gross amount, adjustments, net amount, payable status, eligible/approved/settled/payout timestamps and hold reason. This is a HIGH confidentiality issue; no evidence of exploitation was established.

The table grants authenticated users SELECT only. INSERT/UPDATE/DELETE are not granted to authenticated; service_role has broad write grants. This is better than the previously reviewed finance configuration tables, but the SELECT RLS scope remains overbroad.

### Finance workspace also lacked finance-role verification

`app/finance/partner-settlements.html` checked only for an authenticated session and at least one active organization membership before querying the payable table. It did not verify a finance-specific permission or bind the user to a designated finance organization. As a result, the page could display rows permitted by the overly broad RLS policy to an ordinary customer member.

### Temporary frontend containment committed

The partner payable register was replaced with an explicit access-hold notice. Its direct `krim_partner_payables` query was removed from the page. The page no longer renders gross, adjustments, net, status or update timestamps.

Commits:
- Initial containment: `e4cfed595ecc730e8f9a11ba0070e8c7b1f5378f`
- Follow-up try/catch syntax correction: `f59ebb2e1ff2ed0339019ec64bd0a1f5b835bcc3`

Source verification confirms the hold notice is present and the direct payable table query is absent. Deployment and live-browser verification have not been performed.

### Internal payable/settlement routines inspected

The inspected `krim_internal_create_partner_payable*`, `krim_internal_prepare_partner_payable_approval`, `krim_internal_authorize_partner_settlement`, and `krim_internal_post_partner_settlement_to_ledger` routines are SECURITY DEFINER and have EXECUTE ACL for postgres and service_role only in the catalog output. They are not directly callable by ordinary authenticated users under those ACLs.

The payable creation routines require delivered shipment, completed assignment, accepted partner quote and independently verified delivery POD. The authorization routine checks approved status and may require a treasury control rule and financial approval. However, it updates payable status to scheduled and records an execution reference; this is not evidence of an actual bank transfer or completed payout. Keep all payout/settlement actions disabled under KRIM's partner-direct model unless a separately approved, legally compliant KRIM-managed settlement product is deliberately introduced.

### Required database remediation

- Replace the customer-organization branch with partner-only visibility for partner payable detail.
- Restrict partner payable read to authorized partner finance roles, not any active partner organization member.
- Provide a separate customer-safe shipment financial status view only if required; never expose partner gross/net economics, adjustments, holds or payout timestamps.
- Bind finance-wide visibility to a designated legal finance organization and dedicated finance permissions, with AAL2 for sensitive actions.
- Add direct PostgREST negative tests: customer A must not read partner payable for shipment A; customer B must not read it; partner A may read only its own payable; partner B must not read partner A's payable; ordinary partner member without finance permission must not read detailed economics; unrelated finance tenant must not read it.
- Do not modify production RLS or grants until migration history recovery/reconciliation and the legal-entity/organization mapping are complete.


## 17. Refund and dispute isolation: expanded backend review

### RLS exposure confirmed on both refund tables

The SELECT policy on `krim_refund_requests` allows access when the caller is:
- the `customer_user_id`;
- an active member of the recorded customer organization; OR
- an active member of any organization for which they have generic `finance.view`.

The same cross-tenant finance-view branch exists on `krim_refund_request_events`. Event rows can contain reviewer notes, event notes, event metadata, actor identity and actor organization. The policy therefore exposes more than a basic status: it can reveal sensitive customer complaint/reason text, review rationale, payment references, provider refund identifiers/status, and internal investigation notes to finance-view users outside the responsible customer/legal finance scope.

The `customer_user` role previously inspected includes generic `finance.view`. Therefore this is not safely mitigated by assuming only finance managers possess the permission. The page's own-user filter is only frontend containment; direct PostgREST reads remain governed by the broad RLS policy.

### Refund request submission and review

- Customer submission validates authentication, positive amount, reason length, paid payment order, full refund only, customer ownership or active customer-org membership, and idempotency/duplicate request checks.
- The page now loads paid orders by `customer_id = current session user` and request rows by `customer_user_id = current session user`. Customer request submission remains connected.
- The finance review desk is hidden in the committed page pending a correctly scoped reviewer workflow.
- The review RPC requires AAL2, an active finance/platform/operations organization membership, `finance.manage` or `admin.platform`, a meaningful note, and prevents the requester reviewing their own request.
- **Critical remaining flaw:** the review RPC does not verify that the supplied reviewer organization is the legally/operationally responsible finance entity for the request's customer organization/payment order. A finance manager in an unrelated organization could potentially review another tenant's request by supplying their own organization ID. The function is still executable by authenticated callers through its public wrapper. Do not expose or rely on this review workflow until corrected and tested.

### Refund execution claim RPC

The public `krim_claim_razorpay_refund_execution(uuid)` wrapper is executable by `authenticated` and calls a private SECURITY DEFINER function. The private function checks AAL2, that the caller is the recorded reviewer, that the caller has active finance/platform/operations membership and finance.manage/admin.platform permission in the recorded reviewer organization, that the requester differs from reviewer, that the request is approved/execution-pending, that no provider refund ID already exists, and that the payment order is a fully paid INR Razorpay order for the exact full amount.

Those controls are useful, but because the review function currently accepts an unrelated finance organization, the execution claim chain inherits that reviewer-organization binding weakness. The claim function returns the payment/provider execution payload; it does not itself prove a provider refund was executed. Keep execution disabled until review-organization ownership is enforced and the provider call/webhook reconciliation path is independently audited.

### Frontend and customer-facing model

- `app/finance/refunds-disputes.html` has the finance review panel hidden with an explicit temporary-unavailability notice.
- The customer refund request register is filtered to the signed-in user's own `customer_user_id`.
- Paid payment-order choices are filtered to the signed-in user's own `customer_id`.
- The page does not call the refund execution-claim RPC.
- `public/customer-os/customer-services/refunds.html` is guidance-only and correctly explains that under the partner-direct model freight refunds are handled by the provider that received the payment; it does not submit or execute a refund.

### Remediation requirements

1. Replace generic `finance.view` access with strict audience-specific scope. Customers must see only their own requests and events; partner users must not see customer refund reasons/review notes unless legally necessary and explicitly authorized; finance reviewers must see only requests assigned to their responsible finance/legal entity.
2. Derive the responsible finance organization from a trusted payment-order/customer-entity mapping inside the SECURITY DEFINER function. Do not trust a caller-supplied organization ID as the authority.
3. Bind reviewer identity, AAL2, organization, permission and request ownership together in both review and execution functions.
4. Consider removing direct authenticated SELECT from the raw event table and expose a purpose-built customer-safe event view/RPC. Keep internal reviewer notes separate from customer-visible status history.
5. Restrict authenticated execution claim RPC to a trusted server-side worker or a narrowly scoped, fully verified reviewer flow. Validate wrapper and private function ACLs independently.
6. Add direct SQL/PostgREST negative tests across unrelated finance orgs, customer orgs and partner orgs; test AAL1/AAL2, requester/reviewer separation, repeated claims, duplicate provider refunds, webhook success/failure and replay.
7. No production RLS, grants or function changes were made. Migration-history divergence and unresolved legal-entity mapping still block safe production DDL.


## 18. Payment-order and payment-history isolation review

### Payment orders: HIGH cross-tenant exposure

The authenticated SELECT policy on `payment_orders` allows:
- the individual `customer_id = auth.uid()`; OR
- membership in any active organization of type `finance` with generic `finance.view`.

The finance branch is not bound to the payment order's `customer_organization_id`, shipment customer organization or designated legal finance entity. A finance user in one tenant could therefore read payment orders from unrelated customer organizations. The table contains amount, currency, status, Razorpay order/payment IDs, signature, failure reason, paid timestamp, shipment and quote references.

Authenticated users have SELECT only; write privileges are service_role-only. The RLS read scope, not authenticated write access, is the problem.

### Legacy payments: narrower direct policy

The legacy `payments` SELECT policy is limited to `customer_id = auth.uid()`, and authenticated users have SELECT only. The customer payment-history page also filters by the signed-in user's customer_id and does not display full transaction references. This is a better baseline, although the legacy model must remain reconciled with the newer payment-order model to avoid inconsistent or duplicate history.

### Finance transaction table: overly broad organization-member read

`krim_financial_transactions` grants authenticated SELECT. Its RLS policy permits any active organization member with organization access to read rows whose `organization_id` matches that organization. It does not require a finance-specific role/permission. The table includes provider references and metadata, so ordinary operational/customer members should not automatically receive the full finance transaction record. Create audience-specific safe views/RPCs and reserve raw transaction detail for finance roles.

### Webhook event storage and reconciliation

- `payment_webhook_events` denies all direct authenticated access and grants table access only to service_role. This is the correct general pattern for raw webhook payloads.
- `krim_finance_list_payment_webhook_events(boolean,integer)` is SECURITY DEFINER, requires AAL2 and `admin.platform` on hard-coded organization ID 1, returns masked event/order references and a bounded result set. It does not return raw payloads. Keep this platform-only; replace hard-coded org ID 1 only after platform/legal entity configuration is formally resolved.
- `krim_internal_reconcile_razorpay_captured_payment(uuid,text)` is SECURITY DEFINER and service_role-only. It validates paid INR Razorpay order, exact payment ID, accepted quote, shipment/customer organization binding, accepted partner assignment and confirmed capacity reservation before inserting an idempotent financial transaction. This is a strong server-side control pattern; no reconciliation call was made during this audit.

### Payment processing page containment committed

`app/finance/payment-processing.html` previously queried up to 100 `payment_orders` across all rows visible to the broad finance RLS branch and displayed amount, provider, Razorpay order ID, payment ID and status.

The direct payment-order query and table rendering were removed and replaced with an explicit access hold pending strict customer-entity scope and designated finance authorization.

Commit: `3206a914d99771187a850bf78781082c3f8967f0`.

### Customer-facing page review

- `public/customer-os/customer-services/payment-history.html` filters legacy payments by the current session user's `customer_id`; it displays truncated transaction references only.
- `public/shipper/payment-checkout.html` is guidance-only and clearly states partner-direct freight payment; it does not create orders or collect payment credentials.
- The refunds page similarly filters customer paid orders by current session `customer_id`.

### Required backend remediation

1. Replace payment-order finance read branch with designated finance-entity scope plus explicit finance permission and ownership/issuer rules.
2. Restrict raw `krim_financial_transactions` to finance roles; expose customer-safe own-payment status separately.
3. Keep raw webhook payloads service-role-only; retain AAL2, platform-only masked reconciliation view.
4. Add negative tenant tests for payment orders and financial transactions across customer A/B, partner A/B and finance entity A/B.
5. Reconcile legacy `payments`, `payment_orders`, private `krim_payment_transactions` and `krim_financial_transactions` into one documented source-of-truth map before enabling further payment features.
6. No production DDL, payment write, refund, payout, webhook processing or provider configuration was changed.


## 19. General ledger, journal entries and accounting-report review

### Current data state and legal-entity binding

Read-only production counts:
- 14 ledger accounts
- 0 ledger transactions
- 0 ledger entries
- 1 accounting period
- 5 account mappings
- 3 posting rules

All 14 accounts, all five mappings and all three posting rules belong to organization 21, `KRIM Finance Journey Verification` (organization type `finance`). The only accounting period belongs to organization 1, `KRIM Global Platform` (legal name `KRIM Logistics`, organization type `platform`). Organization 21 is a separate verification tenant; it is not established as the user's legal operating entity. This mismatch means the accounting configuration is not a coherent production ledger for the KRIM legal entity. Do not move or duplicate accounts, rules or periods until the legal-entity and migration model is resolved.

The three rules in organization 21 are:
- `customer_payment`: active, debit bank / credit receivable.
- `partner_settlement`: active, debit partner payable / credit partner funds.
- `revenue_recognition`: suspended, debit receivable / credit revenue.

No mapping/rule configuration exists for organization 1 in the inspected records. No journal posting was performed.

### Ledger read exposure

Authenticated SELECT is granted on `krim_ledger_accounts`, `krim_ledger_transactions` and `krim_ledger_entries`. Their RLS policies use only active organization access; they do not require a finance-specific permission or role. Any active member of the relevant organization can therefore read its chart of accounts, transaction metadata and journal-entry amounts. This is a least-privilege issue even though the current ledger has no posted transactions.

The treasury/audit page checked only for membership in a finance, platform or operations organization before querying ledger counts and sampling up to 1,000 journal entries. It did not verify `finance.view` or bind the query to an explicitly authorized finance entity. The page has now been changed to withhold general-ledger counts and journal sampling pending backend scope and role remediation.

Commit: `ea14cedebfbcb9db5ec57f5c9dee212b6006e076`.

### Direct mutation exposure on accounting configuration

Authenticated users have INSERT, UPDATE and DELETE table grants on:
- `krim_accounting_account_mappings`
- `krim_accounting_periods`
- `krim_accounting_posting_rules`

Their ALL-command RLS policies check only `private.krim_has_organization_access(auth.uid(), organization_id)`. That helper verifies active organization membership, not finance.manage or an accounting-specific permission. Any active member of the organization with these grants may therefore be able to alter account mappings, open/close periods or change posting rules. This is a HIGH integrity and separation-of-duties risk. Ledger accounts themselves are SELECT-only for authenticated users; ledger transactions and entries are service_role-write-only in the inspected grants.

### Posting function and schema drift

Two overloaded SECURITY DEFINER ledger-posting functions exist and are service_role-only:
- Canonical candidate: `krim_internal_post_ledger_transaction(bigint,text,text,text,bigint,bigint,numeric,text,text,text)`. It validates positive amount, distinct active accounts, organization match, currency match and an open accounting period covering current_date; inserts a transaction, matching debit/credit entries and an audit event.
- Legacy overload: `krim_internal_post_ledger_transaction(bigint,text,text,text,bigint,bigint,numeric,text,bigint,text)`. Its inspected body refers to `transaction_reference` and `source_id` columns that do not appear in the current `krim_ledger_transactions` column inventory (current schema exposes `transaction_number` and text `source_id`). Treat this overload as stale/schema-drifted and potentially runtime-failing; do not invoke it. Review all callers and drop/replace only through a reconciled migration after dependency analysis.

The canonical event function `krim_internal_post_financial_event` is also service_role-only. It resolves an active event rule and account-role mappings, then calls the canonical text-source overload. It returns an awaiting-rule/mapping state when configuration is absent. Its current configuration is confined to organization 21, while the open period is organization 1; the mismatch means a coherent posting path for either entity is not established.

### Double-entry integrity observations

- The entry table has row-level checks for positive amount and debit/credit type, and foreign keys to transaction and account.
- The canonical posting function inserts equal debit and credit values in one transaction, so its intended path creates a balanced two-line journal.
- There is no inspected database constraint enforcing aggregate debit = aggregate credit for every posted transaction. Row-level checks cannot guarantee aggregate balance if another privileged write path inserts entries.
- The transaction number unique constraint is global, not composite with organization_id. Review whether global uniqueness is intentional or whether transaction numbering should be tenant-scoped before introducing multiple legal entities.
- No posted journal transactions or entries currently exist, so balance, reversal, period-close and audit-chain behavior have not been empirically tested.

### Financial reporting status

The financial reporting page is still review-preparation only and does not query the ledger. The finance dashboard's legacy revenue report remains withheld because its SECURITY DEFINER RPC is globally unscoped. Treasury/audit now withholds the ledger section; its separate AAL2 platform webhook reconciliation view remains a distinct read-only workflow. No financial reports should be described as operationally certified.

### Required remediation before any ledger launch

1. Confirm the legal entity and map it to one canonical organization; keep verification tenants separate.
2. Recover and reconcile production migration history before changing grants, policies, functions or constraints.
3. Revoke authenticated direct writes to accounting periods, mappings and posting rules; expose narrow finance.manage RPCs with approval separation and immutable audit history.
4. Require finance.view (or more granular accounting permissions) for ledger reads, and scope every query to the authorized legal finance organization.
5. Remove or repair the stale overload after all dependencies are identified; pin SECURITY DEFINER search_path safely and verify explicit EXECUTE grants.
6. Add posting invariants, including transaction-level balanced debit/credit enforcement, source idempotency scoped correctly, immutable posted entries, reversals instead of edits/deletes, and closed-period protection.
7. Test positive/negative cases across two organizations, non-finance members, finance.view, finance.manage, AAL levels, duplicate source IDs, concurrent posts, closed periods, currency mismatch, reversals and audit-event atomicity.
8. No production DDL, grants, policy, function, period, mapping, journal or financial data was changed.


## 20. Invoice, receivable and payable isolation review

### Production data state

Read-only counts returned zero for:
- `krim_invoices`
- `krim_invoice_items`
- `krim_invoice_payment_applications`
- `krim_partner_payables`
- `krim_customer_billing_profiles`
- `krim_payment_terms`

There are no production invoice or payable balances to certify. Zero rows means the workflows have not yet been commercially exercised; it does not prove that the underlying controls are production-ready.

### Invoice and invoice-item access: HIGH

The `krim_invoices` SELECT policy has OR branches for any finance organization with `finance.view`, and for `finance.view` in each of `organization_id`, `customer_organization_id`, `supplier_organization_id` or `partner_organization_id`. It does not bind access to `invoice_type` and the user's exact issuer/recipient role. This is a cross-tenant and cross-party disclosure risk for invoice totals, paid/outstanding balances, notes, tax amounts and shipment references.

The `krim_invoice_items` policy inherits access through membership/permission on the invoice's `organization_id`, not a customer-recipient or supplier-issuer relationship. A recipient can be entitled to see an invoice while failing this item policy if the invoice's organization_id is the issuer; conversely, an issuer organization member with finance.view may see item detail even where the person should not have access to the invoice as a whole. Align item visibility with the corrected parent invoice authorization.

### Customer billing profiles and payment terms

- `krim_customer_billing_profiles` SELECT is granted to authenticated users and the RLS policy allows any active member of the customer account's organization to read the full profile, including billing email, tax identifier, billing address location, delivery preferences and metadata. This is broader than a dedicated billing-role model; sensitive tax/contact fields should be limited to billing administrators and authorized finance users, with ordinary organization members receiving only necessary masked data.
- `krim_payment_terms` SELECT is granted to authenticated users and policy allows any active member of the terms' organization. Credit days, payment method and commercial terms should be restricted to authorized billing/finance roles rather than every member.

### Invoice payment applications

Direct authenticated and anon access is denied; service_role is the only table-level reader/writer. The table has positive applied-amount validation, foreign keys to invoice/payment/organization, unique payment_id and organization-scoped idempotency key. These are useful baseline controls. The unique payment_id means one payment can only be applied once globally; confirm this is intended for the model before enabling split allocation or multi-invoice remittance. No application rows exist.

### Receivable reconciliation function

`krim_internal_reconcile_customer_receivable(bigint)` is SECURITY DEFINER and service_role-only. It requires a paid legacy `payments` row, a quote reference, finds a customer invoice by shipment and invoice_type, checks exact currency and exact payment/invoice total equality, then marks the invoice paid and writes an audit event. This is a narrow full-payment-only path; it does not use `krim_invoice_payment_applications`, does not support partial allocation, and the inspected body does not independently bind the payment's customer organization to the invoice's customer_organization_id. Do not treat it as a complete receivables reconciliation engine until customer ownership, duplicate/replay behavior, partial payment and concurrency are addressed.

### Invoice creation and tax readiness

The internal delivered-shipment invoice creator is SECURITY DEFINER and service_role-only. Its business gates include delivered shipment, accepted quote, completed partner assignment and independently verified delivery POD. However, the current creator sets `tax_amount = 0`. This must not be treated as a compliant tax invoice for India or other jurisdictions. Issuer legal identity, GST/VAT registration and applicability, place of supply, tax classification, invoice numbering, required particulars, credit notes and cross-border tax treatment remain unresolved. Also, customer freight invoices belong to the logistics supplier/partner relationship and must not be counted as KRIM referral revenue.

### Finance dashboard containment

`app/finance/index.html` had queried the first 50 invoices and payment orders after verifying a finance membership and generic `finance.view`. Because invoice RLS and payment-order finance scope are not tenant/party-bound, the dashboard could display unrelated invoice and payment amounts.

The invoice and payment-order dashboard queries are now withheld with explicit source errors; the settlements dataset remains separately governed by its own existing RLS and was not altered in this step.

Commit: `6832baec9829a914360ff66612f94067c11ec60d`.

### Customer invoice surfaces and operational readiness

- `public/customer-os/customer-services/invoices.html` filters customer invoices by the current user's active customer/shipper/enterprise organizations and `invoice_type='customer'`. This is frontend containment; the database policy remains broad. The item query path must also be checked against the corrected parent policy before relying on invoice line details.
- `public/shipper/invoices.html` filters invoice records to the user's customer organizations and legacy payments to the signed-in user's customer_id.
- Finance AP, AR and invoicing pages are review-preparation only: they check authentication/membership but do not read or write invoices/payables. They must not be represented as live accounting modules.
- The partner payable finance register remains held from the previous review. Database RLS still permits shipment customer-organization members to read partner payable economics directly; the frontend hold does not repair direct PostgREST access.

### Required remediation

1. Replace invoice OR-branch access with explicit invoice-type/issuer/recipient authorization and organization-scoped finance permissions; apply identical parent authorization to invoice items.
2. Restrict billing profiles and payment terms to billing/finance roles; expose masked safe fields to ordinary users.
3. Keep payment applications service-role-only; implement atomic, idempotent application/reversal logic with amount/currency/ownership and overpayment checks before use.
4. Bind receivable reconciliation to payment customer, invoice customer, issuer, shipment, quote and legal entity; support safe partial payments only if the commercial model requires them.
5. Define jurisdiction-specific tax/legal invoice rules before issuing invoices; never default to zero tax as a substitute for tax determination.
6. Keep partner payable gross/net economics partner-only and authorized finance-only; customer shipment participation must not grant payable access.
7. Add negative tests for unrelated customer, supplier, partner and finance organizations, including invoice headers, items, billing profiles, terms, payment applications and payable data.
8. No production DDL, grants, RLS, invoice, payment application, receivable, payable or tax record was changed.


## 21. Revenue recognition, commission and allocation review

### Production data state

Read-only counts:
- `krim_revenue_allocation_rules`: 0
- `krim_revenue_allocation_runs`: 0
- `krim_revenue_allocations`: 0
- `krim_shipment_revenue_items`: 0
- Legacy `revenue_ledger`: 1 row

No active allocation rules or canonical allocation runs/allocations are configured. The single legacy revenue-ledger row is not evidence of a reconciled accounting balance and remains part of the legacy/canonical source-of-truth reconciliation.

### Critical business-model mismatch: freight gross vs KRIM earned fee

`krim_internal_recognize_delivered_revenue(bigint)` is a service_role-only SECURITY DEFINER function. It selects the latest `invoice_type='customer'` invoice for a delivered shipment, accepts invoice status issued/partially_paid/paid, and passes the invoice's full `total_amount` to `krim_internal.plan_revenue_allocation` with scope `customer_revenue`.

That invoice represents the customer freight/service amount, not automatically KRIM's earned referral fee. Under KRIM's initial partner-direct model, the customer contracts with and pays the logistics partner directly; KRIM earns only the separately agreed referral fee when the contract-defined qualifying event is satisfied. Therefore the full customer freight invoice must never be treated as KRIM revenue or used as the base for KRIM commission allocations.

Do not activate any customer_revenue allocation rule or invoke this recognition function for the initial partner-direct model until the revenue source is redesigned to consume an independently evidenced KRIM fee receivable/earned-fee event. The revenue scope and source must distinguish partner freight, KRIM referral fee, separately contracted coordination, and later subscription/software revenue.

### Planner behavior and recognition semantics: HIGH

`krim_internal.plan_revenue_allocation(bigint,bigint,bigint,numeric,text)` is SECURITY DEFINER and service_role-only. It:
- selects active, effective rules matching organization/global scope, currency and `revenue_scope='customer_revenue'`;
- computes percentage or fixed allocations;
- inserts rows directly into `krim_revenue_allocations` with status `planned` and a policy snapshot;
- uses a unique allocation reference with `ON CONFLICT DO NOTHING`.

Despite the planner's name, it writes allocation rows. It does not create a corresponding `krim_revenue_allocation_runs` row or persist a run-level allocation snapshot in the inspected function.

The delivered-revenue function then writes an audit event named `revenue.recognized` after receiving a plan with planned allocations, but does not itself post a journal entry. This risks conflating a planned allocation with recognized accounting revenue. Its idempotency check treats any existing matching allocation as already recognized, without distinguishing planned, approved, posted, reversed or cancelled allocation status. A later rule correction/re-run may therefore be silently treated as complete.

### Rule integrity and approval controls

The allocation rules, runs and allocations have authenticated ALL-command grants and organization-membership RLS policies, as previously recorded. Those policies rely on organization access rather than a finance-specific permission. Ordinary active members may therefore have direct write capability where the table grants permit it. This is not an acceptable control for percentage/fixed-fee rules or financial allocation records.

The rule schema includes percentage/fixed amount, currency, approval flag, effective dates, rule code and revenue scope, but no active rules exist. Before use, require finance.manage, maker-checker approval for rule creation/change, immutable rule versions, effective dating, approved fee agreements, jurisdiction/tax mapping, caps and explicit eligible source types. Rule changes must not rewrite historical snapshots.

### Legacy revenue reporting function remains unsafe

`krim_finance_list_revenue_ledger(integer)` remains an authenticated SECURITY DEFINER function with a finance.view gate that checks membership in any finance organization, then selects the entire legacy `revenue_ledger` without organization/tenant scoping. It has an empty search_path and fully qualified object references, but that does not cure the missing tenant predicate. Frontend call was removed from the finance dashboard in an earlier containment commit; the database function itself remains callable under its current ACL and must be remediated after migration recovery.

The legacy table RLS policy has a customer-organization branch and a finance-organization branch; the finance branch is not bound to a revenue record's responsible legal entity. Do not assume the table policy fixes the SECURITY DEFINER RPC's unscoped query.

### Existing accounting mappings

The 14 chart-of-account rows and five mappings belong to organization 21, the finance verification tenant, not the platform/legal entity organization 1. The chart includes both:
- `4000 Freight and Logistics Service Revenue`
- `4010 KRIM Platform Commission Revenue`

These labels are not proof that the current legal/tax model supports KRIM recognizing partner freight revenue. The distinct commission account is a useful conceptual separation, but its actual entity, tax, fee contract, event trigger and posting rule remain unconfigured. Earlier inspection found revenue_recognition posting rule suspended and no mappings/rules for org 1. Do not move or copy org21 configuration into org1 without a legal-entity and migration decision.

### Revenue recognition page status

`app/finance/revenue-commission.html` and `app/finance/financial-reporting.html` currently only verify session and active organization membership and present review-preparation forms. They do not query allocation tables or invoke recognition functions. They are not live revenue accounting modules. No frontend change was needed in this step.

### Required remediation before enabling any KRIM revenue recognition

1. Define separate revenue event/source types for referral fee, coordination service, subscriptions, premium listings, SaaS/API, enterprise licensing, AI/analytics and integration services.
2. For referral fees, require a signed partner agreement and versioned fee schedule, attributable referral record, contract-defined qualifying conversion/acceptance, evidence, cancellation/clawback window and collectible KRIM fee receivable. Do not use partner freight gross as the allocation base.
3. Record a fee-specific source transaction with legal entity, counterparty, currency, tax determination, amount and idempotency key. Separate partner-direct freight money from KRIM money.
4. Change planner to create auditable run records and immutable allocation snapshots; enforce approved rule versions, limits, deterministic rounding and reconciliation of allocation totals to the eligible fee base.
5. Distinguish planned, approved, recognized, posted, reversed and cancelled states; idempotency must be status-aware and tied to source event + policy version.
6. Post only through a verified balanced journal path after legal entity, chart, accounting period and posting mappings are aligned. Recognition and cash collection are distinct accounting events.
7. Restrict rule/run/allocation writes to finance-authorized server-side routines; revoke broad authenticated direct writes after migration reconciliation; add maker-checker and negative tenant tests.
8. Scope or retire the legacy revenue reporting RPC and reconcile its single historical row before any reporting migration.
9. No production DDL, grants, rules, allocations, ledger postings, invoices, payments or provider actions were changed.


## 22. Treasury, cash management and reconciliation review

### Production data state

Read-only counts:
- `krim_treasury_control_rules`: 0
- `krim_financial_transactions`: 1
- `krim_ledger_transactions`: 0
- `krim_ledger_entries`: 0
- `krim_financial_reconciliation_exceptions`: 0
- `krim_financial_reconciliation_exception_events`: 0
- `payment_orders`: 6
- `payments`: 4
- `payment_webhook_events`: 10

The one canonical financial transaction is a completed INR payment row for organization 1, classified as `direction='credit'` and `ownership_scope='company'`; it has no source_reference or idempotency_key. It is not proof of KRIM earned revenue, a reconciled bank deposit, or a verified available cash balance. No bank-account feed, statement import or bank reconciliation source was established in this review.

### Treasury controls absent

There are no treasury control rules. Yet the internal partner settlement authorization routine requires an active `partner_funds` control rule scoped to the shipment's customer organization. If the rule requires approval, it checks an approved financial approval request for matching amount/currency. This means the routine is currently fail-closed when no matching control rule exists; do not add a rule merely to make the workflow pass.

The same routine changes a partner payable from approved to `scheduled`, stores a caller-provided execution reference and action fingerprint, and writes an audit event. This is **authorization/scheduling only**, not evidence that a bank or payout provider executed the transfer. It is a privileged service_role-only SECURITY DEFINER function. Under KRIM's initial partner-direct model, partner funds should not be held or paid out by KRIM at all; keep the entire partner payout/settlement path disabled unless a separately approved regulated/contractual operating model is adopted.

### Partner payout reconciliation control

`krim_internal_reconcile_partner_payout(bigint)` is service_role-only SECURITY DEFINER with an empty search_path. It requires payable status settled/paid, a provider reference in metadata and exactly one matching completed `krim_financial_transactions` row with:
- transaction_type `partner_payout`;
- direction debit;
- ownership_scope `partner_funds`;
- exact net amount and currency;
- matching provider reference and source reference.

This is a useful evidence gate, but the payable's status must not be advanced to settled based solely on the scheduling authorization. Reconciliation must consume independently verified provider/bank evidence, with authenticated bank statement or payout API provenance, exact beneficiary, amount, currency, date, fees and duplicate detection. A caller-supplied execution reference is not provider proof.

### Financial transaction ownership and direct access

`krim_financial_transactions` grants authenticated SELECT and its RLS policy permits any active member of the transaction's organization via `krim_has_organization_access`; it does not require a finance-specific permission. A regular organization member can therefore potentially read transaction amount, provider reference, direction, ownership scope and metadata for that organization. This is too broad for financial/provider metadata. Restrict to dedicated finance/reconciliation permissions and expose masked summaries where appropriate.

`krim_treasury_control_rules` grants authenticated INSERT/UPDATE/DELETE and has an ALL-command RLS policy based only on organization membership, not finance.manage. This is a high-severity treasury integrity and separation-of-duties risk. Do not add rules through the client. Revoke direct authenticated writes and use narrowly scoped maker-checker server-side controls after migration recovery.

Ledger tables remain service_role-write-only but authenticated SELECT is broader than a finance-role model, as described in section 19.

### Reconciliation exception and run visibility

The reconciliation runs, exceptions and exception-event tables have RLS enabled and finance/platform-admin read policies. The policies rely on generic `finance.view` or platform `admin.platform`; they do not yet distinguish dedicated reconciliation permission from generic finance visibility. The treasury page's UI only verifies active organization membership before querying the reconciliation run and exception registers. Although RLS remains the database enforcement layer, generic finance.view and cross-entity role design remain too broad for these sensitive details.

Frontend containment: removed direct reads of `krim_financial_reconciliations` and `krim_financial_reconciliation_exceptions` from `app/finance/treasury-audit.html`; replaced both with explicit access holds pending dedicated `finance.reconciliation.view` authorization and legal-entity scope. Preserved the payment webhook listing RPC, which independently requires AAL2 and `admin.platform` on hard-coded organization 1. This webhook RPC is read-only and masks provider references; its hard-coded platform organization should be replaced only after the legal-entity/organization model is resolved.

Commit: `e0ca37d3c749ade1ade923c958d20fba266f139c`. Fetched source verified: inline JavaScript syntax `ok`, old reconciliation table queries absent, both access holds present, webhook RPC retained.

### Reconciliation function concerns

Two overloaded `krim_internal_run_financial_reconciliation` functions exist:
- no-argument version scans legacy paid payments and settled partner payables and inserts exceptions with `organization_id=NULL`, limiting useful tenant scoping;
- bigint version attempts to detect missing ledger postings and partner payouts, but its partner/customer ownership joins and matching rules need a documented legal-entity model and comprehensive false-positive/false-negative tests.

Both are service_role-only SECURITY DEFINER. They are not invoked in this audit. The reconciliation exception transition/update functions are also service_role-only; no authenticated mutation route was identified in the inspected ACL. Do not trigger reconciliation jobs until their scope, idempotency, source matching and exception ownership are verified.

### Required remediation before treasury activation

1. Confirm the legal entity and bank account owner; bind every account, transaction, period and reconciliation run to that entity.
2. Under partner-direct model, disable KRIM partner-fund custody, partner payable settlement, payout execution and any customer funds-held liability workflow.
3. Track only KRIM's own earned fee receivables and its own receipts; never classify partner freight receipts as KRIM cash or revenue.
4. Implement read-only bank statement import/reconciliation with source provenance, duplicate detection, amount/currency/date/beneficiary matching, bank fees and exception review.
5. Separate scheduled, submitted, provider-accepted, bank-confirmed, reconciled and failed payout states; never label scheduled as paid/settled.
6. Require finance.manage plus maker-checker approval for treasury-rule changes; remove authenticated direct write grants after migration reconciliation.
7. Restrict financial transaction reads to dedicated finance/reconciliation permissions and mask provider references/metadata for ordinary users.
8. Add tenant-negative tests, duplicate statement-line tests, reversal/chargeback tests, bank mismatch tests and independent evidence tests.
9. Keep Razorpay freight checkout and settlement disabled unless KRIM deliberately changes its model and completes legal/provider approval. A KRIM fee payment path is a separate product and requires verified merchant eligibility, contracts, tax treatment and lifecycle tests.
10. No production DDL, grants, RLS, treasury rules, bank integrations, payouts, payments or reconciliation jobs were changed or executed.


## 23. Financial approvals, refunds, disputes, chargebacks and fraud controls

### Production data state

Read-only counts:
- Financial approval policies: 8
- Financial approval requests: 0
- Financial approval events: 0
- Refund requests / events: 0 / 0
- Dispute cases: 0
- Legacy disputes: 0
- Dispute decisions / appeals / evidence links / investigations: 0 / 0 / 0 / 0
- Shipment risk records: 1

The single shipment risk record is a medium-severity open delay risk. It is not a payment-fraud finding. No dedicated chargeback table or chargeback-specific lifecycle was found in the table-name inventory. No actual refund or dispute case exists in the inspected tables.

### Financial approval policies: configured but not operationally verified

Eight active global policies exist for payout, expense, payment, transfer, other, refund, distribution and founder compensation. Every row has:
- `organization_id=NULL`;
- `currency_code='*'`;
- `require_founder_approval=true`;
- `require_dual_control=false`;
- zero auto-approval and founder limits.

**Critical functional mismatch:** `krim_internal.evaluate_financial_approval` searches for a policy using `currency_code = upper(p_currency_code)`, not a wildcard-aware comparison. The configured `*` rows therefore do not match normal currency inputs such as INR. The function returns `approval_required / no_active_policy` without inserting an approval request or event. Partner-payable preparation interprets approval_required as a hold and places the payable under review, but no actionable approval request is created. This is fail-closed in that path, but it is not a functioning approval workflow.

### Approval data permissions and workflow

RLS on approval policies, requests and events uses organization membership only. Authenticated users also have direct INSERT/UPDATE/DELETE grants on all three tables. The ALL policies are not restricted to `finance.manage` or a dedicated policy-management permission. This permits ordinary organization members to alter approval policy/request/event data where their organization scope matches. Approval events should be append-only; direct client mutation is not appropriate.

The approval request organization_id is nullable, while the RLS organization helper is invoked against it. Global policy rows have no organization, but generated approval requests are expected to receive an organization. This relationship needs a non-null, validated legal-entity owner before activation.

The private service_role-only routines `approve_financial_request` and `consume_financial_approval` perform status, expiry, fingerprint and one-time-consumption checks. However, `approve_financial_request` accepts `p_approver_user_id` as an argument and does not itself verify that this user is the authenticated caller, holds finance.manage for the request's organization, is distinct from the requester, or satisfies a dual-control policy. It is executable only by service_role, so the calling Edge Function/server must enforce those checks; that server path and actor provenance were not validated in this review. The consume routine likewise trusts its service_role caller and does not independently bind the action to a legal entity or verify an authenticated actor.

All eight policies set `require_dual_control=false`. Maker-checker separation is therefore not enforced by the configured policy rows. Do not treat founder_approval_required as equivalent to independent dual control.

### Refund lifecycle

The refund request submission path is restricted to the signed-in customer or an active member of the payment order's customer organization. It requires a positive amount, reason of at least 20 characters, an idempotency key, a paid order, and currently supports full refunds only. It prevents a second request for the same payment order. No partial refund support is enabled.

The review function requires AAL2, finance.manage/admin.platform in an active finance/platform/operations organization, a meaningful review note, and separation from the requester. **Critical tenant-binding flaw remains:** it does not verify that the supplied reviewer organization is the responsible organization for the refund request's customer/payment entity. A finance manager in an unrelated tenant can potentially pass their own authorized organization ID and review another tenant's refund.

The refund execution-claim routine further requires that the reviewer is the same user who approved, the reviewer remains an active finance member, the requester differs from reviewer, the payment order is paid INR Razorpay, and the requested amount exactly matches the full order. It creates an execution claim/idempotency snapshot and prevents a second provider refund if a provider refund ID already exists. It does not itself call Razorpay; downstream provider execution and webhook confirmation must be verified separately. The public wrapper is callable by authenticated users and delegates to the private SECURITY DEFINER function.

Refund request and event SELECT RLS permits the customer, active members of the customer organization, and users with generic finance.view in any active organization. This is broader than responsible-entity finance scope. The refund page currently filters customer orders and requests to the signed-in user's own user ID and keeps the finance review panel hidden; this is frontend containment only. Direct RPC and database RLS risks remain. Existing review-panel UI is already marked temporarily unavailable; no additional frontend change was made in this step.

Under KRIM's partner-direct model, freight refunds must be processed by the logistics provider that received the freight payment. KRIM's own refund workflow should apply only to payments actually received by KRIM for its own separately contracted fees/services, after merchant eligibility, contract and tax review.

### Disputes and investigations

Dispute case, legacy dispute, decision, appeal, evidence-link and investigation tables all have RLS enabled. Read policies allow the case's owning organization and claimant/respondent organizations to read case-related rows. This is broadly appropriate for party-facing case status and evidence they are entitled to see, but the investigations policy also exposes investigation findings/recommendations to claimant/respondent parties. Internal investigator notes, fraud signals, privileged legal advice, confidential partner submissions and internal risk assessments should not be exposed wholesale to both parties. Split internal investigation records from party-visible case summaries/evidence and use separate permissions.

The inspected dispute tables have authenticated SELECT grants; their write grants are service_role-only. No dispute/chargeback lifecycle RPC or payment-network chargeback integration was identified in the inspected function/table inventory. The existence of case tables does not establish a working dispute-resolution process, evidence submission workflow, SLA clock, appeal process or provider chargeback response capability.

### Fraud and risk

The only identified `krim_shipment_risks` record is an open medium-severity delay risk. Its SELECT policy permits an active partner assigned to the shipment or an active member of the customer organization. No dedicated payment-fraud case table, fraud rules, velocity limits, device/IP risk controls, identity verification decisions, sanctions screening, chargeback ratios or fraud operations queue was established by this review. Do not market the platform as having automated payment fraud detection or chargeback protection.

### Required remediation before activation

1. Fix the approval policy currency match with explicit wildcard semantics and validate every supported currency; then test that a pending approval request and immutable event are actually created.
2. Make approval policies organization/legal-entity-bound and non-null where required; remove authenticated direct writes to policy/request/event tables; expose narrowly scoped finance.manage workflows.
3. Implement server-side actor verification for approval/rejection: authenticated identity, AAL2, same legal entity, requester/approver separation, dual-control and immutable actor audit.
4. Require independent second-person approval for material payments/refunds/transfers and all changes to beneficiary/bank details; avoid self-approval and replay.
5. Bind refund review to the payment order's customer legal entity and responsible KRIM finance entity. Enforce the binding inside the database function, not just the page.
6. Narrow refund and event read policies to the customer/payment entity and responsible finance entity; do not let generic finance.view across unrelated tenants read refunds.
7. Keep refund execution disabled until a complete provider lifecycle is tested: claim, provider request, timeout, retry, duplicate webhook, failed refund, reversal, partial/full balance and bank settlement confirmation.
8. Split party-visible dispute data from internal investigations; restrict investigator findings, confidential evidence and legal notes to authorized internal roles.
9. Build a genuine payment-provider chargeback ingestion and response workflow before claiming chargeback support; include evidence deadlines, representment, outcome, fee and ledger reconciliation.
10. Treat fraud controls as a future risk program: identity verification, provider risk signals, velocity/abuse controls, account takeover monitoring, manual review, audit and escalation. Do not invent fraud scores or claim coverage.
11. No approval, refund, dispute, chargeback, fraud or payment records were created or modified. No RPCs were invoked. No production DDL, grants, RLS or provider settings were changed.


## 24. Financial reporting, management accounts and profitability accuracy

### Production data state

Read-only row counts:
- `krim_shipment_profitability_snapshots`: 0
- `krim_shipment_revenue_items`: 0
- `krim_revenue_allocations`: 0
- `krim_revenue_allocation_runs`: 0
- legacy `revenue_ledger`: 1
- `krim_metric_definitions`: 0
- `krim_metric_aggregates`: 0
- `krim_partner_performance_metrics`: 0
- `krim_reliability_metrics`: 0
- `krim_settlements`: 0

There are no populated canonical shipment-profitability snapshots, fee-specific shipment revenue items, revenue allocation records/runs, or metric definitions/aggregates. There is no demonstrated live P&L, balance sheet, cash-flow statement, management-accounting pack, partner margin report or forecast based on reconciled source data.

### Legacy revenue ledger: not authoritative

The single legacy `revenue_ledger` row records:
- total amount: INR 12,500;
- platform commission: INR 1,250;
- partner payout: INR 11,250;
- status: reconciled;
- customer_organization_id: NULL.

This legacy row has no customer-organization binding and its status alone does not establish a real customer payment, bank settlement, valid partner contract, earned KRIM fee or accounting journal. The platform commission figure must not be presented as KRIM earned revenue, and the full shipment amount must not be counted as KRIM GMV or cash without independent source evidence. Treat this row as an unverified legacy sample, exclude it from financial statements and business-performance totals until reconciled to source documents and the agreed partner-direct fee model.

The legacy revenue ledger SELECT policy allows customer-organization access or generic finance.view membership in any active finance organization; the previously identified SECURITY DEFINER listing RPC is also unscoped. Frontend listing was already removed and remains withheld. Database-side risks remain.

### Profitability and revenue item access

`krim_shipment_profitability_snapshots` and `krim_shipment_revenue_items` grant authenticated SELECT; RLS checks active organization membership only. They have no finance-specific permission requirement. If records are populated, non-finance members of an organization may read revenue, direct cost, gross profit, gross margin, contribution cost/profit, and source snapshots. These should be limited to explicitly authorized commercial/finance roles, with separate customer/partner views that reveal only their own entitled information.

Revenue allocation runs and allocations retain organization-membership ALL-command RLS and authenticated direct write grants as recorded in section 21. This remains an integrity risk for reporting source data.

### Metric system empty

Metric definitions and aggregates are both empty. There is no active metric catalog defining calculation versions, event sources, units, aggregation methods or dimensional rules. Partner performance and reliability metrics are also empty. Therefore dashboard percentages, averages, rankings, service reliability and performance trend claims must not be represented as live measured KPIs unless sourced from independently verified operational events with documented denominators and freshness.

### Financial reporting pages

`app/finance/financial-reporting.html`, `app/finance/revenue-commission.html` and `app/finance/accounts-receivable.html` are preparation-only pages. They check session and active organization membership but explicitly state finance-specific authorization is not yet verified, do not query accounting/reporting data, and do not save form entries. They are not operational reporting systems.

`app/finance/index.html` requires active finance-organization membership and `finance.view`. Invoice and payment-order registers remain explicitly withheld. It previously queried `krim_settlements`; that table's SELECT policy allows generic finance.view on a finance organization, the row's organization, or the partner organization. The finance dashboard did not bind the query to a single legal-entity/partner scope. Although the table currently has zero rows, this can expose settlement details from other accessible organizations when populated.

Frontend containment: replaced the settlement query with an explicit access hold pending strict finance-entity scoping and partner-direct model review. No other financial data query was enabled. Commit: `8c3725cff055d6b1915494fe04152ad959fdd747`. Fetched source verified separately.

### Accounting interpretation required

KRIM must keep these separate in all reports:
1. **Marketplace GMV / shipment value:** customer-to-partner freight value, reported as marketplace volume only where a qualifying completed transaction is evidenced; not KRIM revenue.
2. **KRIM earned fee revenue:** separately contracted referral/coordination/software fees, recognized only when the applicable contractual performance obligation is satisfied and the amount is reliably measurable.
3. **KRIM cash receipts:** cleared receipts into KRIM's own verified bank/merchant account, net of reversals/refunds/fees; not partner freight funds.
4. **KRIM expenses and operating costs:** supported by supplier invoices, payroll/contractor records and other source documents.
5. **Gross profit / contribution / operating profit / net profit:** calculated only after cost classification, accruals, tax treatment, refunds, chargebacks, FX and period close; do not use shipment freight gross value as the revenue denominator for KRIM's platform margin.
6. **Enterprise value and projections:** forward-looking scenarios, never actual accounting results or guaranteed forecasts.

For a referral-only transaction, the customer and partner contract and settle freight directly. KRIM records only its separately agreed fee receivable/revenue when earned under the contract, and its own fee receipt when cleared. A commission percentage in a legacy row is not sufficient evidence.

### Required remediation before reporting activation

1. Confirm the actual legal entity, accounting entity, bank ownership, tax registrations, functional currency and fiscal period.
2. Retire or quarantine the unscoped legacy revenue ledger and reconcile its single sample row against source payment, partner agreement, shipment, bank and tax records before any migration into authoritative books.
3. Establish a fee-specific source-of-truth event for each KRIM referral/coordination/SaaS fee, including contract, eligible outcome, rate/amount, currency, earned date, invoice/credit note, tax, payment and reversal lifecycle.
4. Keep partner freight gross amounts, partner payables and KRIM fee income in separate ledgers and report dimensions.
5. Build statements from balanced, posted journals only; include trial balance, P&L, balance sheet, cash-flow statement, AR/AP ageing and close controls.
6. Add cost attribution and FX translation policy before calculating shipment-level gross/contribution margins; store immutable calculation version and source snapshot.
7. Define a governed metric catalog with source events, denominator, timezone, aggregation, freshness, correction policy and calculation version; distinguish operational KPIs from accounting measures.
8. Restrict profitability/revenue snapshot reads to finance/commercial permissions and tenant/entity-scoped APIs; remove membership-only access and direct writes after migration reconciliation.
9. Keep settlement and legacy revenue dashboards held until legal-entity scope and role authorization are enforced server-side.
10. Add reconciliation tests against independent source records, double-entry balance, period cut-off, duplicate fees, partial refunds, reversals, multi-currency FX, credit notes and partner/customer tenant isolation.
11. No reporting rows, journals, revenue, expenses, forecasts, settlement records or financial values were created or modified in this audit. No production DDL, grants, RLS or accounting logic were changed.


## 25. Finance permissions, organization isolation and security boundary review

### Read-only production snapshot

Organization memberships currently include:
- Organization 1, **KRIM Global Platform** (platform): one active owner membership.
- Organization 21, **KRIM Finance Journey Verification** (finance): one active manager membership.
- Customer, partner, carrier, warehouse, customs, operations and enterprise organizations have separate active memberships in the current snapshot.

Active role assignments include platform-admin and platform-superadmin assignments in organization 1, and a finance-manager assignment in organization 21. Customer and partner workspace assignments are scoped to their respective organizations. These counts describe the present database snapshot only; they do not prove identity verification, correct business authority, or safe future role provisioning.

### Finance permission matrix

The role-permission mapping currently grants:
- `customer_user`: `finance.view`;
- `finance_manager`: `finance.view`, `finance.manage`;
- `organization_owner`: `finance.view`, `finance.manage`;
- `organization_admin`: `finance.view`;
- `platform_admin` and `platform_superadmin`: `finance.view`, `finance.manage`.

The customer-user grant is a least-privilege concern. A generic `finance.view` permission must never imply access to platform revenue, general ledger, partner payables, treasury, other tenants' invoices, or internal reconciliation data. Customer access should be a separate entitlement for the customer's own invoices, payments and statements. Organization owner/admin finance visibility should also be narrowed to records and actions belonging to that organization's own legal entity.

The finance-manager assignment observed in the database is in the finance verification organization, not proof of an appointed production finance officer for the KRIM legal entity. Platform owner/admin role assignments are not a substitute for a documented finance delegation and maker-checker design.

### Confirmed RLS and direct-write boundary gaps

The live policy/grant snapshot confirms:
- Approval policies, requests and events: authenticated INSERT/UPDATE/DELETE grants plus membership-only ALL policies.
- Treasury control rules: authenticated INSERT/UPDATE/DELETE grants plus membership-only ALL policy.
- Ledger accounts: authenticated SELECT plus membership-only ALL policy, which is broader than read-only intent.
- Invoices: broad SELECT branches for finance organizations and organization/customer/supplier/partner organization permissions.
- Invoice items: SELECT inherited through invoice organization membership rather than invoice issuer/recipient authorization.
- Partner payables: SELECT for partner organization **or** shipment customer organization, exposing partner payable amounts and settlement details to customer members.
- Refund requests/events: customer participants plus generic `finance.view` membership across active organizations.
- Ledger transactions and entries: membership-only SELECT rather than finance-specific access.
- `payment_orders`: own-customer read plus finance-organization `finance.view` branch.
- `revenue_ledger`: customer organization read plus finance-organization `finance.view` branch; the unscoped SECURITY DEFINER list RPC remains a separate critical risk.
- `shipment_financials`: authenticated table grants exist, but RLS denies authenticated access in the inspected policy snapshot.

This confirms that several controls depend on a broad permission or mere organization membership rather than a record-specific financial entitlement. The frontend holds previously applied are containment only; direct database policies, grants and callable RPCs remain authoritative.

### Security posture and remediation order

**Finance access remains NO-GO for live-money production use.** Prioritize in this order:

1. Remove generic finance visibility from customer-facing role semantics; introduce distinct customer billing entitlements and finance-only permissions.
2. Define the legal-entity ownership model for organizations 1 and 21 and establish explicit finance authority for the real KRIM entity.
3. Replace membership-only read/write policies with record-level issuer, recipient, customer, partner and responsible-finance-entity checks.
4. Revoke direct authenticated writes to approval, treasury, accounting configuration and revenue-allocation control surfaces after migration reconciliation; use narrow server-side commands with actor verification, maker-checker and immutable events.
5. Restrict ledger, profitability, reconciliation, payable and refund reads to authorized finance/commercial scopes; customer and partner views must expose only their own contractual records.
6. Audit every SECURITY DEFINER function, view, trigger and Edge Function for caller authorization, explicit organization binding, safe search_path, and EXECUTE grants to PUBLIC/anon/authenticated.
7. Build staging negative tests for customer A versus customer B, partner A versus partner B, ordinary member versus finance manager, finance tenant A versus finance tenant B, owner/admin boundaries, inactive membership, revoked role, AAL2 and service-role actor provenance.
8. Recover and reconcile authoritative production migration bodies before any DDL, grants, policy or function change.

No user identities, memberships, roles, grants, policies, financial records or production functions were modified. No production DDL or financial RPC was executed in this review.
