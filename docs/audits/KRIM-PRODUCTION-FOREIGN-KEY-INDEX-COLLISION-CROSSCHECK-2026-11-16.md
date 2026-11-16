# KRIM Production Foreign-Key Index Collision Crosscheck
**Date:** 16 November 2026  
**Scope:** Read-only comparison of two repository migrations sharing the logical name `add_missing_foreign_key_indexes` against live PostgreSQL index catalog and migration-history metadata. No DDL or data changes.

## Executive result
Both distinct index sets are present in production. Every index queried from the two repository files was found in the expected schema/table with `indisvalid=true` and `indisready=true`. Production migration history records corresponding entries under different version/name metadata than the repository filenames.

This is useful evidence that the index effects exist, but it does not prove that the repository migration files themselves were applied verbatim or that the overall migration history is reconciled.

## Production migration history
A read-only query of `supabase_migrations.schema_migrations` returned:
- Version `20261104163805`, name `20261104235000_add_missing_foreign_key_indexes`
- Version `20261115061923`, name `add_missing_foreign_key_indexes_nov15`

Neither production row uses the repository timestamp exactly as its version value. This is another version/name crosswalk difference; do not alter history to make it look aligned.

## Catalog verification
### Earlier repository file: `20261104235000_add_missing_foreign_key_indexes.sql`
All 12 expected indexes were present and valid/ready:
- 9 public indexes covering corridor compliance, country packs and market activation event/control references;
- 2 private indexes on `private.krim_driver_invitations(accepted_by)` and `(invited_by)`;
- 1 public index on `krim_driver_verification_documents(organization_id)`.

### Later repository file: `20261115072000_add_missing_foreign_key_indexes.sql`
All 27 expected indexes were present and valid/ready across capacity reservations, claims, customs broker assignments/events/licences, customs document submissions/events, network lanes, partner compliance evidence/reviews and refund requests/events.

The catalog query checked index schema, table schema/name, `pg_get_indexdef`, `pg_index.indisvalid` and `pg_index.indisready`. Every returned definition matched the expected index name, target table and ordered column list from the corresponding repository SQL.

## Interpretation and limitation
- The two migration files are not duplicates; they create different index sets.
- The live index effects exist and are currently marked valid and ready.
- Production migration history uses renamed/re-timestamped entries.
- A matching index definition is not proof of the source migration file, deployment commit, or complete migration order. Indexes may have been created by equivalent SQL in a different migration or manually.
- This check does not assess index usage, write overhead, duplicate equivalent indexes under other names, or whether every foreign key in the database is optimally indexed.

## Safety decision
No corrective action is recommended for these index sets at this stage. Do not replay or rename either migration. Keep both classified as **production effect observed; migration provenance requires semantic crosswalk** until the sanitized production manifest and remaining catalog comparisons are complete.

## Sanitized-manifest workflow status
At the latest repository Actions listing, no run for `KRIM sanitized production schema manifest` had appeared. The encrypted export artifact was available, but manual dispatch was still outstanding. The operator guide now records:
- source run ID: `43793099331`
- artifact ID: `14198261776`

No production SQL, grants, policies, functions, triggers, data or migration-history rows were changed.
