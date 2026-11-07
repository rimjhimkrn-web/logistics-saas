# KRIM Staging Extension Prerequisite Review — 2026-11-07

Read-only comparison of installed PostgreSQL extensions in production and isolated staging:

| Extension | Production | Staging | Finding |
|---|---|---|---|
| pg_cron | 1.6.4 in pg_catalog | Not installed; available 1.6.4 | Required prerequisite to assess |
| pg_net | 0.20.4 in extensions | Not installed; available 0.20.4 | Required prerequisite to assess |
| pg_stat_statements | 1.11 in extensions | 1.11 in extensions | Aligned |
| pgcrypto | 1.3 in extensions | 1.3 in extensions | Aligned |
| plpgsql | 1.0 in pg_catalog | 1.0 in pg_catalog | Aligned |
| supabase_vault | 0.3.1 in vault | 0.3.1 in vault | Extension installed; no Vault secrets copied |
| uuid-ossp | 1.1 in extensions | 1.1 in extensions | Aligned |

## Decision

No extension was installed or modified in either project during this check.

The encrypted schema export workflow intentionally excludes Supabase-managed schemas and does not export Vault contents. Before applying application schema to staging, inspect the production DDL for actual references to pg_cron and pg_net and determine whether those extensions are required for the staging test scope. If required, enable them in staging only, using the same extension versions and schema placement where supported. Do not copy scheduled job rows, HTTP credentials, Vault secrets, or production cron jobs.

## Export workflow implementation

Added on feature branch mobile/krim-partner-app:

- .github/workflows/krim-schema-export.yml
- docs/KRIM-SECURE-SCHEMA-EXPORT-INSTRUCTIONS-2026-11-07.md

The workflow requests schema-only SQL for public, private, krim_internal, and graphql_public; encrypts the dump before artifact upload; uses a one-day artifact retention; and never commits the SQL dump. It requires repository secrets KRIM_PRODUCTION_DB_URL and KRIM_SCHEMA_EXPORT_PASSPHRASE. Workflow execution is not yet confirmed because those secrets must be configured by the repository owner.

The repository is public, so uploading an unencrypted SQL dump as an Actions artifact is prohibited. Only the encrypted artifact is intended to leave the runner. The passphrase must remain private and must not be shared in chat.
