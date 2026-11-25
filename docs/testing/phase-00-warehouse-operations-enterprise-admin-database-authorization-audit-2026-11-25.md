# Phase 00 — Warehouse, Operations, Enterprise and Admin database authorization audit

Date: 2026-11-25  
Repository: `rimjhimkrn-web/logistics-saas`  
Ref: `qa/phase-00-baseline-2026-11-25`  
Supabase projects inspected read-only:
- Production: `ebltviniygljwwseplph`
- Staging: `qrpcivhdxobiaofppbkl`

Scope: Read-only inspection of PostgreSQL function definitions, SECURITY DEFINER flags, effective EXECUTE privileges for `anon` and `authenticated`, selected RLS policies, and the server-side authorization logic behind Warehouse, Operations, Enterprise-shared flows and Admin vehicle/capacity operations. No function was invoked, no RPC was tested with a user JWT, no SQL mutation was run, and no Production or Staging data/configuration was changed.

## Executive verdict

**Database source review: PARTIAL PASS. Runtime authorization: NOT VERIFIED. Real-user onboarding: NOT APPROVED.**

The Production database contains several good defense-in-depth controls:
- Warehouse RPCs check the caller identity and resolve a verified warehouse operator for the exact organization/facility.
- Warehouse inventory quality review enforces an independent reviewer, private uploader-owned inspection evidence, and evidence checks on receipt history.
- Warehouse transfer quality review enforces destination-facility operator access, separation from dispatcher/receiver, reviewer-owned private evidence, idempotency and audit records.
- Vehicle administration RPCs delegate to a database guard requiring AAL2 and `admin.platform`; review also prevents self-approval.
- Operations shipment snapshot access checks active Operations membership and shipment-level `shipment.view` permission.
- Operations dispatch readiness filters records using the authenticated caller's `shipment.dispatch` permission for the relevant partner organization.
- Sensitive finance refund review requires AAL2, active finance/platform/operations membership and a finance permission in the underlying private function.

Important blockers:
1. **Staging EXECUTE parity is materially incomplete** for sampled Warehouse, Operations, vehicle-admin and refund functions. Effective `authenticated` EXECUTE was false for all 14 sampled high-risk public functions in Staging, while several corresponding Production functions were executable. Staging cannot presently prove these workflows through the same RPC surface without an approved parity plan.
2. **Enterprise has no clearly named `krim_enterprise_*` RPC family** in the Production catalog search. Its server-side boundary therefore appears to rely on shared shipment/approval RPCs and RLS. A complete Enterprise page-to-RPC map and policy proof remains necessary; do not interpret absence of a prefix as a vulnerability by itself.
3. **Operations dispatch readiness and Warehouse quality flows are privileged SECURITY DEFINER functions.** Their source contains meaningful checks, but only negative runtime tests can prove those checks work with real JWT claims and cross-tenant identifiers.
4. **`krim_dispatch_shipment` has no effective authenticated EXECUTE in Production or Staging.** This may be intentionally server-only, but the actual dispatch path must be confirmed; do not assume the browser can call it directly.
5. No synthetic identities or test records were used, so no direct-call, wrong-role, AAL1, cross-tenant or replay attempt was made.

## Evidence: Production database

### 1. Warehouse RPC authorization — SOURCE PASS WITH RUNTIME GATE

The sampled functions are SECURITY DEFINER, not ordinary invoker functions. This makes their internal authorization checks especially important.

| RPC | Production authenticated EXECUTE | Source evidence |
|---|---:|---|
| `krim_warehouse_dashboard` | Yes | Authenticated user; active organization membership; eligible warehouse organization; `partner.manage` permission |
| `krim_warehouse_list_tasks` | Yes | Authenticated user; filters through `krim_warehouse_is_operator(user, organization, facility)` |
| `krim_warehouse_transition_task` | Yes | Authenticated user; task-specific organization/facility operator check; valid state machine; idempotency key |
| `krim_warehouse_review_inventory_quality` | Yes | Authenticated user; verified operator; reviewer differs from task creator/completer; completed task; private independent inspection evidence; inventory SKU/lot/facility match; receipt history revalidated |
| `krim_warehouse_review_transfer_quality` | Yes | Authenticated user; verified destination operator; reviewer differs from dispatcher and receiver; reviewer-owned private evidence; destination inventory hold; idempotency; audit event |

Additional quality safeguards found:
- Inventory quality review will not proceed without a completed goods receipt/damage exception task.
- It rejects a second final decision on the same task.
- Evidence must belong to the expected private warehouse bucket and exact organization/uploader path, be owned by the uploader, have an allowed MIME type and be no larger than 10 MB.
- Every receipt contributing to the SKU/lot balance is checked for completed goods-receipt task, independent review and valid inspection evidence before stock can be released.
- Transfer review uses a transaction advisory lock and rejects conflicting idempotency replays.
- Task transitions lock the task row, validate permitted status transitions and write task/audit events.

**Caveat:** These RPCs do not all contain a literal `krim_has_permission` call. The warehouse operator helper is used instead. Its full implementation and all downstream helper semantics must be verified, and its effective check must prove active membership, active/approved facility, eligible warehouse organization, and the appropriate partner management permission. No runtime tests were run.

### 2. Operations RPC authorization — SOURCE PARTIAL PASS

- `krim_operations_list_shipment_snapshots(p_limit)`: Production authenticated EXECUTE is enabled. The function checks `auth.uid()`, bounds the limit to 1–100, requires active Operations organization membership, and then filters returned shipments using `krim_has_permission(user, customer_organization_id, 'shipment.view')`.
- `krim_operations_dispatch_readiness()`: Production authenticated EXECUTE is enabled. It is SECURITY DEFINER SQL and includes caller/role checks: the caller must be authenticated (or service role), and non-service callers must hold `shipment.dispatch` on the relevant partner organization. The returned rows are built from accepted/active partner assignments and exact shipment legs, with readiness blockers for partner compliance, completed warehouse handover, verified driver/vehicle, payload, active multi-leg plan and exact-leg authorization.
- `krim_dispatch_shipment(...)`: Production authenticated EXECUTE is false (also false in Staging). Its function body begins with an `auth.uid()` requirement, but this effective ACL means the browser's authenticated role cannot directly invoke it through the exposed RPC. This may be intentional; confirm the authorized dispatch path and any trusted server-side caller before treating dispatch as operational.

Potential role-model question:
- The dispatch-readiness RPC checks `shipment.dispatch` on the partner organization. Confirm that this is the intended permission for Operations Control Tower users, rather than an Operations-specific view/dispatch permission. The page-level permission and function-level permission should match the agreed KRIM role model.

### 3. Admin vehicle verification — SOURCE PASS; ACL/route proof required

- `krim_vehicle_admin_guard()` requires a non-null `auth.uid()`, JWT AAL exactly `aal2`, and `private.krim_has_permission(user, 1, 'admin.platform')`.
- `krim_vehicle_admin_vehicle_list()`, `krim_vehicle_review_queue()`, `krim_vehicle_review_document()`, `krim_vehicle_finalize_verification()`, `krim_vehicle_refresh_expiry()` and `krim_vehicle_requirement_list()` delegate to that guard.
- Document review rejects a reviewer who created the document and rejects already-finalized decisions.
- Vehicle finalization rejects the vehicle registrant and requires a defined country/category document profile and required documents.
- Expiry refresh is not a public maintenance endpoint; it first calls the AAL2 platform-admin guard before changing expired documents/vehicle operational state.

The guard function itself has no direct `authenticated` EXECUTE privilege, which is appropriate for an internal helper. The guarded RPCs have effective authenticated EXECUTE in Production. The vehicle tables also have explicit deny-direct-API policies for `anon` and `authenticated`, pushing access through guarded RPCs.

### 4. Admin capacity listing — TRANSITIVE GUARD FOUND

- `krim_admin_list_capacity_resources()` has authenticated EXECUTE and source checks for `auth.uid()`, `admin.platform` permission and AAL2.
- `krim_admin_list_capacity_resources_lane_aware()` is SECURITY DEFINER and does not repeat those checks in its own body, but it delegates to the guarded `krim_admin_list_capacity_resources()` before enriching the result with lane availability. This is a transitive security dependency and should remain explicit in future reviews.
- It is not currently evidence of a bypass, but a future refactor that removes the inner guard would expose the wrapper. Consider making the wrapper call the same shared admin guard directly as defense in depth.

### 5. Finance refund authorization — SOURCE PARTIAL PASS

- Private `krim_refund_request_review` requires authenticated identity, AAL2, active finance/platform/operations organization membership, and `finance.manage` or appropriate platform permission in the underlying review flow.
- Private `krim_refund_request_submit` requires authenticated identity, a payment order, positive amount, meaningful reason, idempotency key and only allows full refunds for paid, not-yet-refunded orders pending full partial-refund accounting.
- Public wrappers expose only authenticated execution in Production; `anon` cannot execute.
- Staging wrappers do not have effective authenticated EXECUTE in the sampled catalog.
- Refund request review is a request/approval workflow, not proof of provider-side refund completion. No refund provider call was made.

### 6. Enterprise — SHARED AUTHORIZATION MODEL NOT FULLY MAPPED

A catalog search did not find a dedicated `krim_enterprise_*` RPC family in Production. The Enterprise workspace therefore appears to consume shared shipment, approval, document and finance functions. Some shared shipment policies use organization-scoped access helpers.

This audit does not yet prove that every Enterprise approval, export, shipment, document and finance route maps to a backend function with the correct enterprise role and tenant boundary. A separate mapping of each Enterprise page action to its exact RPC, table policy and permission code is still required.

## Evidence: RLS and direct table access

Selected Production policies include:
- Warehouse tasks, events, receipts, inventory, movements and evidence: authenticated SELECT policies bind rows to active membership, eligible warehouse organization and active/approved facility; transfer reads use the warehouse operator helper.
- Vehicle, vehicle-document, driver-binding and vehicle-requirement tables: explicit deny-direct-API policies for both `anon` and `authenticated`.
- Shipment and shipment child tables: selected policies use organization-access or shipment-view helpers; partner-side policies use active assignment checks.
- Refund request and event reads: participant and authorized finance membership checks.
- Payment orders: customer ownership or active finance membership plus `finance.view`.
- Shipment financials and payment webhook events: explicit deny policies for direct client roles.

Observations:
- `krim_shipment_status_transitions` and `krim_shipment_transition_rules` have authenticated read policies with `USING (true)`. These appear to be global workflow catalogue/rule data, not customer shipment records; confirm they contain no tenant-private metadata.
- RLS policy presence does not by itself prove table grants, write checks, or SECURITY DEFINER RPC correctness. The prior audit's RLS table/grant inventory remains applicable.
- A full RLS review of all Enterprise-shared tables and all nine workspace tables is not complete in this pass.

## Production vs Staging effective EXECUTE parity

For the following sampled high-risk functions, Production has authenticated EXECUTE while Staging does not:
- `krim_operations_dispatch_readiness`
- `krim_operations_list_shipment_snapshots`
- `krim_vehicle_admin_vehicle_list`
- `krim_vehicle_finalize_verification`
- `krim_vehicle_refresh_expiry`
- `krim_vehicle_review_document`
- `krim_vehicle_review_queue`
- `krim_vehicle_requirement_list`
- `krim_warehouse_dashboard`
- `krim_warehouse_list_tasks`
- `krim_warehouse_review_inventory_quality`
- `krim_warehouse_review_transfer_quality`
- `krim_warehouse_transition_task`

Other sampled functions such as `krim_dispatch_shipment` are non-executable by authenticated in both environments. Private refund wrappers also differ in effective authenticated grants between environments.

This is a **Staging testability and parity blocker**, not a reason to copy Production grants blindly. The Stage catalog has a large migration-count discrepancy from Production, and grant drift must be reconciled against the intended migration history and security model before any change. Do not alter either environment based on this report alone.

## Findings requiring follow-up

1. Inspect the full `private.krim_warehouse_is_operator` and `private.krim_warehouse_org_eligible` implementations, including their nested helper permissions and facility approval logic.
2. Map every Enterprise page action to the exact shared RPC/table and prove its organization and role permission.
3. Confirm whether Operations users are expected to hold `shipment.dispatch` on partner organizations for readiness visibility; separate view permission from dispatch mutation permission if needed.
4. Confirm the intended caller for `krim_dispatch_shipment` and prove its trusted execution path.
5. Reconcile Staging migrations/ACLs and create a controlled parity matrix before enabling runtime tests; do not grant functions simply to make the test pass.
6. Verify each SECURITY DEFINER function has a fixed safe search_path and explicit caller checks; all sampled core functions use an empty or explicit search_path, but a complete function-wide audit remains separate.
7. Run isolated Staging negative tests only after the Staging origin, synthetic identity isolation and provider test sinks are proven: unauthenticated, AAL1, wrong role, inactive membership, wrong organization, cross-facility, cross-shipment, self-approval, evidence ownership mismatch, idempotency conflict and revoked membership.
8. Do not invoke dispatch, warehouse transition, quality review, vehicle expiry, admin review, refund or provider operations on Production during QA.

## Release decision

| Area | Source evidence | Runtime result |
|---|---|---|
| Warehouse task and facility scope | Partial pass | Not tested |
| Warehouse independent quality review | Strong source safeguards | Not tested |
| Operations shipment snapshots | Membership + shipment permission | Not tested |
| Operations dispatch readiness | Caller + partner dispatch permission | Not tested |
| Enterprise shared RPC/RLS | Incomplete mapping | Not tested |
| Admin vehicle verification | AAL2 + platform permission guard | Not tested |
| Admin capacity lane-aware listing | Transitive guarded call | Not tested |
| Finance refund review | AAL2 + finance/platform membership/permission | Not tested |
| Staging RPC parity | Significant missing authenticated grants | Blocked |

**Real-user onboarding: NOT APPROVED.** The source review is encouraging for several privileged flows, but runtime authorization, cross-tenant isolation and Staging parity have not passed.

No code, database schema, policies, grants, data, Auth settings, secrets, users, storage objects, provider calls or deployments were changed. NO EVIDENCE = NO PASS.
