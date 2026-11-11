# KRIM SaaS Subscription Integration Map
Date: 11 November 2026
Status: read-only production discovery; no schema or payment changes made.

## Existing platform foundations confirmed
Production currently has 425 recorded migration entries and 378 public tables. The following existing tables are relevant to SaaS subscriptions:

| Existing table | Current purpose | Subscription-engine use |
| --- | --- | --- |
| `krim_organizations` | Organisation identity and lifecycle | Tenant owner for each subscription |
| `krim_organization_members` | User-to-organisation membership | Establish organisation membership; do not invent a second membership model |
| `krim_security_roles`, `krim_user_role_assignments`, `krim_security_permissions`, `krim_role_permissions` | Role and permission framework | Gate subscription administration and feature administration |
| `krim_customer_accounts` | Customer account lifecycle | Link customer-type organisations where applicable |
| `krim_customer_billing_profiles` | Freight/customer billing profile | Not a SaaS subscription record; keep separate |
| `krim_invoices`, `krim_invoice_items` | Existing operational/freight invoice domain | Do not overload for SaaS invoices without a reviewed accounting design |
| `payment_orders`, `payments`, `payment_webhook_events` | Existing freight checkout and payment lifecycle | Do not reuse as subscription billing; retain separate provider and ledger boundaries |
| `krim_payment_capability_registry` | Country/provider eligibility controls | Subscription checkout must have its own explicit approval gate and must not infer approval from a configured row |

## Security observations from live policies
- Organisation reads are scoped to active memberships; platform-admin reads require AAL2 and the platform-admin permission.
- Membership rows are currently self-readable by the matching authenticated user.
- Customer accounts and customer billing profiles use organisation-access checks.
- Existing invoice reads are permission-scoped across the relevant organisations.
- Payment capability registry denies direct client access.
- These are useful patterns, not a blanket approval to copy policies. Every subscription table needs a table-specific threat model, least-privilege grants and RLS tests.
- Never accept client-supplied subscription status, payment status, provider IDs, price, entitlement, tax or refund decisions as authoritative.

## Proposed subscription domain boundary
Keep SaaS billing in dedicated tables, separate from freight payments:
1. `krim_saas_products`
2. `krim_saas_plans`
3. `krim_saas_prices`
4. `krim_saas_subscriptions`
5. `krim_saas_subscription_items`
6. `krim_saas_entitlements`
7. `krim_saas_invoices`
8. `krim_saas_payment_attempts`
9. `krim_saas_refunds`
10. `krim_saas_webhook_events`
11. `krim_saas_audit_events`

All tenant-owned records should reference `krim_organizations.id`. The subscription customer is an organisation, not an arbitrary user. Membership and role/permission checks determine who can view or administer the subscription. Product catalogue and plan definitions are platform-controlled; client users cannot create or modify them.

## Entitlement model
- Server-side entitlement evaluation only.
- Resolve active subscription + current price/plan + effective entitlement records.
- Enforce status, trial/grace windows, effective dates and suspension/cancellation.
- Never rely on a hidden button or frontend-only flag as access control.
- Cache only with bounded expiry and a revocation strategy.
- Every feature gate must have a named entitlement code, server-side enforcement point, owner and test.
- Free evaluation access, if enabled, must be explicitly time-bounded and distinguishable from paid status.

## Migration-history reconciliation is a hard blocker
Read-only comparison found:
- Production migration history: 425 entries.
- Repository migration files: 263.
- 201 migration names overlap when compared by descriptive name.
- 60 repository migration names were not found in production history.
- 222 production migration names were not found in the repository.
- The repository also contains several 11 November migrations later than the latest production migration timestamp returned by the history listing.

This is not safe to resolve by blindly replaying files, generating a migration from the live schema, or applying new DDL. Names and timestamps must be mapped to actual SQL content and deployment history. A migration-by-migration reconciliation is required before any subscription table is created.

## Safe next implementation sequence
1. Preserve this production baseline and export/review full migration inventory.
2. Reconcile migration history against repository SQL and actual live schema.
3. Finalise subscription table definitions and constraints only after the baseline is reliable.
4. Review all RLS policies, grants, triggers and functions with security tests.
5. Build subscription admin and organisation billing views against a non-production schema.
6. Add billing-provider integration only after merchant eligibility, recurring billing, refunds, tax and settlement evidence are approved.
7. Run end-to-end tests using provider test mode; no live charge until all gates pass.

## Explicit non-actions
No production DDL, migration application, payment activation, live billing, tax calculation or entitlement enforcement was changed by this discovery task.

## 11 November admin workflow increment
- Added restricted `admin-saas-pilots.html`, linked from the KRIM Global Control Centre governance section.
- The page uses the existing `global-admin-control` Edge Function and its existing AAL2 + platform-admin gate.
- It filters the latest 100 general contact enquiries for the exact software-evaluation inquiry label and allows audited status changes through the existing `inquiries` and `update_inquiry_status` actions.
- This is an enquiry triage surface only. It does not create trial records, grant entitlements, activate paid subscriptions, or create billing records. Do not represent it as trial management.
- The latest 100 limit is displayed in the UI to avoid implying a complete archive.
