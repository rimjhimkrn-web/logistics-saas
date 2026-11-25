# Phase 00 — Shipment workflow runtime notification execution trace

Date: 2026-11-25  
Branch: `qa/phase-00-baseline-2026-11-25`  
Scope: read-only source inspection in Production and Staging. No workflow runtime function invoked; no rows changed; no external messages sent.

## Executive finding

**The shipment workflow notification actions do not create notification outbox rows or delivery attempts.** They mark the workflow step/action as successfully completed with a result indicating that external sending is blocked until provider and recipient readiness.

Therefore, the current workflow's `prepare_customer_notification` and `prepare_partner_notification` action names are preparation markers only. They do not prove that a customer or partner notification has been created, queued, delivered, or received.

## Runtime chain inspected

The workflow runtime batch follows these stages:

1. Select pending `krim_events` using row locks and `SKIP LOCKED`.
2. Dispatch each event to active matching workflow triggers.
3. Materialize queued dispatches into workflow runs, run steps and action executions.
4. Process registered workflow actions through the action batch processor.
5. Recover expired workflow-action leases and retry/quarantine failures through the existing workflow action mechanisms.

The dispatcher creates durable event-workflow dispatch rows with an idempotency key. Materialization creates workflow run/action records with idempotency keys. This is workflow orchestration durability, not notification-delivery durability.

## Exact notification action behavior

In `krim_internal_execute_workflow_action(bigint)`, both action types:

- `prepare_customer_notification`
- `prepare_partner_notification`

only:
- mark the workflow run step completed;
- write a result snapshot with `status=prepared`;
- write `external_send=blocked_until_provider_and_recipient_ready`;
- mark the action execution succeeded.

The inspected function body does not:
- insert into `krim_notification_outbox`;
- insert into `krim_notification_deliveries`;
- resolve a recipient user or destination;
- select a communication intent, route or provider;
- create a delivery attempt;
- call an Edge Function or external provider;
- register a callback or delivery receipt.

The action is considered succeeded even though no message has been queued. This is an important semantic distinction: workflow completion is not notification completion.

## Environment parity

The following function definitions have identical MD5 fingerprints in Production and Staging:

- `krim_internal_dispatch_event_to_workflows(uuid)`: `82b290bd313f9a0643bc91ff7741461c`
- `krim_internal_execute_workflow_action(bigint)`: `6596cd34248457949912fcfdcf5ffb11`
- `krim_internal_materialize_workflow_dispatch(bigint)`: `522c2ea5d5291c52b7ac8708183ad495`
- `krim_internal_process_workflow_runtime_batch(text,integer,integer,integer)`: `b4c493b766711833f76318c385f49672`

The core limitation is therefore present in both environments, not just Staging.

## Reliability observations

Positive source-level controls:
- Event dispatch uses `FOR UPDATE SKIP LOCKED`.
- Event-to-trigger dispatch has an idempotency key and conflict handling.
- Workflow runs and action executions have deterministic idempotency keys.
- Action processing has expired-lease recovery, retry scheduling and dead-letter quarantine.

Important semantic risk:
- A notification preparation action can be marked succeeded while no outbox row exists. Monitoring that treats action success as notification success would report false completion.
- Retry/recovery of this action cannot create a notification because its executor has no notification creation logic.

## Required remediation before notification E2E

1. Define canonical event-to-intent mapping for all nine ecosystems.
2. Resolve recipient using current active organization membership and role/relationship, not only historical submitter IDs.
3. Create notification intent, recipient, outbox and delivery rows atomically with idempotency.
4. Keep workflow state distinct from notification state; action success must mean a durable notification intent/outbox was created, not that a provider delivered it.
5. Implement safe provider dispatch, isolated Staging sink, dry-run, allowlists, leases and stale-processing recovery.
6. Implement provider callback ingestion and separate accepted/sent/delivered/bounced/complained states.
7. Add synthetic positive/negative tests for recipient isolation, duplicate events, concurrent dispatch, provider failures, retries and dead letters.
8. Until the above exists, do not count shipment lifecycle notifications as operationally available.

## Evidence boundary

Read-only function-definition and fingerprint queries only. No event, workflow, action or notification runtime was invoked. No data was inserted or modified. No email, Telegram, SMS, WhatsApp, push or webhook was sent. Production and Staging remained unchanged.
