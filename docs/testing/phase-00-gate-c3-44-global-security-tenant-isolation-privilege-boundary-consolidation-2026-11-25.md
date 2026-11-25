# C3.44 — Global security, tenant isolation and privilege boundary consolidation

Date: 2026-11-25  
Repository: rimjhimkrn-web/logistics-saas  
Environment: immutable source baseline `72d75a18f985ceb09e468839435ee95700e11e46`  
QA branch: `qa/phase-00-baseline-2026-11-25`  
Method: read-only inspection of selected migration source and previously recorded dated security findings. No live database/security-advisor execution.

## Scope and source evidence

Selected immutable-baseline migrations:
- `20261105081710_scope_cross_workspace_read_policies_to_permissions.sql`: permission-scoped SELECT policies for exceptions, invoices, settlements, shipment alerts, customs and milestones.
- `20261105084623_require_active_membership_for_permission_checks.sql`: `private.krim_has_permission` requires matching caller identity (unless `auth.uid()` is null), active role assignment, active membership and active organization.
- `20261115111500_harden_customer_and_partner_organization_provisioning.sql`: SECURITY DEFINER customer/partner provisioning functions check `auth.uid()`, validate names and serialize per-user provisioning; partner provisioning detects ambiguous active partner memberships.
- `20261115123000_restrict_partner_verification_case_mutations_to_aal2_rpc.sql`: removes direct authenticated INSERT/UPDATE/DELETE and directs decisions through audited AAL2 review RPC.
- `20261123101000_refine_admin_driver_licence_expiry_rpc_security.sql`: private SECURITY DEFINER helper checks authenticated identity, AAL2, platform-admin permission, required reason and audit event; public wrapper is SECURITY INVOKER and delegates to helper.
- `20261106110000_revoke_direct_execution_of_dispatch_trigger.sql`: revokes client execution of a trigger-only synchronization function.
- `20261107152000_customs_document_storage_and_broker_read_policies.sql`: scoped customer/accepted-broker customs reads and organization/user-bound storage path checks.

Historical context from the 2026-10-31 Supabase audit: 343 public tables; four RLS-enabled tables without policies; 26 SECURITY DEFINER functions flagged for review; leaked-password protection disabled. These are dated findings, not a claim about today's live state. Later migrations add meaningful controls, but no fresh catalog/advisor snapshot was taken in this gate.

## Positive controls — PARTIAL PASS

1. Cross-workspace read policies replace broad organization membership access with domain permission checks for selected shipment, customs and finance records.
2. Permission evaluation checks active membership and active organization in addition to active role assignment and granted permission.
3. Selected self-service provisioning functions require `auth.uid()`, validate input, serialize duplicate creation and reject ambiguous active partner organization membership.
4. Partner verification case mutations are removed from direct authenticated DML and reserved for the AAL2 review workflow.
5. Selected high-impact driver licence administration uses a private guarded SECURITY DEFINER helper and SECURITY INVOKER public wrapper, with MFA, permission, reason and audit checks.
6. Trigger-only dispatch synchronization no longer needs client EXECUTE permission.
7. Customs storage policies bind evidence paths to active organization membership and uploader identity; reads are scoped to customer or accepted broker, with a separate AAL2 platform-admin condition.

These controls are selective source-level safeguards. They do not certify every table, view, function, storage bucket, Realtime channel, RPC, Edge Function or deployed grant.

## P0 — Complete tenant-isolation matrix is missing

No exhaustive table × operation × role × tenant × parent-resource matrix was verified across all 343 historical public tables and the current baseline's full schema. Selected policies demonstrate permission-aware access, but do not prove that every exposed public table has appropriate RLS, correct grants, safe policies for SELECT/INSERT/UPDATE/DELETE, immutable tenant ownership, and correct parent/child binding. Four RLS-enabled tables without policies in the historical 31 Oct audit may have been intentionally deny-all, but require explicit classification; absence of policies alone is not proof of exposure or vulnerability.

**Required:** fresh catalog inventory of schemas/tables/views/materialized views, grants, RLS/force-RLS, policies and exposed Data API objects; classify every no-policy table as intentionally inaccessible or fix; test cross-tenant read/write denial for every domain and nested child relationship. Include anonymous, authenticated, anonymous-authenticated session, service role, owner and platform-admin contexts.

## P0 — SECURITY DEFINER and EXECUTE privilege inventory not closed

Historical 31 Oct audit flagged 26 SECURITY DEFINER functions. Subsequent migrations intentionally use SECURITY DEFINER for privileged internal logic, but the repository contains a large RPC surface and selected hardening changes alone do not prove all function owners, search paths, EXECUTE ACLs, schema exposure, caller identity checks or nested helper grants are safe. PostgreSQL's default PUBLIC EXECUTE behavior makes grant verification essential for newly created public functions. The inspected AAL2 wrapper is a positive pattern, not evidence that all privileged RPCs follow it.

**Required:** enumerate every function/procedure, owner, SECURITY DEFINER/INVOKER, language, volatility, search_path, schema, PUBLIC/anon/authenticated/service_role EXECUTE grants, direct and transitive calls. Revoke unnecessary PUBLIC/anon access, keep privileged implementations in non-exposed schemas, use empty/fixed safe search_path and schema-qualified objects, assert caller identity and tenant authority inside the privileged body, and verify grants after every migration. Review trigger functions separately.

## P0 — Identity, membership and role lifecycle edge cases remain untested

The selected permission helper allows `auth.uid() IS NULL OR auth.uid() = p_user_id`. For normal authenticated policy evaluation, caller identity is expected to be non-null and match. The null branch is a privileged-context exception whose reachability must be bounded by function ACLs and call graph; it must not become an unauthenticated impersonation path. Membership/role revocation, stale JWT claims, suspended organization, multiple memberships, user deletion with extant tokens, session revocation and concurrent role changes were not tested. The historical audit also recorded leaked-password protection disabled; current Auth configuration was not checked.

**Required:** prove only trusted server/internal callers can reach null-UID helper paths; reject caller-supplied identity mismatch; test immediate revocation and stale token/session behavior; verify app_metadata-only authorization claims; inspect MFA enrollment/recovery/AAL requirements and current leaked-password protection settings.

## P1 — Provisioning and privileged-review flows need broader boundary tests

Customer/partner provisioning source checks authenticated identity and validates legal-name input. Partner flow rejects more than one active partner organization and reuses an existing active organization. Still unverified: role escalation through organization/member provisioning, organization-type coercion, unauthorized owner transfer, duplicate concurrent onboarding, cross-tenant identifiers, and whether every direct DML route is revoked. AAL2 review controls need tests for recovery/fallback sessions, self-review, reviewer separation, evidence owner and immutable audit history.

## P1 — Storage, views, Realtime and client exposure not fully certified

Selected customs storage path policies bind organization and uploader; this does not establish equivalent protections for every private evidence bucket, public asset bucket, signed URL issuer, download route, object move/copy, delete, or metadata operation. Views can bypass RLS unless security-invoker semantics are explicitly used or access is otherwise restricted. No complete view inventory or Realtime publication/row-filter authorization review was performed. Frontend bundle and deployed configuration were not scanned in this gate for leaked service-role/secret keys.

**Required:** bucket × operation × role matrix, path traversal/forged metadata/object overwrite/delete tests, short-lived signed URL authorization/revocation checks, view security_invoker/owner/grants audit, Realtime tenant-isolation tests and client artifact secret scan.

## P1 — Security controls need runtime adversarial evidence

No cross-tenant negative tests, privilege-escalation attempts, IDOR/BOLA probes, anonymous Data API checks, direct RPC execution tests, stale-session tests, MFA bypass tests, storage path attacks, or Edge Function authorization tests were executed. No fresh Supabase Security Advisor, Auth configuration, deployed API exposure or logs were inspected. Source-only findings cannot be represented as penetration-test or compliance certification.

## Required closure evidence

- Current catalog export: all schemas, tables, views, RLS/force-RLS, policies, grants, function definitions/owners/ACLs, storage buckets/policies and Realtime publications.
- Complete role/permission × tenant × resource matrix for all nine ecosystems.
- Automated two-tenant negative suite: read, insert, update, delete, RPC, storage, signed URL, view and Realtime isolation.
- SECURITY DEFINER call-graph and EXECUTE ACL review, including PUBLIC inheritance and null-auth paths.
- Auth tests: revoked/suspended membership, stale JWT, deleted user/session, AAL1/AAL2, MFA recovery, app_metadata trust and leaked-password protection.
- Independent retest of historic 31 Oct findings and C3.39/C3.42/C3.43 P0s.
- Evidence artifacts with environment, commit, timestamp, actor, request/correlation IDs, expected/actual and reproducible negative outcomes.

## Gate disposition

| Area | Status |
|---|---|
| Selected permission-scoped RLS and active membership guards | PARTIAL PASS |
| Selected AAL2 privileged review and admin wrapper | PARTIAL PASS |
| Selected provisioning identity/input safeguards | PARTIAL PASS |
| Complete table/tenant/operation RLS and grants matrix | NOT TESTED |
| Complete SECURITY DEFINER / EXECUTE ACL closure | FAIL / BLOCKED |
| Auth/session/MFA configuration and revocation | NOT TESTED |
| Storage, views, Realtime and client secret exposure | NOT TESTED |
| Runtime cross-tenant and privilege-escalation suite | NOT TESTED |
| Overall C3.44 | **FAIL / BLOCKED** |

**NO-GO:** do not certify tenant isolation, security readiness, regulated evidence handling, privileged admin controls or full operational onboarding from this source review. No claim of penetration-test completion or compliance certification.

**Safety:** No Production/Staging SQL, Supabase advisors, Auth configuration, role/grant changes, Storage, Realtime, Edge Function calls, secret reads, provider requests, deployment, merge or external communication were performed.
