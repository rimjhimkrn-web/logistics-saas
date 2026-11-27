# KRIM Workflow Lane Dependency and Migration Gate — 2026-11-27

## Scope
Read-only Staging audit of project `qrpcivhdxobiaofppbkl`. Production was not accessed. No SQL writes, cron changes, worker invocation, fixture creation, notification, email, or payment activity occurred.

## 1. Confirmed event ingress
Current application event writers include trigger functions for:
- driver assignment created/status changed;
- partner assignment offered/status changed;
- shipment created/status changed.

These writers insert into `public.krim_events`. The events table has AFTER INSERT triggers that:
- create customer shipment in-app notifications;
- enqueue essential emails.

There is also a separately callable event webhook enqueue routine that reads the event and active webhook subscriptions and inserts webhook delivery records. The full call graph for webhook enqueueing and any external delivery worker remains a separate dependency review; do not assume event-lane filtering in the workflow dispatcher also protects webhooks.

## 2. Workflow runtime dependency map
The following shared-table lifecycle must be lane-aware together:
1. `krim_events` pending/failed scan in runtime batch.
2. `krim_internal_dispatch_event_to_workflows(uuid)` event lookup, workflow/trigger match and dispatch insert.
3. `krim_event_workflow_dispatches` queue scan and `krim_internal_materialize_workflow_dispatch(bigint)`.
4. `krim_workflow_runs`, `krim_workflow_run_steps`, `krim_workflow_action_executions` creation and lineage.
5. `krim_internal_claim_workflow_actions` queued/retry/expired-running claim.
6. `krim_internal_process_workflow_action_batch` recovery, claim, execute, retry and quarantine.
7. `krim_internal_recover_expired_workflow_actions` and `krim_internal_recover_workflow_action`.
8. `krim_internal_quarantine_workflow_action` and `krim_workflow_dead_letters`.
9. `krim_internal_process_workflow_dead_letter_replays`, `krim_internal_sync_workflow_dead_letter_replays`, and `krim_workflow_dead_letter_replays`.
10. `krim_internal_reconcile_workflow_runs` and dispatch completion update.
11. The scheduled `krim_internal_process_workflow_runtime_batch` entrypoint, currently called every minute by the active Staging cron job.

A lane filter only in action claiming is insufficient: the event scan, dispatch scan, lease recovery, replay queue, dead-letter sync, and run reconciliation can all process shared rows.

## 3. Trigger and replay dependencies
- Event AFTER INSERT notification/email triggers must explicitly reject or safely ignore test-lane events, with lane assignment protected from caller spoofing.
- Dead-letter replay table has a validation trigger and an audit-event trigger. Replay validation is currently privileged and stateful; the replay processor resets the original action execution to queued and the run back to running. Replay therefore must validate the fixture run/lane ancestry before requeueing.
- Dead-letter replay audit writes to `krim_workflow_dead_letter_events`; this is internal audit history, not a new `krim_events` row in the inspected trigger function.
- `krim_internal_quarantine_workflow_action` updates the parent workflow run to failed; it must not cross lane/run ancestry.
- `krim_internal_reconcile_workflow_runs` selects all running runs and updates all associated dispatches; it must filter and verify lane lineage.
- `krim_internal_recover_expired_workflow_actions` selects all expired running actions; it must filter and verify lane lineage before changing action, step, run or dead-letter rows.

## 4. Security boundaries verified
The inspected internal workflow routines have EXECUTE grants for `postgres` and `service_role`, not `anon` or `authenticated`. They are SECURITY DEFINER with `search_path=public, pg_temp`. These grants should be preserved during the lane migration. AAL2 owner authorization belongs on the dedicated test-run management Edge Function; service-role secrets must never reach the browser.

## 5. Migration design constraints
Do not yet apply the lane migration. Before implementation, produce a full call graph for:
- webhook enqueue and delivery;
- every event producer and event table trigger;
- every worker caller (cron, Edge Function, RPC, manual/admin path);
- every replay request/approval and replay worker path;
- every function that reads/writes the workflow tables, including alternate overloads.

Then implement one atomic, reviewed Staging migration with:
- typed lane column(s), constrained to `production` or `test`, default `production`;
- immutable lineage from event to dispatch to run to step/action to dead letter/replay;
- ordinary event producers unable to set test lane;
- explicit owner-authorized test ingress with a run UUID and isolated synthetic event type;
- production cron explicitly limited to production lane at every lifecycle stage;
- test worker limited to one explicitly enabled run UUID at every lifecycle stage;
- no broad client table grants;
- no shared event notification/email/webhook side effects for test lane;
- rollback/disable mechanism that cannot reclassify production rows as test.

A separate test queue/schema is an alternative, but the existing worker functions cannot consume it without a dedicated test dispatcher/materializer/executor path.

## 6. Current test eligibility
First slice may only include `record_workflow_checkpoint` and `evaluate_delay_risk` after full source verification and isolation. Exclude `create_exception_case` because it inserts into `krim_exceptions` with shipment identity. Exclude notification actions and webhook delivery.

## 7. Exit status
- Event producers and event notification/email triggers confirmed.
- Workflow dispatcher, materializer, claim, recovery, replay, quarantine and reconciliation dependency chain inspected.
- Test-lane isolation is not implemented.
- No migration applied, no rows created, no worker invoked.
- Production untouched.
- Phase 00 remains OPEN — NOT APPROVED; Phase 01 is not authorized.
