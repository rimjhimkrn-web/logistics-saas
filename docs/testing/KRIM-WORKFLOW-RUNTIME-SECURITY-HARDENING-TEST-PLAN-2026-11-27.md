# KRIM Workflow Runtime Security Hardening and Test Plan — 2026-11-27

## Scope
Read-only inspection of Staging Supabase project `qrpcivhdxobiaofppbkl`. No production access, migrations, data mutations, worker invocations, or test events were performed.

## 1. SECURITY DEFINER inventory
A catalog query found 17 public-schema SECURITY DEFINER workflow-related functions configured with `search_path=public, pg_temp`:

- `krim_block_workflow_configuration_truncate()`
- `krim_guard_workflow_configuration_during_execution()`
- `krim_internal_claim_workflow_actions(text,integer,integer)`
- `krim_internal_dispatch_event_to_workflows(uuid)`
- `krim_internal_execute_workflow_action(bigint,uuid)`
- `krim_internal_execute_workflow_action(bigint)`
- `krim_internal_materialize_workflow_dispatch(bigint)`
- `krim_internal_process_workflow_action_batch(text,integer,integer)`
- `krim_internal_process_workflow_dead_letter_replays(integer)`
- `krim_internal_process_workflow_runtime_batch(text,integer,integer,integer)`
- `krim_internal_quarantine_workflow_action(bigint,text)`
- `krim_internal_reclaim_expired_workflow_actions(integer)`
- `krim_internal_reconcile_workflow_runs(integer)`
- `krim_internal_recover_expired_workflow_actions(integer)`
- `krim_internal_recover_workflow_action(bigint)`
- `krim_internal_sync_workflow_dead_letter_replays(integer)`
- `krim_log_workflow_dead_letter_replay_event()`

All returned owners were postgres. Internal worker functions' observed ACLs grant execution to postgres and service_role only; the inspected list did not show anon or authenticated grants. Trigger functions have postgres-only ACLs. This is a catalog snapshot, not a runtime JWT test.

## 2. Hardening decision
Do not bulk-replace the search path yet. Several functions use unqualified built-ins or helper names and trigger code, and changing resolution semantics without per-function compilation and dependency tests could break production-like behavior. Before any migration:
1. Extract every complete function definition.
2. Identify every unqualified relation, type, operator, function and sequence reference.
3. Schema-qualify application objects explicitly.
4. Use a minimal trusted path (normally `pg_catalog`; include `auth` only if unavoidable and explicitly qualified).
5. Preserve trigger semantics and function owner/grants.
6. Compile in a transaction on Staging, verify `proconfig`, ACLs, triggers and dependencies; then run the regression suite.
7. Never grant client execution to internal worker functions.

## 3. Runtime data and policy snapshot
The six core runtime tables are empty: events, workflows, triggers, workflow runs, action executions and dispatches all have zero rows. This means no retry, lease, dead-letter or replay behavior has yet been proven with live test records.

RLS policy inspection found organization-scoped SELECT policies for events, dispatches, workflow runs, action executions, workflows and triggers. Workflow trigger reads resolve through the parent workflow. The returned policy set contained SELECT policies only; this query alone does not prove table grants or deny writes, so ACLs must be checked separately before any client-facing claim.

Integrity constraints already include:
- Unique event UUID.
- Unique dispatch idempotency key and dispatch number.
- Unique action idempotency key.
- Unique workflow trigger per workflow/event type.
- Bounded attempt counters and constrained processing/action statuses.

## 4. Controlled test matrix (not executed)
Use isolated test-only organizations, users, workflows and synthetic non-business events. No real shipment, quote, partner or payment record should be involved.

| Test | Setup/action | Required assertion |
|---|---|---|
| Event dispatch | One active workflow trigger matching event type, org and payload | One dispatch; event marked processed |
| No match | Event with no matching trigger | Processed with explicit no-match outcome; no run |
| Idempotency | Process same event/trigger twice | Unique dispatch key prevents duplicate |
| Condition mismatch | Payload does not contain trigger condition | No dispatch for that trigger |
| Organization isolation | Workflow scoped to Org A; event Org B | No cross-tenant dispatch |
| Lease claim | Queue action and claim it | Running status, unique lease, bounded expiry |
| Stale lease | Execute with wrong/expired lease | Rejected; no action mutation |
| Retry | Force a retryable test action failure | retry_wait and bounded backoff |
| Max attempts | Exhaust configured attempts | Failed action and one quarantine record |
| Dead-letter replay | Owner-approved replay of a test-only action | Requeued exactly once; history retained |
| Replay failure | Replay unsupported action | Re-quarantined; no unintended side effect |
| Concurrency | Two workers claim same queue | SKIP LOCKED prevents duplicate claim |
| Notification fail-closed | Configure notification action without enqueue handler | Unsupported action; no email/push sent |
| Permission boundary | Attempt internal RPC as anon/authenticated | Denied; service worker only |
| RLS tenant boundary | Org A user reads Org B run/event | No rows returned |
| Recovery | Expire a test lease | Correct retry or quarantine based on attempt limit |
| Reconciliation | Create completed/failed test steps | Run and dispatch converge to correct terminal state |

## 5. Known implementation gaps
- Notification actions intentionally fail as unsupported: no verified notification enqueue handler.
- Workflow registry and test events are empty, so the runtime's handler graph is structurally inspectable but not end-to-end demonstrated.
- The runtime uses SECURITY DEFINER functions with mutable `public, pg_temp` search paths.
- Quote acceptance/finalization and workflow event/action context do not yet carry immutable route-generation identity.
- A real multi-user JWT-backed tenant-isolation test remains outstanding.

## 6. Exit criteria
Do not mark workflow runtime verified until every applicable test above passes with stored evidence, including concurrency and tenant isolation. Do not enable notification actions until a durable enqueue handler, delivery state machine, retries, and provider/domain configuration are verified.

## Result
Documentation-only checkpoint. No migrations, code changes, worker invocations, synthetic events, invitations, emails, shipments, quotes or payments were created. Production remains untouched. Phase 00 remains OPEN — NOT APPROVED; Phase 01 is not authorized.
