# Step 48 — Migration-history recovery plan and reconciliation ledger specification

Date: 2026-11-13
Branch: website/global-launch-readiness
Scope: define an evidence-based recovery method for the production migration history drift. No migration or database changes.

## Verified baseline carried forward

- Production Supabase ledger: 425 applied migrations.
- Current PR branch inventory: 265 migration SQL files.
- Only 64 migration version IDs are common between the production ledger and current branch inventory.
- 361 production-applied versions have no same-version SQL file in the current repository inventory.
- 201 repository migration files have version IDs absent from the production ledger.
- 12 duplicate version IDs exist in the repository migration inventory.
- Prior source-recovery search did not locate a complete historical migration archive.
- Production schema export has not run; no encrypted artifact/checksum is available.
- Separate staging remains empty and cannot validate the current migration sequence.

These are inventory mismatches, not proof that 361 live schema changes are missing or that 201 repository files are pending. A migration may have been renamed, squashed, applied under a different version, generated from another branch, or omitted from the current source history.

## Reconciliation ledger required

Create a controlled CSV/JSON ledger with one row per production-applied version and a separate row for every repository-only migration file. Required fields:

1. production migration version and recorded name;
2. candidate repository filename(s), including duplicate candidates;
3. exact source commit and branch for each candidate;
4. Git blob SHA and locally calculated SHA-256 of the exact SQL bytes;
5. source provenance classification: exact / equivalent / renamed / superseded / unavailable / unresolved;
6. evidence for equivalence (object-level diff, function body, trigger, policy, grant, extension or other object);
7. dependencies and required application order;
8. risk classification and reviewer;
9. final disposition: baseline-only / represented-by-other-version / pending / obsolete / do-not-run;
10. approval reference and date.

Never infer equivalence from filename similarity alone. Git blob SHA is useful provenance but should not be confused with a SHA-256 digest of file contents. Preserve exact original bytes and commit IDs.

## Duplicate-version handling

For each of the 12 duplicate version IDs, retain all candidate files and compare their Git history, introducing commits, content hashes and deployed-object evidence. Do not delete, rename, reorder or edit historical files merely to make the CLI inventory appear clean. If two distinct SQL bodies share one version ID, stop and resolve which body (if either) is represented in production before generating a new migration sequence.

## Two-track recovery decision

**Track A — exact historical source recovery:** search original developer machines, secure backups, CI artifacts, Git refs, forks and deployment records for the missing 361 migration SQL bodies and source commits. Record custody and checksums. This is preferred.

**Track B — object-mapped baseline reconstruction:** if exact history cannot be recovered, obtain an encrypted schema-only production export and map every live object to a reviewed canonical definition. Record that this is a reconstructed baseline, not a recovered historical migration archive. Do not fabricate old migration files or mark them as applied just to suppress drift.

## Safe next sequence

1. Owner verifies and manually runs the reviewed encrypted schema-only export workflow; retain the checksum and passphrase separately.
2. Independently verify export artifact integrity and ensure no application data is included.
3. Retrieve and preserve original migration sources/history where available.
4. Populate the reconciliation ledger; resolve every duplicate and classify every production-only and repo-only version.
5. Have a second reviewer approve the object mapping and a disposable non-production baseline plan.
6. Restore only schema to a disposable test environment and verify extensions, roles/grants, RLS, policies, functions, triggers, views and sequences.
7. Test new partner-provisioning code and migration there; only then prepare a production change plan for explicit approval.

## Prohibited shortcuts

- Do not run `supabase db push`, `migration repair`, or a bulk replay against production or current staging to make version counts match.
- Do not mark unknown migrations applied or delete production ledger rows.
- Do not treat a schema dump as a full project backup.
- Do not copy production customer, partner, financial, identity or shipment data into test.
- Do not make partner provisioning changes in production before the baseline and negative authorization tests are approved.

## Step 48 verdict

**RECOVERY METHOD DEFINED; EXECUTION BLOCKED** pending verified encrypted schema export and historical source evidence. This step creates the ledger specification only. No migration files, database objects, migration ledger rows, secrets, projects, branches or settings were changed.
