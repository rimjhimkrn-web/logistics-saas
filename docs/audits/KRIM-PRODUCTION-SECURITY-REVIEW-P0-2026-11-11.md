# KRIM Production Security Review — P0 follow-up — 11 November 2026

## Scope
Read-only review of selected live PostgreSQL function definitions and grants, current Supabase security advisor output, and the repository's privileged Edge Function. No production schema, data, roles, grants, secrets, Auth settings, or deployed functions were changed.

## Verified catalog results
- Public-schema SECURITY DEFINER functions: **307**.
- SECURITY DEFINER functions with an explicit function-level `search_path` setting: **307 / 307**.
- SECURITY DEFINER functions with no function-level `search_path` setting: **0**.
- Functions configured with empty search path: **152**.
- Supabase advisor warning: **126** SECURITY DEFINER functions are executable by the authenticated role. This is an exposure inventory, not proof that all 126 are exploitable. Each exposed function must be checked for the correct user, organisation, role, permission, object ownership and state-transition checks.
- A representative privilege check confirmed `public.krim_transition_shipment(bigint,text,text,jsonb)` is executable by `service_role`, but not by `anon` or `authenticated`.

## Selected function review

### `krim_accept_global_quote(bigint)`
The current production definition has an empty search path and performs the following checks before customer acceptance:
- locks the quote and shipment rows;
- verifies quote and shipment customer-organisation consistency;
- checks active organisation access and `shipment.update` permission;
- requires a sent, unexpired customer quote and a quoted shipment;
- requires a linked, valid partner quote with matching amount/currency;
- requires an accepted shipment-partner assignment before confirming the shipment.

This is a useful fail-closed control. It still requires integration tests for cross-tenant access, expired offers, mismatched currencies/amounts, rejected or withdrawn offers, concurrent acceptance and duplicate retries.

### `krim_create_global_shipment(...)`
The current production definition checks authenticated organisation access and `shipment.create` permission, validates active origin/destination locations and operational country activation, and creates a shipment in `draft` state. It does not itself establish provider availability or confirm a booking. This is consistent with the rule that a shipment draft/request is not a confirmed logistics service.

### `krim_transition_shipment(...)`
The current production function uses an explicit `search_path = pg_catalog, public` and is not executable by `anon` or `authenticated`; the privilege check showed `service_role` only. Preserve that boundary unless a separately reviewed, permission-checked user-facing RPC is designed. Do not grant direct authenticated execution simply to make a UI button work.

### `krim_warehouse_review_inventory_quality(...)`
The current production definition checks an authenticated user, completed goods-receipt/damage task, warehouse operator access, separation of reviewer from task creator/completer, required inspection report, inventory/task organisation and facility match, and a constrained quality decision with reason. Add negative tests for cross-organisation, cross-facility, creator self-review, missing evidence and repeated review.

### `krim_admin_list_partner_capabilities()`
The current production definition checks authenticated user, AAL2 and `admin.platform` permission, and limits the review queue to pending submissions with evidence paths that are correctly scoped to organisation and submitting user and backed by owned storage objects.

## Privileged Edge Function review: `global-admin-control`
The checked-in function:
- requires a Bearer token and validates it with `auth.getUser()`;
- requires current MFA assurance level AAL2;
- checks active server-side `platform_admin` / `platform_superadmin` assignments using the service role;
- restricts role/user administration mutations to platform superadmin;
- validates inquiry status, note length and follow-up outcome inputs;
- uses server-side database access and does not ship the service-role key to the browser.

### Finding requiring remediation
Its `audit()` helper awaits an insert into `krim_audit_events` but ignores the returned Supabase `error`. Therefore an admin operation may succeed even when its audit event fails to persist. Sensitive admin mutations should move to transactional database RPCs that commit the mutation and audit event atomically, or use an explicit durable intent/completion pattern with idempotent reconciliation. Merely throwing after a PostgREST insert failure is not atomic and can report failure after the mutation has already occurred.

### Additional acceptance checks
- Confirm platform role assignment rows are active and the lookup cannot be confused by duplicate or malformed role relationships.
- Confirm the expected `admin.platform` permission model matches the platform role assignment check.
- Test all admin actions as signed-out, AAL1, ordinary authenticated, platform_admin and platform_superadmin users.
- Test audit-table failure and verify sensitive mutations cannot silently complete without a durable audit trail.
- Test concurrent role revocation during an admin request and ensure access is rechecked at the mutation boundary.
- Confirm the browser guard remains defense-in-depth only; server-side Edge Function authorization is authoritative.

## P0 remediation plan
1. Export all 126 advisor-flagged authenticated-executable SECURITY DEFINER function names, signatures, grants, settings and definitions into a controlled review inventory.
2. Classify each as intentionally callable or server-only. Revoke only after tracing frontend/mobile/Edge Function callers and validating replacement paths.
3. For each intentionally callable function, record checks for auth identity, active membership, organisation scope, role/permission, object ownership, state and idempotency.
4. Convert privileged admin mutations to atomic database RPCs with audit events in the same transaction.
5. Classify the 26 RLS-enabled/no-policy tables individually. Private service-only tables may be intentional; public tables need explicit access decisions. Do not add broad policies.
6. Enable leaked-password protection in Supabase Auth after checking user-impact and supported Auth configuration; this setting was not changed in this review.
7. Run a dedicated staging security matrix before production rollout.

## Release decision
P0 is **in progress, not complete**. The function-level search-path baseline is positive, and selected critical functions show strong access/state controls. However, the 126 exposed SECURITY DEFINER review, 26 no-policy table classifications, admin audit durability, leaked-password protection and authenticated end-to-end tests remain open. Do not declare the platform security-complete or open paid checkout yet.


## RLS no-policy privilege classification — read-only follow-up
The live catalog was queried for every RLS-enabled table with zero policies, including direct table privileges for `anon`, `authenticated` and `service_role`.

Result:
- **26 / 26** findings had no direct SELECT, INSERT, UPDATE or DELETE privilege for `anon`.
- **26 / 26** had no direct SELECT, INSERT, UPDATE or DELETE privilege for `authenticated`.
- **25 / 26** had direct `service_role` SELECT privilege.
- `private.krim_ai_rate_limits` had no direct SELECT privilege for `service_role` either; this may be accessed through a narrowly scoped privileged function or another controlled path and needs a call-path review.
- The 21 public-schema tables among these findings are therefore not directly readable or writable by the browser's anon/authenticated database roles, based on the current grants queried. They are still exposed-schema objects and require confirmation that only intended server-side code accesses them.
- No broad RLS policies were added. These findings are now classified as **likely intentional service-only / deny-by-default**, pending verification of every service-role Edge Function/RPC caller and API schema exposure.

This materially narrows the RLS remediation: do not add policies simply to clear the advisor. Preserve the deny-by-default grants and document each privileged access path. The RLS advisor warning may remain for intentionally service-only tables.


## Authenticated-callable SECURITY DEFINER inventory — static triage batch 1

The live catalog was queried for all public-schema SECURITY DEFINER functions for which the authenticated role has EXECUTE. This inventory returns **126 functions**, all with anon EXECUTE false in the same catalog privilege checks.

### Family distribution
| Function family | Count |
|---|---:|
| Platform admin | 53 |
| Driver | 11 |
| Partner | 9 |
| Customer / shipment lifecycle | 11 |
| Vehicle / fleet | 16 |
| Warehouse | 14 |
| Other shared functions | 12 |
| **Total** | **126** |

### Static guard-pattern indicators
Across the 126 function definitions:
- 116 reference `auth.uid()` directly.
- 53 reference `auth.jwt()`.
- 52 explicitly check AAL2.
- 52 explicitly check `admin.platform`.
- 83 reference a KRIM permission helper.
- 9 reference the organisation-access helper.
- 69 reference `private.krim_has_permission`.
- 51 use row locking (`FOR UPDATE`).
- 8 include an idempotency/replay pattern.
- 15 inspect `storage.objects`.

These are static indicators only. A text match is not proof of correct authorization, and the absence of a direct check is not automatically a vulnerability when a function delegates to a separately guarded function.

### Admin-family review
52 of 53 `krim_admin_*` functions explicitly include both AAL2 and `admin.platform` permission checks. The remaining function, `krim_admin_list_capacity_resources_lane_aware()`, delegates first to `krim_admin_list_capacity_resources()`, which independently enforces:
1. non-null `auth.uid()`;
2. AAL2;
3. `private.krim_has_permission(user, 1, 'admin.platform')`.

The wrapper returns only the already-authorized result plus lane availability details. This is an inherited guard path, not an unguarded admin endpoint based on the inspected definition. Add a regression test to ensure this delegation remains intact.

### Functions without a direct `auth.uid()` reference
Ten functions lacked a direct `auth.uid()` string reference in their own definition:
- `krim_admin_list_capacity_resources_lane_aware()` delegates to the guarded admin list function above.
- `krim_partner_register_capacity_resource_for_lane(...)` delegates to the guarded base capacity-registration function before attaching the lane to the returned availability record.
- `krim_partner_submit_service_capability_v2(...)` delegates to the base capability submission function, then attaches bounded metadata to the returned capability.
- Six vehicle administration functions call `public.krim_vehicle_admin_guard()` to establish the authenticated administrator context before acting.
- `krim_vehicle_refresh_expiry()` also uses the same guard; it is a privileged maintenance action and should be invoked only by an authorised admin/scheduler pathway, not a general user client.

The delegation paths were inspected in the live definitions. Regression tests must verify that the guard helper itself enforces the expected identity, MFA and permission, and that no replacement overload bypasses it.

### High-priority follow-up review
The broad static inventory is not a substitute for per-function business-logic review. Highest-risk next targets are:
1. shipment/customer quote, assignment, driver acceptance and delivery-POD transitions;
2. partner capability, compliance evidence, service area and capacity registration;
3. vehicle/driver binding, document review, expiry suspension and maintenance execution;
4. support ticket, exception and escalation actions;
5. warehouse evidence, inventory and QC transitions.

For every function, tests must cover unauthenticated execution, wrong organisation, insufficient permission, wrong object owner, self-approval, invalid state, expired evidence, concurrent request and duplicate retry as relevant.

## Current disposition
- The 126-function authenticated-execution inventory is now captured and grouped.
- No function grants were changed or revoked. This is intentional: revoking a callable RPC without tracing every web/mobile/Edge Function caller could break production workflows.
- No broad grants or policies were added.
- The review is **still in progress** until function-by-function test evidence and a full call-site map exist.
