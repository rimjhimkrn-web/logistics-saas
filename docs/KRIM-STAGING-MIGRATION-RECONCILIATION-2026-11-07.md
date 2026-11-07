# KRIM Staging Migration Reconciliation — 2026-11-07

## Current environment

- Production project: `ebltviniygljwwseplph`
- Isolated staging project: `qrpcivhdxobiaofppbkl` (Mumbai, `ap-south-1`)
- No production writes or configuration changes were made in this review.
- No application schema has been applied to staging.

## Verified migration ledger mismatch

A fresh read-only comparison found:

- Production migration ledger: **422** applied migrations.
- Current repository directory `supabase/migrations` on `mobile/krim-partner-app`: **257** SQL files.
- Repository's earliest visible migration: `20261016120808_krim_user_app_backend_modules.sql`.
- Production's earliest ledger entry: `20260929043657_add_global_partner_lifecycle`.
- Only **64** repository filenames have a timestamp matching a production migration version; **358** production ledger entries have no same-version filename in the current repository directory.

This is stronger evidence of migration drift / incomplete historical source than a simple ordering problem. A blind replay of the visible directory is not an acceptable staging bootstrap.

## Staging system schemas vs application schema

The staging catalog contains Supabase-managed objects in `auth`, `storage`, `realtime`, `vault`, and `extensions`. It has **zero application tables in `public`**, zero public application routines, and zero public application RLS policies. Its empty application schema explains the current empty-database advisor result; that result is not a security sign-off.

## Production catalog inventory (read-only)

The broad catalog query returned 430 table-like relations across schemas, 4 views, 345 sequences, 584 functions, 112 non-internal triggers, 439 policies, 13 enum types, and 7 installed extensions. These counts include non-public schemas and should not be conflated with the earlier PostgREST public-table count.

## Immediate safe engineering plan

1. Locate and reconcile the missing historical migration source from authoritative repository history / release artifacts, or obtain a trusted schema-only database export.
2. Build a deterministic baseline in a separate review branch, not by editing production.
3. Explicitly exclude all table rows, auth users, storage objects, Vault secrets, provider credentials, API keys, webhook secrets, and real payment data.
4. Apply the reviewed baseline to staging only.
5. Compare application catalog objects, constraints, indexes, triggers, function signatures/definitions, RLS policies, and grants against production.
6. Only then create synthetic test identities and execute positive/negative authorization and workflow tests.

## Guardrails

- Do not use production data copy or production secrets in staging.
- Do not expose service-role keys or payment/webhook secrets in app builds or GitHub.
- Do not deploy the unreviewed quote RPC proposal or enable write actions yet.
- Keep customer, partner, driver, finance, warehouse, customs, and operations flows read-only until staging verification is complete.
- Production launch remains NO-GO pending end-to-end operational, payment, legal/compliance, and physical-device validation.
