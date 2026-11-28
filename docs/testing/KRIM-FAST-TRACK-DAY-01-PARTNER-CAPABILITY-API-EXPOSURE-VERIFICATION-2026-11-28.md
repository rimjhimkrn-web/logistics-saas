# KRIM Fast-Track Day 1 — Partner Capability API Exposure & Catalogue Grant Verification
Date: 2026-11-28
Environment: Staging only (`qrpcivhdxobiaofppbkl`)
Branch: `staging/phase00-env-isolation`

## Verification performed

Read-only source and database inspection of `public/partner/services-capabilities.html`, the three relevant public tables, RLS policies, role privileges, PostgREST runtime settings visible through PostgreSQL, and the existing submission/admin RPC ACLs.

## Confirmed frontend contract

The authenticated partner page currently requests:
- `krim_partner_capabilities`: id, organization_id, transport_mode_id, service_type, coverage_country_id, coverage_region, max_weight_kg, refrigerated, hazardous_goods_capable, active, verification_status, effective_from, effective_until, metadata, created_at; filtered by the selected organization and ordered by created_at descending.
- `krim_countries`: id, name, code, iso2_code, is_active; active rows ordered by name.
- `krim_transport_modes`: id, name, code, is_active, category; active rows ordered by name.

The page reads `metadata.submission_details.equipment_details` and `operational_constraints` to render two display fields. The new read API must return only these bounded display values, not raw metadata.

## Staging database evidence

- RLS is enabled on all three tables.
- `krim_countries` and `krim_transport_modes` each have an authenticated-only SELECT policy with predicate `true`.
- `krim_partner_capabilities` has an authenticated SELECT policy using `private.krim_has_organization_access(auth.uid(), organization_id)`; it is not a sufficient substitute for the stricter partner.manage check required by the new API.
- Current direct privileges: anon has no SELECT; authenticated has no SELECT, INSERT, UPDATE or DELETE on any of the three tables. Therefore the current page's direct catalogue reads cannot succeed for authenticated users until the catalogue read grant is deliberately added.
- The country catalogue includes reference attributes such as ISO codes, currency, timezone, region and official languages. The transport-mode catalogue contains mode identifiers, names, codes, active status and category. These are reference catalogues, not partner evidence or user records.
- The capability table contains the expected display columns and a JSONB metadata column. It has no direct authenticated table grant.
- Existing submission and admin list/review RPCs are SECURITY DEFINER with empty search_path, owned by postgres; in the inspected ACL snapshot they are executable by authenticated, not anon, and not executable by PUBLIC.

## API exposure configuration limitation

The SQL session returned NULL for `current_setting('pgrst.db_schemas', true)` and `pgrst.db_extra_search_path`. These values do not establish which schemas the hosted Data API exposes. The expected `supabase/config.toml` path was not present at the inspected branch path. Hosted Data API schema exposure therefore remains **unverified** and must be confirmed from the Staging project's Data API settings or authoritative PostgREST configuration before implementation. Do not infer that `public` is the only exposed schema from these NULL settings.

## Implementation decisions retained

1. Add authenticated SELECT only on the two reference catalogues, retaining their current authenticated-only RLS SELECT policies. No anon access and no write grants.
2. Keep direct authenticated access to `krim_partner_capabilities` denied.
3. Add a narrow partner read RPC with a required organization selector, explicit `auth.uid()`, active partner organization validation and `private.krim_has_permission(auth.uid(), p_organization_id, 'partner.manage')`.
4. Return only the page's safe display fields, including bounded equipment/operational details extracted from metadata. Never return raw metadata, evidence paths, submitter/reviewer IDs, private notes or storage object names.
5. Explicitly revoke default PUBLIC/anon execution and grant the new RPC only to authenticated. Use empty search_path and schema-qualified references if SECURITY DEFINER is necessary.
6. Patch the frontend to call the RPC and map its safe response; keep the existing submission RPC unchanged.

## Remaining blockers before migration creation

- Confirm the Staging Data API exposed schemas through the project settings or authoritative hosted configuration.
- Establish a local PostgreSQL/Supabase test harness and reproducible authenticated JWT/session fixtures for Partner A, Partner B, non-partner and admin-without-partner.manage.
- Inspect the exact helper and organization type/status predicates used for active partner membership, then encode them consistently.
- Build SQL/API tests for cross-tenant denial, unauthorized roles, response field minimization, and catalogue grant boundaries.
- Verify the pinned Supabase CLI version and local migration workflow. Do not run hosted CLI commands without explicit Staging targeting.
- Obtain explicit approval before applying any database change to Staging.

## Scope and safety

This is a read-only verification report. No database grants, DDL, migration, RPC invocation, fixture provisioning, frontend edit, upload, notification or deployment occurred. Production was not accessed or changed. Phase 00 remains OPEN; Phase 01 has not started.
