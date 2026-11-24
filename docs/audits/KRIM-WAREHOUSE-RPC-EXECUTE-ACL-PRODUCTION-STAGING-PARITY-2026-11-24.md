# KRIM warehouse RPC EXECUTE ACL production/staging parity finding — 2026-11-24

## Scope and method
Read-only catalog inspection in production project `ebltviniygljwwseplph` and isolated staging project `qrpcivhdxobiaofppbkl`. For selected SECURITY DEFINER functions, compared `pg_proc.proacl` and effective `has_function_privilege(role, function_oid, 'EXECUTE')` for `anon`, `authenticated` and `service_role`. No grants or schema were changed.

## Verified result

| RPC family / representative functions | Production authenticated EXECUTE | Staging authenticated EXECUTE | anon EXECUTE |
|---|---:|---:|---:|
| Driver accept / trip event / delivery POD | Yes | Yes | No |
| Warehouse task list | Yes | No | No |
| Warehouse evidence registration | Yes | No | No |
| Warehouse task transition | Yes | No | No |
| Warehouse task creation | Yes | No | No |
| Warehouse facility registration | Yes | No | No |

Staging warehouse RPCs in the inspected SECURITY DEFINER family are granted to `service_role` and postgres, but not `authenticated`. Production has explicit `authenticated` EXECUTE grants for the representative warehouse functions above. This is a real environment parity mismatch, not merely a source-code difference.

The reviewed warehouse function bodies include `auth.uid()` and facility/operator authorization checks. However, those checks are only exercised when a caller can execute the RPC. The production grant does not itself prove the whole browser-to-database workflow is safe, and the staging denial does not prove the UI is correctly mediated through an Edge Function.

## Required next work
1. Trace all warehouse UI call sites and any Edge/server functions to establish the intended call path.
2. If browser clients are intended to call these RPCs directly, verify every function's actor, organization, facility, evidence ownership and input checks, then add only the exact required staging grants via a reviewed migration and test both allowed and denied users.
3. If a trusted Edge/server mediation layer is intended, keep browser EXECUTE denied and prove the Edge Function authenticates the caller, derives identity from verified JWT context, enforces membership/facility scope, never trusts caller-supplied user IDs, and returns only scoped data.
4. Reconcile the production/staging ACL difference through the migration ledger before changing either environment. Do not bulk grant or revoke based only on this snapshot.
5. Add staging tests for authorized warehouse operator success, foreign organization/facility denial, foreign task transition denial, and foreign evidence object rejection.

## Release impact
Warehouse authenticated-user workflow readiness is not signed off. Keep PR #245 draft. Do not apply broad grants or alter production ACLs until the intended call path and historical migration state are understood.

## Evidence boundaries
This finding records effective ACL state at the time of inspection. It does not establish whether the frontend uses RPC directly or a trusted server-side wrapper, and it does not replace dynamic RLS/tenant tests.


## Frontend call-path trace — confirmed direct browser RPC calls
Inspected the current branch's warehouse pages and confirmed the browser uses the Supabase publishable client directly for warehouse operations, rather than routing these calls through a server/Edge Function:
- `public/warehouse/facility-management.html` calls `krim_warehouse_register_facility` through `c.rpc(...)`.
- `public/warehouse/goods-receipt.html` calls `krim_warehouse_list_tasks`, `krim_warehouse_transition_task`, `krim_warehouse_create_linked_goods_receipt_task` and `krim_warehouse_list_assigned_shipment_legs` directly through `c.rpc(...)`.
- `public/warehouse/inbound-receiving.html` calls `krim_warehouse_list_tasks`, `krim_warehouse_transition_task`, `krim_warehouse_create_linked_inbound_task` and `krim_warehouse_list_assigned_shipment_legs` directly through `c.rpc(...)`.
- `public/warehouse/dispatch-handover.html` calls `krim_warehouse_list_tasks`, `krim_warehouse_transition_task`, `krim_warehouse_create_linked_handover_task` and `krim_warehouse_list_assigned_shipment_legs` directly through `c.rpc(...)`.

Therefore the staging service_role-only ACLs for these user-facing warehouse RPCs are not consistent with the current browser implementation. The pages are expected to fail with permission denied in staging unless an alternate grant path exists. Do not work around this by exposing service_role keys in the browser. The next safe fix is a narrowly scoped staging migration that grants EXECUTE only on the user-facing RPCs whose full function bodies have been verified to derive the actor from `auth.uid()` and enforce organization/facility authorization, followed by authenticated positive/negative staging tests. Production remains unchanged. The migration-history drift still must be reconciled before any production rollout.


## Follow-up: staging browser execution path and table grants — 2026-11-24

A further read-only pass checked the staging project after tracing the actual current-branch browser pages.

### Direct browser path confirmed
The warehouse pages use the publishable Supabase client in the browser. Examples verified on this branch:
- `public/warehouse/warehouse-evidence.html`: direct `c.rpc("krim_warehouse_list_tasks", ...)`, direct `c.rpc("krim_warehouse_list_evidence", ...)`, browser upload to the private `krim-warehouse-evidence` Storage bucket, then browser-side evidence registration RPC.
- `public/warehouse/goods-receipt.html`: direct RPC calls for assigned shipment legs, task listing, task transition and linked goods-receipt creation.
- `public/warehouse/inbound-receiving.html`: direct RPC calls for assigned shipment legs, task listing, task transition and linked inbound-task creation.
- `public/warehouse/quality-control.html`: direct table SELECTs from `krim_warehouse_tasks` and `krim_warehouse_inventory`, direct evidence-list RPC, direct signed-URL creation, and direct inventory quality-review RPC.

No warehouse-specific Edge Function exists in the staging deployment. The three deployed staging Edge Functions are `global-admin-control`, `krim-resend-email-worker`, and `owner-testing-authorize`; none is a warehouse request adapter. The warehouse browser calls are therefore not being mediated by a warehouse server function in this deployment.

### Staging effective privileges
Catalog checks show all 20 `public.krim_warehouse_*` RPC overloads/functions currently inspected are executable by `service_role`, but not by `authenticated`. This includes task list, evidence list/register, task create/transition, facility registration, inventory review, linked shipment operations and warehouse dashboard functions.

Separately, all 10 warehouse base tables checked have RLS enabled, but effective table-level privileges for `authenticated` are false for SELECT, INSERT, UPDATE and DELETE. RLS policies exist for scoped SELECT, but policies do not themselves grant SQL table privileges. This means a policy cannot make a direct browser table query work without the corresponding GRANT.

### Impact and decision
This is not merely an unproven alternate route: the current warehouse UI directly invokes RPCs and, on the quality-control page, directly queries warehouse tables. In the inspected staging environment those calls are blocked by effective ACLs. No warehouse Edge Function was found to provide the intended mediation path. The current staging warehouse UI is therefore not functionally wired to the deployed database access model.

Do not expose service_role credentials to the browser. Do not bulk grant authenticated access to every warehouse RPC/table. The correct remediation decision remains open between:
1. A narrowly reviewed browser-to-RPC model: grant only the exact browser-required RPC overloads after verifying every function's actor, tenant, facility, evidence and lifecycle checks; add only the minimum read privileges needed for direct table reads, with RLS policies validated; or
2. A trusted warehouse Edge Function adapter: verify JWT with `auth.getUser()`, derive actor from verified token, enforce current membership and facility scope on every action, call only explicitly allow-listed RPCs using user-scoped authorization (never trust caller-supplied user IDs), and return tenant-scoped data. Any service-role use must be paired with complete explicit authorization in the adapter.

Because staging seed/catalogue parity and migration-history reconciliation are still unresolved, neither route was deployed. No production or staging schema, grants, policies, data, or Edge Functions were changed by this review.


## Production ACL baseline confirmed — 2026-11-24

A read-only production comparison now confirms the intended browser access pattern for the warehouse module:

- All 10 `krim_warehouse_*` base tables inspected have RLS enabled and authenticated SELECT privilege in production; authenticated INSERT/UPDATE/DELETE are denied on all 10.
- Of the 20 `krim_warehouse_*` RPC signatures inspected, 19 have authenticated EXECUTE in production. The remaining function, `krim_warehouse_record_movement(...)`, is an internal movement helper and remains service_role-only.
- In staging, all 10 inspected tables have authenticated SELECT/INSERT/UPDATE/DELETE denied, and all 20 inspected warehouse RPCs have authenticated EXECUTE denied; service_role retains EXECUTE on the functions.

This confirms a consistent production model: browser users receive RLS-filtered read access to warehouse tables and invoke only the intended authenticated, actor-checking RPCs for writes; internal inventory movement remains unavailable directly to browser users. Staging currently does not match that model.

This is effective-privilege catalog evidence, not a successful browser E2E. It does not justify blindly copying every production grant: the exact frontend-required overloads and RLS predicates still need a reviewed migration, plus authorized same-tenant and denied cross-tenant tests. No grants, policies, data or functions were changed in either environment.
