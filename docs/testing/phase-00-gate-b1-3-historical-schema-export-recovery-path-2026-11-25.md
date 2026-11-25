# Phase 00 — Gate B1.3 Historical migration-recovery artifacts and schema-export path review

**Date:** 2026-11-25  
**Scope:** Read-only review of historical migration-recovery documents, schema-export workflow, prior export result, and migration crosswalks found in the repository's migration-audit branch.  
**Branch for evidence:** `audit/migration-baseline-collision-inventory-2026-11-24`  
**No Production or Staging database writes, SQL execution, workflow dispatch, artifact creation, secret access, or deployment was performed.**

## Executive finding

**A prior migration recovery path already exists and is more concrete than the latest B1 investigation had surfaced.** The repository contains a guarded GitHub Actions workflow for an encrypted, schema-only Production export, operator instructions, and two historical successful export records.

The most recent documented export was:
- Workflow run: `43793099331`
- Artifact: `krim-schema-export-encrypted`
- Artifact ID: `14193475858`
- Created: `2026-11-16T02:37:49Z`
- Expired: `2026-11-17T02:37:47Z`
- Encrypted archive SHA-256: `345c4d8db112eb964203b845319aacd0e9fd5b95a6d8e032d2f06ad204a6326e`
- Encrypted SQL SHA-256 recorded in manifest: `8d0ecc5e254341547b91cde78898e94e17cc14ab32d0d4b1adc0968efdcfd42d`

The archive was reported as downloaded and checksum-verified, but **not decrypted** because the passphrase was stored as a GitHub Actions secret unavailable to the audit session. It has expired from Actions artifact retention. The older 2026-11-09 export artifact also expired on 2026-11-10.

Therefore, the next reliable source is not a guessed migration replay: it is a newly generated, reviewed schema-only export, created by an authorized operator using the existing workflow and private secrets. This provides a path to reconstruct a deterministic Staging baseline, but it does **not** recover the exact historical SQL body for every Staging ledger row.

## 1. Historical repository findings

### 2026-11-07 source-recovery assessment

`docs/KRIM-HISTORICAL-MIGRATION-SOURCE-RECOVERY-2026-11-07.md` records an earlier branch survey:
- `krim/global-lifecycle-foundation`: 2 migrations
- `krim/global-operations-audit`: 19 migrations
- `fix/platform-admin-canonical-schema`: 26 migrations
- `fix/partner-assignment-rbac`: 7 migrations
- `main` and `strategy/future-ready-foundation`: 257 migrations at that time

That assessment concluded the retained branches were not a complete replay source and explicitly warned against replaying partial directories or fabricating missing SQL.

### 2026-11-07 Staging baseline assessment

`docs/KRIM-STAGING-MIGRATION-RECONCILIATION-2026-11-07.md` describes the Staging project at that time as having zero application tables, public routines, and public RLS policies, with no application schema applied. This is a **historical snapshot**, not a description of the current 2026-11-25 Staging project, whose live catalog now contains 391 public tables and 34 migration ledger records.

### 2026-11-24 Production migration reconciliation

`docs/audits/KRIM-PRODUCTION-MIGRATION-HISTORY-RECONCILIATION-2026-11-24.md` reports:
- 561 Production ledger rows / 561 unique versions
- 368 current repository migration files
- 353 unique repository migration versions
- 82 exact version matches
- 479 Production versions without a same-version repository file
- 209 shared unique names with different version IDs
- 270 Production migration names absent from the current repository
- 13 duplicate repository version groups

The report correctly warns that name matches do not prove SQL equivalence and version mismatches do not prove that an operation is absent from the live schema.

## 2. Existing secure export workflow

Workflow file: `.github/workflows/krim-schema-export.yml`

It is a manually dispatchable GitHub Actions workflow and requires two existing repository secrets:
- `KRIM_PRODUCTION_DB_URL`
- `KRIM_SCHEMA_EXPORT_PASSPHRASE` (minimum 24 characters)

The workflow:
1. Validates the PostgreSQL URI without printing credentials.
2. Installs Supabase CLI 3.0.0.
3. Runs `supabase db dump` for application schemas `public,private,krim_internal,graphql_public`.
4. Scans for executable top-level `INSERT INTO` and `COPY ... FROM stdin;` statements, with scanner self-tests.
5. Scans for several common credential formats.
6. Encrypts the SQL using OpenSSL AES-256-CBC with PBKDF2 and 600,000 iterations.
7. Uploads only ciphertext and a checksum manifest, with one-day artifact retention.

The workflow does not automatically apply the export to Staging.

### Important limits of the workflow

- The scan is a safeguard, not a proof that every secret or sensitive literal is absent. Manual offline review remains mandatory.
- Exported function bodies and configuration literals can still contain sensitive material.
- The export intentionally excludes Supabase-managed schemas such as Auth, Storage, Realtime, and Vault internals. It is an application-schema export, not a full project clone.
- Extension prerequisites, ownership, grants, default privileges, and role dependencies need a separate reviewed treatment.
- The export is from Production, not a recovery of the exact historical Staging SQL bundle.

## 3. Historical export evidence

### 2026-11-09 run
`docs/KRIM-SECURE-SCHEMA-EXPORT-RESULT-2026-11-09.md` records successful workflow run `42619599274`, artifact ID `13676480195`, which expired on 2026-11-10.

### 2026-11-16 run
`docs/audits/KRIM-PRODUCTION-MIGRATION-CROSSWALK-AND-EXPORT-VERIFICATION-2026-11-16.md` records successful workflow run `43793099331`, artifact ID `14193475858`. The archive and encrypted SQL checksums were verified. The artifact expired on 2026-11-17 and was not decrypted.

Neither historical record establishes that the export was imported into the current Staging project. The 2026-11-09 result explicitly says no schema was applied and Staging then had zero application tables. The 2026-11-16 crosswalk report says the export was acquired and integrity-checked, not decrypted or reconciled.

## 4. Recommended next controlled path

1. Authorized operator verifies that the two existing GitHub Actions secrets are still configured and current. Do not reveal them in chat or logs.
2. Authorized operator manually dispatches the existing encrypted schema-export workflow on a reviewed branch/commit. This is a read-only Production export but creates a sensitive encrypted artifact; do not dispatch automatically from this audit.
3. Download the new artifact promptly because retention is one day; verify `SHA256SUMS`.
4. Decrypt only in a private trusted environment using the stored passphrase. Never upload or commit plaintext SQL.
5. Manually inspect the export for secrets, unsafe ownership/grants, role assumptions, extension dependencies, and objects that must not be imported.
6. Produce a sanitized object manifest and SQL content hashes; do not include plaintext function bodies or secret literals in public QA reports.
7. Reconstruct a deterministic baseline in an isolated disposable Staging environment only after explicit authorization. Preserve the existing Staging environment and its ledger as evidence; do not reset it.
8. Compare the reconstructed catalog with both Production and current Staging, including table/column definitions, constraints, indexes, triggers, function signatures/definitions, RLS policies, grants, extensions, and relevant non-public schemas.
9. Separately recover exact historical SQL for unmatched Staging ledger entries where possible. A Production schema dump cannot prove which exact SQL created Staging's current objects.

## 5. Gate B1.3 result

| Check | Result |
|---|---|
| Historical migration recovery documentation found | PASS |
| Existing guarded schema-export workflow found | PASS |
| Historical successful export run verified in documentation | PASS |
| Historical export checksum recorded | PASS |
| Historical artifact still available (2026-11-25) | FAIL — expired |
| Historical export decrypted and reviewed | NOT TESTED |
| Existing workflow secrets verified | NOT TESTED |
| New export dispatched | NOT TESTED — requires authorized operator |
| Exact historical Staging migration SQL recovered | BLOCKED |
| Safe Staging baseline reconstruction authorized | BLOCKED |

## Final disposition

**B1 remains BLOCKED.** The repository has a previously proven, guarded export mechanism, so the next action should be an operator-controlled fresh export and offline review—not an attempt to replay the incomplete migration directory. This will support schema baseline reconstruction but will not, by itself, close the provenance of every Staging ledger row.

No Production or Staging database writes, migration execution, migration-ledger edits, resets, deployments, Auth operations, provider calls, secret reads, or workflow dispatch occurred during this investigation.
