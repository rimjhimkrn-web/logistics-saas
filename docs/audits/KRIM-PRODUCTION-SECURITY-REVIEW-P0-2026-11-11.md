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
