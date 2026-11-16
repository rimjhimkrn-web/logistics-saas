# KRIM authenticated direct-write authorization — finance and organization tables

**Date:** 2026-11-17
**Status:** P0/P1 remediation specification — production read-only inspection only.

## Confirmed policy gap

Production currently grants `authenticated` INSERT/UPDATE/DELETE privileges on numerous public tables. Several sensitive finance/accounting tables use a single `org_isolation_all` policy whose `USING` and `WITH CHECK` predicates only call `private.krim_has_organization_access(auth.uid(), organization_id)`. That helper proves active membership in an active organization; it does not prove the member has a finance-specific permission or an appropriate role.

Confirmed examples include:
- `krim_accounting_account_mappings`
- `krim_accounting_periods`
- `krim_accounting_posting_rules`
- `krim_financial_approval_policies`
- `krim_financial_approval_requests`
- `krim_financial_monitoring_alerts`
- `krim_financial_posting_dlq`
- `krim_financial_posting_events`
- `krim_ledger_accounts`
- `krim_revenue_allocation_rules`
- `krim_revenue_allocation_runs`
- `krim_revenue_allocations`
- `krim_treasury_control_rules`

This is a material authorization boundary defect: an ordinary active organization member can satisfy the RLS predicate for direct writes to these tables if the corresponding table grants are present. Organization isolation alone is not adequate authorization for ledger, posting, approval, treasury or revenue-allocation mutation.

Other examples of broad org-isolation writes include customer identity/workspace profiles, external references, partner discovery profiles, growth opportunities and idempotency keys. Each requires classification by data sensitivity and allowed actor permission.

## Additional scoped observations

- `krim_driver_profiles` permits own-row INSERT and UPDATE policies; verify protected columns such as organization_id, verification status, review state, eligibility and company assignment cannot be self-modified. The exact trigger/column-level guard set was not established in this pass.
- `krim_driver_verification_documents` allows authenticated own-document INSERT and own-document SELECT; verify no direct UPDATE/DELETE, immutable evidence metadata, storage-object ownership and reviewer-only verification state changes.
- `ai_actions` and `ai_messages` use own-user INSERT/SELECT policies, which is narrower than organization-wide access, but mutation and parent conversation ownership should be checked in a dedicated AI data audit.
- `krim_execution_runtime_jobs` has a broad `shipment_org_all` ALL policy. Inspect whether any member of a shipment organization can directly create/update/claim/complete runtime jobs or alter worker control fields.
- The inspected core identity tables are materially narrower: membership, role assignment and role catalog policies are SELECT-only for authenticated users; no authenticated direct write grant was found for the core organization membership and role-assignment tables.

## Required remediation design

1. Finance/accounting writes should be mediated by SECURITY DEFINER or carefully permission-checked RPCs, not unrestricted direct table writes based solely on organization membership.
2. For any direct-write table that genuinely needs client mutation, split SELECT/INSERT/UPDATE/DELETE policies and require exact permission codes for each operation (for example finance.period.manage, finance.posting_rules.manage, finance.approvals.manage, treasury.rules.manage), plus active membership and active organization.
3. Make financial posting events, approval events, immutable ledger movements and audit records append-only; prevent client UPDATE/DELETE except tightly controlled service/reversal workflows.
4. Protect accounting periods from unauthorized close/reopen and enforce separation of duties between requester, approver and poster.
5. Restrict dead-letter queue and runtime job state transitions to service workers or narrowly authorized operators; clients must not self-claim or mark jobs complete.
6. Use column-level privileges or RPCs for driver profiles so users can update contact/profile fields but never organization binding, verification status, reviewer metadata, licence approval or operational eligibility.
7. Build and test a grants × RLS × policy × trigger × RPC matrix for every authenticated-write table before revoking or changing anything.
8. Add negative staging tests: ordinary member cannot change finance periods/rules/ledger/posting/approval/treasury; finance viewer cannot post; requester cannot approve own request; partner/driver/customer roles cannot write another workspace's records; direct REST writes are denied where RPC-only is intended.

## Priority and release gate

Treat finance/accounting direct-write authorization as a production release blocker until permission-specific controls and negative tests pass. Do not run production mutation tests. The current broad membership predicate is not proof that an exploit has occurred, but it is insufficient protection for these sensitive writes.

## Production boundary

No grants, RLS policies, functions, rows or production settings were changed. This specification is not a migration and must not be applied. Full remediation waits for migration-history reconciliation and explicit production-change authorization.