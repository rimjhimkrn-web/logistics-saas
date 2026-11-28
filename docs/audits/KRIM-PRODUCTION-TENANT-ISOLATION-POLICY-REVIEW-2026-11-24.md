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


## Follow-up dependency trace — legacy tenant-policy findings (2026-11-24)

A further read-only production catalog review traced foreign-key dependencies for the three legacy tables flagged above. This confirms that these tables cannot be treated as isolated or safely retired as a quick policy fix.

### Confirmed foreign-key dependency surface

- `shipment_requests` is referenced by `ai_actions`, `ai_conversations`, `delivery_proofs`, `krim_shipments` (legacy link), `notifications`, `partner_payouts`, `payments`, `shipment_dispatches`, `shipment_financials`, `shipment_pod_documents`, `shipment_ratings`, and `support_tickets`.
- `partners` is referenced by `delivery_proofs`, `krim_organization_members` (legacy partner link), `partner_documents`, `partner_drivers`, `partner_fleet`, `partner_payouts`, `shipment_dispatches`, `shipment_pod_documents`, and `shipment_requests`.
- `krim_driver_profiles` is referenced by `krim_driver_verification_documents` and `krim_vehicle_driver_bindings`; the latter uses `ON DELETE RESTRICT`. The profile itself references the organization and Auth user.

### Exact production policy observations reconfirmed

- `shipment_requests` SELECT resolves partner access through `partners.user_id = auth.uid()`; UPDATE uses the same user-linked partner lookup for both USING and WITH CHECK.
- `partners` SELECT and UPDATE remain linked to `partners.user_id = auth.uid()`, without checking active organization membership/status.
- `krim_driver_profiles` SELECT remains `user_id = auth.uid()`; INSERT and UPDATE additionally require an active driver membership, while UPDATE WITH CHECK preserves user ownership and active membership.

### Remediation consequence

Do not drop, rename, truncate, or broadly rewrite these legacy tables or their policies as a shortcut. Before a forward-only policy migration, map each dependent workflow and its canonical organization relationship, identify legitimate self-service profile access after membership revocation, and test both permitted and denied access under two synthetic tenants. In particular, preserve finance, payout, delivery-proof, notification, AI-history, dispatch, fleet, driver-document, and vehicle-binding relationships.

This dependency trace is catalog evidence only. It does not establish exploitability, and no production data, policies, grants, or schema were changed.


## Dynamic staging test — foreign driver assignment acceptance (2026-11-24)

A third synthetic two-user negative test was executed against isolated Supabase staging inside an explicit transaction:

1. Created two disposable, email-confirmed Auth users using `.example.invalid` addresses.
2. User A provisioned a partner organization through the actual `krim_provision_partner_organization` RPC; the resulting owner membership was changed to an active driver membership within the same test transaction.
3. Created a minimal pending driver-assignment row owned by User A in that organization.
4. Switched the request JWT subject to User B and invoked the real `krim_driver_accept_assignment` RPC with User A's assignment UUID.
5. The RPC raised the expected insufficient-privilege error because the assignment is not owned by the authenticated driver. The test also asserted the assignment remained in `assigned` state.
6. Rolled back the complete transaction.

The first fixture attempt exposed a uniqueness constraint because the provisioning RPC already creates the owner membership. The fixture was corrected to update that membership to driver for the isolated test, rather than inserting a duplicate membership. The corrected test passed.

Reproducible script: `tests/sql/staging-driver-assignment-ownership-isolation.sql`.

Post-rollback staging check: 1 Auth user, 0 organizations, 0 driver assignments — matching the pre-test baseline. No persistent test data remains.

This proves the foreign-assignment ownership rejection path only. It does not test a legitimate driver's successful acceptance, licence/vehicle/compliance prerequisites, trip events, POD, or the remaining tenant matrix. Production remains unchanged.
