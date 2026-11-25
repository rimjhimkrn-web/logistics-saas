# Phase 00 — Notification scheduling, callback and event-ingestion audit

**Date:** 2026-11-25  
**Branch:** `qa/phase-00-baseline-2026-11-25`  
**Scope:** Read-only inspection of Production and Staging scheduling catalogs, notification/webhook table counts and schemas, notification-related Edge Function source inventory, and existing notification worker/function definitions.  
**Result:** Production has one active five-minute cron job for the founder-only Telegram retry worker. No notification/Resend provider callback Edge Function was found in the QA source tree or active Edge Function inventory reviewed. Notification delivery and webhook event tables are empty. Staging has no visible `cron.job` relation in the inspected database.  
**Safety:** No cron job was invoked, changed, paused or rescheduled. No function was called. No provider request or database write was made.

## 1. Production scheduler

Read-only query of `cron.job` found one active notification-related job:

| Job | Schedule | Target |
|---|---|---|
| `krim-notification-retry-worker` | `*/5 * * * *` | Production Edge Function `krim-notification-retry-worker` |

The job sends an HTTP POST every five minutes and supplies a bearer token sourced from the Supabase Vault secret reference `krim_notification_cron_secret`. The secret value was not read.

The target worker source processes only the founder inquiry and founder follow-up Telegram queues. It does not call the general `krim_internal.claim_notification_outbox` / delivery pipeline and does not process the general customer/partner outbox.

**Conclusion:** A scheduler exists, but it schedules the founder Telegram retry worker only. It is not evidence of a general notification dispatcher.

## 2. Staging scheduler

Read-only catalog check returned:
- Production: `cron.job` relation exists.
- Staging: `cron.job` relation is absent (`to_regclass('cron.job')` returned null).

This establishes no visible pg_cron job catalog in the inspected Staging database. It does not establish whether an external scheduler exists outside the database.

**Conclusion:** No Staging database cron schedule for notification delivery was evidenced.

## 3. Notification and webhook event tables — Production snapshot

| Table | Rows |
|---|---:|
| `krim_communication_delivery_events` | 0 |
| `krim_inbound_webhook_events` | 0 |
| `krim_webhook_deliveries` | 0 |
| `krim_webhook_endpoints` | 0 |
| `krim_notification_retry_events` | 0 |
| `krim_notification_outbox` | 0 |
| `krim_notification_deliveries` | 0 |

These are point-in-time live counts. They show no recorded notification delivery, notification retry, inbound webhook, or outbound webhook delivery evidence in these tables at inspection time.

The event table schemas include provider event IDs, event type/time, payload, signature-valid flag, processing status, attempt count and failure reason. Schema capability is not proof of a functioning callback handler.

## 4. Provider callback / webhook source inventory

The QA repository tree contains:
- `krim-notification-provider-adapter`
- `krim-notification-retry-worker`
- Razorpay payment webhook and verification functions
- legacy Cashfree webhook functions

No Resend delivery-webhook endpoint or generic notification provider callback Edge Function was found in the inspected tree. The active Edge Function inventory reviewed earlier likewise did not show a dedicated Resend callback function.

The existing payment webhook functions are not substitutes for Resend or general communication provider callbacks.

**Conclusion:** No source evidence of an active Resend delivery/bounce/complaint callback ingestion path was established.

## 5. Reliability and state-integrity implications

The following issues remain release blockers:
1. The only scheduled notification worker is founder Telegram, not the generic customer/partner notification outbox.
2. Staging does not show a database cron scheduler for the notification pipeline.
3. General notification outbox and delivery tables have no rows in Production.
4. Delivery-event and inbound-webhook tables have no rows in Production.
5. No dedicated Resend/provider callback function was found.
6. The generic outbox claim function does not reclaim expired `processing` rows.
7. Worker identity is not a per-claim fencing token.
8. Generic completion marks provider acceptance as `delivered`.
9. Retry event history has no rows in the inspected Production snapshot.
10. Staging Resend worker is a separate real-send path with source provenance and recipient-sink gaps documented in the preceding audit.

## 6. Required next implementation specification

Before any live notification activation:
- Choose one canonical domain-event → intent → recipient → route/provider → outbox → delivery attempt pipeline.
- Build a dedicated provider callback endpoint for each provider that supports delivery events; validate signatures, timestamps, replay/idempotency and provider message correlation.
- Treat provider acceptance as `sent/accepted`; only verified provider receipt events may set `delivered`.
- Add a per-claim fencing token, lease expiry and atomic stale-claim recovery.
- Add unique delivery-attempt identity and idempotent callback event IDs.
- Add bounded retries, backoff/jitter, dead-letter state and permanent-failure/suppression handling.
- Add a Staging scheduler or approved external scheduler, with explicit staging project assertion and a no-send dry-run mode.
- Add recipient allowlist/sink protection before any external Staging provider test.
- Keep essential service/security notifications separate from optional marketing preferences.
- Test worker crash, stale lease, duplicate claim, duplicate callback, invalid signature, replay, provider timeout after acceptance, bounce/complaint, retry exhaustion and tenant/recipient isolation.

## 7. Release decision

- Production founder Telegram scheduler: **ACTIVE; scope limited to founder-only queue**.
- Generic customer/partner notification scheduler: **NOT EVIDENCED**.
- Staging database notification scheduler: **NOT EVIDENCED**.
- Provider delivery callback path: **NOT EVIDENCED**.
- Production delivery/retry/webhook event records: **ZERO IN SNAPSHOT**.
- Reliable nine-ecosystem notification delivery: **NO-GO**.

**No scheduler or database object was changed. No queue was claimed. No secret value was accessed. No email, Telegram or other provider message was sent.**
