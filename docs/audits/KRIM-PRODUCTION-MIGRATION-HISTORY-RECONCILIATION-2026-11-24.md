# KRIM production migration-history reconciliation — 2026-11-24

## Scope

Read-only comparison of the Supabase production migration ledger (`supabase_migrations.schema_migrations`, via the Supabase migration listing) against every `supabase/migrations/*.sql` file on GitHub `main` at the time of inspection.

No migration repair, schema change, migration execution, or history mutation was performed.

## Exact inventory

| Measure | Result |
|---|---:|
| Production migration ledger rows | 561 |
| Unique production versions | 561 |
| Repository SQL migration files | 368 |
| Unique repository migration versions | 353 |
| Exact version matches | 82 |
| Production versions with no same-version repository file | 479 |
| Repository versions absent from production ledger | 286 |
| Repository duplicate-version groups | 13 |
| Repository duplicate files beyond unique versions | 15 |
| Same-name/different-version entries (name matches with a different timestamp; not necessarily unique migration names) | 209 |

Production ledger range: `20260929043657` through `20261124071550`.

Repository migration file range: `20261016120808` through `20261124120000`.

## Important interpretation

The counts above are **version-ID comparisons**, not a list of migrations safe to replay.

The name-based comparison shows that many apparent repository-only versions are already represented in production under a different timestamp. Examples:

| Migration name | Repository version | Production version |
|---|---|---|
| `enforce_payment_provider_reference_idempotency` | `20261017120000` | `20261017054157` |
| `krim_warehouse_core_operations` | `20261024080000` | `20261024081234` |
| `driver_carrier_invitation_and_membership_workflow` | `20261104190000` | `20261104123850` |
| `admin_driver_licence_expiry_control` | `20261123100000` | `20261123045209` |
| `krim_report_operational_exception` | `20261124120000` | `20261124071550` |

There are also repository duplicate timestamp groups. A migration ledger keyed by version cannot safely distinguish multiple different SQL files carrying the same version. The 13 duplicate groups must be resolved in repository history with a reviewed, unique version strategy before a clean replayable baseline can be produced.

The repository currently has 77 migration names not found in the production ledger by name, while production has 270 names not found in the repository by name. These need file/content-level comparison and schema-state evidence; they must not be blindly marked applied or replayed.

## Reconciliation procedure — required before database DDL

1. Freeze new production DDL/migration application while the baseline is reconstructed.
2. Export the complete production migration ledger and retain it as immutable evidence.
3. Build a three-way manifest: production version/name, repository filename/version/name, and SQL-content hash.
4. For each same-name/different-version item, compare SQL content hashes and resulting live schema objects. Do not infer equivalence from names.
5. For production-only migrations, recover the exact SQL from trusted historical commits, deployment artifacts or backups; if unavailable, reconstruct from audited schema only with explicit review.
6. For repository-only migrations, determine whether each is unapplied, superseded, renamed, or already represented by a different production migration.
7. Resolve duplicate repository version IDs by assigning unique new versions only where safe and updating references/CI tooling. Never rewrite the production ledger simply to make counts match.
8. Generate a clean baseline and replay it into a disposable Supabase project/branch. Compare resulting schema, function definitions, grants, RLS policies, triggers, indexes and extensions against production.
9. Only after parity is proven, add notification reliability changes as new forward-only migrations, test in staging, then schedule a controlled production rollout.

## Notification work relationship

The deployed notification Edge Function sources have now been captured in:
- `supabase/functions/krim-notification-retry-worker/index.ts`
- `supabase/functions/krim-notification-provider-adapter/index.ts`

Those source snapshots were verified byte-for-byte against the active deployed `index.ts` files at capture time. This does not correct the notification database RPCs or make customer/partner delivery production-ready.

The notification database remediation remains blocked until the migration baseline and caller/grant inventory are verified. Required fixes remain: lease expiry/reclaim, unique per-claim fencing, idempotent delivery-attempt creation, truthful accepted-vs-delivered states, bounded retries/dead-lettering, provider callback verification, and real customer/partner provider dispatch.

## Safety decision

**NO-GO for applying notification DDL or migration-history repair directly to production at this stage.** The mismatch is a source-of-truth problem requiring a controlled baseline reconstruction. No production changes were made during this audit.
