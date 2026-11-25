# Phase 00 — Notification, communication and delivery reliability audit

**Date:** 2026-11-25  
**Repository:** `rimjhimkrn-web/logistics-saas`  
**Branch:** `qa/phase-00-baseline-2026-11-25`  
**Supabase environments:** Production `ebltviniygljwwseplph`; Staging `qrpcivhdxobiaofppbkl`  
**Method:** Read-only PostgreSQL catalog, aggregate row counts, grants/RLS, triggers, function definitions and source review of notification Edge Functions. No Edge Function was invoked and no external message was sent.

## Executive result

**BLOCKED — KRIM does not yet have evidence of reliable end-to-end, nine-workspace transactional notifications.**

Production contains an in-app notification table and a newer generic notification outbox/delivery/retry architecture, but the generic outbox, delivery, retry, provider configuration, preference, and operational-run tables are all empty. Staging has the same empty notification pipeline and no in-app notifications. The live legacy triggers create in-app notifications for a limited set of legacy shipment/payment/support events. The reviewed Edge Functions do not currently provide a general-purpose dispatcher for the generic outbox across all nine ecosystems.

This is a release-critical gap because journey notifications are a core operating requirement: users must be informed at meaningful lifecycle transitions, and critical service updates must not silently disappear or be disabled as ordinary marketing preferences.

## 1. Live database evidence

### Production

| Table | Rows |
|---|---:|
| `notifications` (legacy in-app) | 5 |
| `krim_notification_outbox` | 0 |
| `krim_notification_deliveries` | 0 |
| `krim_notification_retry_events` | 0 |
| `krim_notification_preferences` | 0 |
| `krim_operational_notification_runs` | 0 |
| `krim_operational_notification_run_events` | 0 |
| `krim_communication_delivery_events` | 0 |

### Staging

All eight tables above contain zero rows.

### Provider configuration

`krim_communication_providers` has no active or inactive provider rows in either environment. Production exposes authenticated SELECT only and service_role write access; Staging is service_role-only. No provider credentials were read.

### Access control

- RLS is enabled on the generic outbox, deliveries, retry events, preferences, operational runs/events, and legacy notification table.
- Generic queue/delivery writes are service_role-only; authenticated access is read-only where granted.
- Legacy `notifications` allows authenticated users to SELECT and UPDATE only their own rows under user_id = auth.uid() policies.
- Staging grants for the generic tables are service_role-only; there is no authenticated read access in the inspected grants. This is fail-closed but means the Staging notification UI/API parity is not established.

## 2. Current event coverage — legacy in-app notifications only

Production has eight notification triggers:

- `shipment_requests`: customer quote status
- `shipment_requests`: customer shipment status
- `shipment_requests`: partner assignment
- `shipment_requests`: partner shipment status
- `payment_orders`: customer payment marked paid
- `partner_payouts`: partner payout marked paid
- `support_tickets`: admin notified of new ticket
- `support_tickets`: customer support status

These trigger functions insert into the legacy `notifications` table. They do not demonstrate delivery through email, SMS, WhatsApp, Telegram or push.

**Important architecture mismatch:** the live notification triggers are attached to legacy `shipment_requests` / `payments`-era models, while KRIM's newer operating core uses `krim_shipments`, partner assignments, driver assignments, shipment legs, warehouse tasks and customs workflows. This audit did not find corresponding notification triggers on the newer lifecycle tables. Do not assume the new nine-workspace lifecycle automatically produces a customer or operator notification.

## 3. Edge Function source audit

Source reviewed from the QA branch:
- `supabase/functions/krim-notification-provider-adapter/index.ts`
- `supabase/functions/krim-notification-retry-worker/index.ts`
- `supabase/functions/krim-resend-email-worker/index.ts`

### NOTIF-01 — Provider adapter is a diagnostic/test endpoint, not a dispatcher
The adapter authenticates a Supabase user, checks platform-admin permission, and supports:
- Resend email credential-presence check only; it explicitly reports `sending_enabled: false`.
- A Telegram `action=test` path that sends a fixed founder test message to a configured chat.

It does not claim or implement generic outbox delivery. The Telegram test path has a real external side effect if invoked; it was not invoked in this audit. Do not treat a successful credential check as a successful delivery test.

### NOTIF-02 — Retry worker is for founder Telegram queues, not generic notifications
The retry worker requires POST and a configured cron secret; alternatively it accepts an authenticated platform administrator. It uses service_role and processes two specific founder Telegram queues:
- `krim_internal_claim_founder_telegram_retries`
- `krim_internal_claim_founder_followup_telegram_retries`

It does not claim `krim_notification_outbox`, nor does it dispatch generic customer, partner, driver, warehouse, customs, finance or enterprise events. Provider calls have a 12-second timeout and finish RPC result handling. Cron scheduling and deployed invocation frequency were not verified.

### NOTIF-03 — Resend worker is narrowly scoped
The Resend worker requires the notification cron secret, service_role and Resend credentials. It claims `krim_internal_claim_resend_email_batch` and sends partner-application follow-up emails to confirmed Auth users, with an idempotency key and escaped HTML. It is not a universal transactional notification worker. It reports provider acceptance, which is not equivalent to recipient inbox delivery. No Resend delivery webhook/callback or bounce/complaint reconciliation was proven in this audit.

### NOTIF-04 — No SMS, WhatsApp or push dispatcher evidence
No reviewed source or live provider configuration proves operational SMS, WhatsApp Cloud API or push-notification delivery. These channels remain NOT TESTED / NOT CONFIGURED, not PASS.

## 4. Generic queue/database function review

Production has private SECURITY DEFINER helpers, including:
- `krim_internal.claim_notification_outbox`: leases one due pending outbox row using `FOR UPDATE SKIP LOCKED`, increments attempts and stores worker_id.
- `krim_internal.validate_notification_delivery`: checks processing state and worker ownership, then creates a queued delivery record if an active provider/credential reference exists.
- `krim_internal.resolve_notification_provider`: resolves an active provider configuration and credential reference.
- `krim_internal.complete_notification_delivery`: checks worker ownership and updates delivery/outbox status.
- `krim_internal.schedule_notification_retry`: verifies worker ownership and schedules retry with a retry-event record.
- `krim_internal.start_notification_run`: creates an idempotent operational notification run.

These functions demonstrate queue/lease/retry building blocks, but **the generic queue is not live and no corresponding generic provider-dispatch Edge Function was found among the reviewed notification workers**. Function presence is not evidence of a running worker or successful provider delivery.

The separate `krim_internal.mark_notification_delivery_result` helper sets `delivered_at` when the provider request succeeds and moves the outbox to `sent`. Provider acceptance should not be conflated with confirmed delivery. The newer completion helper appears to use a `sent` state as well. Define distinct states such as queued, processing, accepted/sent, delivered, bounced, failed, suppressed and dead-lettered, with provider callbacks where supported.

## 5. Critical gaps and severity

### NOTIF-P0-01 — No end-to-end notification delivery proof
**Critical / P0.** Generic outbox and delivery tables are empty; no provider is configured; no generic dispatcher is proven running. No real customer/partner notification journey can be declared ready.

### NOTIF-P0-02 — New KRIM Core event coverage is not established
**Critical / P0.** Legacy triggers cover a subset of legacy tables only. No proven event-to-recipient/channel matrix exists for new `krim_shipments`, partner assignment, driver assignment, warehouse, customs, finance, enterprise and control-tower workflows.

### NOTIF-P0-03 — Mandatory service notifications vs preferences not defined
**Critical / P0.** Preferences table is empty, and no reviewed source establishes a hard distinction between mandatory operational/security/financial notices and optional marketing messages. Essential updates must remain deliverable even when a user opts out of promotional channels; channel/legal rules and fallback paths must be defined.

### NOTIF-P1-01 — Delivery status semantics are ambiguous
**High / P1.** Source marks provider-accepted messages as sent/delivered in parts of the queue logic. This prevents accurate reporting of sent vs delivered vs bounced/failed and can mislead the user-facing notification centre.

### NOTIF-P1-02 — Worker execution/scheduling is unverified
**High / P1.** No live outbox rows or provider rows exist; no cron schedule/last-run evidence was checked; no successful worker invocation or provider callback is proven.

### NOTIF-P1-03 — Retry/dead-letter and duplicate behavior not demonstrated
**High / P1.** Queue lease/retry helpers exist, but there are no rows to validate attempts, stale lease recovery, max attempts, dead-letter handling, provider idempotency or duplicate suppression.

### NOTIF-P1-04 — Nine-workspace recipient resolution and tenant isolation unproven
**High / P1.** The source review does not prove a single authoritative recipient resolver for all workspace roles, active memberships, role changes, organization boundaries, user deactivation and multi-recipient shipment journeys.

### NOTIF-P1-05 — Delivery provider webhooks/bounce handling unproven
**High / P1.** Resend worker records provider acceptance, but inbound delivery, bounce, complaint and suppression events were not evidenced.

### NOTIF-P2-01 — Channel redundancy and locale delivery unproven
**Medium / P2.** No operational fallback matrix for email/SMS/WhatsApp/in-app/push, language templates, time zones, quiet hours or provider outage failover has been demonstrated.

## 6. Required event coverage matrix

The following is the minimum release event inventory. Every event must resolve the correct recipients and be idempotently queued; channels are selected by criticality, verified contactability, consent/legal basis and availability.

| Ecosystem | Mandatory journey events to cover |
|---|---|
| Customer/Shipper | enquiry received; quote ready/expiring; booking accepted/rejected; payment success/failure/refund; partner assigned/reassigned; pickup; milestone/ETA exception; customs hold/release; delivery; POD verified/rejected; claim/support update |
| Partner/Carrier | application received; evidence requested/approved/rejected; capability activated/suspended; opportunity/assignment offered; accept/decline/expiry; pickup/delivery milestone; exception; payout eligibility/approval/settlement/failure |
| Driver | invitation; assignment/route change; pickup instructions; tracking consent/session start/expiry/revocation; milestone reminders; safety/exception escalation; POD accepted/rejected |
| Warehouse | inbound expected; arrival; QC hold/pass/fail; custody transfer; inventory variance; dispatch release/block; task assignment/overdue/escalation |
| Customs | dossier assigned; missing document; filing; query/hold; duty/payment status; clearance/rejection; release deadline |
| Finance | payment pending/paid/failed; refund submitted/approved/rejected/processed; reconciliation exception; invoice due/overdue; payout approved/settled/failed; approval request and escalation |
| Operations Control Tower | SLA risk; missed milestone; capacity conflict; partner/driver unresponsive; route disruption; exception ownership/escalation/resolution |
| Enterprise | onboarding and compliance state; user invite/role change; shipment and approval status; document expiry; invoice/payment; SLA breach; export completion/failure |
| Admin | privileged login/security alerts; provider outage; queue backlog/dead-letter; webhook failure; tenant/security anomaly; reconciliation failure; policy/permission change |

## 7. Required tests — NOT RUN

Use isolated Staging, synthetic users and mocked providers only until environment and provider credentials are approved.

1. Event-to-recipient matrix: each of the nine workspaces receives only its intended event.
2. Cross-tenant isolation: no recipient receives another organization’s shipment, payment, driver, warehouse, customs or finance details.
3. Duplicate source event: exactly one logical notification and delivery per recipient/channel/event idempotency key.
4. Multi-recipient fan-out: customer, partner, assigned driver and relevant operations roles receive correct scoped content.
5. Membership revoked/user disabled: no future delivery to stale recipient.
6. Essential vs promotional preference: operational/security/financial notices remain mandatory; promotional messages respect opt-out.
7. Missing email/phone/consent: no illegal send; fallback/suppression state is auditable.
8. Provider unavailable/429/5xx/timeout: bounded retries with backoff and no duplicate external sends.
9. Worker crash after provider acceptance but before DB completion: idempotent recovery and provider reconciliation.
10. Expired lease/stuck processing: safe reclaim without duplicate message.
11. Maximum retries: dead-letter, alert and owner assignment; no silent drop.
12. Resend accepted/delivered/bounced/complaint events: distinct states and suppression handling.
13. Telegram admin test endpoint: unauthorized/non-admin blocked; test message only sent after explicit owner action.
14. Channel outage fallback: only to legally permitted, verified alternate channel.
15. Locale/time zone/template escaping: correct language, safe HTML and correct local time.
16. Queue load and latency: controlled synthetic load only after staging readiness.
17. Notification centre: unread count, read state and pagination scoped to user/org.
18. Audit evidence: source event, recipient resolution, template/version, provider, attempt history, provider ID and final delivery outcome traceable.

All 18 tests remain **NOT TESTED**.

## 8. Remediation order

1. **P0:** Designate one canonical notification event contract and recipient resolver for all nine ecosystems and the new KRIM Core tables.
2. **P0:** Implement or complete the generic outbox dispatcher with provider adapter, worker lease, retries, dead-letter queue and idempotency. Do not treat the current provider-adapter diagnostic endpoint as a sender.
3. **P0:** Configure providers only after explicit owner approval; test with synthetic recipients and provider test mode/sandbox. Keep the Telegram test endpoint unused until explicitly approved.
4. **P0:** Define mandatory service/security/financial notifications separately from optional marketing and enforce non-suppressible critical events.
5. **P1:** Separate accepted/sent/delivered/bounced/failed/suppressed states; add provider callbacks and reconciliation.
6. **P1:** Add queue health metrics, backlog/age alerts, retry/dead-letter dashboards and verified cron scheduling.
7. **P1:** Add tenant-isolation, role revocation, duplicate and failure-injection tests to CI.
8. **P2:** Add localized templates, channel redundancy, quiet-hours handling for non-urgent notices and delivery analytics.

## Evidence and safety statement

- Read-only Production and Staging table counts, schema, RLS/grants, notification trigger inventory and notification function definitions.
- Reviewed the three QA-branch Edge Function source files listed above.
- No function/Edge Function invoked; no Telegram, Resend, SMS, WhatsApp or push provider request sent; no customer or partner message sent.
- No database writes, DDL, grants, migrations, queue claims, secret reads, auth user lookups, provider configuration changes, cron changes, deployment or merge.
- Runtime delivery, retry, provider callback, notification scheduling and nine-workspace integration remain **NOT TESTED**. This audit is not a release approval.
