# KRIM Phase 04.4 — Staging Migration Statement and Table-Privilege Review

Date: 2026-11-26
Branch: remediation/phase-03dw-isolation-2026-11-26
Scope: Read-only review of privilege-changing migration statements in Production and all 34 Staging ledger entries, plus current grants on four organization/RBAC tables.

## Decision

**Synthetic-user generation remains BLOCKED.** No database or repository runtime configuration was changed. No grants, revokes, migrations, users, or deployments were applied.

## 1. Staging migration ledger review

The 34 Staging ledger entries are primarily a focused set of operational RPC permission restorations and later hardening changes dated November 17–23. They do not include the foundational October migration history that creates and secures customer, partner, and driver provisioning.

Examples of recorded Staging migrations include:
- customer journey RPC access restoration;
- partner assignment and dispatch RPC access restoration;
- driver trip-event and delivery-POD RPC access restoration;
- partner network submission RPC grants;
- country-pack admin review RPC grants;
- driver licence expiry admin RPC hardening.

No Staging ledger entry inspected contains the canonical provisioning RPC grants for customer, partner, or driver.

## 2. Production table-grant history — important interpretation

Production's ledger contains:
- `20260929124519_tighten_api_role_table_privileges`: removes TRUNCATE, TRIGGER, and REFERENCES from anon/authenticated on public tables.
- `20261011162418_least_privilege_krim_table_grants`: revokes anonymous DML on KRIM tables, removes maintenance privileges from authenticated, and revokes authenticated INSERT/UPDATE/DELETE where no qualifying RLS policy exists.
- `20261011162547_restore_only_rls_authorized_krim_write_grants`: restores authenticated DML only where qualifying RLS write policies exist.
- `20261011183957_phase1_isolate_security_definer_authorization_helpers`: isolates helper functions and explicitly grants narrowly scoped access.
- `20261011184123_phase1_harden_postgres_default_privileges`: revokes default table, sequence, and function privileges from anon/authenticated/PUBLIC for future objects created by postgres in public.

The latter default-privilege change is important: **it can explain why newly created Staging tables do not automatically inherit the same authenticated SELECT privileges as older Production tables.** The observed SELECT difference is not, by itself, proof that Staging is wrong or that Production grants should be copied.

## 3. Current table grants confirmed

For the four inspected tables:
- Production currently grants authenticated SELECT on all four.
- Staging currently has no authenticated table privileges on those four.
- service_role has broad table privileges in both environments.
- No anon grants appeared in the inspected result.

This is an API exposure difference, but it may reflect the hardened default privileges and object creation chronology. We must verify actual application reads and intended exposure before granting SELECT. Do not blanket-grant authenticated access.

## 4. Security implication

RLS policies do not replace SQL privileges. A correct SELECT policy is ineffective if the role has no table SELECT privilege. Conversely, a SELECT grant does not by itself bypass RLS. The safe correction, if required, is table-specific and based on real application use plus a reviewed row policy.

The existing four policies were previously inspected and matched between environments. This review did not perform signed-in runtime SELECT tests, negative cross-tenant reads, or API response checks.

## 5. Reconciliation recommendation

Do not import the Production migration history into Staging and do not replay all 561 Production migrations. The two environments have distinct histories and Staging's 34 entries appear to represent a separate curated deployment track.

Prepare a **Staging-specific reconciliation package** consisting of:
1. an authoritative object inventory (tables, columns, constraints, indexes, triggers, policies, functions, ACLs, sequences, storage, and Edge Functions);
2. a per-object provenance map from repository migration/source to live Staging state;
3. a minimal migration that restores only verified required provisioning RPC privileges and any table-specific API grants proven necessary;
4. explicit security tests: anon denied, authenticated own-org allowed where intended, cross-org denied, unverified partner/driver restricted, and platform-admin-only actions protected;
5. post-change advisors and schema/ACL diff evidence.

Before any RPC permission is granted, the driver function's use of user-editable `raw_user_meta_data.krim_account_type` must be corrected or shown not to grant trusted authorization. Customer and partner provisioning functions also need negative tests for existing memberships, duplicate requests, concurrent calls, and attempts to create cross-tenant memberships.

## Status register

| Check | Status |
|---|---|
| Staging's 34 migration entries inspected for privilege statements | VERIFIED |
| Canonical provisioning RPC grants absent from Staging ledger | VERIFIED |
| Production's table privilege hardening sequence recovered | VERIFIED |
| Current authenticated SELECT grants differ on four tables | VERIFIED |
| Difference explained by hardened default privileges as a plausible cause | SUPPORTED, not conclusively proven |
| Required Staging table SELECT exposure | NOT YET DETERMINED |
| Staging provisioning RPC reconciliation | NOT APPLIED |
| Signed-in runtime/RLS tests | NOT TESTED |
| Synthetic-user generation | BLOCKED |

No Production or Staging state was changed.
