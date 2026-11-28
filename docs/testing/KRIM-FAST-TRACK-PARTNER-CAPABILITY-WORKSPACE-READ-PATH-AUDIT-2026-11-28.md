# KRIM Fast-Track — Partner Capability Workspace Read-Path Audit
Date: 2026-11-28
Branch: staging/phase00-env-isolation
Database: Staging project qrpcivhdxobiaofppbkl
Disposition: READ-PATH BLOCKER IDENTIFIED; NO FIX APPLIED

## Scope
Read-only inspection of the current partner capability workspace source, deployed Staging table privileges and relevant RPC inventory/definition. No function was invoked and no database or repository source was modified in this checkpoint.

## Frontend execution paths
File: public/partner/services-capabilities.html
Blob: 12a0d32dd5e850165cf92acf252b0f75c8482156

The page has two distinct runtime branches:
1. If hostname is exactly krim-staging.pages.dev, it calls stagingPreview() and returns before Supabase initialization. It shows illustrative local-only data. No account data is read, no file is uploaded and no RPC is called.
2. On other hostnames, it authenticates the user, reads active memberships, reads partner organizations, then directly selects from public.krim_partner_capabilities, countries and transport modes. It renders the capability register and uses krim_partner_submit_service_capability_v2 for new evidence-backed submissions.

The staging hostname preview is therefore not an authenticated integration test and does not verify the production-style database read path.

## Staging database privilege result
RLS is enabled on public.krim_partner_capabilities and an organization-access SELECT policy exists. However, the authenticated database role has no direct SELECT, INSERT or UPDATE table privilege in the inspected snapshot. service_role has SELECT.

A row policy cannot grant a table privilege. The current non-preview frontend direct SELECT therefore has no demonstrated usable access path under the inspected authenticated role. The current UI does not call a partner-scoped capability-list RPC.

## Existing RPC inventory
Staging contains public.krim_admin_list_partner_capabilities(), SECURITY DEFINER, EXECUTE for authenticated but not anon. Its definition requires:
- auth.uid() present;
- JWT AAL2;
- private.krim_has_permission(user, platform org 1, admin.platform).

It returns platform-admin pending capability records only, with evidence completeness checks. It is not an appropriate partner workspace list API and must not be repurposed or relaxed.

The capability submit RPC krim_partner_submit_service_capability_v2 is executable by authenticated and is insert-oriented. No partner-scoped list/read RPC was found in the targeted capability/service RPC inventory.

## Required safe read API
Create a dedicated, narrowly scoped partner read RPC (versioned name to be selected after API naming review), returning only the caller's active partner-organization capability declarations and the minimum fields required by the workspace.

Security requirements:
- derive user from auth.uid();
- require a valid active organization membership and partner.manage or a dedicated partner capability read permission;
- validate organization type, lifecycle and tenant scope server-side;
- never accept an arbitrary organization id without checking membership and permission;
- return only the caller's organization records, never cross-tenant data;
- do not expose private Storage paths, owner UUIDs, reviewer notes or internal security metadata;
- use a fixed, explicit search_path and schema-qualified object references;
- REVOKE EXECUTE from PUBLIC and anon; grant EXECUTE only to authenticated;
- keep direct table privileges closed;
- test with two independent partner tenants and a non-partner account.

The RPC should include a stable capability_id, category/coverage mapping, active and verification state, and a safe evidence/review summary. If multiple organizations are permitted, the UI must require an explicit organization selection or safely display separated organization scopes.

## Review-linkage dependency
The existing admin list RPC reads evidence_paths and submitted_by from capability metadata and verifies each Storage object. A future append-only submission-history model must update the admin review/read path to reference a specific submission version. Do not let a review decision attach ambiguously to “latest evidence” where concurrent or later resubmissions are possible.

## Safe implementation sequence
1. Define and test partner-scoped read RPC in an isolated local test database or disposable Staging fixture.
2. Add automated SQL tests for tenant isolation, active membership, permission, wrong-org access, AAL requirements where applicable, and field minimization.
3. Update workspace to use RPC instead of direct capability table SELECT.
4. Introduce append-only evidence submission versions and a version-specific review contract.
5. Update admin review list and review action to select/review a specific submission version.
6. Verify all RPC grants, RLS, Storage ownership, audit lineage and advisor output.
7. Only then consider a Staging deployment after migration review, backup/rollback confirmation and explicit approval.

## Evidence limitations
- This is a Staging source/catalog audit, not a live browser execution or authenticated user test.
- No test users or partner fixture records were provisioned.
- No RPC was invoked.
- No SQL migration, grant, policy, table or function was created or changed.
- No upload, notification, email, payment or external provider was invoked.
- Production was not accessed.
- Full repository-wide dynamic/indirect caller certification remains open.

## Result
The partner workspace's Staging preview is intentionally non-functional for account data. The non-preview code path uses a direct capability table SELECT that is not supported by the current authenticated table privilege snapshot. A narrowly scoped partner read RPC is required; the platform-admin list RPC is not a substitute.

Phase 00 remains OPEN. Phase 01 remains unauthorized.
