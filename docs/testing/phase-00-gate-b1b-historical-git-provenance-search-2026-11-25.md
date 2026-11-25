# Phase 00 — Gate B1b historical Git provenance search

**Date:** 2026-11-25  
**Related gate:** B1 Staging migration provenance  
**Repository:** `rimjhimkrn-web/logistics-saas`  
**Safety:** Read-only GitHub history and branch inspection. No Supabase or repository application code changed.

## Result

**B1b: PARTIAL PASS for historical repository search; Staging provenance remains BLOCKED.**

The 31 Staging migration ledger names that lack exact current source files were each checked against GitHub's commit history for their expected `supabase/migrations/<name>.sql` path. All 31 path-specific history queries returned zero commits. This is evidence that those exact file paths do not appear in the accessible GitHub commit history for this repository, not proof that equivalent SQL never existed elsewhere or under another name.

## 1. Repository migration-directory history

GitHub path history for `supabase/migrations` returned 466 commits across five pages:
- newest sampled commit: 2026-11-24;
- oldest returned commit: 2026-10-16;
- no older commit was returned for this directory path.

This accessible migration-directory history therefore does not cover the Production ledger's initial 2026-09-29 migrations. The missing 270 Production names cannot be reconstructed from this repository path history alone.

## 2. Targeted Staging migration history

Each of the 31 unmatched Staging migration names was queried as an exact path under `supabase/migrations`. Result: **31/31 returned zero path-history commits**.

The 31 exact names are recorded in the companion report `phase-00-gate-b1-staging-migration-provenance-investigation-2026-11-25.md`. No exact historical file path was recovered.

## 3. Historical tree snapshot

Inspected the repository migration directory at commit:
- `a1e50f9c62d260dabf2ee1f7d2f848a05d43a846`
- authored 2026-11-17 14:23:21 UTC
- commit message: “Restore authenticated driver trip milestone access”

That historical tree contained 364 migration files. Among the Staging ledger names checked, the only corresponding file present in that snapshot was:
- `20261117017000_restore_driver_trip_event_rpc_access.sql`

The Staging ledger records the same migration name under version `20261117142325`, not the filename's `20261117017000`. This is a **name match, not a version match or proof of identical applied SQL**.

Two additional current name matches — `admin_driver_licence_expiry_control` and `refine_admin_driver_licence_expiry_rpc_security` — have source files dated 2026-11-23 and their live Staging ledger versions also differ from the filenames' timestamps. These are later current source matches, not evidence that the 31 missing November 17 files were archived.

## 4. Other Staging-named branches checked

Inspected `supabase/migrations` directory listings on ten branches:
- `staging/driver-ecosystem`
- `staging/owner-admin-url-fix`
- `admin-os/page-01-command-centre-staging`
- `customs-trade-ecosystem-staging`
- `driver-ecosystem-staging`
- `enterprise-os/page-01-dashboard-staging`
- `finance-ecosystem-staging`
- `operations-control-tower-staging`
- `testing/secure-staging-supabase-target`
- `warehouse-page-01-staging`

Each contained 364–368 migration files. None exposed the missing Staging migration names; the only relevant target found was the existing `restore_driver_trip_event_rpc_access` migration. No branch among these checked provides the missing 31-file source bundle.

This was a targeted branch check, not proof that no other branch or external repository contains related SQL.

## 5. Provenance conclusion

Evidence now supports:
1. The 31 unmatched Staging migration names have no exact migration-file path in the accessible GitHub commit history.
2. A 2026-11-17 historical tree contains the driver trip RPC migration, but its source timestamp differs from the Staging ledger version.
3. Ten Staging-named branches checked do not contain the missing migration bundle.
4. The repository's migration-directory history begins 2026-10-16, while Production's ledger begins 2026-09-29.

Still unknown:
- whether the Staging SQL was run manually in the Supabase SQL Editor;
- whether a local, uncommitted, private, or external repository held the migration scripts;
- whether a dashboard migration workflow recorded a different timestamp from the source filename;
- whether the applied SQL matches the current source for the three name matches;
- whether Staging was provisioned from a schema dump, backup, or manual bootstrap.

## 6. Required next evidence

1. Obtain the original Staging provisioning/bootstrap record and identify the operator/workflow that created its migration ledger entries.
2. Locate the original SQL bundle from local workstation backups, private repositories, deployment artifacts, Supabase dashboard history, or backup exports.
3. Compare each recovered SQL script's exact contents/checksum with the database objects and the recorded migration entry.
4. Keep Production and Staging ledgers untouched. Do not insert, delete, rename, repair or replay migration records.
5. Only after source provenance and object-level diffs are established, prepare a forward-only reconciliation proposal for explicit review.

## Checklist

| Check | Result |
|---|---|
| 31 exact Staging migration paths searched in Git history | PASS — 31 returned no commits |
| Migration-directory history range inspected | PASS — 2026-10-16 through 2026-11-24 |
| Historical 2026-11-17 migration tree inspected | PASS — 364 files |
| Ten Staging-named branches inspected | PASS — 10 branches; no missing bundle found |
| Original Staging bootstrap/provisioning record obtained | NOT TESTED |
| External/local SQL source bundle obtained | NOT TESTED |
| Applied SQL content/checksum verified | NOT TESTED |
| Staging migration provenance established | BLOCKED |
| Migration reconciliation authorized | BLOCKED |

**Safety:** No database writes, migration execution, migration-ledger edits, resets, deployments, merges, Auth changes, or provider operations were performed.