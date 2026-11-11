# KRIM Production Schema Baseline — SaaS Billing Readiness
Date: 11 November 2026
Project: Logistics SaaS production
Method: read-only catalog queries against information_schema, pg_class, pg_policies and pg_proc.
Status: observation only. No production DDL, data writes, migration repair or payment activity was performed.

## 1. SaaS billing objects
The following dedicated SaaS billing objects were not present in the inspected public/private catalog:
- SaaS plan catalogue and plan-price versions
- SaaS plan features and limits
- SaaS subscriptions
- SaaS trials
- SaaS entitlements
- SaaS-only invoice snapshots
- SaaS payment event ledger
- SaaS refunds
- SaaS lifecycle audit events

Therefore the public Plans page and contact form are currently an enquiry surface, not a working subscription or trial system.

## 2. Existing objects — keep domains separate
Observed existing objects include:
- Organisation: `krim_organizations`, `krim_organization_members`, `krim_organization_contacts`, `krim_organization_domains`, `krim_organization_invitations`, `krim_organization_locations`, `krim_organization_onboarding`, `krim_organization_relationships`, `krim_organization_verifications`.
- Customer accounts: `krim_customer_accounts`.
- Freight invoices: `krim_invoices`, `krim_invoice_items`, `krim_invoice_payment_applications`.
- Freight payment: `payment_orders`, `payments`, `payment_webhook_events`, `krim_payment_capability_registry`, `krim_payment_terms`.
- Private payment implementation: `private.krim_payment_capabilities`, `private.krim_payment_providers`, `private.krim_payment_transactions`.
- Audit: `krim_audit_events`.

Do not repurpose freight invoices, payment orders, payment rows, payment webhook events, partner settlements or freight ledgers for SaaS subscriptions.

## 3. Row-level security observations
All 27 matching public/private base tables returned by the read-only catalog query had RLS enabled at the time of inspection.

Selected observed policies:
- `krim_organizations`: active organization members can read their own organization; platform admin read is separately permission-gated and requires AAL2.
- `krim_organization_members`: users can read their own membership rows.
- `krim_customer_accounts`: read is scoped through `private.krim_has_organization_access`.
- `krim_invoices`: read uses finance permission checks and organization/customer/partner/supplier scope.
- `krim_invoice_items`: read is inherited through the parent invoice's organization scope.
- `krim_payment_capability_registry`: client access is explicitly denied.
- `payment_webhook_events`: authenticated client access is explicitly denied.
- `krim_invoice_payment_applications`: anon and authenticated access are explicitly denied.

These policies are useful patterns but do not automatically secure future SaaS tables. Each new table requires explicit RLS, least-privilege grants and cross-organization negative tests.

## 4. Authorization helpers inspected
`private.krim_has_organization_access(uuid,bigint)` is STABLE SECURITY DEFINER with a fixed search_path of `public, pg_catalog`. It checks that the requested user matches `auth.uid()` when a user session exists and that both membership and organization are active.
`private.krim_has_permission(uuid,bigint,text)` is STABLE SECURITY DEFINER with a fixed search_path. It checks active role assignment, granted permission, active membership and active organization.
Public wrappers call the private helpers. The organization helper's current grants observed in routine privileges include authenticated, postgres and service_role. Review of all helper grants and the broader role system is still required before choosing a billing authorization pattern.

## 5. Current roles and permissions
Existing roles include:
- organization_owner
- organization_admin
- finance_manager
- platform_admin
- platform_superadmin
- customer_user
- partner_user
- dispatcher
- operations_manager
- compliance_manager
- viewer

Existing permission catalogue includes finance.view / finance.manage and organization.view / organization.manage, but no dedicated SaaS billing, subscription, plan, trial or refund permission codes were present in the inspected catalogue.
Do not automatically assume finance.manage should authorize subscription changes. Add a distinct billing permission model or explicitly reviewed owner-only policy.

## 6. Key implementation consequences
1. Organisation IDs are bigint in the existing authorization helper; new references must match the actual `krim_organizations.id` type.
2. New SaaS records must be tenant-scoped by organization, not by client-supplied user ID.
3. Billing access needs an explicit definition: organization owner and a separately authorized billing administrator, with server-side permission enforcement.
4. Platform trial grants and overrides must be restricted to privileged KRIM operators, require MFA, and create immutable audit events.
5. Trial expiry and entitlement resolution must be server-time based and fail closed.
6. Public plan catalogue can expose only published plan data. Draft/internal price data and payment-provider identifiers remain server-side.
7. No direct authenticated writes to subscription, invoice, payment event, refund or entitlement tables.
8. Webhook handlers must verify signatures against the raw body, be idempotent and never grant entitlements based on browser redirects.
9. No live checkout until recurring-payment eligibility, refunds, settlements, tax and app-store rules are confirmed.

## 7. Remaining migration reconciliation blockers
The production migration inventory contains 425 history rows while the repository has 263 SQL migration files. Only 64 exact versions overlap. 201 descriptive suffixes appear on both sides, but suffix similarity is not SQL equivalence. Production-only and repository-only versions still require source/artifact and SQL-body reconciliation.
The detailed metadata crosswalk is recorded in `docs/audits/KRIM-PRODUCTION-MIGRATION-NAME-CROSSWALK-2026-11-11.md`.

## 8. Change log and safety
- Catalog and policy queries were read-only.
- No table, index, function, policy, role, grant, data row, migration history or payment configuration was changed.
- No subscription checkout, mandate or charge was initiated.
- Production DDL remains blocked until the migration history and actual deployed SQL baseline are reconciled and a rollback/staging plan is confirmed.
