# Step 37 — Historical migration source recovery assessment (2026-11-13)

## Scope
Read-only investigation of GitHub migration-path history, available branches, and the production Supabase migration ledger. No migration SQL was reconstructed or applied.

## Findings

### Production migration history begins before the tracked repository migration history
- Production's earliest recorded applied migration is `20260929043657_add_global_partner_lifecycle`.
- Production has 36 applied migration entries dated September 2026, 127 dated October 2026, and 262 dated November 2026 (425 total).
- The earliest commit returned by GitHub's history for `supabase/migrations` is `09f1e494cc6f3fa6e2dc3ff1c79e0ee92a54ca46` on 2026-10-16. Its tree contains only `20261016120808_krim_user_app_backend_modules.sql` under `supabase/migrations/`.
- The current `main` tree contains 263 migration files; PR #65 contains 265. The PR branch adds the two 2026-11-13 candidate migrations.
- Sampled historical/active branches did not reveal an archive containing the missing production SQL history. The `strategy/future-ready-foundation` branch contains 257 files; `launch/partner-direct-no-freight-checkout` contains 263; `fix/platform-admin-canonical-schema` contains 26; the sampled lifecycle/audit branches contain zero or two migration files.

### Interpretation
The Git repository's tracked migration history starts on 2026-10-16, while the live production ledger starts on 2026-09-29. The 36 September entries are therefore outside the earliest tracked migration-path commit found in this repository. The remaining missing production versions may have been created/applied from an earlier source, generated elsewhere, or omitted from the repository history. The current evidence does not identify their exact SQL bodies or prove their source.

A production schema dump can describe the current schema, but it cannot recreate the exact historical SQL and ordering of every migration. Migration version/name metadata is not a substitute for original SQL.

## Recovery status
- GitHub repository and sampled branches: searched; no complete missing-history archive found.
- Production ledger: 425 version/name records available for reconciliation.
- Exact SQL for all 425 production-applied migrations: not recovered.
- Full schema-only export: still not run; separate from historical SQL recovery.
- Staging: still empty and not a valid replay target.

## Required source to continue
Recover the original September–October migration source from the environment that created/applied it (for example, the original development computer/repository backup, prior private repository, release archive, or deployment artifact). Preserve original filenames, contents, order, and checksums. Do not regenerate SQL from the current schema and label it as historical migration SQL.

If no original source survives, the safe fallback is a separately reviewed, schema-baseline reconstruction from a verified production schema export, followed by a new controlled migration history for a fresh non-production environment. That is a deliberate baseline strategy—not restoration of the missing 425 historical scripts—and must be reviewed before any staging reset/recreation.

## Safety
No production or staging SQL executed; no project branch created/reset; no migration history changed; no secrets accessed; no merge or deployment performed.

**Decision: historical migration recovery is blocked pending the original source archive or explicit approval of a separately designed baseline-reconstruction plan.**
