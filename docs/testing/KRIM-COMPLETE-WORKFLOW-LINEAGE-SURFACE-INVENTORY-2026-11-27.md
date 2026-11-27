# KRIM Complete Workflow Lineage Surface Inventory — 2026-11-27

## Status
Read-only Staging inventory. No DDL/DML, workflow claims, provider calls, scheduler edits, or Production access.

## Confirmed table surface
The initial lane design covered core runtime tables but was incomplete. Staging contains the following related records, which must be considered before a shared-table lane migration:

### Domain events and dispatch
- `krim_events` (18 columns)
- `krim_event_workflow_dispatches` (22)
- `krim_event_workflow_dispatch_events` (11)

### Workflow run/action runtime
- `krim_workflows` (16)
- `krim_workflow_triggers` (8)
- `krim_workflow_steps` (11)
- `krim_workflow_runs` (18)
- `krim_workflow_run_steps` (10)
- `krim_workflow_run_events` (13)
- `krim_workflow_action_results` (15)
- `krim_workflow_action_executions` (23)
- `krim_workflow_action_execution_events` (10)

### Alternate queue, locks and dead-letter/replay
- `krim_workflow_queue_leases` (19)
- `krim_workflow_queue_events` (9)
- `krim_workflow_concurrency_locks` (14)
- `krim_workflow_concurrency_events` (10)
- `krim_workflow_dead_letters` (23)
- `krim_workflow_dead_letter_replays` (19)
- `krim_workflow_dead_letter_events` (10)

### Notification side effects
- `notifications` (13)
- `krim_notification_outbox` (23)
- `krim_notification_deliveries` (14)
- `krim_notification_retry_events` (10)

These are the complete table names returned by the Staging catalog query for public tables matching workflow/event/notification scope. Workflow configuration tables (`krim_workflows`, `krim_workflow_triggers`, `krim_workflow_steps`) are configuration, not per-run lineage; they still require immutable configuration-version snapshots at run start and must not be casually duplicated for test mode.

## Critical correction to earlier migration scope
A migration that adds lane/run columns only to events, dispatches, runs, run steps, action executions, queue leases and dead-letter parents would still leave audit/event children, action results, concurrency locks, replay records and notification records without authoritative lineage.

At minimum, the following runtime/audit children need lane/run lineage or a non-bypassable FK path to a parent carrying it:
- dispatch event history
- run event history
- action execution event history
- action results
- queue lease event history
- concurrency locks and their event history
- dead-letter replay rows and dead-letter event history
- notification outbox, delivery and retry history, plus in-app notifications if test notification events are ever represented.

Do not add lineage to global configuration tables unless the design explicitly introduces immutable test-only configuration versions. Instead, snapshot the configuration version/hash into each run and reject configuration drift while a run is executing.

## Architecture recommendation
Prefer a physically separate test runtime namespace/table family with a dedicated test-run registry and isolated queues over a partially shared lane on the live operational event/notification tables. This sharply reduces accidental production claims and avoids test-trigger side effects. A shared-table lane remains possible only if every parent, child, audit, lease, retry, replay, reconciliation, notification and webhook path is covered and tested.

Test ingress must be a trusted service-only database function requiring:
- an enabled test-run UUID from the fixture registry;
- a strict allowlisted synthetic event type and schema;
- no real shipment/partner/driver record mutation;
- no caller-controlled lane metadata;
- no outbound notification, email, webhook, Telegram, payment or provider route.

## Required tests before applying any migration
1. Existing business triggers continue to emit only production events.
2. Test ingress rejects missing, disabled, malformed and unknown run IDs.
3. Test ingress rejects unsupported event types and payloads referencing real business records.
4. Production schedulers cannot see or claim test queue records.
5. Test runner can claim only its exact enabled run and cannot claim production or another run.
6. All event, dispatch, run, step, action, action-result, queue, lock, dead-letter, replay and audit history retains the same run lineage.
7. Retry, lease expiry/recovery, quarantine, replay, reconciliation and concurrency locks cannot cross lanes or run IDs.
8. Test execution creates zero rows in production notifications/outbox/deliveries/retry records and cannot invoke any external provider.
9. Existing production workflow behavior and idempotency remain unchanged.
10. Static inventory of cron, Edge Functions, external schedulers, service-role callers and operator tools is signed off.

## Current result
- Expanded table inventory: PASS.
- Complete runtime lineage migration: NOT IMPLEMENTED.
- Test ingress: NOT IMPLEMENTED.
- Workflow test execution: BLOCKED.
- Production: untouched.

Related docs:
- `KRIM-WORKFLOW-RUNTIME-LANE-ISOLATION-INVENTORY-2026-11-27.md`
- `KRIM-DOMAIN-EVENT-TEST-INGRESS-BOUNDARY-2026-11-27.md`
- `KRIM-NOTIFICATION-EVENT-SIDE-EFFECT-ISOLATION-GATE-2026-11-27.md`
