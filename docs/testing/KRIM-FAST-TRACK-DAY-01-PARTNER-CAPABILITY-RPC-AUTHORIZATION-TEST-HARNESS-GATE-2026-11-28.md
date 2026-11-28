# KRIM Fast-Track Day 1 — Partner Capability Read RPC Authorization & Test-Harness Gate
Date: 2026-11-28
Environment inspected: KRIM Logistics Staging (`qrpcivhdxobiaofppbkl`)
Branch: `staging/phase00-env-isolation`

## New authorization evidence

The deployed helper `private.krim_has_permission(uuid,bigint,text)` is STABLE SECURITY DEFINER with search_path `public, pg_catalog`. It requires:
- non-null `auth.uid()`;
- supplied user UUID exactly equals `auth.uid()`;
- an active `krim_user_role_assignments` row for that user and organization;
- a granted role permission matching the requested permission code;
- an active `krim_organization_members` row for the same user and organization;
- an active `krim_organizations` row.

The helper does **not** itself constrain organization type. Therefore the proposed partner read RPC must separately verify that the requested active organization has an allowed partner organization type before returning rows. Staging's `krim_organizations.organization_type` CHECK constraint permits: customer, partner, enterprise, carrier, warehouse, forwarder, platform, customs, finance, operations. Partner-facing types for the read endpoint should be explicitly allowlisted as partner/carrier/warehouse/forwarder, subject to a final caller/product review. Do not use the loosely named `organizations` table; the actual table is `public.krim_organizations`.

The permission code `partner.manage` exists. The helper's use of `auth.uid()` prevents passing another user's UUID to obtain their permissions. The current Staging data has only a platform organization; there are no partner fixture organizations or users to exercise the intended path. A successful cross-tenant runtime test cannot be claimed yet.

## Recommended RPC authorization order

For `public.krim_partner_list_capabilities(p_organization_id bigint)` (working name only; not deployed):
1. Reject null `auth.uid()` and null organization ID.
2. Confirm the requested row in `public.krim_organizations` is active and has an explicitly allowlisted partner organization type.
3. Require `private.krim_has_permission(auth.uid(), p_organization_id, 'partner.manage')`.
4. Return only capability rows for that exact organization.
5. Extract only bounded `equipment_details` and `operational_constraints` values from `metadata->'submission_details'`; do not expose raw JSONB or evidence paths.
6. Order deterministically by `created_at DESC, id DESC`.
7. Use a narrowly scoped SECURITY DEFINER function only because authenticated direct SELECT is intentionally absent. Set an empty search_path, schema-qualify every object, revoke EXECUTE from PUBLIC and anon, and grant EXECUTE only to authenticated. Do not weaken table grants or RLS.

A second review must confirm the exact response shape and whether the display strings require explicit length limits. The RPC must not return other organizations, private notes, evidence object names, submitter/reviewer UUIDs or full metadata.

## Test-harness discovery

- The repository root has no `package.json` and the inspected `supabase/` directory contains `functions/` and `migrations/`, but no `config.toml`.
- Therefore this branch does not currently provide a checked-in Supabase local project configuration or a reproducible local database test harness at the expected locations.
- pgTAP extension availability was checked separately; see the live result recorded in the accompanying work log before choosing pgTAP versus a disposable local Postgres harness.
- No local CLI version was run because no local shell/CLI execution environment is available through the connected repository/database tools. Do not claim CLI validation or local tests.
- No authenticated Partner A/B identities or partner organizations are present in Staging. Do not manufacture them in production or use service-role impersonation as a substitute for real JWT tests.

## Required test matrix before migration approval

| Actor / request | Expected result |
|---|---|
| Partner A, own active partner org with partner.manage | only own capability rows |
| Partner A, Partner B org ID | authorization denied; no rows |
| Partner B, own active partner org with partner.manage | only own capability rows |
| Partner B, Partner A org ID | authorization denied; no rows |
| Active customer org with partner.manage absent | denied |
| Partner org member without partner.manage | denied |
| Admin account without partner.manage on requested partner org | denied; no implicit admin bypass |
| Anonymous / missing JWT | denied |
| Null or inactive org | denied |
| Active non-partner org type | denied |
| Capability metadata containing evidence paths/private fields | none of those fields in response |
| Catalogue SELECT as authenticated | permitted by explicit grant + existing authenticated RLS policy |
| Catalogue SELECT as anon | denied |
| Catalogue INSERT/UPDATE/DELETE as authenticated or anon | denied |

Tests must use separate real authenticated JWT sessions, assert both positive and negative cases, and verify exact response keys. Include empty capability sets and malformed/oversized display metadata. Do not invoke partner submission, notification, or email workflows for this read-only test.

## Migration / execution gate

- Do not create a hand-named migration file: Supabase skill requires `supabase migration new <name>` first. No local CLI is available in this environment.
- Do not use hosted `apply_migration` to bypass the missing local migration workflow.
- Supabase CLI v3 is local-by-default and hosted operations require explicit remote targeting/confirmation; the current repo has no verified pinned CLI setup.
- Hosted Data API exposure configuration remains unverified. The project details endpoint does not expose the PostgREST exposed-schema setting, and PostgreSQL `current_setting('pgrst.db_schemas', true)` returned NULL. Confirm in Staging Dashboard > Integrations > Data API settings before relying on public-schema RPC exposure.
- Before migration creation: add a reproducible local Supabase config/harness, choose and pin CLI, verify Data API exposure, review final RPC return schema, add test SQL/pgTAP or an isolated Postgres integration test, then obtain explicit Staging-only authorization before applying.

## Scope

Read-only audit and report preparation only. No DDL, GRANT, migration, frontend modification, RPC invocation, fixture creation, invitation, email, notification or deployment occurred. Production was not accessed or changed. Phase 00 remains OPEN; Phase 01 has not started.
