# KRIM Historical Migration Source Recovery — 2026-11-07

## Branch-history search

Following the migration-ledger mismatch, several retained Git branches were inspected for historical `supabase/migrations` directories.

| Branch | Migration files found | Result |
|---|---:|---|
| `krim/global-lifecycle-foundation` | 2 | Only customer checkout and payment-order binding migrations |
| `krim/global-operations-audit` | 19 | Partial history, ending 2026-10-20 |
| `fix/platform-admin-canonical-schema` | 26 | Partial history, ending 2026-10-24 |
| `fix/partner-assignment-rbac` | 7 | Partial history, ending 2026-10-17 |
| `main` | 257 | Same incomplete current migration directory |
| `strategy/future-ready-foundation` | 257 | Same incomplete current migration directory |

Other inspected branches did not contain a resolvable `supabase/migrations` directory.

The retained branches therefore do not contain the complete historical migration source needed to replay all 422 production ledger entries. They are useful historical references but are not a safe bootstrap source.

## Decision

**Do not replay any of these partial directories into staging.** Do not fabricate missing migrations from current production state by hand. Do not copy production rows or secrets.

## Safest next source of truth

Obtain a schema-only PostgreSQL dump from the production database using the Supabase CLI / `pg_dump` from a trusted local environment or a secured CI runner. The export must be reviewed to exclude data and secrets. Use a pinned PostgreSQL client version compatible with the production server.

The export should capture application-owned schema objects (types, tables, constraints, indexes, sequences, functions, triggers, views, policies and grants) while deliberately excluding Supabase-managed `auth`, `storage`, `realtime`, `vault` internals and all row data. Extension prerequisites and ownership/grant statements must be reviewed rather than blindly replayed.

After obtaining the dump:
1. Store it only in a private, access-controlled location; never commit secrets or data.
2. Scan for literal credentials, tokens, webhook secrets, Vault rows, and data statements.
3. Split into dependency-ordered, reviewable migrations.
4. Apply only to isolated staging.
5. Compare catalog metadata and run advisor checks.
6. Add synthetic test identities and fixtures only after schema verification.

## What is safe to do before the dump exists

Continue static mobile checks and review app repositories / RPC contracts. Keep all operational writes disabled in mobile apps. Staging remains isolated and incomplete; production remains unchanged.
