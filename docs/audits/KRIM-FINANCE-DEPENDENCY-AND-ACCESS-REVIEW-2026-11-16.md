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
