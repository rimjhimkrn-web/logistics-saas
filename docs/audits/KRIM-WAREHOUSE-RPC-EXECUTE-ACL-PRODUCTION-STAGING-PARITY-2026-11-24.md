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
