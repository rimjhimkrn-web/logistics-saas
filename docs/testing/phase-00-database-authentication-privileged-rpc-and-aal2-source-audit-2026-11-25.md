# Phase 00 — Database-Side Authentication, Privileged RPC and AAL2 Source Audit
Date: 2026-11-25
Repository: rimjhimkrn-web/logistics-saas
Branch: qa/phase-00-baseline-2026-11-25

## Executive verdict

**Source audit completed; backend authorization is partly implemented, but global enforcement is NOT VERIFIED.** Several important database controls explicitly derive identity from auth.uid(), require active membership and permissions, and enforce AAL2 for selected administrative mutations. Partner verification writes are routed through an audited AAL2 RPC. Driver invitations have email binding, expiry, row locking and one-time state transition.

However, this is a bounded migration-source review, not an exhaustive proof of every callable function, deployed function definition, effective ACL, RLS policy or Edge Function. The prior audit recorded 26 SECURITY DEFINER functions requiring review. No live SQL, Supabase advisors, Auth configuration, runtime RPC calls or writes were performed in this task.

## 1. Source files inspected

| Migration | Source SHA | Control examined |
|---|---|---|
| 20261019020919_restrict_privileged_krim_rpc_to_authenticated.sql | e54ace7323fcdd311e5612df435ca0bbe736bc4c | Execute grants for privileged KRIM RPCs |
| 20261105081710_scope_cross_workspace_read_policies_to_permissions.sql | 28031318fbffd1d79953fb56c0ed27b1ad7e500f | Cross-workspace read policy permission scoping |
| 20261105084623_require_active_membership_for_permission_checks.sql | 79aa651a9924941e89ee5e62907b6013b1925b9c | Shared permission helper |
| 20261105062300_enforce_aal2_on_admin_inquiry_followup.sql | e0cbfcc3c0941102e3f911b6963badc783c33e98 | Admin RPC AAL2 check |
| 20261105102900_enforce_aal2_on_global_rate_card_admin_rpcs.sql | 03d18d334f6609ee9d7dc0652f129da7a428b6c4 | Global rate-card admin AAL2 guard |
| 20261115123000_restrict_partner_verification_case_mutations_to_aal2_rpc.sql | c57f7090943166d3443d71be4b68ce3914b9b9 | Direct table mutation removal |
| 20261115123500_bind_partner_verification_approval_to_evidence_owner.sql | c1986de90e104331883be34a51f762312f8383e3 | Admin review authorization and evidence ownership |
| 20261104193000_secure_driver_membership_invitations.sql | 10d6dbf5780ebc234beb5db8a94e6e9c8be68649 | Driver invitation creation and acceptance |
| 20261104195500_rate_limit_and_validate_carrier_driver_invitations.sql | 0694dc1ffe98753d743a664f9025cb90b50e33e8 | Invitation permission and rate limit |
| 20261123101000_refine_admin_driver_licence_expiry_rpc_security.sql | ea45a8d63a3b01ac2b8b73fbb7ecb16ce6578f62 | Private definer helper and invoker wrapper |

Repository tree at this ref contains 368 SQL migration files and 21 Edge Function entrypoints. This review sampled the migrations listed above; it did not inspect every one of those files or deployed objects.

## 2. Positive backend controls observed

### A. Active membership and organization status in shared permission helper

private.krim_has_permission(p_user_id, p_organization_id, p_permission_code):
- Requires auth.uid() to be null or equal to the supplied p_user_id.
- Joins role assignments to granted role permissions and permission catalog.
- Requires the organization membership to be active.
- Requires the organization itself to be active.
- Requires the role assignment to be active and scoped to the same user and organization.
- Matches the requested permission code.

This closes an important stale-role path after membership suspension/removal. For normal authenticated JWT requests, a caller cannot ask this helper to authorize a different user ID.

**Review caveat:** the helper is SECURITY DEFINER and its auth.uid() IS NULL branch allows service/backend contexts to evaluate a supplied user ID. That may be intentional for trusted internal jobs, but every call site and EXECUTE grant must be reviewed to ensure an untrusted caller cannot reach it with a null-auth context. Do not expose this helper as a general public authorization API.

### B. Cross-workspace read policy narrowing

The reviewed policy migration replaces broad membership-only reads with domain permissions such as:
- shipment.view
- compliance.view
- finance.view

Some shipment reads also bind the record through its customer organization. This is stronger than treating any authenticated organization member as authorized to read every workspace dataset.

### C. Selected admin mutations require AAL2 server-side

The inspected admin inquiry follow-up, global rate-card admin, partner verification review and driver licence expiry flows check the JWT aal claim for aal2 in database code. They also check admin.platform permission, not merely a browser-side MFA flag.

The driver licence expiry migration keeps the SECURITY DEFINER implementation in the private schema and exposes a SECURITY INVOKER wrapper. This is a preferable pattern when the public API wrapper does not need elevated privileges itself.

### D. Partner verification approval is constrained

The review RPC:
- Requires auth.uid().
- Requires AAL2.
- Requires admin.platform permission.
- Validates the decision and rejection reason.
- Locks the case row.
- Restricts approval to an active registered-business logistics organization.
- Requires core registration/location metadata.
- Requires submitted document paths to match organization and submitter prefixes.
- Confirms the object exists in the private krim-partner-verification bucket and is owned by the original submitter.

A separate migration removes authenticated INSERT/UPDATE/DELETE grants on the case table and drops direct mutation policies, routing decisions through the audited RPC.

### E. Driver invitation lifecycle

The inspected functions:
- Require an authenticated creator.
- Require partner.manage permission and an eligible verified/compliant registered-business organization.
- Limit invitation creation volume.
- Store an invitation token hash and expiry.
- On acceptance, bind the signed-in email to the invitation email.
- Require pending status and unexpired token.
- Lock the invitation row and serialize membership creation with an advisory transaction lock.
- Check that the carrier organization remains eligible.
- Mark the invitation accepted and write an audit event.

The inspected function body therefore has meaningful replay and wrong-email defenses. The full lifecycle still needs controlled tests and deployed-definition parity verification.

## 3. High-priority concerns and verification gaps

### SEC-RPC-01 — Effective EXECUTE ACLs are not established

The 20261019020919 migration grants EXECUTE on a set of SECURITY DEFINER public RPCs to authenticated. The inspected file does not itself show matching REVOKE EXECUTE FROM PUBLIC/anon statements for those signatures.

PostgreSQL functions normally receive EXECUTE for PUBLIC unless that default is revoked. A GRANT to authenticated does not, by itself, remove inherited PUBLIC access. This is a **verification blocker**, not proof that the deployed functions are anonymously callable: an earlier migration or altered default privileges may revoke it. The effective ACL must be queried for every SECURITY DEFINER function, including PUBLIC, anon, authenticated and service_role.

Required: enumerate deployed function identities, prosecdef, proconfig/search_path, owner, and aclexplode(proacl) or has_function_privilege checks. Do not infer effective ACLs from one grant migration.

### SEC-RPC-02 — SECURITY DEFINER inventory still needs complete review

Prior audit reported 26 SECURITY DEFINER functions flagged. The current sample confirms the pattern is used in both carefully guarded functions and helpers. Every exposed public-schema definer routine must be reviewed for:
- auth.uid() check or explicit trusted service-only access;
- active membership and operation-specific permission;
- AAL2 for sensitive admin writes;
- fixed safe search_path and schema-qualified objects;
- explicit EXECUTE revocation from PUBLIC/anon;
- argument validation and tenant binding;
- audit events and transaction/locking behavior.

Do not assume every definer function is vulnerable; do not assume every one is safe because selected examples are guarded.

### SEC-RPC-03 — AAL2 coverage is selective, not global

The inspected migrations demonstrate AAL2 for selected admin operations. They do not establish AAL2 for all high-impact finance, partner, customs, warehouse, driver, export, account-management or other admin mutations. Build a complete privileged-RPC inventory and map each operation to its required assurance level. Confirm the aal claim is verified by Supabase Auth and cannot be forged by a client.

### SEC-RPC-04 — Permission helper execution boundary

The helper's SECURITY DEFINER and null-auth branch require a complete call-site and ACL review. The intended trusted backend/service context should be distinguished from authenticated browser RPC calls. Never use user_metadata as an authorization source.

### SEC-RPC-05 — Driver invitation token storage and disclosure

The creation RPC returns the raw invitation token to the caller while storing an MD5 hash. The token appears to be generated from two UUIDs, which is a strong random token shape, but MD5 is not a password hashing algorithm. For high assurance, store a modern cryptographic digest (for example SHA-256) of a high-entropy random token, keep the raw token out of logs/audit rows, and ensure it is delivered only to the invited email through a trusted sender. The inspected SQL does not prove delivery or secure handling after the RPC response.

### SEC-RPC-06 — Driver invitation creator function history

The later rate-limit migration changes the creator signature to include p_organization_id. The earlier one-argument function is also visible in the inspected history. The current deployed catalog must be checked for legacy overloads, stale grants and old entrypoints that might bypass the stricter organization-specific implementation. The later migration must not be assumed to have removed every legacy overload without checking the complete migration history and live catalog.

### SEC-RPC-07 — JWT claim freshness and session revocation

Permission checks query active membership/role tables, which helps avoid stale membership authorization. AAL2 checks use auth.jwt()->>'aal'. Validate that sensitive operations reject stale or revoked sessions according to the defined policy; changing membership does not automatically revoke an already-issued JWT. Test session_id / auth.sessions validation where strict revocation is required.

## 4. Required backend negative tests — NOT RUN

Run only in a proven isolated Staging project with synthetic users and explicit approval:

| ID | Test | Expected |
|---|---|---|
| RPC-AUTH-01 | Anonymous calls each privileged public RPC | Rejected; no data mutation |
| RPC-AUTH-02 | PUBLIC/anon attempts EXECUTE on every SECURITY DEFINER function | Denied unless specifically documented public endpoint |
| RPC-AUTH-03 | Authenticated user supplies another user_id to permission helper/call site | Denied |
| RPC-AUTH-04 | User has role assignment but no active organization membership | Denied |
| RPC-AUTH-05 | Membership inactive or organization suspended | Denied immediately on protected operation |
| RPC-AUTH-06 | Active member lacks exact permission code | Denied |
| RPC-AUTH-07 | User tampers with user_metadata role/admin claims | No privilege change |
| RPC-AUTH-08 | AAL1 user calls AAL2 admin RPC directly | Denied at database boundary |
| RPC-AUTH-09 | AAL2 lookup/claim missing or malformed | Fail closed |
| RPC-AUTH-10 | Cross-organization ID supplied to finance/partner/warehouse RPC | Denied; no cross-tenant result |
| RPC-AUTH-11 | Partner verification table direct INSERT/UPDATE/DELETE | Denied; guarded review RPC required |
| RPC-AUTH-12 | Non-admin or AAL1 user invokes partner verification review | Denied; no case mutation |
| RPC-AUTH-13 | Admin attempts approval with another submitter's evidence path | Denied |
| RPC-AUTH-14 | Driver invitation accepted by wrong email | Denied; invitation remains pending |
| RPC-AUTH-15 | Expired, replayed or concurrently accepted invitation | Exactly one acceptance; subsequent calls denied |
| RPC-AUTH-16 | Legacy one-argument invitation RPC called | Removed or equally protected; no bypass |
| RPC-AUTH-17 | Dynamic search_path/object-shadowing payload against definer function | No privilege escalation |
| RPC-AUTH-18 | Revoked membership with still-valid JWT calls privileged RPC | Denied by fresh database permission check |
| RPC-AUTH-19 | Revoked session/refresh token calls sensitive RPC | Denied according to strict session policy |
| RPC-AUTH-20 | Duplicate/replayed mutation request | Idempotent or safely rejected; no duplicate business action |

## 5. Required read-only catalog verification before Staging tests

Obtain and retain evidence for:
1. All public and private SECURITY DEFINER functions: schema, identity arguments, owner, search_path, ACL and function body hash.
2. Effective EXECUTE privileges for PUBLIC, anon, authenticated and service_role.
3. Every function accepting a user ID, organization ID, role code, permission code, AAL-sensitive operation or object/document path.
4. All calls to private.krim_has_permission and whether caller context is authenticated or trusted backend.
5. All AAL2 checks mapped to privileged write RPCs and Edge Functions.
6. Public Edge Function JWT verification settings and any intentionally unauthenticated routes.
7. RLS policies and table grants for high-risk finance, membership, admin, partner verification and document tables.
8. Deployed migration ledger and deployed function definitions compared with the QA source revision.

No production writes or schema changes are authorized by this audit. Read-only catalog queries are still to be scheduled under the controlled test plan.

## 6. Status and release decision

| Control | Status |
|---|---|
| Active membership and active organization check in shared permission helper | PASS — migration source inspected |
| Domain permission narrowing in sampled cross-workspace reads | PASS — migration source inspected |
| AAL2 in sampled admin RPCs | PASS — selected RPCs only |
| Partner verification direct table mutation restriction | PASS — migration source inspected |
| Partner verification evidence-owner binding | PASS — migration source inspected |
| Driver invitation email/expiry/one-time flow | PASS — migration source inspected; runtime not tested |
| Effective function EXECUTE ACLs across catalog | NOT TESTED |
| Complete SECURITY DEFINER inventory | NOT TESTED |
| Complete AAL2 coverage for privileged operations | NOT TESTED |
| Helper call-site and null-auth boundary review | NOT TESTED |
| Legacy driver invitation overload retirement | NOT TESTED |
| JWT/session revocation behavior | NOT TESTED |
| Runtime negative RPC tests | NOT TESTED |
| Production/Staging parity | NOT VERIFIED |

**Release decision:** Do not authorize unrestricted real-user onboarding or unrestricted admin/finance operations on this evidence. Keep Phase 00 IN PROGRESS. No evidence = no pass.

Safety: QA-branch read-only source review only. No database connection/query, SQL execution, migration, configuration change, user creation, provider call, deployment or merge was performed.
