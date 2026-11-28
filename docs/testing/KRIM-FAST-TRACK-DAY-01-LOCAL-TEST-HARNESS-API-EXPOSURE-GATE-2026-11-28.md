# KRIM Fast-Track Day 01 — Local Test Harness and Partner Capability API Exposure Gate
Date: 2026-11-28
Branch: `staging/phase00-env-isolation`
Target database: KRIM Logistics Staging (`qrpcivhdxobiaofppbkl`)
Production project: not accessed or changed

## Outcome
**BLOCKED — no reproducible local Supabase/Postgres test harness is currently present, and Staging Data API exposed-schema settings remain an owner-dashboard verification item.** No migration, grant, RPC, fixture, deployment, or database mutation was performed.

## Repository inspection
Inspected the complete branch tree at commit `72dc311c7be3ed12c3d2cb1d058a5dfd4be2c633` (2,606 entries; tree response not truncated).

- No root `package.json`.
- No `supabase/config.toml`.
- No root Deno config or root JS package lockfile.
- No `supabase/tests` directory or database test harness was found in the relevant paths.
- Mobile apps have their own package manifests, but they do not establish a Supabase database test environment.
- A tracked `node_modules/playwright*` subtree exists; this is not a database test harness and must not be treated as one.
- The existing `.github/workflows/krim-env-isolation.yml` uses Node 22 and runs `node scripts/verify-krim-environment-isolation.mjs`. That script checks environment-to-project mapping and scans HTML/JS consumers; it is not a Postgres/RPC authorization test.
- `.github/workflows/krim-notification-email-policy-tests.yml` uses Deno v2.x to run the notification email policy unit test only. It does not provision or test a database.
- No workflow inspected establishes a disposable local Supabase stack, a pinned Supabase CLI, or a Partner A/B JWT database test.

## Data API exposure gate
The project details API did not expose the active Data API exposed-schema configuration. SQL inspection previously returned NULL for `pgrst.db_schemas` and `pgrst.db_extra_search_path`; these values are not sufficient evidence of the Dashboard configuration.

Owner verification required in Staging Dashboard:
1. Open Project Settings / Integrations → Data API (the current dashboard may label this under Integrations).
2. Record the exact **Exposed schemas** list and any **Extra search path** values.
3. Confirm whether `public` is exposed and whether `private` or `krim_internal` is exposed. Do not add schemas for this test.
4. Confirm the settings belong to project ref `qrpcivhdxobiaofppbkl`, not Production.
5. Share the visible values or a screenshot with secrets/API keys redacted.

Official Supabase guidance confirms that Data API grants control whether a role can reach an object, while RLS policies control which rows can be accessed after that. Functions require explicit EXECUTE grants and are not protected by RLS. Any exposed table must have RLS enabled; SECURITY DEFINER functions should not be exposed as broad APIs. Reference: https://supabase.com/docs/guides/api/securing-your-api

## Important CI workflow boundary observed
The branch contains `.github/workflows/krim-staging-schema-bootstrap.yml`, triggered by completion of the encrypted schema-export workflow for branch `mobile/krim-partner-app`. It checks for a Staging database secret, downloads the source run's encrypted schema artifact, rejects detected data statements and credential-like strings, checks that target application schemas are empty, and applies schema-only DDL in a single transaction to Staging.

This workflow is **not** a local test harness and is not a safe substitute for a versioned migration/test workflow. It has not been dispatched or invoked during this review. Its source export lineage is a separate operational risk to keep under review; do not rerun or modify it as part of this task. No artifact was downloaded and no Production secret or database was accessed.

## Required next sequence
1. Owner confirms Staging Data API exposed-schema settings.
2. Establish a reproducible disposable local PostgreSQL/Supabase environment and pin compatible CLI/tool versions; first inspect current Supabase CLI breaking changes and documented config syntax.
3. Create the project config using the supported CLI workflow, not a hand-invented migration filename.
4. Add deterministic database tests for the proposed `krim_partner_list_capabilities(bigint)` contract, including Partner A own-org success, cross-tenant denial, Partner B mirror tests, non-partner org rejection, missing permission, anon, null/inactive org, bounded response fields, and catalogue read-only grants.
5. Run tests locally against disposable fixtures, then review the migration and security advisor output.
6. Only after review, obtain explicit authorization for a Staging-only schema change. Keep Production untouched.

## Current gate status
- Local Supabase/Postgres harness: **NOT PRESENT**.
- Pinned Supabase CLI in the inspected workflows: **NOT ESTABLISHED**.
- Partner A/B authenticated database tests: **NOT RUN**.
- Staging Data API exposed-schema settings: **OWNER VERIFICATION REQUIRED**.
- Proposed partner capability list RPC: **DESIGN ONLY; NOT CREATED**.
- Phase 00: **OPEN — NOT APPROVED**.
- Production: **NOT ACCESSED OR CHANGED**.
