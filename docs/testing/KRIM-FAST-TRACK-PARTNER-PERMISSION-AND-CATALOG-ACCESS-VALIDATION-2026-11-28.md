# KRIM Fast-Track — Permission and Reference-Catalog Access Validation
Date: 2026-11-28
Environment: Staging project qrpcivhdxobiaofppbkl; read-only
Branch: staging/phase00-env-isolation
Status: VALIDATION COMPLETE — NO SCHEMA CHANGE

## 1. Partner permission catalogue
The current permission catalogue contains:
- partner.manage — system permission, resource_type=partner, action=manage.
- admin.platform — system permission, resource_type=platform, action=admin.
No partner.read or partner.capability.read permission code was found in the targeted lookup.

The existing private.krim_has_permission(p_user_id uuid,p_organization_id bigint,p_permission_code text) helper:
- is SECURITY DEFINER with explicit search_path public, pg_catalog;
- requires auth.uid() not null and equal to p_user_id;
- checks an active user role assignment, granted role-permission mapping, active membership and active organization.
- authenticated EXECUTE true; anon EXECUTE false.

Implication: partner.manage is currently the canonical existing authorization capability for the workspace. A read-only permission would require a deliberate permission-catalogue/role-mapping migration and rollout; do not invent a permission code in the read RPC. For the initial read API, reuse partner.manage unless product/security owners approve a separate read permission and update all relevant partner role mappings atomically.

## 2. Exact table SELECT privilege snapshot
The direct has_table_privilege check on Staging returned:

| Table | authenticated SELECT | anon SELECT | service_role SELECT |
|---|---:|---:|---:|
| krim_countries | false | false | true |
| krim_transport_modes | false | false | true |
| krim_organization_members | true | false | true |
| krim_organizations | true | false | true |
| krim_partner_capabilities | false | false | true |

RLS SELECT policies exist for:
- krim_countries: authenticated, USING true.
- krim_transport_modes: authenticated, USING true.
- krim_organization_members: authenticated, user_id = auth.uid().
- krim_organizations: authenticated, active membership or AAL2 platform admin.

RLS policies do not grant SQL table privileges. Therefore:
- The partner page's direct membership and organization reads have an explicit authenticated SELECT grant and scoped RLS policies.
- Its direct country and transport-mode catalogue reads have SELECT policies but no authenticated SELECT table privilege; these reads are also blocked at the table privilege layer.
- Its direct capability read has no authenticated SELECT privilege and must be replaced by a tenant-scoped RPC.
- Do not assume a policy means the frontend can SELECT the table.
- Do not solve this by broadly granting SELECT on the capability table.

## 3. Required API split
Keep authorization and response minimization explicit:

A. Partner capability list RPC
- Reuse canonical partner.manage for exact organization scope.
- Return only the partner's own capabilities and safe evidence/review summary.
- Never return raw metadata or evidence object paths.
- Keep direct capability table SELECT closed.

B. Reference catalog access
Two safe options remain for country and transport-mode catalogues:
1. Explicitly grant authenticated SELECT on those reference tables while retaining/enabling RLS with the existing authenticated read-only USING(true) policies, after confirming the tables contain only intended public reference fields and no sensitive columns; or
2. Add narrowly scoped read-only catalogue RPC(s) returning only id/name/code/is_active/category fields.

Do not grant INSERT/UPDATE/DELETE. Verify column contents and RLS before choosing option 1. If table-level SELECT would expose sensitive columns, use option 2.

## 4. Frontend read-path patch scope
The current public/partner/services-capabilities.html non-preview branch directly reads:
- krim_organization_members
- krim_organizations
- krim_partner_capabilities
- krim_countries
- krim_transport_modes

After this validation, a complete functional patch requires:
- partner capability RPC for capability rows;
- a safe country catalogue access path;
- a safe transport-mode catalogue access path;
- retain existing membership/organization reads only after checking exact columns and policies;
- keep partner submission RPC unchanged in this isolated patch.

The exact krim_has_permission helper and current role mapping should be the authorization source. Do not rely on the frontend's membership list as proof of partner.manage.

## 5. Security tests to add
- A with partner.manage on Org A reads only A capabilities.
- B with partner.manage on Org B reads only B capabilities.
- A→Org B and B→Org A denied.
- Active membership without partner.manage denied.
- Revoked/inactive membership denied.
- No partner.read code assumed or accepted until provisioned.
- Anonymous denied.
- Direct SELECT on capabilities remains false.
- Country/mode catalog reads reveal only approved reference fields.
- No writes possible via catalog access.
- Admin approval remains AAL2 + admin.platform and cannot be invoked through partner list API.

## 6. Evidence and limitations
- Frontend source: public/partner/services-capabilities.html, blob 12a0d32dd5e850165cf92acf252b0f75c8482156.
- Permission catalogue lookup found partner.manage and admin.platform; no partner.read/capability.read.
- private.krim_has_permission definition was inspected directly.
- Table privilege check used has_table_privilege for authenticated, anon and service_role.
- RLS policies were inspected independently from table privileges.
- No authenticated browser session was used, so this is a catalog-backed access diagnosis, not a live UI request trace.
- No schema change, grant, policy, RPC, fixture, upload, notification or deployment was performed.
- Production was not accessed.

## Disposition
Permission contract validated: use partner.manage for initial scoped read RPC.
Reference catalog access remains a separate blocker: countries and transport modes also lack authenticated SELECT grants despite read policies.
Next step: inspect reference table column sensitivity and the full frontend rendering requirements, then finalize one minimal Staging-only patch and executable two-tenant tests.

Phase 00 remains OPEN. Phase 01 remains unauthorized.
