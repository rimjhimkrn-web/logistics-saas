# KRIM CRM, Consent, Notifications and External Communication Assurance Audit
**Date:** 16 November 2026  
**Scope:** Read-only review of production PostgreSQL function definitions, RLS policies, aggregate table counts, and deployed Supabase Edge Function source. No customer/partner message was sent, no test enquiry was submitted, no notification was enqueued, and no production data or schema was changed.

## Executive decision
**NO-GO for declaring CRM and notification delivery production-proven.** The core public enquiry pipeline is implemented and has meaningful anti-abuse and transactional controls, but customer consent semantics, partial-failure recovery, notification delivery proof, worker recovery, and email readiness remain incomplete. Current production counts show no real enquiries, acquisition profiles, consent records, follow-ups, notification outbox rows, deliveries or retry events; therefore live operational reliability cannot be inferred from code inspection.

## Evidence reviewed
- Production functions: `krim_submit_public_contact_inquiry`, `krim_check_public_inquiry_ip_limit`, `krim_internal_link_public_inquiry_to_service_request`, `krim_admin_schedule_inquiry_followup`, `krim_internal_queue_due_inquiry_followup_reminders`, `krim_internal_claim_founder_telegram_retries`, `krim_internal_finish_founder_telegram_retry`, and the follow-up retry claim/finish functions.
- Deployed Edge Functions: `krim-public-contact-inquiry` v20 (JWT verification disabled, application-level public validation), `krim-notification-retry-worker` v14 (JWT verification disabled, own cron-secret or authenticated platform-admin gate), and `krim-notification-provider-adapter` v18 (JWT verification enabled).
- Current RLS policies on inquiry, acquisition, consent, qualification, follow-up, outbox, delivery, retry-event, notification-preference and user-consent tables.
- Aggregate production row counts; all ten reviewed CRM/consent/notification tables currently contain zero rows.

## Positive controls
1. Public enquiry validates field lengths and email format, requires privacy-notice acknowledgement, uses a honeypot, applies per-email throttling, and uses Cloudflare-provided client IP (not caller-supplied X-Forwarded-For) for hashed IP rate limiting when available.
2. Inquiry, acquisition profile/event, qualification case, founder event and Telegram outbox row are created within one database RPC transaction.
3. The database applies an advisory lock around per-email throttling; the public endpoint does not trust caller-supplied identity or arbitrary source-page labels.
4. Public inquiry function returns a reference and distinguishes saved enquiry from booking; service-request linkage is explicitly not a quote or booking.
5. Founder follow-up reminders are separately queued and explicitly marked as founder-only; the scheduler records customer contact as false.
6. Notification retry claim functions use row locks with SKIP LOCKED, bounded batch sizes and attempt limits; Telegram messages are bounded and provider responses are checked.
7. Notification provider adapter requires a valid user session and platform-admin permission. Telegram test route sends a clearly identified founder-authorized test message only. Resend route reports credential availability and does not send.
8. CRM, consent and notification tables have RLS enabled. The reviewed policies generally scope acquisition, consent, qualification, outbox and delivery reads through organization access or the owning user.

## Findings and risks

### P0 — Privacy acknowledgement is not marketing or communications consent
The public inquiry RPC writes `privacy_consent=true` and a privacy notice version, then stores `consent_status=recorded` in acquisition metadata. This records notice acknowledgement, not granular opt-in to marketing, promotional email, WhatsApp, or partner sharing. The separate `krim_customer_consents` ledger is empty. Do not use the public-form checkbox as marketing permission or as proof of every downstream processing purpose. Split privacy notice acknowledgement from optional, purpose-specific consent, with notice/version, purpose, channel, timestamp, source and withdrawal evidence.

### P1 — Consent lifecycle is incomplete
`krim_grant_customer_consent` accepts terms, privacy, data_processing, communications and referral, but no reviewed withdrawal/revocation routine was found in the inspected function set. The upsert can re-grant an existing consent version and retains the prior `granted_at` value; the function also accepts an optional evidence reference. A separate immutable event history and a clear withdrawal route are needed before relying on this ledger for communication preferences. Marketing-specific purposes and channel-specific preferences need explicit modelling.

### P1 — Public enquiry can succeed while customer-service linkage fails
The deployed public endpoint logs a failure from `krim_internal_link_public_inquiry_to_service_request` but still returns HTTP 200 and `success=true`. The saved enquiry and founder outbox row remain, but the linked service request/qualification journey may be absent. Add a durable linkage state, idempotent retry/reconciliation job and operational alert; the user response should not imply the complete CRM journey succeeded when only intake was persisted.

### P1 — Immediate Telegram send can race the retry worker
The public endpoint sends Telegram directly after creating a pending outbox row. On provider success it updates the row to sent; on failure it marks it failed. The retry worker can claim pending/failed rows independently. There is no visible atomic claim that prevents the worker from claiming the pending row while the immediate sender is in flight. A duplicate founder alert is therefore possible under concurrent scheduling. Use a single outbox dispatcher or an atomic claim/lease before any provider call.

### P1 — Processing claims can become stranded
Retry claim RPCs set status to processing. The reviewed claim queries select pending/failed only and do not reclaim processing rows after a worker crash or timeout. A crash after claim can strand the notification indefinitely. Add lease timestamps, worker identifiers, bounded lease expiry/reclaim and a dead-letter review path. A failure to persist the finish result also needs an observable recovery mechanism.

### P1 — Retry implementation is split across overlapping RPC generations
Two enquiry retry claim/finish paths and a separate follow-up path coexist. Their attempt metadata, retry delays and finish semantics differ. The worker processes batches sequentially and can spend up to roughly four minutes in provider calls at the current 10+10 batch and 12-second timeout limits, before platform overhead. Consolidate into one versioned queue contract, add provider idempotency/deduplication where supported, and monitor queue age, attempts, stale leases and dead letters.

### P1 — “Sent” is not proof of human delivery
The Telegram worker treats provider API success as sent/delivered and writes `delivered_at`; this proves provider acceptance, not that the founder read or received a human-visible notification. Distinguish queued, provider_accepted, delivered (only if provider supplies that signal), and acknowledged/read. Do not present Telegram API acceptance as verified human delivery.

### P1 — Rate limiting has a fallback gap
The Edge Function applies hashed-IP throttling only when `cf-connecting-ip` is present. Per-email throttling still applies in the database, but the IP control is bypassed when that header is unavailable. Verify the production ingress always supplies the trusted header; otherwise fail closed or use a trusted edge-derived alternative. Never substitute caller-supplied forwarding headers.

### P1 — Follow-up scheduling can create duplicates
`krim_admin_schedule_inquiry_followup` inserts a new follow-up each time and has no idempotency key or duplicate-window guard. It updates inquiry status only when currently new, but still returns success for repeated scheduling. Add explicit duplicate prevention or make repeated calls idempotent.

### P1 — Email/Resend is not send-ready
The deployed provider adapter only checks whether `RESEND_API_KEY` exists and returns `sending_enabled=false`; it does not verify sender-domain authentication, provider account status, delivery webhooks, bounce/complaint suppression, or actual email delivery. No Resend send workflow was verified. Email must remain disabled until domain, sender identity, consent rules, delivery events, suppression and end-to-end tests pass.

### P2 — RLS alone does not certify the whole data lifecycle
RLS policies exist for the reviewed tables, but policy existence does not prove correct insert/update actor checks, consent immutability, retention, export/deletion workflows, or service-role access minimization. The public Edge Function uses the service-role key and therefore depends on strict input validation and narrowly scoped RPC calls. Review service-role data access and audit every privileged mutation before launch.

## Current production data baseline
All counts below were zero at audit time:
- Public contact inquiries
- Customer acquisition profiles and events
- Customer qualification cases
- Customer consent records and user consent events
- Inquiry follow-ups
- Notification outbox rows, delivery rows and retry events

This means no live enquiry-to-notification journey, no CRM conversion funnel, no consent lifecycle, and no retry behaviour has been proven by production records. No sample customer or partner records were created for this audit.

## Required staging verification
1. Submit synthetic enquiry with valid, invalid, missing and oversized fields; verify honeypot, CORS, content-length, per-email and trusted-IP throttles.
2. Force service-request linkage failure after intake; verify durable reconciliation and truthful response state.
3. Race immediate Telegram dispatch against worker claim; prove exactly-once logical notification and idempotent provider handling.
4. Crash worker after claim; prove lease expiry, safe reclaim, attempt count and dead-letter review.
5. Exercise provider timeout, HTTP rejection, malformed response, duplicate callback, finish-RPC failure and Telegram rate limits.
6. Verify notification preference and purpose-specific consent enforcement before any customer-facing email/WhatsApp/SMS.
7. Verify grant, withdrawal, re-grant and audit chronology without overwriting historical evidence.
8. Verify duplicate follow-up scheduling is blocked or idempotent.
9. Verify queue metrics and alerts for oldest pending, stale processing, repeated failures and dead-letter count.
10. Verify actual Resend domain/sender authentication and delivery/bounce/complaint webhooks in staging before enabling email.

## Recommended remediation order
1. Correct privacy acknowledgement vs granular consent semantics and implement auditable withdrawal.
2. Make enquiry-to-service-request linkage durable and retryable.
3. Make outbox dispatch single-owner with atomic claim/lease and crash recovery.
4. Consolidate retry RPCs and define accurate delivery states.
5. Add idempotent follow-up scheduling and queue observability.
6. Complete Resend domain, sender, webhook and consent gates.
7. Run synthetic staging E2E tests and retain redacted evidence.

## Change-control and release gates
- This audit is read-only. No production DDL, function replacement, Edge Function deployment, test enquiry, Telegram message, email, or customer/partner contact was performed.
- Production migration reconciliation remains unresolved (repository migration history does not match production history). Do not apply schema or function fixes until the complete migration crosswalk and sanitized schema manifest are reviewed.
- Financial collection remains deferred to the final phase and is outside this audit.
- **Release status: NO-GO** for claims of end-to-end CRM/notification reliability or automated customer communications. Founder-only Telegram notifications may be tested separately with explicit authorization; customer messaging remains disabled until consent and delivery controls are verified.
