# KRIM Production Tenant-Isolation Policy Review — 2026-11-24

## Scope and method

Read-only inspection of the production Supabase project `ebltviniygljwwseplph`. No database writes, test records, role changes, migrations, or deployment were performed.

Inspected PostgreSQL RLS enablement, selected policies and grants for core organisation, shipment, partner, driver, customer, preference and notification tables, plus the definitions of the organisation-access helper functions.

This is a policy-source review, not a successful authenticated cross-tenant penetration test.

## Positive controls observed

- All 391 public base tables returned by the catalog query have row-level security enabled (0 without RLS).
- `private.krim_has_organization_access(user_id, organization_id)` checks that the caller matches the supplied user ID and that both the membership and organisation are active.
- `krim_shipments` SELECT policy scopes customer access through that helper; partner access is derived from a non-rejected/non-cancelled assignment and active partner membership, with additional organisation state checks in the helper.
- `krim_user_app_preferences` SELECT/INSERT/UPDATE policies bind rows to `auth.uid()`, including UPDATE `USING` and `WITH CHECK`.
- Notification outbox and delivery SELECT policies are organisation-scoped; notification preferences are user-scoped.
- `krim_shipment_partner_assignments` authenticated SELECT policy checks access through the shipment's customer organisation or the assigned partner organisation. Service-role ALL policy is explicitly privileged.

## Findings requiring remediation or explicit acceptance

### F-01 — Legacy shipment request access does not revalidate active organisation membership (High)

Table: `public.shipment_requests`

The authenticated SELECT and UPDATE policies use the caller's linked `partners.user_id` record to match `partner_id`. They do not require an active `krim_organization_members` row or an active partner organisation. The UPDATE policy also does not re-check partner organisation verification/compliance state.

Impact: if a partner user's legacy `partners` profile remains linked after their organisation membership is suspended or removed, the legacy policy can continue to authorize access to rows assigned to that partner profile. This is a stale-access gap, not proof that a cross-organisation exploit was executed.

Recommendation: determine whether this legacy table is still used by any live UI, RPC, trigger, or integration. If retained, replace the policy predicates with the canonical active-membership/active-organisation checks and verify both `USING` and `WITH CHECK`. If retired, remove client grants and access paths through a separately reviewed forward-only migration. Do not change production until dependencies and migration history are reconciled.

### F-02 — Partner profile access is user-linked, not membership-linked (Medium)

Table: `public.partners`

SELECT and UPDATE policies bind access to `partners.user_id = auth.uid()`; they do not also require the linked organisation membership to remain active.

Impact: a former member may retain access to their own legacy partner profile after membership removal. The row is user-linked, so this alone does not demonstrate access to another organisation's profile.

Recommendation: confirm whether partner profile self-service is still required. If so, add an active membership check against `krim_organization_id` to the applicable policies and test the intended offboarding behaviour.

### F-03 — Driver profile SELECT is not membership-state gated (Low/Medium)

Table: `public.krim_driver_profiles`

The SELECT policy checks only `user_id = auth.uid()`. INSERT and UPDATE additionally require an active driver membership (UPDATE has a WITH CHECK membership predicate).

Impact: a driver whose membership is revoked can still read their own driver profile. This is a stale-access/retention decision, not evidence of cross-user profile disclosure.

Recommendation: decide whether users should retain read-only access to their own profile after offboarding. Encode that lifecycle decision explicitly and test it.

## Verification limits

- No test users, synthetic tenant rows, or authenticated JWT role simulations were created or used against production.
- No cross-tenant SELECT/INSERT/UPDATE/DELETE attempt was executed.
- Static policy inspection cannot prove every view, RPC, SECURITY DEFINER function, storage policy, or edge function preserves the same tenant boundary.
- The app's organisation selector and saved preference are routing/UI state only; database policies must remain the authorization boundary.
- A production RLS-enabled table count does not establish that every policy is correct.

## Required next gates

1. Trace all live references to `shipment_requests` and `partners` before changing legacy policies.
2. Build isolated staging fixtures for two organisations and separate users, including active, suspended and revoked memberships.
3. Test positive and negative cases for SELECT, INSERT, UPDATE (including attempts to change organisation/owner IDs), DELETE, RPCs and storage.
4. Add regression tests that assert both tenant isolation and offboarding/revocation behaviour.
5. Reconcile migration history before applying any production or staging DDL.
6. Re-run Supabase security advisors and verify the deployed policy definitions after an approved migration.

## Release decision

**Tenant-isolation gate remains OPEN.** The review found useful canonical controls, but F-01 and F-02 require dependency analysis and remediation/acceptance. No production changes were made. Do not represent this review as proof of end-to-end tenant isolation.
