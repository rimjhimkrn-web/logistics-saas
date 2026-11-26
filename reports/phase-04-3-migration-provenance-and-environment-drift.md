# KRIM Phase 04.3 — Migration Provenance and Environment Drift

Date: 2026-11-26
Branch: remediation/phase-03dw-isolation-2026-11-26
Scope: Read-only inspection of the complete migration ledger metadata, provisioning-related migration statements, repository migration inventory, and the previously observed RPC/table ACL differences.

## Executive decision

**Phase 04 synthetic-user creation remains BLOCKED.** The Staging database has a distinct, partial migration history and does not contain the provisioning-related migration ledger records present in Production. No migration was applied, no ledger was edited, no schema or privilege was changed, and no environment was reset.

## 1. Migration ledger comparison

| Environment | Ledger entries | Oldest version | Newest version |
|---|---:|---|---|
| Production | 561 | 20260929043657 | 20261124071550 |
| Staging | 34 | 20261117135137 | 20261123044931 |

The Production ledger contains a large migration history from September through November. Staging has only 34 entries, mostly later operational fixes dated November 17–23.

The Staging ledger entries do not map to migration filenames in the current repository branch by timestamp. The 34 Staging ledger names appear to have been recorded through a separate process (several names are manually timestamp-prefixed), so the exact source SQL files and their checksums must be reconciled before using that ledger as migration provenance.

## 2. Provisioning migration provenance confirmed in Production

The Production migration ledger contains:

- `20261014220717 / krim_customer_org_provisioning`
- `20261016042526 / repair_customer_org_provisioning_and_add_partner_signup`
- `20261019020919 / restrict_privileged_krim_rpc_to_authenticated`
- `20261020192326 / provision_driver_workspace_on_first_signin`
- `20261105085118 / require_active_organization_for_workspace_access`
- `20261106062238 / harden_driver_org_provisioning_context`
- `20261115091128 / harden_customer_and_partner_organization_provisioning`

The repository contains similarly named migration files, but there is a timestamp/version discrepancy:
- Repository file: `20261115111500_harden_customer_and_partner_organization_provisioning.sql`
- Production ledger record: version `20261115091128`, name `harden_customer_and_partner_organization_provisioning`

Do not blindly re-run or insert either version into Staging. First compare the complete stored SQL statements and current schema/function definitions, then prepare a clean, reproducible migration history.

## 3. Root cause evidence for missing Staging function permissions

The Production migration `20261019020919_restrict_privileged_krim_rpc_to_authenticated` explicitly:
- revokes PUBLIC and anon execution on customer provisioning;
- grants authenticated execution on customer provisioning;
- revokes PUBLIC and anon execution on partner provisioning;
- grants authenticated execution on partner provisioning.

The Production ledger also records driver provisioning creation in `20261020192326_provision_driver_workspace_on_first_signin`, whose stored SQL explicitly revokes PUBLIC and anon and grants authenticated execution.

Staging has no ledger rows for these provisioning migrations. This aligns with the observed Staging ACLs:
- customer provisioning: authenticated EXECUTE absent;
- driver provisioning: authenticated EXECUTE absent;
- partner provisioning: authenticated EXECUTE present, despite the missing canonical migration ledger history.

The partner grant's provenance in Staging remains unexplained. It may be a direct/manual grant or the effect of a separate untracked script. Do not assume it is safe or reproducible until the Staging SQL statement history and ACL provenance are reconciled.

## 4. Table grant discrepancy remains unresolved

Production has authenticated SELECT grants on the four inspected organization/RBAC tables; Staging does not. The selected Production ledger includes a least-privilege table-grant migration, but this review has not yet fully traced every later revoke/restore statement affecting those four tables.

No blanket grant is recommended. The next pass must inspect exact table-level grant/revoke statements and verify each table's RLS policy, API exposure intent, and application call sites.

## 5. Important security review note

The driver provisioning function checks user-editable `raw_user_meta_data.krim_account_type`. This metadata check is not an authorization boundary and must not be used to confer verified-driver or commercial operating rights. The function also creates an active driver membership and driver-individual organization. Before enabling this RPC for synthetic accounts, verify all downstream verification, invitation, vehicle, assignment, and dispatch controls and decide whether unverified self-service driver organization creation is still intended.

## 6. Migration recovery plan — no action applied

1. Export and compare the full SQL statements and metadata for the seven Production provisioning-related ledger records.
2. Trace all table grants/revokes for the four organization/RBAC tables from the Production ledger.
3. Recover and version-control the exact SQL for the 34 Staging ledger records, including their stored statement arrays; identify any manual/dashboard-originated changes.
4. Compare Staging's live function definitions, ACLs, table grants, RLS policies, triggers, and dependent objects against the intended migration source.
5. Build a new, ordered, idempotent Staging-only reconciliation migration after independent review. Do not copy Production user/business rows or overwrite the existing migration ledger.
6. Apply only the specifically approved migration to Staging, then verify ACLs, advisors, RLS behavior, and negative authorization cases.
7. Only then begin synthetic-user creation and browser-based onboarding tests.

## Status register

| Item | Status |
|---|---|
| Production/Staging ledger counts | VERIFIED |
| Production provisioning migration history | VERIFIED |
| Missing Staging provisioning migration records | VERIFIED |
| Customer and driver EXECUTE mismatch explanation | STRONGLY SUPPORTED by missing migration history |
| Staging partner EXECUTE provenance | UNRESOLVED |
| Organization/RBAC table grant provenance | PARTIAL |
| Full 34-entry Staging SQL recovery | NOT YET COMPLETE |
| Reconciliation migration | NOT CREATED |
| Database changes | NONE |
| Synthetic-user generation | BLOCKED |

No Production or Staging database state was changed.
