# Phase 04.16 — Notifications, Delivery Reliability and Operational Escalation Audit

Date: 2026-11-26  
Scope: Read-only comparison of Production and Staging notification tables, RLS, worker functions, Edge Functions, scheduling and escalation controls. No messages were sent, no queue rows were created, and no schedules, secrets, functions or policies were changed.

## Executive result

**FAIL — notification data structures and some operational controls exist, but there is no verified end-to-end customer/partner/driver notification service. Staging is materially incomplete compared with Production scheduling and worker deployment. Mandatory-versus-optional notification enforcement is not demonstrated.**

## Evidence inspected

- Notification data model: `krim_notification_outbox`, `krim_notification_deliveries`, `krim_notification_preferences`, `krim_notification_retry_events`, `krim_operational_notification_runs`, `krim_operational_notification_run_events`, `krim_communication_delivery_events`, legacy `notifications`.
- RLS policies and FORCE RLS flags on the above tables.
- Notification and exception-escalation database functions and ACLs.
- Production and Staging Edge Function inventories and source for notification workers.
- Production `pg_cron`/`pg_net` extensions and active schedules; Staging extension/scheduler availability.
- Queue row counts and existing in-app notification counts.
- Repository source for the Staging Resend worker on `remediation/phase-03dw-isolation-2026-11-26`.

## Positive controls

1. Outbox schema records event ID, organization, recipient type/reference, notification type, channel, priority, payload, status, schedule, attempts, errors, provider and provider message ID.
2. Delivery schema records channel/provider/status, attempt count, next attempt, sent/delivered/failed timestamps, last error and provider message ID.
3. Retry event schema records previous/new status, attempt number, retry time, error, worker ID and timestamp.
4. Unique idempotency indexes exist for notification outbox, notification preferences and operational notification runs.
5. Notification tables have RLS enabled in both environments. Read policies generally scope by organization membership or own user ID.
6. Production has a five-minute notification retry cron job that calls the `krim-notification-retry-worker` Edge Function using a Vault secret.
7. Production has a five-minute exception escalation worker and an authenticated, organization-scoped exception acknowledgement RPC. Escalation processing RPC is not directly executable by authenticated/anon.
8. Staging Resend worker uses a custom secret header, requires a secret of at least 32 characters, uses service-role access server-side, checks email confirmation, escapes HTML, constrains the workspace path and sends an idempotency key to Resend.

## Findings

### F04.16-01 — Production retry worker is not a general customer notification dispatcher (CRITICAL)

Production `krim-notification-retry-worker` v14 is named as a notification worker, but its inspected source processes founder Telegram enquiry/follow-up retry queues using Telegram bot credentials and internal founder retry RPCs. It does not claim or dispatch the generic `krim_notification_outbox` rows.

The Production `krim-notification-provider-adapter` v18 is an authenticated platform-admin diagnostic adapter. Its Resend route reports credential availability and explicitly returns `sending_enabled: false`; its Telegram route sends a founder-authorized test message. This is not evidence of production transactional email/push delivery.

### F04.16-02 — Staging scheduler is absent (CRITICAL)

Production has `pg_cron` and `pg_net`, with nine active scheduled jobs, including notification retry and exception escalation every five minutes.

Staging has neither `pg_cron` nor `pg_net` installed in the inspected extension list; `cron.job` is absent. Therefore no Staging cron schedule is present for the Resend worker or exception escalation. The Staging Resend Edge Function is deployed, but a deployed worker without a scheduler is not an operational delivery pipeline.

### F04.16-03 — Staging and Production worker responsibilities do not match (HIGH)

Production deploys `krim-notification-retry-worker` v14 and `krim-notification-provider-adapter` v18. Staging deploys only `krim-resend-email-worker` v1 for notification-related email; the other two are absent.

The Staging Resend worker handles a narrow partner-verification “additional information required” email workflow. It is not a generic dispatcher for customer booking, quotes, shipment lifecycle, driver assignments, delivery, claims, disputes, security and account events.

### F04.16-04 — Staging Resend worker secret and runtime configuration are unverified (HIGH)

The Staging worker requires `KRIM_NOTIFICATION_CRON_SECRET`, `RESEND_API_KEY`, `RESEND_FROM_EMAIL`, service-role key and Supabase URL. Secret values are not exposed or inspected, correctly; configuration presence/validity and actual delivery were not verified. The Edge Function has `verify_jwt=false` and relies entirely on the custom secret header. This requires negative tests for missing, short, wrong, replayed and rotated secrets, plus confirmation that the secret is stored in both the scheduler and function environment.

### F04.16-05 — No end-to-end generic notification pipeline is evidenced (CRITICAL)

Both environments contain the generic outbox, deliveries, preferences and retry tables. Both have zero rows in these tables and zero operational notification runs. Production has five rows in legacy `notifications`; Staging has zero. No evidence was found that booking, quote, partner assignment, driver assignment, pickup, transit, POD, claim or dispute state changes atomically enqueue the corresponding user-facing events.

A table and worker schema do not prove that lifecycle events reliably create outbox records or that the intended recipient is resolved correctly.

### F04.16-06 — Mandatory service/security notifications are not protected from opt-out by inspected schema (CRITICAL)

`krim_notification_preferences` exposes `user_id`, `organization_id`, `notification_type`, `channel`, `enabled` and quiet-hours fields. The inspected schema does not show a mandatory/essential classification, a non-overridable policy flag, or a protected category that the user cannot disable.

There may be enforcement in function code not captured by the schema, but no such enforcement was proven in this audit. Until verified, essential security, authentication, compliance, safety, shipment exception and transactional status notices must not be assumed protected from opt-out or quiet-hour suppression.

Marketing/announcement preferences must be separately configurable and must never suppress essential service/security notices.

### F04.16-07 — RLS is enabled but not FORCE RLS (MEDIUM)

The seven inspected notification tables have RLS enabled in both environments, but `relforcerowsecurity=false` for all. This does not by itself establish a vulnerability because privileged owners/service-role operations may be intentional, but table-owner and SECURITY DEFINER paths must be reviewed. Keep service-role worker access isolated and never expose it to browsers.

### F04.16-08 — Provider acceptance is not final delivery (HIGH)

The Resend worker increments its successful count when the provider returns an accepted message ID. This is provider acceptance, not proof of mailbox delivery, inbox placement or user visibility. Production communication delivery events have provider event ID, event type and event time fields, but actual provider webhook ingestion, signature verification, deduplication, event ordering and bounce/complaint handling were not proven.

### F04.16-09 — Escalation schedule and recipient path are only partially proven (HIGH)

Production runs the exception escalation processor every five minutes and stores escalation run/event structures with idempotency keys. The acknowledgement RPC is authenticated. However, the complete mapping from escalation policy → responsible recipient → in-app/email/push delivery → escalation confirmation → next-level escalation was not traced end to end. Staging has no scheduler and denies authenticated EXECUTE on the acknowledgement RPC, so Staging cannot currently verify the same operator workflow.

### F04.16-10 — Push, SMS and multi-channel fallback are not verified (HIGH)

The inspected generic schema can represent channels, but no deployed generic push/SMS dispatch provider or end-to-end fallback was established. Browser push permission, device-token lifecycle, expired-token removal, SMS provider, channel failover and delivery receipts were not tested. Do not claim push or SMS readiness.

### F04.16-11 — No operational delivery evidence exists (HIGH)

Production and Staging each have zero generic outbox rows, delivery rows, preferences, retry events and operational notification runs. The five Production legacy in-app notifications are not proof of current end-to-end lifecycle delivery. No real provider message was sent during this audit.

## Required remediation and test plan

1. Define a versioned notification event catalogue for Customer, Partner, Driver, Warehouse, Customs, Operations and Administration. Include booking created, quote received/accepted/rejected, partner assignment, driver invitation/assignment, pickup, in-transit, delay, exception, POD verified, delivery completion, claim/dispute, security/auth and account events.
2. Mark each event as essential transactional/security, operational, or optional marketing. Enforce essential status server-side; user preferences may mute only eligible optional categories. Quiet hours must not suppress urgent safety/security/compliance notices.
3. Implement a generic transactional outbox producer that writes the business event and notification intent atomically, with a unique event/idempotency key and recipient-resolution snapshot.
4. Deploy and schedule a single reviewed generic dispatcher in isolated Staging. Separate channel adapters for email, in-app, push and SMS; no production recipients or live provider traffic in tests.
5. Reconcile Staging migrations and ACLs for notification functions. Grant no broad EXECUTE privileges; verify service-role-only queue claim/finish functions and deny anon/authenticated direct queue mutation.
6. Configure scheduler secrets via secure secret management; never put secrets in repo, browser code, logs or chat. Verify secret rotation and fail-closed behavior.
7. Add provider webhook ingestion with signature verification, event ID deduplication, replay protection, event ordering tolerance, bounce/complaint handling and delivery-state reconciliation.
8. Test recipient membership and tenant isolation, wrong-user read, cross-org read, preference manipulation, mandatory notice opt-out, quiet hours/time zones, duplicate source event, duplicate worker invocation, concurrent claim, provider 429/5xx/timeout, permanent rejection, invalid email, unconfirmed email, expired push token, dead-letter queue and retry exhaustion.
9. Verify delivery history in each workspace: created → queued → attempted → provider accepted → delivered/bounced/failed, with timestamps, provider reference, retry count and human-readable failure state.
10. For operational escalations, prove SLA start/pause/resume, holiday/timezone handling, recipient on-call mapping, acknowledgement, escalation level changes, closure cancellation and no repeated alerts after resolution.
11. Use synthetic Staging recipients and provider sandbox/test mode. Do not send customer/partner messages or turn on live notification delivery until the Staging test suite passes.
12. Keep Production unchanged and keep mobile app notifications out of this website-only phase.

## Status register

| Control | Status |
|---|---|
| Generic outbox/delivery/retry schema | VERIFIED PRESENT |
| Idempotency indexes | VERIFIED PRESENT |
| Notification RLS enabled | VERIFIED |
| RLS FORCE enabled | NOT ENABLED |
| Production scheduled retry job | VERIFIED PRESENT |
| Production worker is generic user dispatcher | FAIL |
| Production provider adapter sends transactional email | FAIL / DIAGNOSTIC ONLY |
| Staging generic dispatcher parity | FAIL |
| Staging Resend worker source/authentication | STATICALLY REVIEWED |
| Staging scheduler and cron delivery | FAIL / ABSENT |
| Essential-notification non-opt-out enforcement | NOT VERIFIED |
| Event-to-outbox transactional wiring | NOT VERIFIED |
| Email provider acceptance/delivery webhooks | NOT VERIFIED |
| Push/SMS delivery and fallback | NOT VERIFIED |
| Exception escalation end-to-end recipient path | NOT VERIFIED |
| Runtime/provider/cross-tenant/retry tests | NOT TESTED |

## Change control

Read-only audit only. No DB writes, migrations, grants, Edge Function deployments, schedule changes, secret reads, message sends, provider tests, synthetic recipients or Production changes were made.
