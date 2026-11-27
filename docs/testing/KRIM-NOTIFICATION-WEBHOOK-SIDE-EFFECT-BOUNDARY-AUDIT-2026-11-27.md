# KRIM Notification and Webhook Side-Effect Boundary Audit — 2026-11-27

## Scope
Staging Supabase project `qrpcivhdxobiaofppbkl` and repository branch `staging/phase00-env-isolation` only. Read-only audit. Production was not accessed.

## Confirmed repository worker call paths
- `krim-notification-email-worker` calls:
  - `krim_claim_email_notification_delivery`
  - `krim_cancel_email_notification_delivery`
  - `krim_check_notification_email_eligibility`
  - `krim_complete_email_notification_delivery`
  - Reads `krim_notification_outbox` and Auth user records.
  - Has a `KRIM_NOTIFICATION_EMAIL_SENDING_ENABLED === "true"` gate, then sends real email to Resend API. Never invoke during test-lane work.
- `krim-notification-retry-worker` calls:
  - `krim_internal_claim_founder_telegram_retries`
  - `krim_internal_finish_founder_telegram_retry`
  - `krim_internal_claim_founder_followup_telegram_retries`
  - `krim_internal_finish_founder_followup_telegram_retry`
  - Sends real Telegram messages. Never invoke during test-lane work.
- `krim-notification-provider-adapter` has an authenticated platform-admin Telegram test route that sends a real Telegram message. Its Resend route reports credential status only and states sending disabled. Do not invoke the Telegram test route as part of automated workflow testing.

## Deployed/repository drift
- Repository contains `krim-notification-email-worker`, `krim-notification-retry-worker`, and `krim-notification-provider-adapter`.
- The deployed Staging inventory previously identified `krim-resend-email-worker` as ACTIVE with `verify_jwt=false`, protected by `x-krim-cron-secret`. Its source claims the legacy Resend queue and calls `https://api.resend.com/emails`.
- The currently fetched repository email worker has a separate enable flag and a different claim/finish RPC contract. The deployed legacy function is not a source-equivalent deployment of the repository function. Treat deployed code as an independent live worker until explicitly reconciled.
- The deployed list also contains owner/admin and Phase 00 fixture functions. Their invocation is outside this audit.

## Database-side notification effects
- `public.krim_events` has two AFTER INSERT triggers:
  1. `trg_krim_customer_shipment_in_app_notification` → `krim_internal_create_customer_shipment_in_app_notification()`.
  2. `trg_krim_enqueue_event_essential_emails` → `krim_internal.krim_enqueue_event_essential_emails()`.
- The notification trigger creates rows in `public.notifications` for supported customer, partner and driver shipment/assignment event types.
- `public.notifications` has a BEFORE INSERT/UPDATE history trigger `trg_krim_sync_in_app_notification_history`; it maintains delivered/read history fields.
- Therefore, inserting a synthetic row into the shared `krim_events` table is not side-effect-free, even if no workflow runner is manually called. A test lane must suppress or redirect both event-trigger effects before test events are permitted.

## Webhook boundary
- `public.krim_internal_enqueue_event_webhook_deliveries(bigint,text)` is SECURITY DEFINER and service_role-executable; anon/authenticated EXECUTE are false.
- It reads active `krim_webhook_endpoints` and inserts pending `krim_webhook_deliveries` for matching event subscriptions.
- The Staging endpoint table had zero rows at the prior inventory snapshot. This reduces current delivery exposure but is not a durable isolation control.
- No SQL routine caller or public table trigger invoking this webhook enqueue function was identified in the targeted source/trigger scan. External service-role callers and non-SQL callers remain unverified.
- Do not call the webhook enqueue routine or any delivery worker in test runs.

## Privilege and caller interpretation
- Notification claim/finish/eligibility RPCs and webhook enqueue are privileged service-side operations. No broad anon/authenticated execution path was identified for the sensitive queue claim/finish routines in the audit snapshot.
- A SQL routine name search is not a complete call graph: dynamic SQL, Edge Function RPC calls, dashboard invocations, external schedulers and operator scripts may not appear as SQL routine callers.
- Current cron inventory previously showed only the workflow runtime and capacity-hold expiry jobs; no dedicated notification/webhook cron was identified. This does not prove the absence of external schedulers.

## Mandatory test boundary before test events
1. Do not insert synthetic events into shared `krim_events` until both AFTER INSERT triggers have a verified test-lane no-op/isolated path.
2. Do not invoke deployed `krim-resend-email-worker`, repository email worker, Telegram retry worker, provider adapter Telegram test route, or webhook delivery routines during Phase 00 workflow tests.
3. Add an explicit, typed test-lane/run identifier to all queue/outbox/delivery records, and make every claim/retry/replay/finish function filter and validate that lineage.
4. Keep production lane as the default for ordinary business events; client-supplied metadata must never grant test-lane status.
5. Use a provider sink/mock for any provider integration test; verify no outbound network request is possible.
6. Reconcile deployed worker source and repository source, then deploy only to Staging after review and test.

## Status
- Read-only audit only. No SQL writes, migrations, queue claims, provider calls, webhook deliveries, emails, Telegram messages, test events or fixture provisioning.
- No production project accessed.
- Phase 00 remains OPEN — NOT APPROVED. Phase 01 is not authorized.
