# Phase 00 — Notification outbox, delivery, retry and scheduler review

**Date:** 2026-11-25  
**Environment:** Production Supabase, read-only catalog/source review  
**Status:** Source/catalog review completed for selected notification components; no runtime delivery test performed.  
**Safety:** No queue row was claimed or modified; no cron job was invoked; no email, Telegram, SMS or webhook was sent.

## What was inspected

- Public notification/outbox/delivery/preference/retry/run table schemas.
- Private `krim_internal` functions:
  - `claim_notification_outbox`
  - `complete_notification_delivery`
  - `enqueue_communication_intent`
  - `mark_notification_delivery_result`
  - `resolve_notification_provider`
  - `schedule_notification_retry`
  - `start_notification_run`
  - `validate_notification_delivery`
- Public founder Telegram claim/finish retry functions.
- Production `cron.job` inventory.
- Production Edge Function inventory and the source of the notification retry worker and provider adapter.

## Positive findings

1. A generic notification data model exists: `krim_notification_outbox`, `krim_notification_deliveries`, `krim_notification_preferences`, `krim_notification_retry_events`, plus operational notification run and event tables.
2. Communication intents route through active communication routes and providers. `enqueue_communication_intent` requires an idempotency key and returns an existing outbox row for a repeated key.
3. The generic outbox claim function uses row locking with `FOR UPDATE SKIP LOCKED`, a bounded lease (30–3600 seconds), and records worker identity.
4. Delivery completion checks the worker identity stored on the outbox row before changing status. Successful completion records sent state and provider message ID; failed completion marks delivery failed and schedules the outbox for retry.
5. Retry scheduling records a retry event and validates retry seconds. Provider resolution fails closed if no active provider or credential reference is configured.
6. Founder Telegram retry functions use recipient/type/idempotency filters, row locks with `SKIP LOCKED`, attempt caps, processing state, provider message IDs, and dead-letter state after the fifth failed attempt.
7. The active Production cron inventory includes a five-minute job for the founder Telegram retry Edge Function. The cron command retrieves the secret from Vault at execution time; the secret value was not read or disclosed.

## Important gaps and risks

### N-01 — Generic outbox has no identified active dispatcher in the inspected Edge Function/cron inventory

The generic database primitives exist, including claim, provider resolution, validation, delivery completion and retry scheduling. However, the inspected Production Edge Function inventory contains no generic multi-channel notification delivery worker, and the active cron inventory has a founder Telegram retry job but no generic outbox dispatcher schedule.

This means the existence of generic queue tables and RPCs does not prove customer/partner/driver/warehouse/finance notifications are actually dispatched. Identify the intended worker in another runtime (if any) and prove it is deployed and scheduled. If none exists, generic external notifications are not operationally complete.

### N-02 — Generic claim/validate functions do not by themselves prove an end-to-end provider send

The database path can claim an outbox row and create a delivery record, but no matching generic provider-send worker was identified in the deployed Edge Function inventory. The provider adapter currently supports an email/Resend credential-readiness response with sending disabled, and a founder Telegram test action that performs a real send. Neither is a general customer notification dispatcher.

### N-03 — Generic retry and founder retry are separate systems

The generic outbox functions and the founder-only Telegram retry worker are separate paths. The deployed retry worker claims only founder Telegram inquiry and follow-up notification types. It does not demonstrate customer/partner/driver journey notification retry coverage.

### N-04 — Delivery status semantics need reconciliation

The generic completion function marks successful provider response as `sent` and sets `delivered_at` at the same time. A provider acceptance/send response is not necessarily proof that the recipient's device/mailbox received or displayed the message. The product should distinguish at least queued, processing, sent/accepted, delivered (where provider delivery receipts exist), failed, retrying and dead-letter. Do not label provider acceptance as recipient delivery without provider evidence.

### N-05 — Worker lease and failure recovery require runtime tests

The generic claim function stores a lease deadline in `next_attempt_at`, but the inspected function only claims rows in `pending` state. A worker crash after changing a row to `processing` needs a verified lease-expiry recovery path. The inspected retry scheduler requires the worker identity, but no generic worker was found to demonstrate timeout recovery. Test worker crash, lease expiry, stale worker completion, concurrent claim, provider timeout, and duplicate provider callback.

### N-06 — Preferences and mandatory service notices need policy separation

A notification-preferences table exists, but the inspected schema alone does not show how mandatory transactional/security notices are protected from user opt-out or quiet-hour suppression, nor how legally required channel consent is enforced. Define essential service notices separately from optional marketing/preferences and prove consent enforcement at the provider send boundary.

## Production scheduler evidence

The read-only `cron.job` inventory showed an active five-minute schedule for `krim-notification-retry-worker`, which calls the founder Telegram retry Edge Function using a Vault secret. No active cron job for the generic `krim_internal.claim_notification_outbox` / delivery pipeline was identified in the returned active job list.

No cron job was manually triggered.

## Decision

**Notification data model and database primitives: PARTIAL PASS (source/catalog only).**

**Founder Telegram retry: SCHEDULE PRESENT; delivery not runtime-tested.** It remains a real-send path and must not be invoked until an isolated test chat and explicit test approval are confirmed.

**Generic customer/partner/driver notification delivery: NOT PROVEN / BLOCKED.** A generic outbox, provider routing and retry primitives exist, but the inspected deployed workers/schedules do not establish an operational multi-channel dispatcher.

**Mandatory journey notifications: NOT APPROVED for launch** until each required event has a verified recipient mapping, route/provider, consent/policy decision, send worker, retry/dead-letter behavior, delivery evidence, and user-visible notification state.

## Next actions

1. Search the repository and all deployed runtimes for any generic notification dispatcher not represented in the current Edge Function inventory.
2. Trace shipment, assignment, pickup, transit, delivery/POD, invoice, payment and exception events into notification intents/outbox rows.
3. Confirm which channels are supported and isolate provider credentials/test recipients for Staging.
4. Implement or complete a safe generic dispatcher only after the current deployment architecture is verified and approved.
5. Add synthetic runtime tests for queue claims, idempotency, retries, dead-letter, stale leases, preference/consent rules and provider delivery receipts.
