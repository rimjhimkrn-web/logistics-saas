# KRIM Notification, Alert Routing and Delivery Assurance Audit — 2026-11-16

## Executive result
**Status: FOUNDER-ONLY TELEGRAM RETRY PATH EXISTS; GENERAL CUSTOMER/PARTNER NOTIFICATION DELIVERY IS NOT PRODUCTION-VERIFIED.**

Read-only review of live Supabase Edge Functions, PostgreSQL retry/finish RPCs, cron schedule, notification/outbox/delivery/preferences/consent/suppression/webhook tables and notification UI. No messages were sent, no rows were changed, no secrets were retrieved, and no provider was contacted.

## 1. Live inventory
| Area | Production rows |
|---|---:|
| Notification outbox | 0 |
| Notification delivery attempts | 0 |
| Notification retry events | 0 |
| Notification preferences | 0 |
| Operational notification runs/events | 0 / 0 |
| Outbound webhook endpoints/deliveries | 0 / 0 |
| Inbound webhook events | 0 |
| Communication delivery events | 0 |
| Communication suppressions | 0 |
| Customer consent records | 0 |
| User consent events | 0 |
| Legacy `notifications` rows | 5 |
| Payment webhook events | 10 |

Zero outbox/delivery/preference rows means no production history proves the general-purpose notification system has sent or delivered customer/partner messages. The five legacy notification rows do not establish delivery through the current outbox/provider path.

## 2. Actual deployed components

### Founder Telegram retry worker
Live Supabase Edge Function:
- `krim-notification-retry-worker`
- ACTIVE, version 14
- `verify_jwt=false`, but function performs its own authorization
- Scheduled PostgreSQL cron job every five minutes
- Cron uses a Vault-held secret; the secret value was not retrieved.

Worker:
- Requires POST.
- Authenticates either a >=32-character cron secret (SHA-256 digest comparison) or a valid user session with `admin.platform` on organization 1.
- Uses server-side service-role client and Telegram credentials; no provider secrets are exposed in the browser.
- Processes two narrowly scoped queues: founder primary Telegram alerts for new customer inquiries and due inquiry follow-up reminders.
- Uses Telegram Bot API `sendMessage`, checks HTTP response and Telegram JSON `ok === true`, captures Telegram message ID, and calls finish RPC.
- Claims up to 10 rows from each queue per invocation; provider requests have a 12-second timeout.
- Retry ceiling is five attempts.

This is a real deployed founder-only retry path, not a general customer notification service. A successful Telegram API response confirms API acceptance/message creation, not proof the human recipient read or received a notification on a particular device.

### Provider adapter
Live function `krim-notification-provider-adapter`, ACTIVE version 18, requires JWT and platform-admin permission:
- Resend email route only checks whether `RESEND_API_KEY` is configured and explicitly returns `sending_enabled:false`.
- Telegram `action=test` can send a founder-authorized test message when Telegram credentials exist.
- No SMS/WhatsApp send path is implemented in this adapter.
- No customer/partner notification dispatch path is exposed by this adapter.

The support notification dispatch UI correctly says general outbound delivery is disabled/unverified, but its hero badge names SendGrid, Twilio and WhatsApp Cloud API as if they are part of the current stack. That label should be treated as a roadmap/legacy label, not proof of connection. Its copy also describes Resend as readiness-only, which matches the live adapter.

## 3. Positive controls
- Retry claim and finish functions are SECURITY DEFINER with empty search_path and are not executable by anon or authenticated roles.
- Claim queries lock rows with `FOR UPDATE SKIP LOCKED`, preventing two concurrent workers from claiming the same pending/failed row.
- Queue filters are tightly scoped to founder primary Telegram and expected notification types/idempotency-key prefixes.
- Message length is bounded (10–3500 chars); attempt count capped at five.
- Finish functions bound status updates to the expected channel/provider/recipient/type and only a currently processing row.
- Backoff is bounded: new-inquiry retry uses exponential seconds up to one hour; follow-up retry uses exponential minutes up to four hours.
- Notification/outbox/delivery/preferences/consent/suppression/webhook tables have RLS enabled. Authenticated policies are predominantly read-only and organization/user scoped.
- The worker does not read marketing preference data or send marketing messages; its queues are founder-only operational alerts.

## 4. P0/P1 defects and gaps

### P0 — Provider acceptance is incorrectly recorded as delivery
Both founder Telegram finish RPCs set `delivered_at = now()` whenever Telegram's sendMessage API returns success. Telegram Bot API success means the API accepted/created the message and returned a message ID; it does not provide a user-device delivery receipt or read receipt. This overstates delivery certainty and contaminates future delivery reporting.

**Required:** keep `sent_at` / provider-accepted status distinct from `delivered_at`; only populate delivered_at from a provider event that genuinely establishes delivery, where that provider offers such evidence. For Telegram, report `accepted_by_telegram` or `sent`, not `delivered` or `read`.

### P0 — Claimed rows can be stranded in processing
Claim RPCs change outbox status to `processing`. The worker only claims `pending` and `failed` rows. If the worker is terminated, times out, crashes or cannot call its finish RPC after claiming, those rows can remain `processing` indefinitely. There is no visible lease expiry/reclaim predicate in either claim function. The main inquiry queue writes a claimed-at metadata value, but the claim query does not use it to recover stale claims; the follow-up claim path does not visibly record a claim lease at all.

**Required:** add a bounded claim lease/heartbeat and stale-processing recovery with a unique claim token/attempt identity. Finish must match that claim token, and reclaims must be safe against a late worker response.

### P1 — Batch duration can exceed cron HTTP timeout
The cron HTTP request has a 30-second timeout. Each provider request can take up to 12 seconds, and the worker can claim up to 10 new-inquiry messages plus 10 follow-up messages sequentially. Worst-case processing time can substantially exceed the cron request timeout. This risks overlapping invocations and orphaned claims unless the worker is bounded by elapsed-time budget and has leases.

**Required:** cap total batch size and execution budget to fit platform runtime and cron timeout, process queues with controlled concurrency, and preserve claim leases/idempotency.

### P1 — Provider idempotency is not guaranteed across ambiguous timeout
Database idempotency keys prevent duplicate enqueue for the same logical alert. They do not guarantee provider-side idempotency. If Telegram accepts a message but the response is lost, the worker may record failure and retry, creating a duplicate message. If Telegram accepted the message but the finish RPC fails, the same issue occurs.

**Required:** record an attempt ID and provider response correlation, reconcile ambiguous attempts where possible, and mark delivery outcome as unknown rather than assuming failure. Telegram's sendMessage method does not provide a general client idempotency key, so the product must explicitly accept/mitigate duplicate risk.

### P1 — No general-purpose recipient preferences or consent pipeline
Notification preference rows, canonical customer consent rows, consent event rows and communication suppression rows are all zero. The current founder-only worker does not need customer marketing consent, but no general customer/partner delivery should be enabled until channel-specific preferences, transactional-vs-marketing purpose, legal basis, unsubscribe/suppression handling and contact verification are implemented and enforced at enqueue and send time.

### P1 — No delivery webhook/callback evidence
Communication delivery events and inbound webhook events are zero. No callback/bounce/complaint/rejection pipeline was demonstrated for Resend, SMS, WhatsApp or other external providers. Do not show a generic `delivered` status without a provider event and verified correlation.

### P1 — Deployment source parity
The deployed notification retry worker is not present in the checked-in `supabase/functions` tree inspected during this audit. The deployed source was read directly from Supabase. Keep an exact version-controlled source copy and deployment record to prevent unreviewed production-only code drift.

### P1 — Cron invocation observability
The cron job invokes the worker every five minutes, but a configured cron schedule is not proof every invocation succeeded. Add/verify monitoring of HTTP response status, execution duration, claimed/sent/failed counts, stuck claims and last successful run. Do not treat an HTTP 2xx or worker `sent` count as human receipt.

## 5. UI and product truth
- The public notification dispatch page states that general live delivery is not verified and outbound dispatch is disabled. This is appropriate for the general system.
- Its provider badge naming SendGrid, Twilio and WhatsApp Cloud API is misleading without qualification; those are not verified as live sending routes in the current adapter.
- Partner and warehouse notification pages are operational visibility/attention views, not proof of external notification delivery.
- Keep separate status vocabulary: queued, claimed/processing, accepted by provider, delivered (only with genuine receipt), bounced/rejected, retry scheduled, dead-lettered, and unknown.
- Keep founder operational Telegram alerts distinct from customer/partner shipment updates and from marketing communications.

## 6. Safe next implementation sequence
1. Reconcile deployed worker source into repository and document its build/deployment version.
2. Correct status semantics: Telegram API acceptance must not set delivered_at.
3. Add claim leases, claim tokens, stale-processing recovery and bounded batch/time budgets.
4. Add observable cron/worker run history and alerts for stuck claims/dead letters.
5. Build general notification preferences, channel verification, consent/purpose classification and suppression enforcement.
6. Implement provider callback verification, signature validation, correlation, bounce/complaint handling and retention/redaction.
7. Run staging tests: duplicate enqueue, concurrent claim, crash after claim, provider timeout after acceptance, finish RPC failure, stale lease reclaim, max attempts/dead-letter, invalid recipient, suppression, cross-tenant reads and verified provider callbacks.
8. Only then conduct an explicitly authorized test to a controlled founder mailbox/chat. No test was sent during this audit.

## 7. Release safety
The production migration-history mismatch remains unresolved. No production RPC, trigger, table, RLS policy, secret, cron job or notification data was modified. Do not change finish/claim RPCs or add DDL until migration history is reconciled, then implement in staging and verify before production.

## 8. Evidence reviewed
- Live Supabase Edge Function inventory and deployed source for `krim-notification-retry-worker` and `krim-notification-provider-adapter`.
- Live cron job schedule and command (Vault secret value not accessed).
- Live PostgreSQL definitions for both claim and finish RPC pairs.
- RLS policy definitions for outbox, deliveries, retry events, preferences, communication delivery events, suppressions, customer consents and webhook tables.
- Production row counts in the inventory table above.
- `public/support/notifications-dispatch.html` and partner/warehouse notification workspaces.

## Next priority
Audit the public enquiry → CRM/customer profile → partner acquisition → qualification and founder follow-up journey for durable linkage, duplicate handling, consent boundaries, attribution and real revenue conversion evidence.