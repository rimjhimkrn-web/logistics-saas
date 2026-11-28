# KRIM Fast-Track Day 1 — Reference Catalogue Access & Frontend Contract Audit
Date: 2026-11-28
Environment: Staging only (`qrpcivhdxobiaofppbkl`)
Branch: `staging/phase00-env-isolation`

## Result
The prior access assessment is refined by a direct catalogue of columns, grants and RLS policies. Both reference tables have valid authenticated SELECT policies, but authenticated has no table-level SELECT grant. RLS policy presence does not itself grant Data API privileges. Therefore the partner page's authenticated catalogue reads remain blocked unless another access path exists.

## Exact frontend read contract
File: `public/partner/services-capabilities.html`

After authentication and active partner membership checks, the page concurrently issues:
- `krim_partner_capabilities`: selects id, organization_id, transport_mode_id, service_type, coverage_country_id, coverage_region, max_weight_kg, refrigerated, hazardous_goods_capable, active, verification_status, effective_from, effective_until, metadata, created_at; filters organization_id to the selected partner org.
- `krim_countries`: selects id, name, code, is_active; filters is_active=true; orders by name.
- `krim_transport_modes`: selects id, name, code, is_active, category; filters is_active=true; orders by name.

The page maps country and mode IDs into display labels. Submission uses the separate evidence-backed RPC `krim_partner_submit_service_capability_v2`. The Staging-hostname preview branch short-circuits before Supabase initialization and uses illustrative local-only data; it does not test the authenticated data path.

## Staging database evidence
### `public.krim_countries`
Columns used by the page exist: id bigint, name text, code varchar, is_active boolean.
- RLS enabled.
- Authenticated SELECT policy `KRIM countries readable`, predicate `true`.
- Direct grants returned only for service_role; no anon/authenticated SELECT grant.

### `public.krim_transport_modes`
Columns used by the page exist: id bigint, name text, code text, is_active boolean, category text.
- RLS enabled.
- Authenticated SELECT policy `KRIM transport modes readable`, predicate `true`.
- Direct grants returned only for service_role; no anon/authenticated SELECT grant.

### Capability register
Previous Staging audit remains: RLS enabled, authenticated direct SELECT privilege absent, and no capability rows existed at that aggregate snapshot. The partner UI's direct table query is therefore not an acceptable least-privilege read design.

## Required minimal correction
1. Keep direct authenticated access to `krim_partner_capabilities` closed. Implement a narrowly scoped authenticated read RPC (prefer SECURITY INVOKER where feasible; if SECURITY DEFINER is genuinely required, place it in a non-exposed schema, derive identity from auth.uid(), enforce active partner membership plus partner.manage, and explicitly restrict EXECUTE).
2. Return only the UI-required safe capability fields. Do not return private evidence paths, raw submission metadata, reviewer identity, or unrelated organization records.
3. For country/mode catalogues, choose one explicit access method: grant authenticated SELECT on only the required reference tables with RLS enabled and reviewed, or expose a narrow safe read RPC. Do not change grants until the complete current policy/data classification is reviewed.
4. Update the page to consume the selected access contracts and handle RPC errors without exposing internal details.
5. Test authenticated Partner A and Partner B, non-partner, unauthenticated, and platform-admin sessions. Confirm cross-tenant denial and that no private evidence fields are returned.
6. Test the real authenticated Staging data path. The illustrative preview is not an acceptance test.

## Supabase version guidance
Supabase CLI v3 database commands target the local stack by default; hosted operations require explicit `--remote`, and unattended hosted changes require `--yes`. Any later migration workflow must pin/verify CLI version and explicitly target Staging. See the official CLI v3 migration guide: https://supabase.com/docs/guides/local-development/cli/migrating-to-v3

## Scope and status
- Read-only Staging inspection and source review only.
- No SQL mutation, grants, migration, frontend edit, RPC invocation, fixture creation, upload, notification or deployment.
- Production untouched.
- Phase 00 remains OPEN; no Phase 01 start authorization.
