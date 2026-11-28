# KRIM Fast-Track Day 01 — Staging Migration Ledger Reconciliation
Date: 2026-11-28
Branch: `staging/phase00-env-isolation`
Branch head inspected: `c1256ba00fc214e5a46d7395b878f9a7b78aa3cc`
Staging project: `qrpcivhdxobiaofppbkl`
Production: not accessed or changed

## Outcome
**BLOCKED — repository migration files and the live Staging migration ledger are not a replayable, one-to-one history.** A local reset or migration push must not be attempted until the history is reconciled and a clean baseline is established.

## Read-only evidence
The complete branch tree was inspected (2,607 entries; response not truncated). The Supabase migration list was retrieved from the Staging project.

| Measure | Result |
|---|---:|
| SQL files under `supabase/migrations/` | 499 |
| Unique 14-digit migration versions represented by those files | 467 |
| Duplicate-version groups | 28 |
| Extra files sharing an already-used version | 32 |
| Staging migration ledger entries | 163 |
| Ledger versions with an exact filename-version match in the repository | 3 |
| Ledger entries with no exact matching filename version | 160 |
| Repository migration files whose version is absent from the Staging ledger | 496 |

The comparison is by the 14-digit version prefix only. A matching version is not proof that the SQL content is identical or that a local replay is safe.

## Critical findings
1. **Duplicate migration versions:** 28 version groups have more than one SQL file. Supabase migration history is version-keyed; multiple different SQL files sharing one version cannot be treated as a deterministic migration sequence. Examples include:
   - `20261025150000`: two different files.
   - `20261104190000`: four different files.
   - `20261105153000`: two different files.
   - `20261127077000`: two different files.
   - `20261127190000`: three different files.
2. **Staging ledger/file mismatch:** only 3 of 163 Staging ledger versions exactly match a repository filename version. The remaining 160 ledger versions have no exact filename-version match in this branch. This may reflect a separate migration naming/import history, but it must be reconciled rather than guessed.
3. **Large unapplied/unknown set:** 496 repository migration files have version prefixes not present in the current Staging ledger. This does not mean they are safe or intended to be applied. Some may already be represented by imported schema state, some may be historical, and some may be genuinely unapplied. SQL content and schema state must be compared before any action.
4. The Staging ledger currently lists 163 entries, from `20261117135137` through `20261127093019`. It does not itself provide a complete clean baseline for replaying the 499-file branch history.

## Safety decision
Do not:
- run `supabase db reset` or replay all 499 files;
- run `supabase db push` against Staging or Production;
- mark migrations as applied or repair the ledger by hand;
- rename or retimestamp migration files without a reviewed dependency/order plan;
- invoke the existing schema-bootstrap workflow as a substitute for a local test harness.

No migration, SQL DDL, grant, fixture, RPC, workflow, deployment, or database mutation was performed.

## Required recovery sequence
1. Preserve a read-only export of the current Staging schema and migration ledger using an owner-approved process; exclude application data, Auth users, Storage objects, Vault secrets and credentials.
2. Inventory all duplicate-version groups and compare each file's SQL content and Git history. Decide whether duplicate files are separate operations that need unique version numbers, already-applied equivalents, obsolete files, or conflicting changes.
3. Reconcile all 163 Staging ledger entries against the repository and any retained migration archive. Never infer equivalence from similar names alone.
4. Identify the exact schema baseline that corresponds to the Staging database at the ledger's first recorded version.
5. Produce a reviewed, deterministic migration chain in a separate recovery branch; validate it against a disposable database before proposing any Staging change.
6. Only after the chain is deterministic, build the local Partner A/B authorization tests and prepare the capability read RPC migration.

## Current gate
- Migration files: **499**.
- Unique versions: **467**.
- Duplicate-version groups: **28**.
- Exact Staging ledger/file version matches: **3 of 163**.
- Safe clean replay: **BLOCKED**.
- Partner A/B authenticated tests: **NOT RUN**.
- Capability list RPC: **DESIGN ONLY; NOT CREATED**.
- Phase 00: **OPEN — NOT APPROVED**.
- Production: **NOT ACCESSED OR CHANGED**.
