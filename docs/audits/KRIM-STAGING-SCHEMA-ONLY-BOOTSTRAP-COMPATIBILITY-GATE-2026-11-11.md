# KRIM Staging — Schema-Only Bootstrap Plan and Compatibility Gate
Date: 2026-11-11
Status: PREPARATION ONLY — NO EXPORT OR RESTORE PERFORMED

## Environment comparison (live read-only checks)

| Item | Production | Staging |
|---|---|---|
| Project ref | `ebltviniygljwwseplph` | `qrpcivhdxobiaofppbkl` |
| Region | ap-northeast-1 | ap-south-1 |
| PostgreSQL | 17.6.1.165 | 17.11.0.018 |
| Application tables in public/private | 378 public + 6 private (previous catalog inventory) | 0 |
| Migration history | 425 recorded versions | 0 |
| Application functions | present | 0 |
| Extension baseline | pgcrypto, pg_stat_statements, plpgsql, supabase_vault, uuid-ossp; pg_cron and pg_net were present in the earlier installed-extension inventory | staging has pgcrypto, pg_stat_statements, plpgsql, supabase_vault, uuid-ossp; pg_cron is available/installed in the staging extension inventory; pg_net availability/installation must be checked against exact installed rows before use |

Note: the Supabase extension listing includes both installed and available extensions. Only rows with a non-null `installed_version` are installed. Do not infer installation from an extension being listed.

## Critical finding: do not replay the repository migration folder blindly

Production has 425 recorded migration versions. The repository migration directory previously contained 263 SQL files, with only 64 exact version overlaps, 199 repository-only versions and 361 production-only versions in the comparison. This is not a valid one-to-one migration history.

Therefore:
- Do not run `supabase db push` from the current repository against the blank staging project.
- Do not mark historical migrations as applied merely to silence drift.
- Do not apply the current repository migration folder in timestamp order and assume it reconstructs production.
- Do not copy production data, auth users, storage objects, secrets, JWT keys or payment credentials to staging.
- Do not use production as a target for any bootstrap command.

The safest bootstrap source is a reviewed, schema-only dump of the current production database, restored to the separate blank staging project using the Supabase CLI and a local trusted environment. The resulting dump must be treated as a one-time staging baseline, not as proof that the repository migration history is repaired.

## Official CLI behaviour verified against current Supabase docs

Supabase `db dump`:
- dumps the remote database schema by default (no data and no custom roles unless explicit flags request them);
- runs pg_dump with Supabase-specific exclusions for managed schemas such as auth, storage and extension-owned schemas;
- requires the local project to be linked to a remote database, or an explicit database URL;
- warns that default privileges in the target database can grant broader privileges than intended. Review/revoke target default grants before restoring, and verify grants afterwards.

Official reference: https://supabase.com/docs/reference/cli/supabase-db-dump
Backup/restore guide: https://supabase.com/docs/guides/platform/migrating-within-supabase/backup-restore

## Controlled bootstrap procedure (trusted computer required)

### A. Prepare a clean local workspace
1. Use a trusted computer with current Supabase CLI, Docker and PostgreSQL client tools.
2. Check versions and exact CLI syntax first:
   `supabase --version`
   `supabase db dump --help`
   `supabase link --help`
3. Keep database passwords in an OS secret manager or interactive prompt. Never paste connection strings/passwords into GitHub, chat, source files or command history.
4. Create a separate temporary workspace outside the production application checkout, or a clean worktree, to avoid mixing the schema baseline with application migrations.

### B. Export production schema only
1. Obtain the production database connection string from Supabase Dashboard > Connect using a secure session-pooler or supported direct connection.
2. Run the documented schema-only `supabase db dump` against production using its `--db-url` option and an output file in the temporary workspace.
3. Do not use `--data-only`, `--role-only`, or any command that exports data, auth records or secrets.
4. Keep the dump local and private; do not commit it to the public repository.
5. Scan the dump for:
   - unexpected data INSERT/COPY statements;
   - credentials, tokens, secrets, webhook values or connection strings;
   - production-only URLs or project identifiers embedded in function bodies;
   - grants/default privileges that could be too broad on staging;
   - references to extensions or managed schemas unavailable on staging.
6. Produce a manifest of schemas, tables, functions, triggers, policies, views, sequences, types and extension dependencies. Compare counts with production catalog snapshots.

### C. Prepare staging target
1. Verify the target project ID is exactly `qrpcivhdxobiaofppbkl` before connecting.
2. Confirm it still has zero application tables, zero app functions and zero migration history. Abort if any unexpected objects or data appear.
3. Confirm staging is on PostgreSQL 17 and inspect installed extension versions. Enable only extensions required by the reviewed schema, after checking compatibility and availability.
4. Review target default privileges. Supabase docs warn that target default privileges may grant all table privileges to anon/authenticated. Revoke broad defaults before restore, then restore only explicit reviewed grants.
5. Do not copy production Auth settings, email provider secrets, Vault contents, storage buckets/objects, Edge Function secrets, payment keys, webhook secrets, cron jobs or production schedules.
6. Replace or disable outbound integrations in staging. Telegram, email, Razorpay, Cashfree and other external calls must be stubbed or routed to test sinks.

### D. Restore schema only
1. Use a staging-specific database connection string and restore the reviewed schema dump to staging only.
2. Use a transaction-safe restore option where supported by the generated SQL and CLI tooling.
3. Stop on first SQL error. Do not continue with a partially restored schema.
4. Do not run production seed data. Add only synthetic test organisations, memberships, partners, capabilities, shipments, quotes and capacity records after security review.
5. Keep production and staging credentials separate at all times.

### E. Post-restore validation
Compare production and staging catalog metadata:
- required public/private schemas and object counts;
- tables, columns, types, nullability, defaults, identity and sequences;
- primary/foreign/unique/check constraints and indexes;
- functions, identity arguments, return types, SECURITY DEFINER, search_path and execute grants;
- triggers and trigger function definitions;
- RLS enabled/forced state, policies and role grants;
- views, including security_invoker option and grants;
- installed extension versions;
- Data API exposure settings and explicit grants;
- storage bucket definitions only if separately recreated as empty test buckets;
- cron/pg_net integrations absent or safely disabled until separately reviewed.

Run Supabase security and performance advisors on staging. Any differences must be classified as expected Supabase-managed environment differences or unresolved parity defects.

### F. Create a clean repository baseline
1. Store only a redacted, reviewed schema baseline or a set of reviewed migrations in the private development branch; never commit a raw dump with secrets or data.
2. Generate migration files using the current Supabase CLI workflow and review each file.
3. Add an explicit baseline note explaining that production history and repository history diverged; do not fabricate historical migration records.
4. Establish a single forward-only migration source of truth after staging parity is verified.
5. Keep production deployment blocked until a separately approved migration has been tested on staging and reviewed.

## Important limitations

- The available ChatGPT Supabase tools can inspect catalogs, apply SQL and manage projects/branches, but they do not provide the local CLI/Docker file-export and restore workflow needed to create a trustworthy schema-only dump in this session.
- No production connection string or database password was requested or exposed.
- A SQL query that recreates tables manually from catalog metadata is not an acceptable substitute for a complete schema dump: it can miss triggers, function bodies, policies, grants, extensions, operators, types, dependencies and ownership.
- The staging database being blank is useful: it provides a clean target, but it does not itself make a partial migration replay safe.
- Staging project already exists; creating a Supabase development branch is a separate action and may incur charges. No such branch is authorised.

## Current result

The environment comparison is complete. The safe next action is a schema-only export and reviewed restore from a trusted computer. No export, restore, migration, SQL, data, auth setting, extension, Edge Function, secret, webhook or payment setting was changed. No paid staging branch was created.
