# KRIM Workflow Test Lane — Scheduler and Claim-Boundary Design Gate
Date: 2026-11-27
Environment reviewed: Staging Supabase project `qrpcivhdxobiaofppbkl` only.

## Decision
The current workflow runtime has no test/production lane separation. Do not create workflow fixtures in the shared runtime tables and do not run the scheduled batch as a test harness. The next implementation must add a fail-closed lane boundary across event dispatch, dispatch materialization, action claiming, recovery, replay, and reconciliation—or use a physically separate test runtime. A marker in JSON metadata alone is insufficient.

## 1. Current scheduler verified
The live Staging `cron.job` catalog currently shows one active workflow scheduler:
- Job: `krim-workflow-runtime-staging`
- Schedule: every minute
- Command: `public.krim_internal_process_workflow_runtime_batch('krim-db-cron', 25, 50, 25)`

This is the current catalog snapshot; it replaces earlier assumptions that two workflow-named cron jobs were active.

## 2. Current worker claims all eligible actions
`krim_internal_claim_workflow_actions(text,integer,integer)` selects any queued, due retry, or expired-running action from `public.krim_workflow_action_executions`, bounded by attempt count and lease expiry. It has no lane, fixture-run, workflow namespace, or owner-enable predicate.

The runtime batch also:
- scans all pending/eligible failed rows in `public.krim_events`;
- materializes all eligible queued/failed rows in `public.krim_event_workflow_dispatches`;
- processes dead-letter replay queues;
- invokes the action batch (which recovers expired leases and claims actions);
- synchronizes replay state and reconciles workflow runs.

Therefore adding a test flag only to the action claim query would not isolate the full runtime.

## 3. Event insertion trigger hazard reconfirmed
The current `public.krim_events` AFTER INSERT triggers invoke:
- customer shipment in-app notification creation;
- essential email enqueueing.

Any shared-table event fixture needs an explicit, reviewed trigger guard. Merely setting `source='test'` or a metadata marker is not a proven bypass unless both trigger functions enforce it and reject spoofed/unauthorized test markers.

## 4. Recommended implementation boundary
Preferred option: introduce an explicit, typed `runtime_lane` with only `production` and `test` values, defaulting existing and new business records to `production`. Never infer lane from user-controlled JSON metadata.

Required propagation and enforcement:
1. `krim_events.runtime_lane`: default `production`; ordinary business event writes cannot set `test`; test ingress alone may create test-lane rows.
2. Event notification/email triggers: return without side effects for test-lane events, while protecting lane assignment from client writes and proving the event was created by the dedicated test ingress.
3. Dispatcher event scan and event-to-workflow matching: production scheduler selects only production-lane events; dedicated test runner selects only its enabled test run.
4. Dispatch rows: carry lane/run identity immutably from the source event; production scheduler must not materialize test dispatches.
5. Workflow runs, run steps and action executions: carry the same lane/run identity; all joins verify matching lane/run ancestry.
6. Action claim: production worker claims only production-lane rows; test worker claims only the exact explicitly enabled test run. Keep `FOR UPDATE SKIP LOCKED`, lease tokens, retry limits and idempotency.
7. Expired-lease recovery, dead-letter quarantine/replay/synchronization and run reconciliation: lane-scoped end-to-end; no cross-lane processing.
8. Test runner: owner JWT + AAL2 + trusted active platform-superadmin, exact Staging project guard, unique run UUID, allowlisted actions, explicit enable/disable, immutable audit and fixture-owned cleanup.
9. First safe test slice: only `record_workflow_checkpoint` and `evaluate_delay_risk`. Exclude `create_exception_case` because it writes `krim_exceptions` using shipment identity. Keep all notification actions and provider integrations disabled.
10. Before execution, prove the scheduled production batch leaves disabled test-lane rows untouched and the test runner cannot claim production rows.

## 5. Important compatibility constraint
The existing event dispatcher and materializer are hardwired to the shared `public.krim_events`, dispatch, workflow and run tables. The executor reads the source payload by joining `krim_events` on event UUID. A truly separate test schema/queue therefore requires a dedicated test dispatcher/materializer/executor path or a carefully designed shared-table lane propagation. Do not simply create isolated test tables and assume the existing worker can process them.

## 6. Migration sequencing and acceptance gates
Do not apply a broad migration until the complete dependency list is captured for:
- event triggers and all event ingress functions;
- event dispatcher and runtime batch;
- dispatch materializer;
- claim, execute, retry, recover and quarantine functions;
- dead-letter replay and run reconciliation;
- cron entrypoint and any manual worker callers;
- all relevant uniqueness constraints, RLS and grants.

Acceptance tests (all required):
- default lane is production for legacy-compatible business writes;
- clients cannot set or change runtime lane;
- event test lane cannot enqueue customer notifications or essential email;
- scheduled production worker skips test events, dispatches and actions;
- disabled test run cannot be claimed;
- enabled test runner claims only its exact run;
- test runner cannot claim production rows;
- lease expiry/recovery and replay remain lane-isolated;
- test fixture cleanup is constrained to its run ledger;
- all unauthorized JWT roles/AAL states fail;
- no shipment, quote, assignment, exception, notification, email, push or payment row is created by the first test slice.

## 7. Current exit status
- One active every-minute workflow cron job confirmed.
- No lane separation exists in the inspected event/action claim logic.
- Existing event triggers can enqueue notification/email work.
- No fixture records created; no worker invoked; no migration applied.
- Production untouched.
- Phase 00 remains OPEN — NOT APPROVED; Phase 01 is not authorized.
