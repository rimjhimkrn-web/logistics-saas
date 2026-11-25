# Phase 00 — SECURITY DEFINER and privileged RPC authorization audit

**Date:** 2026-11-25  
**Repository:** `rimjhimkrn-web/logistics-saas`  
**Supabase projects:** Production `ebltviniygljwwseplph`; Staging `qrpcivhdxobiaofppbkl`  
**Method:** Read-only PostgreSQL catalog inspection (`pg_proc`, ACLs, function definitions, owners, language, `proconfig`) and targeted source-body review. No function was invoked.

## Executive status

**BLOCKED — privileged RPC authorization is not release-certified.**

The live catalogs contain hundreds of SECURITY DEFINER functions. The count differs materially between Production and Staging, and Staging has one SECURITY DEFINER trigger function with effective anonymous EXECUTE privilege. No unpinned SECURITY DEFINER search_path was found in the catalog snapshots. No Production SECURITY DEFINER function was executable by anon in the catalog snapshot. However, the audit identified public callable privileged RPCs, caller-supplied actor/organization arguments, and several older helper/operations endpoints whose complete business authorization must be independently verified.

| Catalog measure | Production | Staging |
|---|---:|---:|
| Non-system functions inspected | 632 | 626 |
| SECURITY DEFINER functions | 474 | 488 |
| SECURITY DEFINER functions executable by anon | 0 | 1 |
| SECURITY DEFINER functions executable by authenticated | 174 | 47 |
| SECURITY DEFINER functions without a fixed search_path | 0 | 0 |
| Authenticated-executable definers with no literal `auth.uid()` in their body | 14 | 4 |

The last row is a triage indicator, not a vulnerability count: trigger functions and wrappers may correctly delegate to guarded functions, and authorization can be performed by a helper such as `krim_vehicle_admin_guard()`.

## Positive controls

1. All inspected SECURITY DEFINER functions pin `search_path` using `proconfig`; none were found without a fixed search path.
2. Production has no SECURITY DEFINER function executable by `anon` in the inspected catalog.
3. Client-callable helper `private.krim_has_organization_access(p_user_id,p_organization_id)` and `private.krim_has_permission(p_user_id,p_organization_id,p_permission_code)` bind the supplied user to `auth.uid()` whenever a JWT user exists. Their null-auth branch is relevant to trusted backend/trigger execution; it must not be exposed as a client impersonation route.
4. Customs review/transition helpers inspected require an authenticated user and AAL2, and perform further organization/role checks in their bodies.
5. Vehicle review functions call `public.krim_vehicle_admin_guard()`; verification also rejects self-approval of the vehicle registrant.
6. Core shipment/driver/dispatch RPCs inspected derive the actor from `auth.uid()` and check permission for the assignment's partner organization.

## Findings

### RPC-01 — SECURITY DEFINER inventory is large and differs between environments
**Severity: HIGH / governance and parity blocker**

Production has 474 SECURITY DEFINER functions, Staging 488. The total non-system function counts also differ (632 vs 626). This is not a reason to blindly copy or drop functions: Supabase-managed schemas include internal trigger and extension functions. However, the 14-function count difference and the 127-function difference in authenticated-executable definer count require a canonical application-function allowlist and deployment parity review.

**Required action:** Generate a checked-in inventory of application-owned functions by schema, signature, owner, ACL, security mode, search_path and migration provenance. Compare the application-owned signatures in both environments; classify platform-managed functions separately.

### RPC-02 — One Staging SECURITY DEFINER trigger function is effectively executable by anon
**Severity: LOW direct exposure; MEDIUM ACL hygiene**

Staging `private.krim_require_warehouse_handover_before_shipment_dispatch()` has default ACL and catalog privilege checks report anon/authenticated EXECUTE. It is a trigger-returning function, which PostgreSQL does not permit callers to invoke as an ordinary scalar/table RPC. It is designed to run from a trigger and enforces accepted partner assignment, exact shipment leg and private warehouse-handover proof before dispatch.

This is not a demonstrated direct RPC exploit. Still, its ACL should be explicitly restricted to the trigger execution model (revoke client EXECUTE/PUBLIC as appropriate, while preserving trigger behavior) in an approved Staging migration, then checked in the live catalog. Production has no corresponding anon-executable definer.

### RPC-03 — Caller-supplied actor/organization arguments require strict identity binding
**Severity: HIGH review priority**

The following privileged functions accept actor or organization identity arguments. The parameter alone is not proof of a defect; each body must independently derive the caller from `auth.uid()` and compare the supplied organization to an active membership/permission. The reviewed customs functions do contain authentication/AAL2 and further actor checks, but this must be asserted by automated tests and kept consistent across overloads:

- `private.krim_claim_review(p_claim_id, p_decision, p_approved_amount, p_note, p_actor_organization_id)`
- `private.krim_customs_broker_assign(p_customs_record_id, p_broker_organization_id, p_actor_organization_id, p_note)`
- `private.krim_customs_broker_close(p_assignment_id, p_action, p_actor_organization_id, p_note)`
- `private.krim_customs_document_review(p_submission_id, p_decision, p_note, p_actor_organization_id)`
- `private.krim_customs_transition_case(p_customs_record_id, p_actor_organization_id, p_target_status, p_note)`
- `public.krim_assign_driver_to_partner_shipment(p_partner_assignment_id, p_driver_user_id)`
- `public.krim_vehicle_driver_bind(p_organization_id, p_vehicle_id, p_driver_user_id)`

**Required action:** Add adversarial tests that spoof another organization ID, another driver ID, the customer organization instead of broker organization, and an actor UUID/organization pair from another tenant. Ensure all functions derive actor identity from JWT and treat caller-supplied IDs only as target resource identifiers, never as authority.

### RPC-04 — Two partner submission wrappers do not directly reference auth.uid()
**Severity: MEDIUM / delegated authorization must be proven**

The following authenticated-executable SECURITY DEFINER wrappers do not contain a literal `auth.uid()` in their own function bodies:
- `public.krim_partner_register_capacity_resource_for_lane(...)`
- `public.krim_partner_submit_service_capability_v2(...)`

The first validates the lane and delegates to `public.krim_partner_register_capacity_resource(...)`; the second validates bounded JSON metadata and delegates to `public.krim_partner_submit_service_capability(...)`. The wrappers do not themselves visibly authenticate the actor or prove that the supplied `p_organization_id` belongs to the caller. Security therefore depends on the delegated function's guard. The delegated base functions were not fully re-audited in this focused pass.

**Required action:** Verify both base functions require auth.uid(), active organization membership and exact partner.manage/appropriate permission, and reject a caller-supplied organization they do not control. Prefer adding an explicit wrapper-level guard for defense in depth.

### RPC-05 — Legacy admin and vehicle function families need full role/permission review
**Severity: MEDIUM**

Production's authenticated-executable definer inventory includes legacy and current functions. Examples include:
- `public.krim_admin_list_capacity_resources_lane_aware()` — wrapper calls `krim_admin_list_capacity_resources()`; confirm the delegated function has current admin authorization and returns only fields intended for the caller.
- `public.krim_vehicle_admin_vehicle_list()`, `krim_vehicle_finalize_verification(...)`, `krim_vehicle_review_document(...)`, `krim_vehicle_review_queue()`, `krim_vehicle_set_document_requirement(...)` — each calls `krim_vehicle_admin_guard()`; verify that guard checks active admin permission and required AAL2, and test creator/reviewer separation.
- Older functions such as `public.accept_partner_shipment`, `public.accept_shipment_quote`, `public.create_partner_payout`, `public.complete_partner_payout`, `public.update_partner_cost`, `public.has_role` and `public.is_admin` should be classified as supported, deprecated-but-secured, or retired. The sampled bodies use auth.uid()/role checks in several cases, but role model compatibility and caller ACLs must be confirmed.

**Required action:** Maintain an allowlist of callable RPC signatures for each client workspace; revoke EXECUTE on superseded/unused overloads only after code-reference and dependency analysis. Do not remove functions solely by name or guess.

### RPC-06 — Private helper EXECUTE grants need intentional classification
**Severity: MEDIUM**

In Production, the two private permission helpers are executable by authenticated users but not anon. Their body binds the supplied user ID to auth.uid() for authenticated requests. This is currently consistent with the intended helper use. The null-auth branch permits trusted backend execution and is safe only while the helpers remain non-anonymous and every privileged caller preserves its own auth boundary.

The same helpers are service-role-only in Staging, demonstrating environment ACL drift. Do not broaden Staging grants without understanding the call paths and required client helper calls.

### RPC-07 — SECURITY DEFINER functions are not automatically protected by RLS
**Severity: HIGH design rule**

The function owner executes with owner privileges and can bypass ordinary table RLS. Therefore, the table policies audited in the prior RLS report cannot be treated as protection for any SECURITY DEFINER body. Every callable function must enforce authentication, role/permission, active organization membership, tenant binding, input validation, idempotency and audit behavior itself. Trigger-only functions must be treated separately from RPCs.

## Specific authorization tests — NOT RUN

Run only with synthetic users and isolated Staging after parity remediation:

1. Anonymous calls to every intended authenticated RPC are denied.
2. Ordinary authenticated user calls every admin RPC at AAL1: denied.
3. Non-admin AAL2 user calls platform admin RPC: denied.
4. Admin AAL1 calls AAL2-gated action: denied.
5. User A supplies User B UUID as `p_driver_user_id`: denied unless the caller has dispatch permission for the assignment's organization and the target driver is an eligible active member.
6. User A supplies another tenant's `p_organization_id` to capacity/capability submission: denied.
7. Broker A supplies a different broker/customer organization as `p_actor_organization_id`: denied.
8. Caller supplies another user's UUID to `krim_has_permission` or `krim_has_organization_access`: false.
9. Stale/revoked membership cannot invoke a previously authorized RPC.
10. Repeated payment/quote/dispatch/approval calls with the same idempotency key do not duplicate effects.
11. Concurrent duplicate calls cannot create duplicate assignments, financial postings or approvals.
12. Superseded overloads cannot bypass the current permission/MFA checks.
13. Trigger guard still blocks shipment dispatch without exact-leg warehouse handover after its ACL is tightened.
14. No service-role key or secret is present in browser code or public responses.

All 14 tests remain **NOT TESTED**.

## Release gates and remediation order

1. **P0:** Resolve the Production finance direct-write gap from the previous RLS report. RPC hardening alone does not compensate for direct authenticated table grants.
2. **P0:** Verify delegated base-function authorization for partner capacity and capability submission wrappers.
3. **P0:** Test caller-supplied actor/organization/driver ID spoofing across customs, driver, vehicle and partner RPCs.
4. **P1:** Restrict the Staging trigger function's effective client EXECUTE ACL while preserving trigger execution.
5. **P1:** Reconcile application-owned function signatures/ACLs between Production and Staging; do not attempt wholesale migration copy or function drops.
6. **P1:** Build CI checks that fail on new SECURITY DEFINER functions without fixed search_path, explicit ACL, auth/permission checks or a documented trigger/internal exemption.
7. **P2:** Deprecate or remove legacy RPCs only after confirming no live frontend/Edge Function/migration dependency.

## Evidence and safety

- Read-only catalog queries inspected all non-system function metadata in both environments and retrieved targeted function definitions.
- No function was invoked; no API request was made.
- No SQL DDL/DML, grants/revokes, migration, test-user creation, authentication action, payment action, notification, Storage action, deployment or branch merge was performed.
- Findings are source/catalog-level. Runtime exploitability is not claimed without the negative tests above.
