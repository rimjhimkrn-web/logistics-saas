# KRIM Fast-Track Day 1 — Partner Capability Read Contract & Least-Privilege Implementation Gate
Date: 2026-11-28
Environment inspected: Staging only (`qrpcivhdxobiaofppbkl`)
Branch: `staging/phase00-env-isolation`

## Current confirmed implementation facts

### Partner capability submission
The deployed `public.krim_partner_submit_service_capability_v2`:
- is SECURITY DEFINER with an empty search_path;
- is executable by authenticated, not anon;
- delegates to `public.krim_partner_submit_service_capability`;
- derives caller identity from `auth.uid()`;
- requires `private.krim_has_permission(uid, organization_id, 'partner.manage')`;
- verifies active registered-business partner organization and current compliance;
- verifies active transport mode and country;
- verifies 1–5 private evidence objects are under the exact organization/user capability folder and owned by the caller;
- creates an inactive pending capability and returns `capability_id`, `verification_status`, `active`, and `evidence_count`.
The v2 wrapper then writes only equipment details and operational constraints into metadata.

### Admin-only list and review are not partner APIs
`public.krim_admin_list_partner_capabilities()` is SECURITY DEFINER, requires auth.uid(), AAL2 and `admin.platform`, and returns all pending capabilities including organization identifiers, metadata and evidence-related context. It is not safe to reuse for partner accounts.
`public.krim_admin_review_partner_capability(bigint,text,text)` is also SECURITY DEFINER, AAL2 + `admin.platform`, and is a separate approval workflow. It validates compliance, evidence path/owner, self-approval and specialist capability restrictions. Keep it admin-only.

### Permission helper
`private.krim_has_permission(uuid,bigint,text)` checks the supplied user matches auth.uid(), and requires an active role assignment, granted permission, active organization membership and active organization. This is the existing canonical permission primitive for `partner.manage`.

## Selected minimal access design

### Reference catalogues
For `public.krim_countries` and `public.krim_transport_modes`:
- Both have RLS enabled and an authenticated SELECT policy with predicate `true`.
- The country fields used by the page (`id,name,code,is_active`) exist. Additional fields are public reference data (ISO codes, currency, timezone, region, languages, source metadata).
- The transport-mode fields used by the page (`id,name,code,is_active,category`) exist.
- Current role grants show service_role only; authenticated SELECT is absent.
- Recommended implementation: grant authenticated SELECT only on these two reference tables; retain RLS and its authenticated-only SELECT policy; do not grant anon or any write privilege. This is simpler and narrower than a new RPC for public reference data. Confirm effective API exposure and test after change.

### Partner capability register
Do not grant authenticated table SELECT or return the admin-list RPC.
Add a dedicated partner read RPC with this contract:
- one required organization ID argument, validated using `auth.uid()` and `private.krim_has_permission(auth.uid(), p_organization_id, 'partner.manage')`;
- active partner organization type/status check;
- return only the page's necessary fields: capability id, organization id, transport mode id, service type, country id, region, max weight, refrigerated/hazardous flags, active, verification status, effective dates, created_at, and the two bounded display details (equipment_details, operational_constraints);
- never return `metadata` wholesale, evidence_paths, submitter UUID, reviewer UUID, storage object names, private notes, or unrelated organizations;
- deterministic order by created_at descending, id descending;
- unauthenticated and unauthorized calls fail closed;
- SECURITY DEFINER only if required to read the protected table, empty search_path, fully qualified object references, explicit auth.uid()/permission checks, and explicit EXECUTE grant to authenticated with PUBLIC/anon revoked;
- expose only the function through the Data API. No direct capability-table grant.

The organization ID supplied by the UI is not trusted; it is only a selector. The database permission check is the authorization boundary. A user with partner.manage in Org A must not retrieve Org B records.

## Frontend patch contract
Replace the direct `krim_partner_capabilities` query with the new RPC. Keep country and mode reads as direct SELECT from their two narrowly granted catalogues. Remove the `metadata` selection and map only the safe fields returned by the RPC. Preserve the separate evidence submission RPC and its current response contract. Keep the illustrative Staging preview clearly marked and do not count it as a live test.

## Required test matrix
1. Partner A + Org A: sees only Org A safe capability rows.
2. Partner A + Org B argument: permission denied, no rows.
3. Partner B + Org B: sees only Org B rows.
4. Partner B + Org A argument: permission denied, no rows.
5. Authenticated non-partner/no partner.manage: denied.
6. Unauthenticated/anon: denied; RPC EXECUTE unavailable.
7. Platform admin without partner.manage: no implicit partner read bypass.
8. Capability response contains no evidence paths, metadata, submitter/reviewer identity or storage object names.
9. Country/mode catalogues: authenticated SELECT works; anon and all writes remain denied.
10. Existing submit RPC still creates pending/inactive record only after genuine eligible partner session and valid private evidence.

## Implementation gate
This is a reviewed contract, not deployed code. Before writing/applying migration:
- inspect full schema and grants for all joined objects;
- verify PostgREST exposed schemas and function execute ACL;
- establish local PostgreSQL/Supabase test harness and fixture session strategy;
- build SQL tests for cross-tenant and non-partner cases;
- create migration via the pinned/verified CLI workflow (CLI v3 hosted commands require explicit `--remote`; never target Production);
- review SQL and obtain explicit Staging-only approval before applying.
Do not invoke submission/review RPCs or provision test users as part of this read-only audit.

## Current Supabase guidance
- Supabase RLS docs recommend explicit minimal grants plus RLS; views bypass RLS by default unless `security_invoker=true` on PostgreSQL 15+.
- Supabase's Data API exposure change was enforced for existing projects on 2026-10-30: grants and RLS are separate gates.
- Supabase CLI v3 uses local database commands by default; hosted commands require explicit `--remote`, and unattended hosted changes require `--yes`.

## Scope
Read-only Staging catalog/function/source review and design documentation only. No database mutation, grant, migration, frontend edit, RPC invocation, fixture creation, upload, notification, or deployment. Production untouched. Phase 00 remains OPEN.
