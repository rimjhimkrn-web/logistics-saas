# KRIM staging warehouse onboarding blockers — 2026-11-24

## Scope and method

Read-only catalog and data comparison between the Supabase staging project and production. No SQL writes, DDL, grants, seed changes, or user messages were issued.

Projects:
- Staging: `qrpcivhdxobiaofppbkl`
- Production: `ebltviniygljwwseplph`

## Verified staging state

The staging project currently has:
- 1 Auth user
- 0 `krim_organizations`
- 0 `krim_organization_members`
- 0 `krim_warehouse_facilities`
- 0 `krim_warehouse_tasks`
- 0 `krim_warehouse_evidence`
- 0 verified active warehouse partner capabilities

The following required catalogue/configuration rows are also missing or inactive:
- `krim_security_permissions` has no `permission_code = 'partner.manage'` row.
- `krim_countries` has India (`IN`, id 246) marked `is_active = false`.

## Production comparison

Production has:
- `partner.manage` permission (id 20, “Manage Partners”).
- India (`IN`, id 1) marked active.
- `partner.manage` granted to organization_owner, organization_admin, operations_manager, platform_admin and platform_superadmin roles.

Neither environment currently has a verified active warehouse capability row. Production/staging counts of such capabilities are both zero at the time of this audit.

## Why this blocks warehouse staging tests

The inspected staging function `private.krim_has_permission(uuid,bigint,text)` returns true only when an active user role assignment joins to a granted role-permission row whose `permission_code` matches the requested code. With no `partner.manage` permission row in staging, no role assignment can satisfy the warehouse operator permission check.

The inspected `private.krim_warehouse_org_eligible(bigint)` requires an active organization in an eligible verified partner lifecycle/compliance state and either a warehouse/fulfilment organization type or a verified active warehouse capability. The direct facility-registration RPC additionally requires an active country catalogue entry. India's inactive staging catalogue row therefore blocks an India warehouse facility registration even after a test organization is provisioned.

These are independent of the previously documented warehouse RPC EXECUTE ACL mismatch. Granting authenticated EXECUTE alone would not make the staging workflow usable.

## Safe remediation sequence

1. Reconcile the staging seed/catalogue state against the authoritative versioned source and production intended state. Do not copy production business data.
2. Restore the missing permission catalogue and role-permission mappings through a reviewed, versioned migration or seed process. Preserve least privilege; do not grant `partner.manage` to every role.
3. Restore the active India country catalogue row through the same controlled seed process.
4. Create synthetic staging-only users and organizations through supported provisioning flows; do not modify production.
5. Provision a verified warehouse capability only through the intended verification workflow or a clearly marked staging fixture that cannot be mistaken for a real partner.
6. Apply the exact 14-function authenticated RPC ACL proposal only after migration-history reconciliation and function-body review.
7. Execute positive same-tenant facility/task/evidence/transition tests and negative foreign-tenant tests, then verify rollback/cleanup counts.

## Release decision

No staging or production data was changed. Do not treat the warehouse ACL proposal as sufficient remediation. Staging catalogue/seed parity, identity provisioning, capability verification and migration-history reconciliation remain release blockers. Do not use service-role credentials in browser code and do not grant broad permissions to bypass these controls.
