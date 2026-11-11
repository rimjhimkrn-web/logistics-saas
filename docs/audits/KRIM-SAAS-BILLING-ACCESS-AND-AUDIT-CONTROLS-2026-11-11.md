# KRIM SaaS billing access and audit controls — 11 November 2026

## Work completed
Added `docs/drafts/KRIM-SAAS-AUDIT-IMMUTABILITY-AND-BILLING-READ-ACCESS.sql` as a review-only companion to the SaaS foundation. It proposes:
- append-only audit events enforced by database UPDATE/DELETE triggers;
- no direct client INSERT/UPDATE/DELETE/TRUNCATE privileges on the audit table;
- conservative owner-only subscription and audit reads until a dedicated billing permission is introduced.

This is not a migration and has not been applied to any database.

## Live production catalog checks (read-only)
- `krim_organization_members` uses bigint organisation IDs, UUID user IDs, text role and status fields.
- `krim_user_role_assignments` uses nullable bigint organisation scope, UUID user ID, bigint role ID and boolean active state.
- Existing permission catalogue includes `organization.manage`; the targeted lookup did not find a billing or subscription permission code.
- The targeted membership-role aggregation returned no rows, so the current owner-role vocabulary could not be confirmed from live memberships. The draft's `lower(role) = 'owner'` condition is a proposed conservative convention, not a verified production value.
- The existing organisation access helper checks active membership and active organisation; it does not by itself establish billing authorization.

## Important deployment warning
Do not apply the owner-only policy until the actual membership role vocabulary and intended ownership rules are confirmed in a staging fixture. Better long-term approach is a dedicated `billing.view` permission granted only to approved roles through KRIM's role-permission framework.

## Still blocking implementation
1. Confirm owner and finance-manager role mapping using known staging fixtures.
2. Add dedicated billing permissions and review role grants.
3. Enforce idempotency in the trial approval RPC (request ID + action + actor + canonical payload hash).
4. Make audit events append-only and verify table ownership/privileged bypass controls.
5. Complete migration source/body reconciliation and create an isolated staging baseline.
6. Implement and test the customer trial request and admin approval Edge Function only after schema sign-off.
7. Run the complete security matrix, including cross-tenant, membership revocation, replay, concurrency and expiry.

## Safety status
No production DDL, data changes, migration repair, payment activation or trial approval occurred. The SQL remains in `docs/drafts/` only.
