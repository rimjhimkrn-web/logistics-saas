# Step 36 — Migration inventory reconciliation and staging baseline safety (2026-11-13)

## Scope
Read-only comparison of the Supabase migration history in production and staging against the migration files in PR #65 head commit `e7b199956c73c5eda39e18b2cb08f9755d377890`. No database or repository source changes were made during the comparison.

## Verified counts

| Source | Count |
|---|---:|
| Production applied migration history | 425 |
| Staging applied migration history | 0 |
| Migration SQL files in PR branch | 265 |
| Version IDs present in both production history and repo | 64 |
| Version IDs present in repo but absent from production history | 201 |
| Production history version IDs absent from repo | 361 |
| Duplicate migration version IDs in repo | 12 |

All 64 overlapping version IDs also have matching migration names.

## Critical findings
1. The repository migration directory is not a complete archive of production's applied migration history: 361 applied production version IDs have no corresponding SQL file in this branch.
2. There are 201 repository migration files whose version IDs are not recorded as applied in production.
3. The repository has 12 duplicate version IDs across multiple SQL files. Examples include `20261104190000`, `20261104191500`, `20261104234500`, and `20261106190000`. A migration history keyed by version cannot safely represent multiple distinct files with the same version.
4. Staging has no applied migrations. It is not a safe migration validation environment in its current state.

## Interpretation
This is material migration-history drift, not a routine missing-migration queue. The counts alone do not prove which SQL files produced the live production objects: some historical migrations may have been applied through a different source, renamed, squashed, or omitted from the repository. The 201 repository-only files may include migrations already represented by other version IDs or changes that were never applied. No automatic inference is safe.

## Required recovery plan — do not replay blindly
1. Preserve a verified, encrypted, schema-only production export and checksum outside the database.
2. Obtain the canonical source/history for every production-applied version (all 425), including any historical migration files stored elsewhere or prior commits/releases.
3. Build a reconciliation ledger with one row per production version: version, exact filename, source commit, SQL checksum, object scope, and whether an equivalent SQL file exists in the current repo.
4. Resolve the 12 duplicate repository version IDs by reconstructing intended chronological history from Git commits and deployed history. Do not simply rename already-applied migrations or edit their contents.
5. Classify all 201 repo-only files as already represented, intentionally superseded, pending, or obsolete; do not apply them until reviewed.
6. Only after the ledger is complete, establish a disposable non-production validation environment using a controlled baseline. Test migrations in sequence and run schema/security checks before considering any production action.

## Supabase CLI v3 safety note
Supabase CLI v3 database commands target the local stack by default; hosted operations require explicit `--remote`. Hosted mutations require explicit confirmation and unattended hosted changes require `--yes`. Never rely on defaults or add `--yes` to a production command without a separately approved change plan.

## Result
**Staging baseline is blocked.** Do not create/rebase/reset a Supabase development branch, replay migrations, apply pending migrations, or merge PR #65 as a substitute for reconciliation. This step was read-only; no secrets, schema, data, functions, or production settings were changed.
