# KRIM Production Migration Crosswalk & Encrypted Export Verification
**Date:** 16 November 2026  
**Production project:** `ebltviniygljwwseplph`  
**Repository branch:** `main`  
**Repository commit inspected:** `c14c98065725f8ef8de7271100e3c2fd2c8ca1de`  
**Method:** Read-only Supabase migration metadata, GitHub repository tree, GitHub Actions artifact metadata and local archive/checksum verification. No database or repository migration was applied.

## Executive result
The migration mismatch is confirmed, and the detailed crosswalk reveals more than simple missing timestamps. Many migrations have the same logical name but different timestamps; hundreds of production migration names have no corresponding file in the current repository; and some repository migration names are not recorded in production. A timestamp-only comparison overstates some differences, but name matching still leaves a substantial unresolved gap.

**Do not run `supabase db push`, repair/baseline migration history, replay migrations, squash migrations or apply corrective DDL until the SQL source is reconciled.**

## Counts
| Measure | Count |
|---|---:|
| Production migration-history rows | 558 |
| Repository SQL migration files on main | 363 |
| Unique repository migration timestamps | 348 |
| Exact version + name matches | 82 |
| Repository names also present in production (any timestamp) | 288 |
| Same logical name, different timestamp | 206 |
| Repository migration names absent from production history | 75 |
| Production migration names absent from repository | 270 |
| Repository duplicate-timestamp groups | 13 |
| Repository duplicate-name groups | 3 |

The 13 duplicate-timestamp groups represent 15 extra files beyond the 348 unique timestamps. Duplicate logical names are:
- `enforce_active_markets_for_shipment_booking`
- `seed_country_localization_and_units`
- `add_missing_foreign_key_indexes`

A migration name match does not prove SQL-body equivalence. A version/name mismatch does not prove that the operation is absent from the live schema. Only source/body and live-schema comparison can establish that.

## Migration history boundary
- Production latest migration: `20261115231834 require_warehouse_handover_before_leg_dispatch`.
- Repository latest migration on main: `20261116028000_require_warehouse_handover_before_leg_dispatch.sql`.
- These share the logical name but not the version timestamp.
- Production has a recorded exact-leg sourcing sequence on 15 November; the repository has a separately timestamped sequence on 16 November. Do not infer that the repository copies are safe to replay.

## Encrypted schema-only export
GitHub Actions run: `43793099331`  
Artifact: `krim-schema-export-encrypted`  
Artifact ID: `14193475858`  
Created: `2026-11-16T02:37:49Z`  
Expires: `2026-11-17T02:37:47Z`  
Archive SHA-256 (matches GitHub artifact digest):  
`345c4d8db112eb964203b845319aacd0e9fd5b95a6d8e032d2f06ad204a6326e`

Archive contents:
- `krim-schema-export.sql.enc`
- `SHA256SUMS`

The encrypted SQL file's SHA-256 was independently recomputed and matched the included `SHA256SUMS` entry:
`8d0ecc5e254341547b91cde78898e94e17cc14ab32d0d4b1adc0968efdcfd42d`

**Important limitation:** The encrypted artifact has been downloaded and checksum-verified, but not decrypted. The decryption passphrase is a GitHub Actions secret and is not available to this audit session. No secret was requested, displayed or copied into chat.

## Required recovery sequence
1. Preserve the verified encrypted artifact before its short retention expires. Keep it private; do not publish the decrypted schema.
2. Decrypt only in a trusted local environment or a controlled GitHub Actions job using the existing repository secret. Never put the passphrase in source, workflow logs, chat or command-line arguments visible to process listings.
3. Validate the SQL dump is schema-only and contains no data statements or credentials.
4. Generate a sanitized manifest of live tables, columns, constraints, indexes, triggers, policies, grants, functions, function definitions/hashes, views and extensions.
5. Build a migration crosswalk keyed by both logical migration name and timestamp. Record duplicate timestamp/name groups and the 206 timestamp shifts.
6. Compare repository migration SQL with recovered historical source and live object definitions. For production-only migration names, recover the original SQL from trusted CI artifacts, backups or source-control history; do not reconstruct from names alone.
7. Rebuild the migration sequence in an isolated staging database from a verified baseline, then compare resulting schema to the production manifest.
8. Prepare a forward-only migration plan with explicit preconditions, rollback/recovery strategy and independent review.
9. Only then consider any production migration metadata repair or schema change, with a verified backup and explicit approval.

## Decision
**Recovery status: encrypted backup acquired and integrity-checked; SQL source not yet decrypted or reconciled.** The migration-history issue remains an active production safety blocker. No database mutation was performed.
