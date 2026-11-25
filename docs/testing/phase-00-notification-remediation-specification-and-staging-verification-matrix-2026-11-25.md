# KRIM Notification Remediation Specification and Staging Verification Matrix

**Date:** 2026-11-25  
**Branch:** `qa/phase-00-baseline-2026-11-25`  
**Status:** Design and verification specification only — NOT IMPLEMENTED  
**Decision:** Notification reliability remains a launch blocker. No production or staging configuration, schema, data, secrets, workers, schedules or provider settings were changed while preparing this document.

## 1. Objective and acceptance rule

KRIM must reliably notify the correct authorized people as important operational events occur across all nine workspaces:

1. Customer / Shipper
2. Partner / Carrier
3. Driver
4. Warehouse
5. Customs
6. Finance
7. Operations Control Tower
8. Enterprise
9. Platform Admin

**NO EVIDENCE = NO PASS.** Source code, table existence, configured workflow steps, successful HTTP acceptance by a provider, or a notification preview do not by themselves prove end-to-end delivery.

A notification journey passes only when evidence demonstrates:
- the triggering business event was committed;
- exactly the intended recipients were resolved from current authorized membership/assignment data;
- an outbox item and delivery attempt were created idempotently;
- the correct route and provider were selected;
- a provider accepted the message;
- provider delivery/bounce/complaint events were authenticated and correlated where supported;
- the recipient can see the service notification in the correct workspace/inbox;
- retries, failures, suppression and audit history behave correctly;
- no other organization/user can read the message or its sensitive content.

Essential transactional, safety, security and account notices must not be silently disabled by marketing preferences. Marketing and promotional communications must remain consent/preference controlled and legally compliant.

## 2. Evidence baseline carried forward

The following prior Phase 00 reports are the evidence basis for this specification:

- `phase-00-nine-ecosystem-event-and-notification-coverage-inventory-2026-11-25.md`
- `phase-00-legacy-notification-producers-and-secondary-event-path-reconciliation-2026-11-25.md`
- `phase-00-legacy-notification-recipient-authorization-and-idempotency-review-2026-11-25.md`
- `phase-00-workspace-notification-inbox-and-support-feed-audit-2026-11-25.md`
- `phase-00-customs-finance-operations-enterprise-admin-alert-source-audit-2026-11-25.md`
- `phase-00-notification-provider-and-retry-worker-execution-risk-audit-2026-11-25.md`
- `phase-00-notification-scheduling-callback-and-event-ingestion-audit-2026-11-25.md`

Verified baseline facts:
- Canonical shipment events and six shipment lifecycle workflow definitions exist, but their notification actions are prepare-only and external sending is blocked.
- Legacy in-app notification triggers exist for selected shipment, payment, payout and support events. They do not establish provider delivery.
- The customer notifications page is not a live inbox; partner notifications/support is a local illustrative preview.
- Driver has an authenticated legacy-notifications feed with user-scoped access in source, but no real-time subscription or delivery receipt.
- Warehouse alerts are operational task/quality queues, not a verified notification inbox.
- Customs, Finance, Operations, Enterprise and Platform Admin have operational/support surfaces, but a complete notification inbox/recipient-routing path was not established.
- Production has a five-minute founder-only Telegram retry worker. It is not the general notification dispatcher.
- Production Resend adapter source reports readiness only and has sending disabled.
- Staging has an active Resend worker with real-send capability, but its source is missing from the QA branch and it lacks recipient sink/allowlist and dry-run safeguards.
- No dedicated Resend delivery/bounce/complaint callback function was evidenced.
- Production notification outbox, delivery, retry-event, communication delivery-event, inbound-webhook and outbound-webhook delivery tables all had zero rows in the inspected snapshot.
- No Staging `cron.job` relation was visible in the inspected catalog.
- No worker, provider, queue, webhook, or schedule was invoked during the audits.

## 3. Canonical target architecture

Implement one auditable notification pipeline. Do not create a separate ad-hoc sending implementation inside each workspace.

### 3.1 Event-to-delivery flow

1. **Domain transaction:** A business action commits successfully (for example shipment confirmed, driver assigned, POD accepted, customs hold raised, invoice approved).
2. **Transactional event/outbox:** The same database transaction records a canonical event and durable notification intent/outbox item. If the business transaction rolls back, no notification is queued.
3. **Recipient resolution:** Resolve recipients at dispatch time from active organization membership, role, shipment/leg assignment, responsibility and notification category. Never trust a user ID supplied by the browser as the recipient authority.
4. **Policy and preferences:** Classify as essential service/security, operational, financial or marketing. Apply mandatory service-notice policy separately from consent-controlled marketing preferences and suppression rules.
5. **Route selection:** Select in-app, email, SMS, WhatsApp or push only where that provider/channel is configured, legally permitted, verified and available. Never imply a channel is active just because a route row exists.
6. **Outbox claim:** Worker claims due items atomically with row locking, a unique claim/fencing token, lease expiry and bounded batch size.
7. **Delivery attempt:** Persist a distinct attempt with provider, destination reference, idempotency key, request correlation and safe redacted diagnostics.
8. **Provider acceptance:** Record `accepted` / `sent` only. A successful API response is not proof that the recipient's mailbox/device received it.
9. **Provider callback:** Verify provider signature, timestamp/replay protections and event ID. Correlate using provider message ID and idempotency key. Persist callback event once.
10. **Final state:** Use `delivered`, `bounced`, `complained`, `failed`, `suppressed`, `dead_letter` only when supported by verified evidence and defined state transitions.
11. **Workspace inbox:** Independently expose the durable in-app service notice to the authorized user with unread state, pagination, mark-read, and audit history.
12. **Observability:** Record event, intent, recipient-resolution decision, attempts, provider callbacks, retry transitions and operator actions without leaking message secrets or unnecessary personal data.

### 3.2 Required delivery state model

Minimum state model (final enum names must be reconciled with the existing schema before migration):

`queued → claimed → accepted → delivered`

Failure branches:

- `claimed → retry_scheduled → queued` for retryable errors after lease-safe release.
- `claimed → failed` for terminal errors.
- `accepted → delivery_unknown` when provider outcome cannot be confirmed.
- `accepted → bounced` or `complained` only from verified provider events.
- `queued → suppressed` when a lawful suppression rule applies.
- `retry_scheduled → dead_letter` after bounded attempts.

Never label a provider-accepted message as delivered. Avoid a permanent `processing` state by implementing lease expiry and safe recovery.

### 3.3 Idempotency and concurrency

- Unique business event key, notification intent key and recipient/channel delivery key.
- Unique provider callback event ID within provider scope.
- Worker claim includes an unpredictable fencing token; completion must match the current token.
- Expired claims are reclaimed atomically only when lease expiry is confirmed.
- Retry attempts are append-only and bounded; duplicate event/worker execution cannot create duplicate logical deliveries.
- A timeout after provider acceptance must be treated as ambiguous; retry only with provider idempotency support or a reconciliation check.

### 3.4 Security and privacy

- Recipient resolution uses server-side organization memberships and current assignments.
- Every inbox read/update is scoped to the authenticated recipient and organization.
- Do not put full shipment, financial, identity or customs details in email/SMS previews; use minimal content and authenticated deep links.
- Do not log provider tokens, secrets, full sensitive payloads or unredacted destination data.
- Verify inbound provider signatures against the raw request body and enforce timestamp/replay windows.
- Validate tenant isolation, revoked membership, deactivated users and reassigned shipment/leg access.
- Use separate secrets and provider accounts/configuration for staging and production.
- Staging must fail closed if the environment/project identity does not match the expected staging project.

## 4. Nine-ecosystem minimum event and recipient matrix

This matrix defines minimum coverage to implement and test. It is not a claim that these flows currently work.

| Workspace | Minimum events to cover | Authorized recipient source | Minimum user-visible outcome |
|---|---|---|---|
| Customer / Shipper | inquiry received/qualified; quote ready/expired; shipment confirmed; partner/driver assigned; pickup/dispatched/in-transit; delay/exception; delivered/POD available; payment/invoice/refund status; support reply | Customer's active organization membership and shipment stakeholder role; billing contact for financial notices | Durable customer inbox item plus eligible service-channel notice; status/deep link; read state |
| Partner / Carrier | application received; verification requested/approved/rejected; capability approved/expired; quote invitation/award; shipment/leg assigned or changed; pickup/delivery milestone; POD rejected/accepted; settlement/invoice status; compliance expiry | Active partner organization membership and explicit assigned operational/finance/compliance roles | Partner inbox and assigned-work alert; only relevant partner organization sees it |
| Driver | invitation/activation; assignment created/changed/cancelled; pickup instructions; route/time change; safety/exception alert; delivery/POD accepted/rejected; support/security alert | Active driver identity linked to current organization and current assignment | Driver inbox and appropriate urgent channel; revoked/reassigned driver loses future sensitive access |
| Warehouse | inbound expected; dock/slot change; receipt discrepancy; QC hold/release; inventory quality status change; pick/dispatch task; custody handoff; incident/escalation | Active warehouse organization membership and facility/task assignment; role-scoped QC/operations recipients | Warehouse task/inbox alert with action link and acknowledgement history |
| Customs | document required/missing; filing submitted; query/hold; clearance/rejection; deadline approaching; release granted; regulatory evidence expiry | Active customs organization membership and shipment-leg/case assignment with compliance permission | Case-linked alert with evidence/deadline context; sensitive docs remain behind authorized session/MFA |
| Finance | payment initiated/paid/failed/refunded; invoice issued/overdue/credited; reconciliation mismatch; partner settlement due/completed/failed; approval required/decided | Authorized finance role in the correct organization; payer/payee stakeholder mapping | Finance inbox with amount/currency/reference and authenticated record link; no unauthorized payout or bank details |
| Operations Control Tower | shipment milestone missed; ETA/delay risk; exception opened/escalated; SLA breach risk; custody gap; partner capacity failure; recovery action due/resolved | Active operations organization membership and region/market/queue assignment | Prioritized exception alert with owner, severity, SLA and audit trail |
| Enterprise | shipment portfolio milestone/exception; approval requested/approved/rejected; spend threshold; SLA breach; compliance issue; monthly report ready | Enterprise tenant membership, portfolio scope and delegated approver roles | Tenant-scoped consolidated inbox/digest; approver actions auditable |
| Platform Admin | security/auth anomaly; privileged action; webhook/worker failure; queue backlog/dead-letter; provider outage; tenant abuse report; support escalation; compliance/platform health incident | Explicit platform-admin/on-call routing; MFA/AAL2 for privileged review | Protected admin alert queue with severity, acknowledgement/escalation and immutable audit trail |

### 4.1 Channel policy

- **In-app inbox:** canonical user-visible record for applicable transactional/operational notices; must be available in each relevant workspace.
- **Email:** use only after domain/sender configuration, recipient verification and provider callback/reconciliation are proven.
- **SMS / WhatsApp / push:** remain disabled until provider credentials, consent/legal basis, template rules, delivery receipts, retry and suppression are verified.
- **Telegram:** founder/internal operational alert channel only; never a substitute for customer, partner or driver delivery.
- **Marketing:** separate campaign system, explicit lawful consent/preference and unsubscribe/suppression handling.

## 5. Staging-only verification plan

No tests below may be run against Production. Staging test execution requires:
- confirmed staging origin and correct project ref;
- verified staging-only Supabase Auth redirect configuration;
- staging worker source parity and provenance;
- separate staging provider credentials;
- a controlled recipient sink/allowlist (test mailbox and test phone only);
- explicit dry-run mode that does not claim queue rows or call providers;
- synthetic users and organizations with no real personal/customer data;
- a documented cleanup/retention plan for synthetic records;
- user approval before any external provider send is enabled.

### 5.1 Test personas

Create synthetic, clearly marked identities for all nine workspace types, plus:
- two unrelated tenants to test cross-tenant isolation;
- one user with multiple legitimate roles;
- one revoked/deactivated member;
- one reassigned driver/partner user;
- one finance approver and one unauthorized finance user;
- one platform admin with MFA and one non-admin;
- one unconfirmed email recipient and one suppressed destination.

Never reuse actual customers, partners, drivers or real personal contact data.

### 5.2 Verification cases and required evidence

| Test group | Positive case | Negative/failure case | Required evidence |
|---|---|---|---|
| Event atomicity | committed domain action creates one event/intent | rollback creates none; duplicate event creates no duplicate intent | transaction IDs, event IDs, unique-key result |
| Recipient routing | only intended active role receives | wrong tenant, revoked member, unrelated user, stale assignment receive nothing | recipient-resolution trace with redacted IDs and denial reason |
| Inbox/RLS | user reads and marks own item read | another tenant/user cannot list, fetch or update it | JWT-scoped query/API result and RLS denial |
| Worker lease | one worker claims due item | concurrent worker cannot double claim | claim token, lease timestamps, attempt IDs |
| Stale recovery | expired lease safely requeued | stale worker completion rejected by fencing token | before/after state and token mismatch result |
| Provider safety | allowlisted sink receives one controlled test | non-allowlisted destination, production project, missing secret or dry-run must fail closed | request audit, destination masked, provider response |
| Provider callbacks | valid signed callback updates matching attempt | invalid signature, stale timestamp, replay, duplicate event, unknown message ID rejected/idempotently handled | signature decision, callback ID, resulting state |
| Retry policy | transient timeout schedules bounded retry | permanent 4xx, suppression, max attempts go terminal | attempt history, backoff timestamps, dead-letter record |
| Ambiguous send | provider idempotency/reconciliation prevents duplicate | timeout after provider acceptance does not blindly resend | provider idempotency key and reconciliation trace |
| Delivery semantics | verified delivery callback marks delivered | API 2xx alone never marks delivered | provider acceptance record vs callback record |
| Preferences | marketing follows consent/unsubscribe | essential service/security notice is not silently suppressed by marketing opt-out | policy decision and audit |
| Security | authorized support/admin can view assigned alert | non-admin cannot read or resolve privileged alert | permission decision, AAL2/MFA state |
| Observability | full trace links event to delivery | no secrets or sensitive content in logs | redacted correlated trace |
| Resilience | worker recovers after controlled crash | no stuck processing or duplicate delivery | injected-failure record and final state |

### 5.3 Required failure-injection scenarios

Run only in isolated Staging after approval:
1. Duplicate business event.
2. Two workers claim simultaneously.
3. Worker crashes after claim but before provider call.
4. Worker crashes after provider acceptance but before recording response.
5. Provider 429, 4xx, 5xx, connection timeout and slow response.
6. Duplicate and out-of-order provider callbacks.
7. Invalid callback signature and replayed timestamp.
8. Unknown provider message ID.
9. Recipient email unconfirmed, destination suppressed or outside allowlist.
10. Membership revoked or assignment changed between event and dispatch.
11. Lease expiry while original worker is still running.
12. Retry exhaustion and dead-letter recovery.
13. Staging worker pointed at a production project (must refuse before any send).
14. Dry-run mode (must not claim queue items, write delivery attempts or call provider).

## 6. Implementation sequence and gates

### Gate N0 — Source and environment parity
- Retrieve exact deployed Staging Resend worker source and establish version/hash provenance.
- Confirm real Staging origin, Supabase project ref, Auth redirect and environment mapping.
- Inventory current table definitions, constraints, indexes, RLS policies, RPCs and cron/external schedules.
- Reconcile migration history without replaying or resetting either environment.

**Pass evidence:** source hash, deployed function metadata, environment identity, read-only schema diff and approved staging origin.

### Gate N1 — Canonical schema and state machine
- Design changes only after current schema/function definitions are reconciled.
- Add unique idempotency keys, delivery-attempt records, lease/fencing fields, callback-event uniqueness and appropriate constraints/indexes.
- Define exact state transition rules and service/marketing classification.
- Review RLS and service-role-only claim/finish/callback operations.

**Pass evidence:** reviewed migration, schema diff, SQL unit tests, RLS policy tests and rollback plan. No production migration in this QA phase.

### Gate N2 — Safe worker and scheduler
- Implement dry-run with no claim/no write/no provider call.
- Add staging project assertion, recipient allowlist and sink-only delivery.
- Add lease recovery, fencing and bounded retries.
- Configure a Staging-only scheduler with a documented pause/kill switch.

**Pass evidence:** dry-run negative proof, worker unit tests, concurrency tests, scheduler run logs in Staging only.

### Gate N3 — Provider callbacks and delivery truth
- Implement signature-verified callback ingestion.
- Add event replay protection and idempotent state updates.
- Distinguish provider acceptance from actual delivery.
- Handle bounce, complaint, suppression and permanent failures.

**Pass evidence:** valid/invalid signature suite, duplicate/replay suite, callback-to-attempt correlation and provider test-sink receipt.

### Gate N4 — Nine-workspace integration
- Implement canonical event producers and recipient resolution for all nine workspaces.
- Add inbox views, unread counts, pagination, mark-read and authorized deep links.
- Confirm support and exception feeds are not misrepresented as notification inboxes.

**Pass evidence:** complete persona journey traces, inbox/RLS tests, cross-tenant negatives and event-to-delivery correlation for every required event family.

### Gate N5 — Reliability and launch readiness
- Run load/concurrency, retry exhaustion, provider outage, stale lease, callback replay and security tests.
- Review queue age, failure rate, dead-letter count, delivery latency and alerting thresholds.
- Document operational ownership and incident response.

**Pass evidence:** reproducible test report, no unresolved critical/high notification findings, approved runbook and explicit release sign-off.

## 7. Launch decision today

| Capability | Current status |
|---|---|
| Shipment workflow notification preparation | SOURCE-VERIFIED; runtime end-to-end not proven |
| Legacy in-app notifications for selected event families | SOURCE-VERIFIED; coverage incomplete; runtime not proven |
| Customer live inbox | NOT READY |
| Partner live inbox | NOT READY |
| Driver legacy inbox | SOURCE-VERIFIED; runtime/RLS testing pending |
| Warehouse notification inbox | NOT READY; current surface is operational attention queue |
| Customs notification inbox | NOT EVIDENCED |
| Finance notification inbox | NOT EVIDENCED |
| Operations notification inbox | NOT EVIDENCED |
| Enterprise notification inbox | NOT EVIDENCED |
| Platform Admin notification/incident alert stream | NOT EVIDENCED |
| General customer/partner outbox dispatcher | NOT EVIDENCED |
| Founder Telegram retry schedule | ACTIVE; limited to founder inquiry/follow-up |
| Resend email delivery | NOT PROVEN; Production adapter sending disabled; Staging worker requires safety/provenance work |
| Provider delivery/bounce/complaint callbacks | NOT EVIDENCED |
| Staging synthetic-user end-to-end tests | NOT RUN |
| Nine-ecosystem reliable notifications | **NO-GO** |

**Do not invite real users on the assumption that notifications are reliable until Gates N0–N5 have passed with retained evidence.** This does not block continued source audit or isolated local test-harness development; it blocks claiming notification readiness or enabling unguarded external sends.

## 8. Explicit non-actions

During this specification task:
- no Supabase schema, data, RLS, function, secret or Auth configuration changed;
- no Production or Staging worker was invoked;
- no cron schedule was changed;
- no queue item was claimed;
- no email, Telegram, SMS, WhatsApp or push message was sent;
- no deployment or merge to `main` occurred.

**Final rule: NO EVIDENCE = NO PASS.**
