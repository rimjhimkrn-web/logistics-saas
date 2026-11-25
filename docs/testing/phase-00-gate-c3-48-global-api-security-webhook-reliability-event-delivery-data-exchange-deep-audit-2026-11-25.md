# C3.48 — Global API security, webhook reliability, event delivery and external data-exchange deep audit
**Date:** 25 November 2026  
**Baseline:** `72d75a18f985ceb09e468839435ee95700e11e46` (immutable source snapshot)  
**Method:** Read-only source and dated-evidence review of Razorpay webhook processing, founder notification adapter/retry worker, shipment event bridge, notification lease/retry remediation specification, lifecycle/event audit, API contract and webhook management/partner pages. No live requests, SQL/RPC execution, webhook replay, provider call, queue mutation, credentials or deployment were used.

## Executive verdict
**FAIL / BLOCKED — NO-GO for general-purpose external webhooks, customer/partner event delivery, reliable financial webhook processing, or partner API onboarding.** Some useful controls exist: Razorpay raw-body HMAC verification, event allowlisting, event IDs, duplicate handling, exact amount/currency/captured-state checks, and transactional finance reconciliation RPC; the retry worker has cron-secret/admin authorization and bounded per-message timeout. But these controls do not form a complete concurrency-safe, bounded, recoverable event-processing system. New canonical shipment status events are emitted, while customer/partner notification workflow actions remain prepare-only. The webhook-management page explicitly says endpoint registration, signing-secret issuance, delivery, retries and test pings are not enabled.

## Evidence reviewed
1. `supabase/functions/razorpay-webhook/index.ts` — selected payment webhook source.
2. `supabase/functions/krim-notification-provider-adapter/index.ts` and `krim-notification-retry-worker/index.ts` — internal notification test and retry worker.
3. `docs/audits/KRIM-SHIPMENT-NOTIFICATION-EVENT-BRIDGE-GAP-2026-11-24.md` — new shipment event-to-notification bridge gap.
4. `docs/remediation-pending/2026-11-16-notification-lease-fencing-and-delivery-state.md` — inspected lease, fencing and delivery-state defects/specification.
5. `docs/audits/KRIM-SHIPMENT-LIFECYCLE-STATE-MACHINE-AND-EVENT-CONSISTENCY-P0-P1-AUDIT-2026-11-16.md` and `docs/audits/KRIM-P0-FINANCIAL-SECURITY-REMEDIATION-PLAN-RAZORPAY-WEBHOOK-AND-REVENUE-ALLOCATION-2026-11-16.md`.
6. `docs/FRONTEND-INTEGRATION-CONTRACT.md`, `public/developer/webhooks-management.html`, and `public/partner/api-webhooks.html`.

## 1. Public webhook/API product boundary
**PARTIAL PASS — UI preview accurately labels itself planned.** The developer webhook manager says endpoint setup, signing-secret issuance, delivery, retries and test pings are not enabled; it shows no active endpoint and no verified delivery metrics. This is appropriately transparent.

**P0/P1 — no partner-facing webhook service is established.** No active partner endpoint registration, tenant-bound subscription lifecycle, secret issuance/rotation/revocation, outbound delivery worker, signed payload versioning, delivery log, replay console, retry schedule, or dead-letter recovery was evidenced in the inspected baseline. The partner API page is an informational integration surface; its presence is not a live API contract or connected partner endpoint. Do not onboard carrier/enterprise API consumers against these preview pages.

## 2. Razorpay webhook — positive controls and material gaps
### Positive source controls (PARTIAL PASS)
- POST-only handling; raw request body is read and HMAC-SHA256 checked before JSON parsing.
- Event ID is required; supported event types are explicitly allowlisted.
- Existing processed events are acknowledged as duplicates; a unique-insert conflict returns retryable 409.
- Captured/order-paid handling correlates the provider order to a KRIM payment order and checks payment ID presence, exact integer amount, currency and captured status.
- A previously paid order is reconciled only with the same provider payment ID; a conflicting ID returns 409.
- The finance reconciliation RPC is invoked before successful acknowledgement; payment.authorized does not itself mark the order paid.
- Refund outcomes are restricted to an existing approved refund request and checked against the original provider payment, amount and currency.

These are source observations, not live Edge Function parity or executed webhook tests.

### P0 — captured-payment freight kill-switch bypass remains
The handler's captured/order-paid path transitions `payment_orders.status` to `paid` and calls financial reconciliation without checking the same `KRIM_FREIGHT_COLLECTION_ENABLED` and approval-version control enforced by order creation/verification. This is the previously recorded C3.25/C3.47 P0. A valid signed provider event can therefore enter the paid/finance path while new freight collection is supposed to remain disabled. This must be fixed atomically and independently retested before any collection or payment activation.

### P0 — event claim is not concurrency-safe
The handler first selects an event row and, when absent, inserts `processed=false`. The unique-insert race returns 409, which is a useful safeguard. However, when an event row already exists as unprocessed, another concurrent delivery is allowed to proceed without acquiring a processing lease, claim token or row lock. Multiple executions can process the same unprocessed event concurrently. The final `processed=true` update is not conditional on a unique claim generation. Downstream conditional order mutation and finance RPC idempotency reduce some duplicate damage but do not establish one authoritative event processor or prove all side effects are race-safe.

### P0 — payment mutation and finance posting are separate operations
The source conditionally updates the payment order to `paid` before invoking the finance reconciliation RPC. If the RPC fails, the function returns 500 and leaves the event retryable, but the payment row can remain paid while the financial transaction is absent. Retry may repair this through the RPC, but the intermediate inconsistent state is real and must be monitored/reconciled. The earlier financial remediation plan correctly requires one atomic transaction for event claim, order state, and financial posting, plus a durable deferred/quarantine state while collection is disabled.

### P1 — input and event-governance hardening incomplete
- No explicit request-body byte cap or content-length/stream-size guard was found before `req.text()` and JSON parsing.
- Signature hex is converted by a permissive parser; explicit exact 64-hex-character validation and strict rejection of malformed encoding should precede comparison.
- Unsupported signed event types are acknowledged as ignored without durable audit/quarantine. This may be intentional for provider noise, but it prevents later reconciliation and should be governed by an explicit ignore registry and metrics.
- The source does not visibly bind a stored event ID to a payload digest/type on replay. A reused provider event ID with a different payload should be a hard conflict and security alert, not silently treated as an existing row.
- No evidence in this gate of bounded payload retention/redaction, event age/replay window, out-of-order event policy, operator quarantine, per-event processing lease, or alert-on-stuck-unprocessed event.
- CORS is broad, though webhook is server-to-server and browser CORS is not authentication; endpoint exposure and deployed gateway JWT settings still require independent verification.

## 3. Canonical shipment event → notification bridge
**P0 — customer/partner notifications are not delivered from the new shipment event pipeline.** The dated 24 November audit records:
- canonical `krim_shipments` status trigger inserts a pending `shipment.status_changed` domain event;
- six workflow triggers exist for confirmed, assigned, dispatched, in-transit, delivered and exception states;
- notification actions are explicitly prepare-only, recording `external_send = blocked_until_provider_and_recipient_ready`;
- no generic customer/partner notification outbox consumer was found;
- the point-in-time queue snapshot had zero pending/failed domain events, queued workflow dispatches/actions, retry-wait/dead-letter workflow actions and generic notification outbox rows, while five legacy notifications existed.

Those historical counts are not current state and legacy notification rows do not prove new canonical event delivery. The bridge still needs authoritative recipient resolution for customer organization members, partner members and assigned drivers; role/tenant/consent checks; durable idempotent outbox creation; provider routing; a dedicated consumer; authenticated feeds; and provider receipt reconciliation.

## 4. Notification worker lease, retry and delivery-state integrity
The dated lease-remediation specification records the following live-inspected defects as of 16 November; they were not revalidated against current live database definitions in this gate:
- expired `processing` leases were not reclaimed;
- worker ID was not a unique fencing token/generation;
- repeated validation could create duplicate delivery attempts unless separate constraints prevented it;
- provider acceptance was also written as `delivered_at`;
- competing completion/result functions had different authorization and timestamp semantics;
- retry scheduling and completion could diverge in claim release and retry-event bookkeeping;
- ambiguous provider timeout could lead to duplicate sends without provider idempotency/reconciliation.

The inspected founder Telegram retry worker uses claim and finish RPCs, processes at most ten rows per queue per invocation, and applies a 12-second per-message timeout. It does not itself demonstrate that the underlying RPCs have been remediated with expired-lease reclaim, claim fencing, unique attempt IDs, a single state-transition authority or provider idempotency. It is a founder-only internal path, not the customer/partner event bus.

## 5. API and data-exchange contract
The frontend integration contract states the correct requirements: server-side authentication/authorization, schema/ownership/state validation, idempotency, backend-authoritative lifecycle transitions, safe public tracking projection, correlation IDs, secret-safe logs and negative/failure testing. The document itself explicitly warns that a contract does not prove runtime integration.

**P1:** No exhaustive API caller-to-endpoint-to-function/RPC mapping or deployed contract conformance evidence was completed here. No proof of per-tenant outbound webhook filtering, event schema versioning, payload minimization, replay protection, consumer acknowledgement, backpressure, per-partner rate limits, endpoint SSRF protections, DNS/IP revalidation, TLS policy, secret rotation, or signed delivery retries. These controls are required before accepting arbitrary partner callback URLs or exposing tenant data through external event subscriptions.

## 6. Prioritized remediation and acceptance criteria
### P0 — must be resolved before payments or customer/partner event delivery
1. Enforce the freight collection kill switch in the captured-payment webhook and finance RPC boundary; quarantine/defer valid captures without paid-state or ledger mutation while collection approval is absent.
2. Implement atomic event claim + payment order transition + finance posting, or an equally strong transactional state machine with durable quarantine and deterministic recovery.
3. Add atomic event claims with lease expiry/reclaim, per-claim fencing token/generation, conditional completion and full payload-digest conflict detection.
4. Implement canonical shipment event → tenant-authorized recipient resolution → durable outbox → provider delivery → verified receipt/status bridge. Keep provider acceptance distinct from recipient delivery.
5. Fix notification lease reclaim, fencing, unique attempt identity, one completion authority, bounded retry/backoff, dead-letter and ambiguous-timeout reconciliation.
6. Preserve immutable event evidence and alert on stuck/unprocessed/deferred/conflicting financial and operational events.

### P1 — required before external API/webhook partner onboarding
- Define versioned event schemas, endpoint ownership/tenant binding, subscription scopes, payload allowlists, signing secret issuance/rotation/revocation and delivery attempt history.
- Protect callback registration against SSRF (private/link-local/loopback/metadata IP ranges, redirects, DNS rebinding and IP changes); enforce HTTPS and safe egress policy.
- Add outbound request size/time limits, bounded retries with jitter, per-tenant quotas, circuit breakers, delivery ordering semantics and replay windows.
- Verify signatures over exact raw bytes, strict encoding, timestamp/nonce or provider event-ID dedupe, replay and out-of-order cases.
- Add consumer contract tests for duplicate, delayed, malformed, oversized, unauthorized, cross-tenant, timeout, provider outage, 429/quota, 5xx, stale lease, worker crash and dead-letter replay.
- Redact payload PII/secrets, define retention and deletion, correlation IDs and audited operator replay approvals.

### Required pass evidence
- Current deployed function/config parity and exact grants/ACL verified.
- Isolated Staging tests demonstrate one-at-a-time claim under concurrent duplicate deliveries, expired lease reclaim, stale-worker rejection and idempotent recovery.
- Payment tests prove disabled kill switch blocks paid-state/finance posting and safely quarantines captured events; enabled-mode tests require separate legal approval and explicit authorization.
- Full canonical shipment event-to-customer/partner notification journey with tenant isolation, consent, provider callback and authenticated delivery feed.
- Partner webhook registration, signed delivery, endpoint validation, retries, replay, revocation and SSRF negative tests.
- Independent finance/security retest and audit evidence. None of these runtime acceptance tests was performed in this gate.

## Final decision
**C3.48 FAIL / BLOCKED.** NO-GO for customer/partner event-delivery claims, partner webhook/API onboarding, or KRIM-collected payment activation. Source-level Razorpay safeguards and a founder-only Telegram retry worker are PARTIAL PASS only. The canonical shipment notification bridge is not operationally complete; the public webhook manager is an explicitly disabled preview. The payment kill-switch bypass remains a P0.

No Production/Staging requests, SQL/RPC execution, webhook replay, queue mutation, provider calls, messages, payments, secrets, deployments, merges or external communications were performed.
