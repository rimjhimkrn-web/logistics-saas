# KRIM Notification Outbox Lifecycle Audit — 2026-11-27

## Scope and safety
- Staging Supabase project: `qrpcivhdxobiaofppbkl`.
- Repository: `rimjhimkrn-web/logistics-saas`, branch `staging/phase00-env-isolation`.
- Read-only SQL inspection and repository source review only.
- No queue claims, status changes, messages, provider calls, test events, fixture creation, migrations or production access.

## Data model verified
- `krim_notification_outbox`: event/org/recipient/type/channel/provider, content/payload, status, scheduled time, attempts, errors, idempotency, retry time, delivery timestamps and metadata.
- `krim_notification_deliveries`: outbox FK, channel/provider/status, attempt count, retry time, provider ID and timestamps.
- `krim_notification_retry_events`: append-style transition history with attempt number, retry time, error and worker ID.
- `krim_notification_preferences`: per-user/org/type/channel enabled state and quiet-hour fields.
- `krim_user_consent_events`: append-only consent decisions, including marketing email.
- `notifications`: in-app records with delivered/read history.
- Status constraints exist for outbox and delivery rows; retry history links to outbox. No typed runtime lane or fixture-run ID exists on these queue/history records.

## Claim and completion lifecycle
- `krim_internal.claim_email_notification_delivery(worker_id, lease_seconds)` claims any due `channel='email'` outbox row with attempt_count < 5, including pending rows and expired processing leases. It does not filter by provider, notification type, runtime lane or test run.
- It sets processing status, increments attempts, writes worker ID and lease expiry into `next_attempt_at`, then calls `validate_notification_delivery`.
- Validation checks recipient metadata and eligibility, active provider configuration and credential reference, then creates/returns a delivery row.
- `complete_notification_delivery` checks worker ownership and lease expiry. Success marks delivery/outbox sent; failure marks delivery failed and outbox pending or dead_letter with exponential retry and a retry-history row.
- `cancel_notification_email_delivery` cancels both delivery and outbox after validating worker ownership.
- The claim and completion wrappers are service_role-only; anon/authenticated EXECUTE are false in the inspected snapshot.
- A separate legacy `krim_internal_claim_resend_email_batch` / `krim_internal_finish_resend_email` lifecycle exists. It filters to partner-verification Resend messages, claims queued/failed deliveries and uses a separate transition implementation. The deployed legacy worker uses this path.

## High-priority findings
1. **No test-lane boundary:** the current generic email claim function has no runtime_lane or fixture_run_id predicate. A test runner cannot safely share this queue with a live worker.
2. **Generic claim is over-broad:** it claims every due email outbox item regardless of provider/type. Worker-side filtering after claim is too late; it can cancel unsupported records and hold unrelated work.
3. **Repository worker field mismatch:** `krim-notification-email-worker` selects `id,organization_id,recipient_type,recipient_reference,subject,message,provider,idempotency_key,metadata,status` but later checks `outbox.notification_type`. That field is not selected, so it evaluates as undefined and the allowed-event check fails. As written, the worker will cancel claimed items at that validation step instead of sending them. Fix the projection and add a source-level test before any deployment or invocation.
4. **Attempt and lease lifecycle:** generic claim increments attempt_count and stores lease expiry in outbox.next_attempt_at. Completion rejects expired leases. A worker crash leaves processing work to be reclaimed after lease expiry; verify the retry/recovery behavior with deterministic unit/integration tests before enabling.
5. **Legacy and generic state machines differ:** separate claim/finish paths and status/attempt logic risk conflicting workers acting on the same outbox family. Establish one canonical worker lifecycle or explicit disjoint queue ownership.
6. **Consent and preferences:** eligibility helper validates confirmed, non-deleted user and active organization membership. Essential email bypasses marketing consent/preferences. Marketing requires latest marketing_email consent and enabled email preference. Preference setter rejects disabling essential categories. This is directionally correct; test revocation and preference changes immediately before send.
7. **In-app history:** in-app notification trigger writes notification rows for event types; notification history trigger maintains delivered/read status. Shared `krim_events` inserts therefore create persistent customer/partner/driver notifications.
8. **RLS/grants:** RLS is enabled on the inspected notification tables. Outbox/delivery/preferences/retry/consent tables have no direct authenticated SELECT table grant in this snapshot despite SELECT policies; authenticated can SELECT `notifications` with own-user policy. Do not add broad grants merely to make testing convenient.
9. **Data snapshot:** the grouped status-count query returned no rows at audit time; no notification outbox/delivery/retry activity was observed in that result. This is a point-in-time observation, not a proof that workers are disabled or that future rows cannot appear.

## Recommended remediation order (not applied)
1. Patch repository worker projection to include `notification_type`; add tests proving valid and invalid event types.
2. Make claim SQL provider/type-specific and lease-safe, with an immutable production/test lane plus fixture_run_id; do not rely on worker-side filtering.
3. Add lane/run lineage to outbox, delivery and retry-history rows and enforce it in claim, validate, cancel, complete, retry, dead-letter and replay paths.
4. Make test-lane records route only to a provider sink/mock; reject real provider credentials/URLs for test runs.
5. Reconcile legacy Resend and generic email state machines; ensure exactly one active owner for each queue class.
6. Add tests for essential notification non-suppression, marketing consent revocation, opt-out, invalid recipient, retry ceiling, expired lease, duplicate idempotency key, cancellation and delivery-history integrity.
7. Confirm no notification worker is scheduled or externally invoked during testing.

## Status
- Audit only; no changes to database or worker code.
- Production untouched.
- Phase 00 remains OPEN — NOT APPROVED; Phase 01 remains unauthorized.
