# KRIM Finance Workspace Authorization and Database Advisor Follow-up — 2026-11-16

## Scope
Read-only repository and production metadata inspection. No refund, settlement, payment, invoice, journal, or other financial business function was invoked. No production data, schema, grants, or policies were changed.

## Finance workspace authorization review
The following 12 finance HTML entry points were inspected in the repository:
- `app/finance/index.html`
- `app/finance/invoicing.html`
- `app/finance/accounts-receivable.html`
- `app/finance/accounts-payable.html`
- `app/finance/payment-processing.html`
- `app/finance/partner-settlements.html`
- `app/finance/revenue-commission.html`
- `app/finance/refunds-disputes.html`
- `app/finance/multi-currency.html`
- `app/finance/tax-compliance.html`
- `app/finance/financial-reporting.html`
- `app/finance/treasury-audit.html`

Explicit `finance.view` checks are present on the finance command centre, invoicing, accounts receivable, accounts payable, payment processing, partner settlements, referral/coordination fees, multi-currency, tax compliance, financial reporting and treasury/audit pages.

Refunds & Disputes is intentionally different: the customer request workflow is scoped to the signed-in customer's own paid INR orders and own refund requests. The finance review desk remains hidden/disabled pending a separate reviewer authorization and cross-organization scope review. It must not be opened merely by granting generic `finance.view`; reviewer actions remain server-side AAL2/role/organization gated. No refund RPC was called during this review.

## Production Supabase security advisor
The production security advisor reported 29 `rls_enabled_no_policy` findings across private/public tables at observation time 2026-11-16 12:31:31 UTC.

A read-only catalog/grant query examined the reported tables. The returned rows showed no `anon` or `authenticated` table grants on the inspected no-policy tables; the returned grants were service-role-only where present, and some tables had no matching role grants in the query result. This supports a fail-closed interpretation for ordinary Data API callers, but is not a full proof of every access path:
- service-role code bypasses RLS and must be audited independently;
- SECURITY DEFINER functions may expose data or mutations;
- views, triggers, storage policies and indirect RPC paths need separate review;
- the advisor's 29 count and the targeted query's returned subset are not interchangeable.

The 29 advisor findings include internal rate-limit/payment tables and public-schema operating-control, country/market readiness, partner compliance, capacity, rate-card, dispatch/custody and POD tables. No policies should be added mechanically: some tables are intentionally service-role-only and adding broad authenticated policies could weaken security.

## Release decision
No security sign-off is granted by this inspection. Finance UI authorization improvements reduce accidental entry-point access but do not repair the previously identified broad finance-table RLS policies, approval/ledger defects, accounting-period mismatch, or migration-history discrepancy. The release remains NO-GO for unrestricted live financial operations.

## Required next work
1. Reconcile migration history and live schema before any production DDL.
2. Map all finance table grants, RLS policies, view security modes, function ACLs and SECURITY DEFINER call chains.
3. Replace broad finance table access with least-privilege server-side authorization only after migration reconciliation and staging tests.
4. Keep refund review disabled until dedicated reviewer permission, AAL2, legal-entity scope and separation-of-duties tests pass.
5. Run negative tenant-isolation tests for all nine workspaces in staging.

## Evidence boundaries
This report records static code review, advisor output and read-only catalog inspection only. It is not a penetration test, production authorization certification, or evidence of successful business transactions.
