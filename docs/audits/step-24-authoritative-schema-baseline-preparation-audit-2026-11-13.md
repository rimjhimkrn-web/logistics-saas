# Step 24 — Authoritative schema baseline preparation audit

Date: 2026-11-13
Production project: `ebltviniygljwwseplph`
Staging project: `qrpcivhdxobiaofppbkl`
Branch: `website/global-launch-readiness`
PR: #65 (draft, unmerged, undeployed)

## Read-only production schema inventory

A read-only metadata inventory was collected from production. It reports:
- 378 public tables;
- 6 private tables;
- 1 view and 0 materialized views;
- 459 routines across the inspected application schemas;
- 98 non-internal triggers;
- 412 policies;
- 385 custom enum/domain/composite types;
- 1,729 constraints;
- 7 installed extensions.

These are catalog counts, not a schema export. They do not prove that every dependency, grant, extension, storage policy, auth configuration, or Edge Function is included in a future staging baseline.

## Existing encrypted schema-export workflow inspected

Repository file: `.github/workflows/krim-schema-export.yml`

The workflow already implements a schema-only export using Supabase CLI, exports the application schemas `public,private,krim_internal,graphql_public`, checks the dump for executable INSERT/COPY data statements, scans for selected credential patterns, encrypts the SQL with OpenSSL AES-256-CBC + PBKDF2 (600,000 iterations), uploads only the encrypted artifact and checksum, and sets one-day artifact retention.

It requires two GitHub repository secrets:
- `KRIM_PRODUCTION_DB_URL` — PostgreSQL connection URI;
- `KRIM_SCHEMA_EXPORT_PASSPHRASE` — export encryption passphrase of at least 24 characters.

The workflow does not expose or print the database URI or passphrase. No secret values were accessed, requested, changed, or displayed.

## Important workflow limitation

The workflow's push trigger is restricted to branch `mobile/krim-partner-app`; it also supports `workflow_dispatch`. A manual run can be selected in GitHub Actions on the intended branch, but it will fail closed if either required secret is absent or invalid. The workflow was inspected but not dispatched in this step, so export completion and artifact availability are not verified.

The workflow's selected schema list is an application-schema export, not a complete Supabase project backup. It does not by itself recreate auth users/configuration, storage objects/buckets/policies outside the exported schemas, Edge Functions, secrets, API settings, extensions managed outside the dump, cron/queues configuration, or external integrations. Those must be separately inventoried and recreated safely for staging.

## Safety status

- Production SQL used only catalog metadata SELECT queries.
- Staging remains empty.
- No database dump was initiated.
- No secrets were accessed or changed.
- No customer, partner, shipment, payment, identity, storage, or document data was copied.
- No migrations were applied.
- No provider calls, deployment, or merge occurred.

## Next safe action

A repository administrator should confirm that both required GitHub Actions secrets already exist, then manually run `KRIM encrypted schema-only export` on the intended `website/global-launch-readiness` branch. Do not paste credentials or the passphrase into chat. Download/decrypt the artifact only in a secured environment, verify its checksum and data-free status, review its DDL, and then reconcile the exported schema against staging before applying anything.

After the export is verified, build a separate staging bootstrap checklist for non-schema Supabase services and staging-only credentials. Never reuse production provider credentials or copy production business data.

## Result

Step 24 completed as an inventory and export-workflow readiness review. The authoritative schema export itself is **not yet produced or verified**. No environment was changed. Staging remains healthy but empty; it is not yet ready for lifecycle tests.
