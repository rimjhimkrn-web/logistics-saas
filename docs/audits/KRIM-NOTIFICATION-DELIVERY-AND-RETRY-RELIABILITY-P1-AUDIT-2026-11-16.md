# KRIM Notification Delivery and Retry Reliability Audit
Date: 2026-11-16

## Executive result

**NO-GO for treating notifications as a production-reliable customer communication service.** The current live notification implementation is a founder-only Telegram retry path plus a provider readiness probe. It does not yet provide end-to-end customer notification delivery evidence.

Two concrete reliability/integrity defects were confirmed in the live implementation:

1. **P1 — a worker crash can strand claimed outbox rows in `processing` indefinitely.** Both Telegram claim RPCs select only `pending`/`failed` rows and set them to `processing`. Neither the claim query nor the retry worker includes a stale-processing lease/reclaim path. The outbox schema has no explicit lease expiry or claim token/lease field. A process crash after claiming but before finishing can therefore leave the row permanently outside future retry selection.
2. **P1 — Telegram API acceptance is recorded as delivery.** Both finish RPCs set `delivered_at` to the current timestamp whenever the Telegram `sendMessage` API returns success. The provider response confirms API acceptance/sending, not that a recipient received or read the message. The same transition also sets `sent_at`, but the `delivered_at` field overstates the evidence.

Additional readiness gaps:
- The active notification provider adapter only reports whether the Resend credential exists; it explicitly returns `sending_enabled: false` and contains no Resend send implementation.
- The Telegram retry worker processes only founder Telegram inquiry and follow-up queues, not general customer/partner notification channels.
- The live `krim_notification_outbox` and `krim_notification_deliveries` tables both returned zero rows at audit time. No live delivery/retry evidence exists to demonstrate successful operational notifications.
- The retry worker is deployed with JWT verification disabled, but it implements a separate long random cron-secret check and a platform-admin authenticated fallback. The internal claim/finish RPCs are restricted to service_role/postgres in the observed ACL. No unauthenticated queue claim path was found in the inspected implementation.

## Live implementation reviewed

### Edge Functions
- `krim-notification-provider-adapter` — active, JWT required. Authenticates the caller, requires platform-admin permission, checks Resend credential presence without sending, and supports an explicit founder Telegram test message.
- `krim-notification-retry-worker` — active, JWT verification disabled. Requires a configured cron secret (minimum 32 characters) or a valid platform-admin session; processes only two founder Telegram retry queues.
- `public-shipment-tracking` — active, public endpoint. Uses a 32-character hexadecimal tracking token, no-store response headers, and returns ordinary tracking events separately from consent-gated GPS points. The prior public-tracking abuse-control/rate-limit audit remains applicable.

### Retry state machine
- Claim RPCs use row locking with `FOR UPDATE SKIP LOCKED`, bounded batch sizes and attempt limits.
- Claim RPCs move eligible rows to `processing`.
- Finish RPCs transition successful API calls to `sent`, and failures to `failed` or `dead_letter` with retry backoff.
- Neither claim function recovers expired/stale `processing` rows.
- Finish functions stamp both `sent_at` and `delivered_at` on Telegram API success.

### Production evidence
- `krim_notification_outbox`: 0 rows.
- `krim_notification_deliveries`: 0 rows.
- The outbox schema includes status, attempt_count, next_attempt_at, sent_at, delivered_at, provider_message_id and metadata, but no dedicated processing lease expiry or claim-token field.
- Claim/finish RPCs are SECURITY DEFINER and observed ACLs are limited to postgres/service_role.

## Required remediation — not applied

1. Introduce a bounded processing lease (for example, `claimed_at` and `lease_expires_at`) plus a unique claim token/worker identifier. Allow only expired claims to be reclaimed, using row locking and compare-and-set completion so a delayed worker cannot overwrite a newer attempt.
2. Add a scheduled stale-claim recovery path and alert on rows exceeding the lease/maximum retry window.
3. Reserve `sent_at` for provider acceptance. Populate `delivered_at` only when the provider supplies a genuine delivery receipt/webhook and the event can be securely correlated to the outbox row. Otherwise keep delivery state unknown/accepted.
4. Add provider event ingestion with signature verification, deduplication, event ordering, invalid-recipient/bounce/suppression handling and dead-letter observability before enabling email delivery.
5. Implement the actual Resend send path and customer/partner notification types, or keep those channels visibly disabled. A credential-presence probe is not a working email adapter.
6. Add staging tests for worker crash after claim, duplicate worker invocation, stale lease recovery, delayed completion after reclaim, provider timeout after remote acceptance, duplicate provider webhooks, and delivery-vs-acceptance semantics.
7. Run an authorized founder-only test after configuration and persist evidence of provider acceptance and any actual delivery receipt separately. Do not send customer/partner messages as part of testing.

## Release impact

**NO-GO for customer-facing notification reliability and for any UI/analytics that represents Telegram API success as confirmed recipient delivery.** The existing founder-only retry design has useful authorization, bounded attempts and queue locking, but it needs lease recovery and truthful delivery-state semantics. Email is not yet enabled for sending.

## Evidence boundaries

Read-only inspection of live Edge Function source, database function definitions/ACLs, outbox columns and aggregate row counts. No function was invoked, no message was sent, no queue row was changed, and no production schema or configuration was modified.
