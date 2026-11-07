# KRIM Staging Baseline Assessment — 2026-11-07

## Decision

The isolated Supabase project `KRIM Logistics Staging` was created successfully in `ap-south-1` (Mumbai). Project ref: `qrpcivhdxobiaofppbkl`.

No production schema, data, secrets, Edge Functions, or configuration were copied or changed. No staging migrations or schema writes have been applied.

## Read-only comparison

| Metric | Production | Staging |
|---|---:|---:|
| Public base tables | 378 | 0 |
| Public routines | 337 | 0 |
| Public RLS policies | 411 | 0 |
| Installed extensions | 7 | 5 |
| Applied migrations | Extensive history | 0 |
| Security advisor findings | Previously audited separately | 0 (empty database) |
| Performance advisor findings | — | 0 (empty database) |
| Health advisor findings | — | 0 (empty database) |

The zero staging advisor findings are not a security certification; the database has no application schema yet.

## Why migration replay is not safe yet

- Production has an extensive migration history beginning before the earliest migration file currently present in the repository.
- The production migration ledger's versions/names do not map one-to-one to the current repository migration filenames.
- The repository currently exposes 257 SQL migration files, but its earliest visible migration is not a complete empty-database bootstrap for the current production schema.
- Several migrations assume pre-existing tables, functions, roles, extensions, policies, and seeded reference data.
- Applying the visible files blindly to an empty project could fail midway or create a schema that differs from production.

## Safe next steps

1. Produce a reviewed, schema-only baseline from the authoritative production schema, including table definitions, sequences, constraints, indexes, RLS policies, grants, functions, triggers, views, enums, and required extension dependencies.
2. Exclude all production row data, auth users, storage objects, payment credentials, webhook secrets, Vault contents, and provider tokens.
3. Apply the baseline to staging only, in reviewed batches.
4. Compare staging catalog metadata against production for object coverage and privilege/RLS equivalence.
5. Add synthetic test fixtures and dedicated staging-only test accounts.
6. Run authenticated negative/positive integration tests for customer, partner, driver, warehouse, customs, finance, and operations workflows.
7. Keep payment provider calls mocked or in sandbox mode until explicit payment testing approval and provider configuration review.

## Release boundary

Production remains unchanged. The mobile apps remain read-only pending authenticated staging tests. Do not enable quote submission, assignment acceptance, driver write actions, payments, or partner payouts until their respective staging tests pass.
