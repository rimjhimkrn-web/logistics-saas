# KRIM Fast-Track Day 01 — Partner Capability Read Contract and Frontend ACL Gap
Date: 2026-11-28
Branch: `staging/phase00-env-isolation`
Target: KRIM Logistics Staging (`qrpcivhdxobiaofppbkl`)
Production: not accessed or changed

## Scope and safety
Read-only source and catalog review. No database objects, grants, rows, fixtures, storage objects, notifications, or deployments were changed.

## Frontend caller evidence
Inspected `public/partner/services-capabilities.html` at branch HEAD.

After authentication, the page:
1. Reads the caller's active memberships from `krim_organization_members`, filtered by `user_id = auth user` and `status = active`.
2. Reads those organizations from `krim_organizations`.
3. Selects the first organization whose `organization_type_code || organization_type` is one of `partner`, `carrier`, `forwarder`, `logistics_provider`, `warehouse`, `warehouse_operator`, and whose status is active.
4. Directly selects partner capability rows, countries, and transport modes using the browser client.
5. Uses `krim_partner_submit_service_capability_v2` for evidence-backed submissions.

The page's staging hostname branch exits early into local illustrative data. That branch does not exercise the authenticated browser/database path.

## Fresh Staging grants and RLS evidence

| Table | authenticated SELECT grant | anon SELECT grant | RLS | Authenticated SELECT policy |
|---|---:|---:|---:|---|
| `krim_organization_members` | yes | no | enabled | own membership only (`user_id = auth.uid()`) |
| `krim_organizations` | yes | no | enabled | active member's organization; AAL2 platform-admin path |
| `krim_partner_capabilities` | no | no | enabled | organization-access policy exists |
| `krim_countries` | no | no | enabled | read-all authenticated policy exists |
| `krim_transport_modes` | no | no | enabled | read-all authenticated policy exists |

The policy definitions for countries and transport modes are authenticated SELECT policies with predicate `true`; they do not grant table access by themselves. The partner-capabilities policy scopes rows through `private.krim_has_organization_access(auth.uid(), organization_id)`, but the missing authenticated table grant means the current browser SELECT is not available through ordinary table privileges.

### Consequence
The current authenticated page's three direct SELECT calls cannot all succeed under the inspected ACL snapshot. In particular, partner capability, country and transport-mode reads lack authenticated SELECT grants. This is a confirmed source/ACL mismatch; it is not a claim that a live user encountered a runtime failure, because no authenticated partner session was used.

## Safer read API recommendation
Prefer one bounded RPC over adding direct browser grants to three tables:

`public.krim_partner_get_capability_workspace(p_organization_id bigint)`

The RPC should return one JSON object with:
- `capabilities`: only the requested organization's records, minimized to fields actually rendered by the page;
- `countries`: only active country reference fields required by the form;
- `transport_modes`: only active mode reference fields required by the form.

Authorization requirements:
1. Require non-null `auth.uid()` and non-null organization ID.
2. Fetch the organization by exact ID and require active status.
3. Require canonical `organization_type` to be in an owner-approved partner allowlist. Candidate set from the database constraint: `partner`, `carrier`, `warehouse`, `forwarder`. The frontend's legacy `logistics_provider` and `warehouse_operator` values are not permitted by the current Staging organization-type CHECK constraint; do not silently include them.
4. Require `private.krim_has_permission(auth.uid(), p_organization_id, 'partner.manage')`. That helper checks current user identity, active role assignment, permission, active membership and active organization.
5. Do not treat platform-admin status as an automatic bypass unless product/security owners explicitly require and specify that behavior.
6. Return only rows where `organization_id = p_organization_id`; never accept a caller-supplied user ID.
7. Return only active countries/modes, deterministic ordering, and bounded fields. Do not return evidence object paths, private metadata, submitter IDs, or internal compliance evidence to the partner browser unless a separately reviewed need is established.
8. Use SECURITY DEFINER only if necessary to bridge the current table grants; use empty search_path and fully-qualified object names. Revoke EXECUTE from PUBLIC and anon; grant only authenticated. Validate JWT identity inside the function. Keep the function narrowly scoped and run advisors/review before deployment.
9. Keep direct SELECT on `krim_partner_capabilities` denied. Do not add broad grants as a shortcut.

The page should then call this RPC once, replacing its three direct SELECTs. Membership and organization discovery can remain as current RLS-scoped queries, but the RPC must independently revalidate organization type, membership, permission and active status; frontend checks are not authorization.

## Required authorization and contract tests
Use independent real Partner A and Partner B JWT sessions, not service-role impersonation.

- Partner A + Org A: succeeds; only Org A capabilities returned.
- Partner A + Org B: denied with a stable authorization error.
- Partner B + Org B: succeeds; only Org B capabilities returned.
- Partner B + Org A: denied.
- Customer org, enterprise, platform, customs, finance, operations: denied.
- Each candidate partner org type: tested only after owner approves allowlist.
- Active membership without `partner.manage`: denied.
- Revoked/inactive membership, inactive organization, null ID, unknown ID: denied.
- Anonymous call: denied; PUBLIC and anon EXECUTE absent.
- Response keys exactly match contract; no evidence paths, private metadata or cross-tenant rows.
- Countries/modes contain only active reference records; deterministic sort and empty-result behavior tested.
- Existing direct browser SELECT on capabilities/catalogues remains denied.
- Existing submission RPC behavior remains unchanged by the read migration.

## Remaining blockers
- No local Supabase/Postgres harness or pinned CLI has been established.
- Staging Data API exposed-schema/extra-search-path settings still require owner dashboard verification.
- Partner organization type allowlist needs owner/product confirmation.
- No independent partner test identities/orgs exist in Staging; do not provision fixtures until a side-effect-safe plan and explicit approval exist.
- No migration or frontend change is authorized or prepared for deployment in this audit.

## Status
- Frontend caller path and exact direct reads: source-inspected.
- Membership/organization RLS: verified read-only.
- Direct SELECT grant mismatch: verified read-only.
- Unified workspace RPC: design recommendation only; not created.
- Tests: specified, not run.
- Phase 00: OPEN — NOT APPROVED.
- Production: NOT ACCESSED OR CHANGED.
