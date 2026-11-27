# KRIM Workflow Runtime Isolation — Staging Runtime Inventory 2026-11-27

## Status
**BLOCKED — no safe workflow test lane exists in the current Staging schema.**

Inspection target: Supabase Staging project `qrpcivhdxobiaofppbkl`. This was read-only. No schema changes, queue claims, workflow execution, event inserts, scheduler edits, or Production access were performed.

## Verified lineage gaps
The inspected tables have business lineage keys but no typed `runtime_lane` or `test_run_id` columns:

- `krim_events`
- `krim_event_workflow_dispatches`
- `krim_workflow_runs`
- `krim_workflow_run_steps`
- `krim_workflow_action_executions`
- `krim_workflow_queue_leases`
- `krim_workflow_dead_letters`
- `krim_workflow_dead_letter_replays`
- `krim_workflow_dead_letter_events`

Existing relationships include event → dispatch → run → run step/action → queue lease → dead letter/replay. They do not provide a typed test boundary.

## Runtime paths requiring isolation
Staging contains two distinct workflow execution families:

### A. Event/dispatch/action runtime
Service-role-only SECURITY DEFINER functions include:
- `public.krim_internal_process_workflow_runtime_batch`
- `public.krim_internal_dispatch_event_to_workflows`
- `public.krim_internal_materialize_workflow_dispatch`
- `public.krim_internal_claim_workflow_actions`
- `public.krim_internal_execute_workflow_action`
- `public.krim_internal_process_workflow_action_batch`
- `public.krim_internal_process_workflow_dead_letter_replays`
- `public.krim_internal_quarantine_workflow_action`
- `public.krim_internal_reclaim_expired_workflow_actions`
- `public.krim_internal_reconcile_workflow_runs`
- `public.krim_internal_recover_expired_workflow_actions`
- `public.krim_internal_recover_workflow_action`
- `public.krim_internal_sync_workflow_dead_letter_replays`

The existing claim/recovery/reconciliation path operates on shared records without a typed test lane/run boundary. The scheduled `krim-workflow-runtime-staging` job calls the shared runtime batch every minute (previous scheduler inventory).

### B. Alternate queue-lease runtime
The `krim_internal` schema also contains service-role-only SECURITY DEFINER functions:
- `claim_workflow_queue_item`
- `execute_workflow_queue_item`
- `process_workflow_queue_item`
- `heartbeat_workflow_queue_lease`
- `release_workflow_queue_lease`
- `finalize_workflow_action_result`
- `propagate_workflow_run_after_action`
- `quarantine_workflow_action_dead_letter`
- `quarantine_workflow_action_failure`
- `request_workflow_dead_letter_replay`
- `approve_and_queue_workflow_dead_letter_replay`
- `process_dead_letter_replay`
- `sync/reconcile and transition helpers`

The inspected `claim_workflow_queue_item` selects any due released/expired/leased queue lease, without a lane or run filter, then claims it and updates the linked action. It is not safe as a test runner against the shared queue.

## Privilege boundary
The inventoried internal runtime functions deny EXECUTE to `anon` and `authenticated`, and grant EXECUTE to `service_role`. This is a useful API boundary, but does not provide tenant/run isolation inside service-role worker execution.

## Required migration design before any test execution
1. Introduce typed `runtime_lane` with strict values `production` and `test`, defaulting existing/new business events to `production`. Add nullable UUID `test_run_id`; require it for test lane and forbid it for production lane.
2. Propagate immutable lane/run lineage across all nine tables listed above. Enforce via trusted database functions/constraints/triggers; do not infer from event JSON metadata.
3. Make all production schedulers and production claim/recovery/reconciliation/replay functions explicitly filter `runtime_lane='production'`.
4. Add separate test-run APIs that require one explicitly enabled run UUID and only claim/execute records belonging to that run. No broad worker fallback.
5. Ensure both runtime families (event/action and queue-lease) use the same lineage contract, or formally disable and revoke the unused runtime path only after all callers are inventoried.
6. Scope dead-letter replay, queue recovery, lease expiry, run reconciliation, concurrency locks, and idempotency keys by lane/run. Preserve lineage through every transition.
7. Audit all SQL callsites, cron jobs, Edge Functions, external schedulers, operator scripts, and service-role callers before cutover.
8. Add database tests for production/test non-cross-claiming, cross-run denial, replay/recovery isolation, and unchanged production behavior.
9. Keep test action allowlist to verified, side-effect-free actions. Exclude notifications, shipment mutations, external webhooks, payments, and any provider calls.
10. Run advisors and regression tests, deploy to Staging only, then prove the test runner cannot claim production work and production cron cannot claim test work.

## No-change assurance
This checkpoint did not invoke any workflow runner or alter scheduler state. It did not create test events, queue records, actions, or replay records. Production was not accessed.

## Related gates
- `KRIM-WORKFLOW-LANE-SCHEDULER-CLAIM-BOUNDARY-DESIGN-2026-11-27.md`
- `KRIM-WORKFLOW-LANE-DEPENDENCY-MIGRATION-GATE-2026-11-27.md`
- `KRIM-ALTERNATE-WORKFLOW-RUNTIME-WEBHOOK-CALLER-INVENTORY-2026-11-27.md`
- `KRIM-NOTIFICATION-EVENT-SIDE-EFFECT-ISOLATION-GATE-2026-11-27.md`
