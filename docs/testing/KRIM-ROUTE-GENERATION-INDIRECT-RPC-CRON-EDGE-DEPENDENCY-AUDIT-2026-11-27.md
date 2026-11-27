# KRIM Route-Generation Indirect RPC, Cron and Edge Function Dependency Audit — 2026-11-27

## Scope
Read-only audit of Staging Supabase project `qrpcivhdxobiaofppbkl`, branch `staging/phase00-env-isolation`. Inspected dynamic-SQL candidates, pg_cron jobs, scheduled worker definitions, and all five currently deployed Staging Edge Functions. No writes, migrations, or Production access.

## 1. Dynamic SQL and indirect database execution
A catalog scan of public/private PL/pgSQL function definitions for dynamic `EXECUTE`, `format`, dblink, pg_net/http and cron references found:
- `public.rls_auto_enable()`: event-trigger function dynamically runs `ALTER TABLE ... ENABLE ROW LEVEL SECURITY` for newly created public tables. This is schema governance, not a shipment/route workflow consumer.
- `private.krim_claim_razorpay_refund_execution(uuid)`: dynamic/format keyword hit was in function body; no route-generation consumer identified in returned excerpt. This is a finance/refund path and remains outside route migration scope.
- `public.krim_accept_global_quote(bigint)`: format keyword hit; quote acceptance is a critical route-generation boundary and must be rechecked in full during implementation because it creates/locates partner assignment and may bind an operational leg.
- `private.krim_require_warehouse_handover_before_shipment_dispatch()`: uses `format()` only to construct a fixed diagnostic message. It checks each accepted/active assignment and requires current handover evidence for its exact `shipment_leg_id`.
No dynamic SQL route-table query was identified by this bounded scan. This does not rule out dynamic SQL in uninspected languages, Edge Functions, external clients or SQL assembled outside stored function bodies.

## 2. Scheduled jobs
Staging `cron.job` currently contains two active jobs, both scheduled every minute:
1. `krim_internal_process_workflow_runtime_batch('krim-db-cron',25,50,25)`
2. `krim_internal_expire_capacity_holds(200)`

### Workflow runtime batch
- SECURITY DEFINER.
- Configured search_path: `public, pg_temp`.
- Processes pending/failed `krim_events`, materializes workflow dispatches, handles dead-letter replay, processes workflow actions, synchronizes replay queue and reconciles workflow runs.
- No direct route-plan/leg reference was visible in the inspected function body. It is an indirect workflow execution engine: every event type, workflow action and registered handler that can mutate shipments, assignments, tracking, warehouse or POD must be inventoried before route-generation release.
- The function catches per-event/per-dispatch exceptions, increments attempts, applies retry scheduling and dead-letters after five attempts. Runtime job execution history and each downstream handler still need E2E verification.
- Security review required: SECURITY DEFINER with a non-empty `public, pg_temp` search_path. Do not change blindly; inspect every unqualified relation/function and effective object resolution, then pin safe search_path/schema qualification in a separate reviewed migration if needed.

### Capacity-hold expiry
- SECURITY DEFINER, empty search_path.
- Uses `FOR UPDATE SKIP LOCKED`, validates reservation ↔ binding shipment/leg/availability identity, checks assignment partner against reservation organization, expires linked reservation/binding and clears assignment binding pointer.
- This worker is exact-leg aware, but it does not check route-generation identity. Generation-aware eligibility and history must be added when the canonical generation key exists.
- No active fixture records exist to test expiration or release behavior.

## 3. Deployed Staging Edge Functions
Current catalog: five ACTIVE functions.
- `global-admin-control` v2, verify_jwt=true: admin overview counts and shipment/quote read endpoints; no route-plan or operational-leg write path observed in the inspected source. Admin shipment list is shipment-level.
- `krim-phase00-provision-test-organizations` v2, verify_jwt=true: test organization provisioning only; no shipment fixture creation.
- `krim-phase00-test-user-invites` v3, verify_jwt=true: invite-only test identity provisioning; no shipment fixture creation.
- `krim-resend-email-worker` v1, verify_jwt=false: guarded by `KRIM_NOTIFICATION_CRON_SECRET`, claims and finishes email batches through database RPCs. No direct route/leg references in source. Its downstream claim/finish routines and notification payload builders still need generation-aware event handling.
- `owner-testing-authorize` v5, verify_jwt=true: owner staging authorization; no route/leg references observed.

This is the complete current deployed Edge Function catalog returned by Staging at audit time. It does not cover local functions not deployed, external services, dynamic RPC names, or frontend invocations of functions not represented in the source excerpts.

## 4. Route-generation implications
1. Treat `krim_accept_global_quote` as a critical backend callsite; inspect its full function body and all invoked helpers before changing route identity.
2. Inventory every workflow event type and handler reachable from the one-minute workflow runtime batch. Add generation identity to event payloads and enforce it at mutation boundaries.
3. Update capacity expiry to retain exact leg/generation identity and ensure an expired hold cannot release or mutate capacity belonging to a newer generation.
4. Update the email worker's source-event and notification payload contract after generation-aware event schemas are finalized.
5. Keep owner fixture provisioning separate from operational shipment fixture creation; only create operational fixtures through supported authenticated application workflows.
6. Review SECURITY DEFINER search_path of the workflow runtime batch before release; pin object references and test shadow-object resistance.

## Status
- Deployed Edge Function catalog inspected: 5 ACTIVE.
- Active cron jobs inspected: 2.
- Dynamic SQL scan: bounded; no route-table dynamic SQL identified.
- Route-generation implementation: not started.
- No migration or code changes applied.
- Production untouched.
- Phase 00 remains OPEN — NOT APPROVED.
