# Step 49 — Schema-baseline reconstruction evidence requirements

Date: 2026-11-13
Branch: website/global-launch-readiness
Scope: read-only inventory of production database metadata and definition of evidence required before a disposable baseline can be reconstructed.

## Live metadata recheck

Production project `logistics-saas` (`ebltviniygljwwseplph`):
- Status ACTIVE_HEALTHY; PostgreSQL 17.6.1.165; region ap-northeast-1.
- Supabase table inventory returned 384 tables across `public` and `private`.
- One private table, `private.krim_driver_invitations`, was reported with RLS disabled. This is not a finding about public Data API exposure; preserve and review its intended access model before restoring or changing anything.
- Seven extensions are installed: `plpgsql` 1.0, `supabase_vault` 0.3.1, `pg_stat_statements` 1.11, `uuid-ossp` 1.1, `pg_net` 0.20.4, `pgcrypto` 1.3, and `pg_cron` 1.6.4.
- Supabase reports 71 additional available extension candidates not installed; do not install them merely because they appear in the catalogue.
- 19 Edge Functions are listed as ACTIVE. Four legacy Cashfree-related functions remain listed; these need an explicit retain/disable decision in a separate controlled review. Function listing does not verify secrets, external provider accounts, schedules or successful execution.

Separate staging project `qrpcivhdxobiaofppbkl`:
- Status ACTIVE_HEALTHY; PostgreSQL 17.11.0.018; region ap-south-1.
- It is not version-aligned with production and has no applied migration history (per prior verification).

## What a schema-only export can establish

A verified schema-only export can provide a snapshot of database definitions: schemas, tables, columns, constraints, indexes, views, functions, triggers, policies and grants included by the dump scope and permissions. It must be reviewed for omitted objects, ownership/role assumptions, extension dependencies and unsupported managed objects.

It does **not** by itself provide a full Supabase project recovery package. Separate inventories/configuration evidence are required for:
- Auth provider configuration, redirect URLs, password/MFA settings, email templates and user identities (do not copy real users to test);
- Storage buckets, bucket policies and object files (object bytes are outside ordinary database metadata backups);
- Edge Function source, deployment versions, JWT settings, environment variable names and separately provisioned secret values;
- Realtime publication membership and settings;
- pg_cron jobs, queues and external integrations;
- project region, Postgres major/minor version, database parameters, API/Data API exposed schemas and network restrictions;
- Vault secret metadata and safe secret re-provisioning (never export or place plaintext secret values in a report);
- roles, grants, ownership, default privileges and extension versions/schemas.

The connected read interface does not expose a complete export of all those Auth, Storage, project, secret and external-provider settings. These remain owner/dashboard verification items.

## Required baseline evidence package

Before creating a disposable test baseline, assemble and checksum:
1. encrypted schema-only SQL + checksum; independently verify decryption and file integrity in controlled custody;
2. exact production migration ledger export (version + name) and repository migration inventory at a fixed commit;
3. reconciliation ledger from Step 48, with source commit/blob and SQL SHA-256 for every available candidate;
4. object inventory: schemas, tables, views, materialized views, sequences, functions/procedures, triggers, policies, grants, ownership, publications, extensions and installed versions;
5. Auth configuration checklist (settings only, no credentials/user data);
6. Storage bucket/policy inventory and a separate object-data decision (do not copy customer documents to test);
7. Edge Function source/version/JWT/config inventory and secret *names* only;
8. cron/queue/webhook/external integration inventory, with credentials excluded;
9. project/database configuration and version compatibility record;
10. reviewer sign-off on omissions, role mapping, extension availability and restore plan.

## Recommended test target

Do not use the existing staging project yet. Prefer a new disposable non-production project/database only after the owner approves any cost and region/version selection. Ideally match production's PostgreSQL 17.6 minor/build and region where supported; if exact build is unavailable, document the difference and run compatibility tests. Restore schema only, with synthetic test identities and no production business data. Reconcile managed Supabase schemas/roles carefully; do not blindly replay a full dump over a fresh Supabase-managed Auth/Storage installation.

## Important additional observation

The live Edge Function inventory still includes legacy Cashfree order/verification/webhook functions alongside Razorpay functions. Their presence alone does not prove they are reachable or configured. Keep KRIM freight checkout disabled under the partner-direct launch model, and separately confirm obsolete provider routes are safely gated before launch.

## Step 49 verdict

**EVIDENCE REQUIREMENTS DEFINED; BASELINE RESTORE NOT READY.** The live inventory adds important extension, private-schema and Edge Function facts, but a verified export and managed-configuration inventory are still missing. No production data, schema, extension, function, secret, project setting, migration or staging resource was changed.
