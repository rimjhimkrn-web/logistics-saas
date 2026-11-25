# Phase 00 — Notification schema, constraints, indexes and RLS audit

Date: 2026-11-25  
Branch: `qa/phase-00-baseline-2026-11-25`  
Scope: read-only catalog inspection of Production (`ebltviniygljwwseplph`) and Staging (`qrpcivhdxobiaofppbkl`). No rows were inserted/updated/deleted; no migrations, grants, policies, or functions were changed; no provider or worker was invoked.

## Executive result

The databases already contain a substantial notification/communications schema. This is not a greenfield build. Core concepts present include communication intents, recipients, providers, routes, suppressions, notification outbox/deliveries/retry events, delivery-event history and inbound webhook-event storage. Both environments show the same broad design in the inspected catalog. The existence of these objects does **not** prove that a complete event-to-recipient-to-provider-to-delivery pipeline is active.

**Status: schema foundation partially present; end-to-end notification readiness remains NO-GO.**

## Catalog evidence

The following objects/columns were confirmed in the catalog inspection:

- `krim_communication_intents`: unique `intent_code`; urgency, required/fallback channel arrays, template code, localization flag and status.
- `krim_communication_recipients`: intent, organization/user recipient references, destination hash, language, timezone, resolution source and resolution status.
- `krim_communication_providers`: channel/provider, credential reference, priority, status, configuration and last-success/failure timestamps.
- `krim_communication_routes`: intent/channel/provider, route order, fallback threshold and retry limit; unique route ordering by (intent, channel, route_order).
- `krim_communication_suppressions`: user/org, channel, destination hash, reason and effective interval.
- `krim_communication_delivery_events`: delivery reference, event type, provider event ID, event timestamp and payload. Allowed event types include queued, sent, delivered, opened, clicked, bounced, failed, complained and unsubscribed.
- `krim_inbound_webhook_events`: integration/event identifiers, signature-valid flag, processing state, attempt count, payload/headers and failure reason. A unique index on (integration_id, event_id) and processing index were visible.
- Earlier catalog/source review also identified `krim_notification_outbox`, `krim_notification_deliveries` and `krim_notification_retry_events` with attempt/status/provider fields. This audit did not independently certify every constraint on those three tables; those definitions must be fetched in a focused follow-up before any migration is designed.

## RLS and authorization observations

- RLS is enabled on the inspected communication and inbound-webhook tables in both environments.
- The inspected communication tables do not have FORCE ROW LEVEL SECURITY enabled. This is not automatically a defect, but privileged-owner/service-role paths must be reviewed separately.
- Visible policies are predominantly SELECT-only; no end-user direct write policy was evidenced in the inspected policy set.
- Intent and route policies expose active configuration rows to authenticated users.
- Provider rows are scoped to organization access.
- Recipient rows are scoped to the recipient user or organization membership.
- Suppression rows are scoped to the recipient user or organization membership.
- Delivery-event reads are joined through the delivery and outbox organization. The predicate explicitly allows rows where the outbox organization is NULL; that global-row behavior requires an explicit product/security decision and negative cross-tenant tests before launch.
- Inbound webhook event reads are scoped through the related integration; integrations with NULL organization IDs receive global-style treatment in the policy predicate and require review.
- RLS policy inspection is source/catalog evidence only. No authenticated JWT tests were run for same-organization, cross-organization, anonymous, or service-role access.

## Integrity and idempotency observations

- Unique intent codes and route ordering are present.
- Inbound webhook events have a unique (integration_id, event_id) key, providing a database-level duplicate-event guard for that table.
- Delivery-event history has a normal lookup index by delivery and descending event time; the inspected index list did not show a unique constraint on provider event ID. Duplicate provider callbacks therefore remain a runtime/idempotency test requirement.
- The outbox has an idempotency-key field according to the earlier column catalog, but its exact uniqueness semantics were not certified in this focused output. A nullable field alone is not a concurrency-safe idempotency guarantee.
- Retry and lease recovery behavior cannot be inferred from table columns alone; claim/finish function bodies and scheduler execution must be verified.

## Function-level observations

Catalog inspection surfaced SECURITY DEFINER functions in related delivery/webhook areas, including internal event-webhook enqueueing and delivery-POD operations. The internal webhook enqueue function is service-role-only in the inspected ACL output. Admin delivery functions explicitly check authenticated identity, AAL2 and platform-admin permission in their source. These are adjacent delivery/webhook mechanisms and should not be confused with a proven user-notification dispatcher.

The prior provider/retry-worker review remains controlling: the Production retry worker handles founder Telegram inquiry/follow-up queues, not all nine workspace notifications; the email provider adapter does not currently send in its inspected branch; the Staging Resend worker has real send capability and is not safe to invoke in ordinary QA.

## Required follow-up before implementation

1. Fetch complete definitions, constraints, indexes, grants and policies for the outbox, deliveries and retry-event tables separately (avoid truncated aggregate output).
2. Trace every insert/update producer into the outbox and communication-delivery tables, and map each to the nine workspaces.
3. Inspect every claim/finish/lease/recovery RPC body and prove crash recovery and duplicate-invocation behavior.
4. Add a provider-event uniqueness/idempotency design for delivery callbacks, after confirming the provider's event-ID semantics.
5. Resolve NULL-organization visibility behavior for delivery events and inbound webhook events.
6. Build staging-only recipient allowlisting and dry-run/test-sink protections before any provider invocation.
7. Run JWT-based positive and negative RLS tests using synthetic identities; do not use Production data or real provider destinations.

## Evidence boundary

This report records database catalog/source inspection only. It does not establish that any notification was delivered, that all nine workspaces are covered, that retries recover from worker crashes, or that recipient isolation passes runtime tests. No provider messages were sent and no database changes were made.
