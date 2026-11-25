# Phase 00 — Nine-workspace ecosystem, authorization and tenant-isolation audit
Date: 2026-11-25
Branch: qa/phase-00-baseline-2026-11-25
Method: read-only PostgreSQL catalog, RLS policy, ACL, role/permission and operational-record inspection across Production and Staging; prior QA-branch source audits for Customs, Finance, Operations, Enterprise and Platform Admin were used as supporting context.
Safety: no JWT impersonation, test-account creation, data writes, RPC invocations, grants, policies, schema changes or external communications.

## Executive decision
**Nine-workspace access architecture is SOURCE/CATALOG-PARTIALLY CONFIRMED, but end-to-end authorization and cross-tenant isolation are NOT VERIFIED. Staging is currently not ready for signed-in workspace execution with its inspected database ACL state. No unrestricted user onboarding approval.**

## 1. Organization and role model — Production
Production catalog currently contains:
- 14 active organizations across nine organization types: 5 customer, 2 partner, 1 carrier, 1 warehouse, 1 customs, 1 finance, 1 operations, 1 enterprise and 1 platform.
- 13 active organization memberships: 7 owner, 4 manager, 1 member and 1 driver.
- 17 active user-role assignments: 6 organization_owner, 1 organization_admin, 2 customer_user, 2 partner_user, 1 finance_manager, 1 operations_manager, 1 compliance_manager, 2 platform_admin and 1 platform_superadmin.
- 11 role definitions and 23 permission definitions, with 155 role-permission mapping rows (granted mappings counted per role below).

Defined roles and granted permission counts:
- compliance_manager 8
- customer_user 10
- dispatcher 9
- finance_manager 7
- operations_manager 15
- organization_admin 21
- organization_owner 22
- partner_user 11
- platform_admin 22
- platform_superadmin 23
- viewer 7

Permission catalog covers organization, partner, compliance, document, finance, platform administration, quote, shipment and tracking actions. This is a structured baseline, not proof that each workspace page enforces the correct subset.

Important: organization membership and role assignment are separate tables. The permission helper requires both an active role assignment for the same user/organization and an active organization membership in an active organization. This is a sound source-level tenant-binding pattern. Runtime negative tests have not been run.

## 2. Staging parity — material blocker
Staging has:
- 0 organizations
- 0 organization members
- 0 network memberships
- 0 role-permission mappings
- 11 role definitions
- 0 permission definitions
- 1 user-role assignment
- 0 customer accounts, partner verification cases, partner capabilities, driver profiles, warehouse facilities, customs broker assignments or operational execution state rows.

Across the 79 KRIM workspace/security tables in scope:
- Production: all 79 have RLS enabled; 76 have at least one policy; 3 have no policy; 9 have FORCE RLS.
- Staging: same RLS/policy/force-RLS catalog counts.
- Production authenticated table grants: SELECT on 65 tables, INSERT on 14, UPDATE on 12, DELETE on 11.
- Staging authenticated table grants: zero SELECT, INSERT, UPDATE or DELETE privileges across all 79 tables.

This means the schema and policies are present in Staging, but the client role cannot directly access any of these 79 tables through the inspected grants. This may be an intentional closed baseline, incomplete ACL deployment, or deliberate staged isolation. Either way, it blocks authenticated workspace validation until an approved, least-privilege staging grant plan exists. Do not copy Production grants wholesale.

## 3. RLS and direct table exposure
The 79-table scoped set contains 79 RLS-enabled tables and zero RLS-disabled tables. In Production, 74 of these tables have at least one table privilege for anon/authenticated combined; RLS is therefore an active row-security boundary, not a substitute for policy review. No anon/authenticated direct table privileges were found on the three RLS-enabled/no-policy tables:
- `krim_partner_compliance_evidence` (FORCE RLS)
- `krim_partner_compliance_reviews` (FORCE RLS)
- `krim_partner_shipment_capacity_commitments` (not FORCE RLS)

The no-policy condition is fail-closed for direct client access in the inspected ACLs. Do not add broad policies to these tables; access appears designed to occur through privileged RPC paths.

The three no-policy tables and all other scoped policies still require role-by-role runtime tests. RLS policy catalog presence does not prove that a policy is correctly scoped or that an exposed SECURITY DEFINER RPC performs equivalent checks.

## 4. Authorization helper source review
Production definitions inspected:
- `private.krim_has_organization_access(user_id, organization_id)` checks active membership and active organization, and requires `auth.uid()` to be NULL (trusted backend context) or equal to the requested user ID.
- `private.krim_has_permission(user_id, organization_id, permission_code)` additionally requires an active role assignment bound to the same user and organization, a granted role-permission mapping, and an active organization membership.
- Public wrappers delegate to the private helpers.
- Private helpers are SECURITY DEFINER with a constrained `search_path` of public and pg_catalog.
- Production grants authenticated EXECUTE on these helper wrappers; Staging does not grant authenticated EXECUTE on either public or private helper.

These are positive source-level controls. However, Staging cannot exercise the same helper paths under the inspected ACLs. Runtime tests must verify that user-supplied IDs cannot be substituted for another user and that missing/expired membership or inactive role assignment denies access.

## 5. Nine-workspace readiness matrix

| Workspace | Production data/catalog signal | Staging signal | Current decision |
|---|---|---|---|
| Customer/Shipper | 5 customer organizations; 0 canonical customer-account rows; earlier booking source maps to shipment RPC | 0 organizations and no customer records; no table grants | NOT VERIFIED |
| Partner/Carrier | 2 partner + 1 carrier organizations; 1 verification case and 1 capability row, but prior audits found 0 verified active capabilities/service areas and 0 assignments | 0 organizations, cases, capabilities; no table grants | NOT VERIFIED |
| Driver | 1 active driver membership; 0 driver profiles, assignments, verification docs, vehicles or POD rows | 0 driver data; no table grants | NOT VERIFIED |
| Warehouse | 1 warehouse organization; 0 facilities, tasks, receipts, inventory or evidence | 0 warehouse data; no table grants | NOT VERIFIED |
| Customs | 1 customs organization; 0 broker assignments/doc submissions | 0 customs data; no table grants | NOT VERIFIED |
| Finance | 1 finance organization; canonical ledger entries/transactions and refunds remain empty | 0 finance records; no table grants | NOT VERIFIED |
| Operations Control Tower | 1 operations organization; 0 operational execution state rows | 0 operations records; no table grants | NOT VERIFIED |
| Enterprise | 1 enterprise organization; prior source audit found approval/register pages but no proven end-to-end event/notification flow | 0 enterprise organization or records; no table grants | NOT VERIFIED |
| Platform Admin | 1 platform organization; 2 platform_admin and 1 platform_superadmin role assignments | no organizations or permission definitions; no table grants | SOURCE PARTIAL; runtime NOT VERIFIED |

Organization records alone do not demonstrate operational readiness. A user may have an organization but still lack a valid permission, verified business status, capability, active assignment, facility, broker license, finance entitlement or operational evidence.

## 6. Five-workspace source evidence carried forward
Prior source audits establish:
- Customs secure workspace requires session, AAL2, active customs organization membership and compliance.view; actual JWT tests are still absent.
- Finance workspace is controlled/read-only; partner settlement page is unavailable pending authorization corrections.
- Operations exception register supports scoped read and acknowledgement, but resolution remains disabled pending evidence and closure controls.
- Enterprise approval page scopes to enterprise organization memberships and shows approval event history, not a complete notification inbox.
- Platform Admin support queue uses admin RPCs; SIEM page explicitly states its verified event stream/integrity path is not connected.
- Unified notification delivery for all nine ecosystems remains NOT EVIDENCED, as detailed in the earlier notification reports.

## 7. High-priority runtime test matrix — not executed
Before onboarding, create an isolated Staging test sink and synthetic identities, then test:
1. Anonymous user cannot read or mutate private workspace data.
2. Authenticated user with no membership is denied.
3. User A in organization A cannot read/update/delete organization B records by changing IDs, URL parameters, RPC arguments or storage paths.
4. Membership revoked or organization suspended immediately denies subsequent requests after token/session refresh.
5. Role assignment inactive, missing permission, or permission mapped to a different organization is denied.
6. Owner, manager, dispatcher, customer_user, partner_user, finance_manager, compliance_manager, operations_manager, enterprise user and platform admin each receive only documented permissions.
7. AAL1 is denied for operations requiring AAL2; valid AAL2 succeeds only for approved platform/admin paths.
8. Cross-workspace role confusion is denied (e.g. finance cannot approve partner compliance; partner cannot see another partner's quote; driver cannot see unassigned shipment).
9. SECURITY DEFINER RPCs enforce their own auth, organization, permission, state, idempotency and evidence checks.
10. Read, insert, update, delete, storage upload/download and signed URL behavior are tested separately.
11. Multi-role users receive the union of explicitly assigned permissions only, with no accidental global elevation.
12. Revocation, duplicate requests, replay, concurrency and stale-token behavior are tested.

## 8. Remediation sequence
1. Preserve current Production and Staging ACLs. No broad grant/policy changes.
2. Produce a page-to-RPC-to-table-to-role matrix for all nine workspaces.
3. Decide whether Staging is intentionally closed or should be activated for QA. If activated, add only reviewed table/RPC grants to Staging after test sink and synthetic identities are ready.
4. Seed minimal synthetic organizations for all nine organization types with clearly fake data, after explicit test-plan approval and isolated staging confirmation.
5. Run positive and negative JWT tests, including cross-tenant and role escalation cases.
6. Resolve Production-vs-Staging function EXECUTE drift only against the documented matrix; do not mirror grants blindly.
7. Complete notification inbox and provider-sink tests as a separate mandatory launch gate.

## 9. Evidence classification and release gate
- Schema/role/permission catalog: **INSPECTED**.
- Organization and membership snapshot: **INSPECTED**.
- RLS enabled and no-policy ACL checks: **INSPECTED**.
- Authorization helper source: **SOURCE-REVIEWED**.
- Workspace page-to-RPC mapping: **PARTIAL; prior five-workspace audit evidence reused**.
- Signed-in positive/negative tests: **NOT TESTED**.
- Cross-organization isolation: **NOT TESTED**.
- AAL1/AAL2 enforcement runtime: **NOT TESTED**.
- Storage object isolation: **NOT TESTED**.
- Staging workspace execution: **BLOCKED by zero authenticated table grants in scoped set**.
- Real user onboarding: **NO-GO / NOT VERIFIED**.

No Production or Staging data was changed. No external communications or payment actions occurred.
