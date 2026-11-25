# Gate C3.30 — Shared events, notifications, provider webhooks and delivery reliability
Date: 2026-11-25
Baseline: `72d75a18f985ceb09e468839435ee95700e11e46`
QA branch: `qa/phase-00-baseline-2026-11-25`
Status: **FAIL / BLOCKED — NO-GO for general customer/partner notification delivery, emergency alert guarantees, or provider-webhook reliability certification.**

## 1. Scope and method
Read-only review of the immutable source baseline, notification provider adapter, retry worker, Razorpay webhook handler, notification/event/communication audit records dated 2026-11-16 and 2026-11-24, and the prior C3.10/C3.25/C3.29 gate findings. This gate reconciles source-level design with prior read-only Production observations. It does not claim a fresh runtime test or a refreshed Production count.

No Production or Staging SQL/RPC/function invocation, queue claim, provider call, message send, webhook replay, secret retrieval, external communication, configuration change, or deployment was performed. No customer or partner was contacted.

## 2. Architecture and evidence inventory
### 2.1 Founder Telegram path
The reviewed retry worker authenticates either a long cron secret (SHA-256 digest comparison) or a valid platform-admin session, then uses a service-role client. It handles only founder inquiry and follow-up Telegram queues, claims up to ten rows per queue, uses a 12-second provider timeout, and delegates queue state transitions to internal claim/finish RPCs. A prior Production audit reported an active five-minute cron schedule and an active worker deployment. This is a narrow founder alert path, not a general-purpose notification service.

The provider adapter requires a user session and platform-admin permission. Its Resend route only checks whether `RESEND_API_KEY` exists and explicitly returns `sending_enabled: false`; it does not send email. Its Telegram test route can send a founder-authorized test message. No SMS/WhatsApp send path is implemented in this adapter. The source snapshot must not be mistaken for an authorized test or proof of current provider availability.

### 2.2 Shared event and delivery model
Prior audits identify event, outbox, delivery, retry, preferences, consent, suppression, inbound/outbound webhook and operational queue/dead-letter structures. RLS and service-role-only internal helper ACLs were positive controls in the reviewed snapshots. However, a durable generic event-to-notification consumer covering all nine workspaces is not established. C3.29 correctly distinguishes business event creation from notification delivery. A row in a domain event or in-app attention table is not proof of queueing, provider acceptance, recipient delivery, or acknowledgement.

Prior 2026-11-16 Production snapshot: notification outbox 0; notification deliveries 0; retry events 0; preferences 0; operational notification runs/events 0/0; outbound webhook endpoints/deliveries 0/0; inbound webhook events 0; communication delivery events 0; suppressions 0; customer consent records 0; user consent events 0; legacy notifications 5; payment webhook events 10. These are historical snapshot counts, not refreshed in this gate.

### 2.3 Provider webhooks
The Razorpay webhook source verifies the HMAC signature against the raw request body, requires a provider event ID, limits supported event types, stores event records, and attempts duplicate handling. Refund events are reconciled against approved KRIM refund requests and original payment identifiers. C3.25 separately identified a critical captured/order-paid path that can mark an order paid and invoke company-owned reconciliation despite freight collection being disabled. That risk remains open; webhook signature validation does not correct a business-policy kill-switch bypass.

No general Resend/WhatsApp/SMS delivery callback ingestion, bounce/complaint pipeline, or recipient delivery receipt evidence was demonstrated. Provider webhook receipt must not be conflated with recipient delivery.

## 3. Findings
### P0 — Telegram provider acceptance is reported as recipient delivery
The founder Telegram finish RPCs set both `sent_at` and `delivered_at` when Telegram's API returns success. A successful Bot API response and message ID establish provider acceptance/message creation, not device delivery or human reading. This corrupts delivery metrics and user-facing status semantics.
**Required:** record provider acceptance as `sent`/ `accepted_by_provider`; leave recipient delivery unknown unless a trustworthy provider receipt exists. Telegram sendMessage does not provide a general read/delivery receipt.

### P0 — claimed notifications can be stranded indefinitely
The founder queue claim RPCs move rows into `processing`, while later claims select only `pending`/`failed`. The reviewed implementation has no effective expired-lease reclaim/fencing path. A worker crash, timeout, or failed finish call can leave work permanently outside retry selection. Prior general outbox helper review also found expired-processing recovery absent and incomplete worker ownership fencing.
**Required:** bounded leases, unique per-claim fencing tokens, heartbeat/expiry, compare-and-set completion, stale-claim recovery, and a late-worker test proving an old claimant cannot overwrite a newer attempt.

### P0 — freight collection kill-switch is not enforced consistently in webhook capture path
C3.25 found the Razorpay captured/order-paid webhook path can mark orders paid and trigger company-owned reconciliation even while freight collection/manual verification is disabled. This is a payment policy and event-consumer integrity defect, not merely a notification issue. Keep it as a cross-gate P0 and do not enable freight collection or automatic partner split/payout flows.

### P1 — no generic nine-workspace dispatch contract or proven transactional outbox
No complete, versioned producer-to-consumer matrix proves that customer, partner, driver, warehouse, customs, finance, operations, enterprise and admin business mutations atomically enqueue the correct tenant-scoped notification. Event insertion and notification enqueue atomicity are not demonstrated across workflows. Partial failure could leave committed business state without a corresponding alert.
**Required:** define canonical event types, producer ownership, transactional outbox insertion in the same transaction as each business mutation, consumer/channel mapping, tenant and recipient resolution, schema versioning and replay policy.

### P1 — no production evidence for customer/partner channel delivery
The prior snapshot had zero general outbox/delivery/preference/consent/suppression/callback records. Resend remains readiness-only; SMS and WhatsApp sends are not implemented in the reviewed adapter. Founder Telegram traffic cannot be used as evidence for customer or partner shipment communications.
**Required:** retain disabled status until isolated staging tests and an explicitly authorized founder-only test demonstrate provider acceptance, callback correlation and recipient-side receipt where available.

### P1 — no trustworthy delivery callback/correlation pipeline
No verified provider callback path was evidenced for Resend, SMS or WhatsApp. Delivery event tables and inbound webhook rows were zero in the historical snapshot. Generic `delivered` labels are not supportable without authenticated, deduplicated, correctly correlated provider evidence.
**Required:** verify provider signatures, timestamp/freshness and endpoint environment; persist raw-event hash/minimized payload, provider event ID, message correlation, event ordering and deduplication; model bounce, complaint, rejection, suppression and unknown states.

### P1 — no consent, preference, suppression and contact-verification enforcement
Historical preferences, consent, consent events and suppression rows were zero. The founder operational alert path is not a customer marketing consent system. Transactional versus marketing purpose, channel-specific preference, legal basis, verified destination and unsubscribe/suppression enforcement are not proven at enqueue and send time.
**Required:** implement purpose-specific lawful-basis/consent handling, verified contact points, channel preferences, suppression and unsubscribe checks, retention and audit before enabling customer/partner channels. Emergency and transactional exceptions require documented legal review rather than bypassing controls.

### P1 — retry execution budget can exceed scheduler timeout
A worker may claim up to twenty messages across two sequential queues, each with a 12-second network timeout, while the prior cron request timeout was 30 seconds. This can exceed the scheduler budget, causing overlap and abandoned processing rows.
**Required:** bound total elapsed execution and batch size, reserve time for finalization, control concurrency, and instrument run duration/claims/success/failure/timeouts.

### P1 — ambiguous provider timeout can cause duplicate messages
Database idempotency prevents duplicate enqueue for a logical event but cannot guarantee Telegram provider idempotency. Telegram may accept a message while the response is lost; retry can send a duplicate. The worker currently has no complete unknown-outcome reconciliation protocol.
**Required:** persist attempt identity and provider correlation, distinguish failed from unknown, reconcile where possible, and document duplicate-risk policy for providers without idempotency keys.

### P1 — cron, queue lag, dead-letter and recovery observability are not certified
A configured five-minute cron schedule is not proof each invocation succeeds. No fresh run-history, queue-lag, stuck-claim, dead-letter, provider-error, alert acknowledgement or recovery evidence was collected. The prior operational audit found external notifications disabled and no verified on-call acknowledgement/fallback.
**Required:** monitor last successful run, schedule drift, duration, queue age, expired leases, attempt counts, dead-letter totals, provider response classes, callback lag and alert acknowledgement; provide audited operator replay with approvals and bounded replay scope.

### P1 — webhook freshness/order and processing concurrency need staging proof
The Razorpay handler checks signature and event ID and stores unprocessed events, but source review alone does not establish timestamp freshness policy, out-of-order event monotonicity, lease-based recovery, atomic event/business-state updates, or safe concurrent processing for every event type. The duplicate insert conflict path is retryable, but full race/recovery behavior remains untested.
**Required:** stage duplicate/concurrent delivery, delayed and out-of-order events, replay, invalid signature, stale timestamp, partial failure and late retry; make state transitions monotonic and event processing fenced/idempotent.

### P1 — emergency routing and escalation are not operationally evidenced
In-app exception records and founder Telegram alerts do not prove an accountable emergency communication service. Verified emergency contacts, on-call rota, multi-channel fallback, acknowledgement timers, escalation ladder, delivery evidence and service recovery are absent or unverified. C3.26 already blocks incident-response and alert-delivery certification.
**Required:** approved contact registry, ownership/on-call coverage, escalation policy, acknowledgement and failover drills, auditable incident timeline and independently verified delivery evidence.

### P2 — provider/source/deployment parity and lifecycle governance
The 2026-11-24 source-parity snapshot records live worker versions and notes production-only source drift risk. Keep exact source, build hash, deployment record, secret-name inventory, rotation ownership, environment endpoint allowlists and rollback evidence in version control. Never expose secret values. Provider labels in UI must distinguish live, disabled, readiness-only and roadmap providers.

## 4. Required status vocabulary
Use distinct states: `queued`, `processing`, `accepted_by_provider`/`sent`, `delivered` (only with genuine correlated receipt), `bounced`, `rejected`, `retry_scheduled`, `dead_lettered`, and `unknown`. Keep `read` separate and only where the provider actually supplies a read receipt. A successful HTTP 2xx, Telegram API `ok`, cron schedule, database event, or in-app notification must not be represented as recipient delivery.

## 5. Gate verdict and release boundary
**C3.30 FAIL / BLOCKED.** The narrow founder Telegram retry path has useful authentication, bounded attempts and row locking, and Razorpay raw-body HMAC verification is a positive control. Those controls do not establish general notification delivery, reliable retries, complete webhook recovery, consent compliance, or emergency response.

**NO-GO:** general customer/partner outbound email, SMS, WhatsApp or push; certified emergency alerts; generic notification delivery guarantees; freight collection or automated split/payout; and production replay/worker changes.

Permitted next work is documentation/source-level remediation planning and isolated staging design. Any Staging execution, provider test, founder test message, schema/RPC change, secret/configuration change, Production action or deployment requires explicit approval and environment isolation proof.

## 6. Evidence references
- `docs/audits/KRIM-NOTIFICATION-ALERT-ROUTING-DELIVERY-AND-RETRY-ASSURANCE-AUDIT-2026-11-16.md`
- `docs/audits/KRIM-NOTIFICATION-DELIVERY-AND-RETRY-RELIABILITY-P1-AUDIT-2026-11-16.md`
- `docs/audits/KRIM-NOTIFICATION-EDGE-SOURCE-PARITY-2026-11-24.md`
- `docs/audits/KRIM-NOTIFICATION-RUNTIME-READINESS-2026-11-24.md`
- `docs/audits/KRIM-SHIPMENT-NOTIFICATION-EVENT-BRIDGE-GAP-2026-11-24.md`
- `docs/operations/KRIM-EVENT-NOTIFICATION-DELIVERY-AND-RECOVERY-READINESS-AUDIT-2026-11-16.md`
- C3.10, C3.25, C3.26 and C3.29 reports and this immutable-baseline source review.

## 7. Evidence boundary
This is a source review and reconciliation of prior dated read-only Production evidence. No current runtime/provider/delivery/cron behavior was tested or refreshed. No external message was sent. No secrets were retrieved. No Production/Staging state was changed.
