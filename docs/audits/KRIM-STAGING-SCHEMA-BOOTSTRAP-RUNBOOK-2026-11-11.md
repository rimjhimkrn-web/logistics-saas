# KRIM Staging Schema Bootstrap Runbook
Date: 2026-11-11
Status: PREPARATION ONLY — no export, restore, or database mutation performed.

## Decision

Use the existing `KRIM Logistics Staging` Supabase project as the isolated test target, but do not implement booking changes there until its application schema has been safely bootstrapped from the production schema.

Projects:
- Production: `ebltviniygljwwseplph`, PostgreSQL 17.6.1.165, ap-northeast-1.
- Staging: `qrpcivhdxobiaofppbkl`, PostgreSQL 17.11.0.018, ap-south-1.

## Verified parity gap

| Catalog item | Production | Staging |
|---|---:|---:|
| public tables | 378 | 0 |
| private tables | 6 | 0 |
| public views | 1 | 0 |
| public application functions | populated | 0 |
| Supabase migration history | 425 records previously audited | 0 |
| Required booking lifecycle RPCs | present | 0 |

Installed extensions differ:
- Production: pg_cron 1.6.4, pg_net 0.20.4, pg_stat_statements 1.11, pgcrypto 1.3, plpgsql 1.0, supabase_vault 0.3.1, uuid-ossp 1.1.
- Staging: pg_stat_statements 1.11, pgcrypto 1.3, plpgsql 1.0, supabase_vault 0.3.1, uuid-ossp 1.1.

The absence of `pg_cron` and `pg_net` in staging is material: production includes scheduled workflow and network integration dependencies. Do not assume schema restore alone reproduces scheduler jobs or Edge Function behavior.

## Safe bootstrap method

Use the official Supabase CLI schema dump workflow, not raw `pg_dump` and not a blind replay of the repository migration directory. The official CLI filters Supabase-managed schemas and its default dump contains schema only (no data and no custom roles). See:
- https://supabase.com/docs/guides/platform/migrating-within-supabase/backup-restore
- https://supabase.com/docs/reference/cli/supabase-db-dump

### 1. Prepare a private local workspace

Use a trusted computer with current Supabase CLI, Docker and PostgreSQL client tools. Do not paste database passwords, connection strings, service-role keys or secret keys into chat, GitHub, issues, commits or logs.

Keep exports outside the Git repository, with restrictive local file permissions. Never commit schema dumps: they may contain sensitive function definitions, policies, internal object names or hard-coded configuration.

### 2. Export production schema only

From the production project's Connect dialog, obtain its database connection string privately. Run:

```sh
supabase db dump --db-url "$PRODUCTION_DB_URL" -f production-schema.sql
```

Do not run `--data-only` or `--role-only`. Do not export or restore production data, auth users, storage objects, payment records, secrets or credentials.

### 3. Review the dump before restore

Inspect for:
- hard-coded API keys, tokens, passwords, webhook secrets, production URLs or external destinations;
- production cron jobs and network calls;
- grants/default privileges that would accidentally broaden access;
- functions, triggers, policies, extensions and dependencies that are unavailable in staging;
- references to production Edge Function URLs, Vault secrets, auth providers, SMTP or payment providers.

Replace environment-specific integration values with safe staging values or leave those integrations disabled. Do not restore production Vault secret values.

### 4. Prepare staging privileges and dependencies

Before restore, compare installed extension versions and required schemas. The live inspection found `pg_cron` and `pg_net` missing from staging. Enable only what is required and supported, with reviewed staging-safe configuration. Do not copy production cron jobs or outbound network tasks blindly.

Supabase's CLI dump documentation warns that default privileges on the target project can affect restored table access. Review and set restrictive target defaults before restoring, then validate grants and RLS after restore. In particular, do not allow default table privileges to grant broad `anon` or `authenticated` access.

### 5. Restore schema only

After review, use the staging database connection string privately and restore the reviewed schema file to staging only. Do not restore production role passwords, user rows, storage objects, Vault secrets or production data. Stop immediately on any SQL error; do not continue with a partially restored schema.

### 6. Reconfigure staging-only services

Manually configure, with separate staging credentials:
- Auth redirect URLs, email confirmation and SMTP settings;
- Edge Functions and their environment secrets;
- storage buckets and private policies (empty buckets only);
- safe webhook endpoints and disabled payment execution;
- any scheduler jobs, only after review and with staging-only targets.

### 7. Verify parity before lifecycle work

Compare production and staging object inventories:
- schemas, tables, columns, constraints and indexes;
- functions, signatures, owners, SECURITY DEFINER flags, search_path and EXECUTE grants;
- triggers and trigger functions;
- RLS enabled/forced flags and every policy;
- views and security_invoker behavior;
- extensions and versions;
- storage bucket definitions and policies;
- grants/default privileges;
- scheduled jobs and Edge Function dependencies.

Then run the booking lifecycle preflight queries from `KRIM-BOOKING-LIFECYCLE-IMPLEMENTATION-PREFLIGHT-AND-TEST-PLAN-2026-11-11.md`.

Create only synthetic fixtures for a customer organisation, partner organisation, verified route capability, shipment, opportunity, partner quote, assignment and capacity commitment. No real user/customer/partner data.

## Release gates

Do not start the coordinated booking migration until:
1. Staging schema inventory matches the reviewed production baseline for all relevant dependencies.
2. All environment-specific secrets and production outbound integrations are absent/disabled.
3. RLS, grants, policies, function execution grants and trigger definitions have been compared.
4. Synthetic fixtures can exercise award → partner acceptance → customer acceptance → activation → dispatch.
5. Regression tests cover rejection, expiry, retry, concurrency, capacity release, multi-tenant isolation and payment eligibility.
6. Customer booking and payment remain fail-closed until tests pass.

## What was not done

- No schema dump or restore was run.
- No production or staging DDL/data was changed.
- No extensions were enabled.
- No Edge Function, cron job, secret, auth setting or storage policy was changed.
- No production records were copied.
