# KRIM Event Processing, Notifications & Recovery Readiness Audit
**Date:** 16 November 2026  
**Scope:** Read-only production inspection of event processing, workflow dispatch, notification outbox/delivery, outbound webhooks, queue leases, and dead-letter recovery.  
**Project:** Logistics SaaS production (ebltviniygljwwseplph)

## Executive result
**Status: PARTIALLY BUILT; NOT PRODUCTION-VERIFIED FOR CUSTOMER/OPERATIONAL NOTIFICATIONS OR AUTOMATED RECOVERY.**

The core event/workflow path has historical evidence of successful processing: 23 event rows are marked processed; 9 matching workflow dispatch rows exist; their linked workflow runs are completed and all 18 recorded run steps completed. This is useful evidence that a workflow path has executed before, but it is not an end-to-end proof of current scheduling, external delivery, or recovery.

The notification and external webhook delivery layers have schema but no production activity in the inspected tables. All inspected notification outbox/delivery/retry, webhook endpoint/delivery, workflow queue lease/event, and dead-letter/replay tables have zero rows. Correction from the follow-on scheduler audit: production has an ACTIVE Supabase Edge Function named krim-notification-retry-worker (version 14), and an active pg_cron job invokes it every five minutes. The worker is not present in the checked-in supabase/functions directory listing, but it is deployed in the Supabase project. This changes the architecture finding: a Telegram founder retry worker exists and is scheduled. It does not change the delivery-readiness verdict because the outbox/delivery tables are empty and no real message delivery was independently verified.

No production rows were created, modified, replayed, or sent during this audit.

## 1. Production counts

| Area | Table | Rows |
|---|---|---:|
| Event intake | krim_events | 23 |
| Event deduplication registry | krim_event_deduplication | 0 |
| Workflow dispatch | krim_event_workflow_dispatches | 9 |
| Workflow dispatch history | krim_event_workflow_dispatch_events | 0 |
| Notification outbox | krim_notification_outbox | 0 |
| Notification delivery attempts | krim_notification_deliveries | 0 |
| Notification retry history | krim_notification_retry_events | 0 |
| Notification preferences | krim_notification_preferences | 0 |
| Operational notification runs/events | krim_operational_notification_runs / krim_operational_notification_run_events | 0 / 0 |
| Outbound webhook endpoints/deliveries | krim_webhook_endpoints / krim_webhook_deliveries | 0 / 0 |
| Inbound webhook events | krim_inbound_webhook_events | 0 |
| Workflow queue leases/events | krim_workflow_queue_leases / krim_workflow_queue_events | 0 / 0 |
| Workflow dead letters/events/replays | krim_workflow_dead_letters / krim_workflow_dead_letter_events / krim_workflow_dead_letter_replays | 0 / 0 / 0 |
| Legacy dead-letter events | krim_dead_letter_events | 0 |
| Workflow run/action event logs | krim_workflow_run_events / krim_workflow_action_execution_events | 0 / 0 |

Event state: all 23 rows are processed; all 23 have at least one processing attempt; none has a recorded last_error. Nine of 23 events have a workflow dispatch row; 14 have none. That is not automatically a defect: event types may not match an active trigger. It must be validated against the intended event-to-trigger catalogue rather than assumed to mean all events were routed.

There are six active workflows and six active workflow triggers in the current catalogue.

## 2. Workflow execution evidence
The nine dispatch rows (created 11 October 2026) have status dispatched, a linked workflow run, an input snapshot, and a result snapshot. Each linked run (IDs 18–26) is completed; each has two steps and both steps are completed. No linked run has a recorded error.

**Important lifecycle mismatch:** all nine dispatch rows still have completed_at = NULL even though their linked workflow runs are completed. Their dispatch status remains dispatched. This creates ambiguity for control-tower reporting, SLA timers, stuck-work detection, and reconciliation. Define whether dispatch dispatched means “handed off” or “workflow finished”; if it means handoff, add a separate terminal outcome/status and timestamp. Do not blindly backfill historical rows.

The workflow event-history table is empty, so there is no row-level dispatch state transition trail for these nine records.

## 3. Event processor behaviour and controls
Inspected privileged function: krim_internal_dispatch_event_to_workflows(uuid).

Observed behaviour:
- Locks the target event row.
- Selects active triggers matching event type, active workflow, organization scope, and JSON payload condition.
- Creates dispatches with a deterministic key based on event row and trigger ID; conflict on that key is ignored.
- Marks the event processed and increments attempts after dispatch generation.
- On exception, marks it failed, increments attempts, records the SQL error, and rethrows.

This provides a useful per-event/per-trigger dispatch idempotency key. The separate krim_event_deduplication table is empty, so do not assume that generic inbound-event deduplication is in use. The dispatch key only prevents duplicate dispatch rows for the same stored event and trigger; it does not alone prevent duplicate source-event ingestion.

The function marks an event processed even when no trigger matched and zero dispatches were created. This may be intended, but operational monitoring must distinguish “processed with no matching workflow” from “processed and routed”. Add an explicit no-match metric/state or a reconciliation report before relying on event counts as workflow coverage.

## 4. Notifications and external delivery
The database has a notification outbox with recipient reference, channel, priority, content/payload, schedule, status, idempotency key, attempt count, next-attempt time, provider and provider-message ID. Delivery rows record provider, status, attempt count, next attempt, sent/delivered/failed timestamps, error and provider message ID. Retry events provide a history structure.

However, all three tables are empty. Preferences are also empty. Production inspection confirms a dedicated deployed function, krim-notification-retry-worker (ACTIVE, version 14, verify_jwt=false with its own cron-secret or platform-admin authorization), and an active five-minute cron job. It processes two founder-only Telegram queues: new customer inquiry alerts and due follow-up reminders. The checked-in repository directory listing did not include this deployed function, so deployment/source parity must be reconciled. No live message was confirmed by recipient, and no provider callback, bounce/complaint or suppression path was tested.

**Conclusion:** the outbox schema is a foundation, not evidence of a functioning notification service. Founder Telegram/email alerts remain unverified until an authorized test event is queued and provider delivery is independently confirmed. No test notification was sent as part of this audit.

Required before enabling:
1. Reconcile the deployed worker source with version-controlled source; keep secrets server-side and no provider keys in browser code.
2. Explicit channel/provider allowlist, recipient verification, user preference/consent and transactional-vs-marketing classification.
3. Stable idempotency across enqueue, worker retries, provider timeouts and webhook callbacks.
4. Bounded exponential backoff with jitter, retryable/permanent error classification, max attempts, quarantine/dead-letter and operator alerting.
5. Provider callback signature verification and correlation by provider message ID.
6. Delivery semantics clearly named: accepted by provider, sent, delivered, bounced, rejected and unknown are distinct states.
7. Redaction/retention rules for message bodies, addresses, phone numbers and provider responses.
8. Per-tenant access tests and no cross-organization recipient/data leakage.

## 5. Outbound webhooks
Endpoint and delivery tables support organization association, subscribed event types, secret references, endpoint status, failure counters, suspension/recovery timestamps, delivery attempts, HTTP response status, retry schedule and errors. The inspected enqueue function:
- Selects active, non-suspended endpoints within organization scope (or global scope).
- Matches event subscriptions.
- Enqueues at most one delivery per endpoint/event using the unique endpoint/event conflict target.

There are zero endpoint and delivery rows, so outbound webhooks are not currently demonstrated in production. The enqueue function is not a delivery worker. Before activation, verify HMAC/signature design, timestamp/replay window, secret rotation, SSRF protections (private/link-local/metadata IP blocking, DNS rebinding and redirect policy), response-size/time limits, retry backoff, endpoint suspension/recovery, and tenant ownership. Never expose endpoint secrets in reads or logs.

## 6. Queue and dead-letter recovery
Queue lease schema includes worker ID, status, priority, available time, lease expiry, heartbeat, attempt number, maximum attempts and last error. Dead-letter schema includes failure class/code, attempt count, original payload/error snapshot, replay count, resolution actor/reason and timestamps. Replay requests enforce platform-admin permission for authenticated requests, immutable target fields, a reason, quarantined-state checks, and an approved worker transition path. Replay worker functions are SECURITY DEFINER and must remain internal.

All inspected queue/dead-letter/replay tables are empty. Therefore there is no production evidence that leases, worker heartbeats, expired-lease reclamation, bounded retries, dead-letter quarantine, replay approval, replay execution, or replay reconciliation have been exercised. The presence of replay functions is not proof that a scheduler invokes them.

## 7. Access-control observations
RLS is enabled on the inspected event, dispatch, notification, webhook, queue and dead-letter tables. The inspected policies provide organization-scoped SELECT access for event/dispatch/notification/webhook/queue/dead-letter data, with platform-admin exceptions on selected tables. Authenticated users have SELECT on the event/outbox/delivery and related operational tables; authenticated INSERT/UPDATE on the replay request table is policy-limited to platform-admin request/approval states. Service role and postgres have broad table privileges.

No anonymous table grants appeared in the inspected grant results. This is a positive baseline, not a complete security certification. RLS is not forced on these tables, so privileged owners/service role bypass it by design. SECURITY DEFINER functions must be audited separately for EXECUTE grants, caller checks, fixed search_path, tenant scoping and secret handling before public invocation.

## 8. Blocking gaps and safe next actions
**P0 — before real customer or partner operations**
- Implement and prove one server-side event-to-notification worker, with safe secrets, provider allowlist and test-mode gating.
- Reconcile event-to-trigger coverage and add monitoring for processed-with-zero-dispatch events.
- Resolve dispatch status/timestamp semantics and expose a stuck/overdue workflow report.
- Verify a scheduler/worker actually invokes queue processing, lease recovery, retry and dead-letter synchronization.
- Add end-to-end idempotency tests across event intake, dispatch, notification enqueue, provider timeout, duplicate callback and replay.

**P1 — before enterprise integrations**
- Activate outbound webhook endpoints only after SSRF, signature, secret rotation, replay, retry and suspension tests.
- Test organization isolation for all read paths and platform-admin-only replay controls.
- Add delivery observability: queue age, oldest pending, attempt histogram, provider acceptance/delivery/bounce, dead-letter count/age, expired leases and no-match events.

**P2 — resilience and governance**
- Add retention and redaction policies for event payloads and delivery snapshots.
- Add incident runbooks and audited operator actions for retry, replay, endpoint suspension and recipient suppression.
- Run controlled staging chaos tests for provider outage, worker crash, lease expiry, duplicate delivery, poison message and recovery.

## 9. Staging acceptance test set
1. Same source event submitted twice: exactly one canonical event or documented duplicate receipt.
2. Same event processed concurrently by two workers: one dispatch per trigger.
3. Event with no matching trigger: explicitly counted as no-match, not silently treated as fully routed.
4. Event with two matching triggers: exactly two dispatches, each with stable idempotency key.
5. Workflow step fails transiently: bounded retry and eventual success without duplicate side effect.
6. Worker crashes after lease acquisition: lease expires, is reclaimed, and action resumes safely.
7. Permanent/poison failure: dead-letter quarantine with complete redacted error context.
8. Replay request by non-admin: denied.
9. Replay request without reason or for non-quarantined item: denied.
10. Replay approval and execution: audited actor, immutable target, one replay, correct terminal state.
11. Provider timeout after accepting a message: retry does not create a duplicate user-visible message where provider idempotency is available.
12. Invalid provider callback signature: rejected.
13. Duplicate provider callback: idempotent.
14. Cross-organization notification/outbox/webhook read: denied.
15. Webhook target resolves to loopback/private/link-local/metadata address: blocked.
16. Webhook redirect to a private address: blocked.
17. Repeated webhook failures: backoff and endpoint suspension threshold applied.
18. Successful recovery: endpoint re-enabled only through an audited control.
19. Notification opt-out/suppression: marketing send blocked; essential transactional messages follow documented lawful basis and preference rules.
20. Sensitive payload fields: absent from client-readable logs and routine telemetry.

## 10. Scope and limitations
This was a read-only schema, row-count, state, function-definition, grant and RLS-policy inspection plus a repository function-directory listing. A subsequent read-only scheduler audit inspected active pg_cron jobs, recent cron run history, the deployed notification Edge Function metadata/source, and only the existence/length (not value) of its Vault cron secret. It did not inspect provider dashboards or expose secrets, invoke workers manually, send test messages, simulate provider callbacks, replay dead letters, or run staging tests. It does not certify that scheduled infrastructure outside the inspected repository/database is absent. The migration-history reconciliation blocker remains in force: no production DDL or migration replay should be attempted until the canonical migration source is recovered and reconciled.

**Decision:** keep customer-facing notifications, outbound customer webhooks and automatic recovery marked “not yet production-verified”. Continue with a safe worker/scheduler inventory and staging test design; do not activate real sends or replays during readiness work.
