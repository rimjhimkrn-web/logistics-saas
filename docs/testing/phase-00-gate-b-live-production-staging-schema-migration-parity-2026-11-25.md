# Phase 00 — Gate B live Production/Staging schema and migration parity audit

**Date:** 2026-11-25  
**Scope:** Read-only live catalog comparison of Supabase Production and Staging.  
**Projects:** Production `ebltviniygljwwseplph`; Staging `qrpcivhdxobiaofppbkl`.  
**Safety:** SELECT/catalog introspection only. No DDL, DML, migration, reset, rebase, deployment, Auth or provider action.

## Executive decision

**Gate B: BLOCKED — migration lineage is unrelated, despite a surprisingly close public table/column/policy baseline.**

The two environments have **zero shared migration version identifiers**. Production records 561 migrations (from 2026-09-29 to 2026-11-24); Staging records 34 (from 2026-11-17 to 2026-11-23). This is not simply 527 unapplied migrations in a shared lineage: every migration version in each environment is unique to that environment.

At the same time, both currently expose 391 public base tables, with identical public table-name and column fingerprints, identical public policy fingerprints, and equal public index/constraint counts. But public function definitions, public triggers, indexes and constraints have differing fingerprints; public function and trigger counts differ. Therefore equal table/column counts are not proof of operational equivalence.

**Do not reset Staging, blindly apply Production migrations, rebase, merge, or run synthetic-user tests.** First produce a controlled catalog-level difference set and determine how Staging was provisioned.

## 1. Live database identity and version

| Attribute | Production | Staging |
|---|---|---|
| Project ref | `ebltviniygljwwseplph` | `qrpcivhdxobiaofppbkl` |
| Project status | ACTIVE_HEALTHY | ACTIVE_HEALTHY |
| Region | ap-northeast-1 | ap-south-1 |
| PostgreSQL engine | 17 | 17 |
| Reported version | 17.6.1.165 | 17.11.0.018 |
| Migration records | 561 | 34 |
| First recorded migration | 20260929043657 | 20261117135137 |
| Last recorded migration | 20261124071550 | 20261123044931 |

## 2. Migration lineage comparison

An exact comparison of all returned `version` keys found:

- Production-only migration versions: **561**
- Staging-only migration versions: **34**
- Shared version identifiers: **0**
- Shared version identifiers with differing names: **0** (none to compare)

This confirms the ledgers do not represent one shared migration sequence. The Production manifest starts with `add_global_partner_lifecycle`; Staging starts with `grant_partner_service_area_admin_queue`. Staging includes a selective set of later hardening and access-restoration migrations. Migration count subtraction is therefore not a valid application plan.

**Required provenance investigation:** determine whether Staging was created from a schema snapshot, manually provisioned, restored from a different baseline, or populated through selective migrations. Retrieve the exact migration SQL from the repository and map each Staging ledger version to its source file; identify any Staging-only migration files and whether they were ever intended for Production. No automatic repair is safe until this provenance is understood.

## 3. Live catalog metrics

Read-only PostgreSQL catalog queries were executed independently in each project.

| Catalog measure | Production | Staging | Observation |
|---|---:|---:|---|
| Non-system base tables (all schemas) | 443 | 439 | 4-table difference |
| Non-system columns (all schemas) | 5,516 | 5,483 | 33-column difference |
| Public base tables | 391 | 391 | Equal |
| Public columns | 4,964 | 4,964 | Equal |
| Public RLS-enabled tables | 391 | 391 | Equal |
| Public policies | 412 | 412 | Equal |
| Public indexes | 1,561 | 1,561 | Equal count; definitions differ |
| Public constraints | 1,807 | 1,807 | Equal count; definitions differ |
| Public triggers | 113 | 115 | 2-trigger difference |
| All non-system functions | 632 | 626 | 6-function difference |
| Public functions | 366 | 376 | 10-function difference |
| Non-system schemas | 118 | 24 | Significant schema inventory difference |
| Installed extensions | 7 | 5 | Two extension difference |

The public table-name hash is identical in both projects:
`b0e8e27ca18945e947c80e9103648efb`.

The public column fingerprint (table, column, type, nullability, default and ordinal) is identical:
`97006bcd2ff389d9d0b228972470b801`.

The public RLS policy fingerprint (schema, table, policy, command, roles, USING and WITH CHECK expressions) is identical:
`6f7ef72a6631048eea7545dfdb9f05fe`.

These are useful equivalence signals for the captured public catalog fields only; they do not prove grants, effective authorization, function bodies, trigger behavior, Storage or runtime behavior.

## 4. Public executable objects differ

| Fingerprint | Production | Staging |
|---|---|---|
| Public functions | 366 / `ed8c7b62f2397b1f77fed9d856ccbd05` | 376 / `6a569249bd3f36f40d81274e0e5ced03` |
| Public triggers | 113 / `c7156404bfda27e376329e9afb45d913` | 115 / `feb338a02f1a5470dba5dc07227f26c8` |
| Public indexes | 1,561 / `d98270edadaf9a70647e1b3ca676d94a` | 1,561 / `8b5f1b1f00791d945392be6d7f12be45` |
| Public constraints | 1,807 / `0b2e3ac0b91fe1c5acf93a4e1f002b6c` | 1,807 / `4d39f62e4e55d0d2528df2c7556e8942` |

A differing hash means at least one item in the fingerprinted set differs; it does not by itself identify the defect. Equal counts do not imply equal definitions. Exact object-level diffs are still required for:
- functions (signature, body, owner, SECURITY DEFINER, search_path, EXECUTE ACL);
- triggers (function binding, timing, events, condition and enabled state);
- indexes (definition, uniqueness, predicates, validity);
- constraints (definition, validation state and deferrability);
- grants/default privileges and RLS policies including effective roles.

The earlier Phase 00 audits already identified critical Staging grant/parity concerns and a Staging Storage policy concern; this audit does not clear those risks.

## 5. Extension parity

Installed extensions returned by the live extension catalog:

- Production: `pg_cron`, `pg_net`, `pg_stat_statements`, `pgcrypto`, `plpgsql`, `supabase_vault`, `uuid-ossp`.
- Staging: `pg_stat_statements`, `pgcrypto`, `plpgsql`, `supabase_vault`, `uuid-ossp`.

**Missing in Staging relative to Production:** `pg_cron` and `pg_net`.

These matter because Production has scheduled database jobs and asynchronous HTTP capability. Their absence can make workflow/notification/scheduler behavior materially different. This is a parity observation, not a recommendation to enable extensions without a reviewed dependency and permission plan.

## 6. Interpretation

1. Public table names, public columns and public RLS policy definitions are aligned for the fingerprinted fields.
2. The public function, trigger, index and constraint catalogs are not aligned.
3. The non-system schema inventories differ materially (118 vs 24), and all-schema table/column counts differ.
4. The migration ledgers have no shared versions. Treating Staging as a normal lagging replica of Production would be incorrect.
5. The missing `pg_cron`/`pg_net` extensions may prevent scheduler and HTTP integration parity.
6. Neither migration count nor table count is a sufficient release criterion.

## 7. Safe remediation sequence

**B1 — Establish provenance (BLOCKED):** identify the Staging bootstrap source and whether selective migrations were intentionally applied. Preserve both ledgers as evidence.

**B2 — Produce exact object-level diffs:** enumerate schemas, relations, columns, types/defaults, indexes, constraints, triggers, views, functions, grants, default ACLs, RLS policies, Storage policies, extensions and cron jobs. Include function bodies/ACLs and trigger dependencies.

**B3 — Classify each delta:** intended environment difference, safe missing object, stale/legacy object, security-sensitive difference, data dependency, or unknown. No automatic “Production wins” assumption.

**B4 — Review a forward-only reconciliation plan:** source-controlled migration files, dependency order, idempotency, lock/runtime impact, rollback/compensation and explicit approval. Never use reset/rebase/merge as a shortcut.

**B5 — Apply only to Staging after approval:** backup/restore point and rollback plan, one reviewed migration at a time, verify each change with catalog fingerprints and targeted tests. No Production writes.

**B6 — Re-run parity and test boundary checks:** prove the Staging project identity, deployed website commit, auth redirect settings, grants, policies, reference data, extension/runtime parity and isolated test identities before synthetic tests.

## 8. Gate B checklist

| Check | Result |
|---|---|
| Live migration manifests collected | PASS |
| Shared migration version lineage | FAIL — zero shared versions |
| Public table names | PASS — identical fingerprint |
| Public column definitions | PASS — identical fingerprint |
| Public RLS policy definitions | PASS — identical fingerprint |
| Public function definitions | FAIL — different count/fingerprint |
| Public trigger definitions | FAIL — different count/fingerprint |
| Public index definitions | FAIL — different fingerprint |
| Public constraint definitions | FAIL — different fingerprint |
| All-schema inventory | FAIL — table/column/schema counts differ |
| Extension parity | FAIL — pg_cron and pg_net absent in Staging |
| Exact object-level diff and provenance | NOT TESTED |
| Approved forward-only reconciliation | BLOCKED |
| Synthetic user/authenticated tests | BLOCKED |

## Safety statement

Only project metadata, migration manifests, extension inventory and read-only PostgreSQL catalog queries were used. No table rows were modified; no migration, DDL, DML, reset, rebase, merge, deployment, Auth change, Storage change, secret read, provider request or synthetic identity was created.

**Disposition: Gate B BLOCKED. Phase 00 remains IN PROGRESS; KRIM is not release-ready.**
