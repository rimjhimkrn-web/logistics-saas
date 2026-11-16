# KRIM Customer Shipment Visibility, Tracking, Support, Exceptions and Notification Reliability Audit
**Date:** 16 November 2026  
**Scope:** Read-only production counts, RLS/grant/policy review, support RPC inspection and deployed public shipment-tracking Edge Function review. No public tracking request was sent; no ticket, notification, shipment event or exception was created; no customer or partner was contacted.

## Executive decision
**NO-GO for claiming a reliable customer-facing shipment tracking and support service.** The database has 41 shipment status-history rows and 5 in-app notification rows, but zero customer service requests, support tickets, support messages/events, notification preferences, notification outbox items, delivery records, retry events, exception records, timers, escalations or exception signals. Shipment event receipt and per-shipment event-sequence tables are also empty. The tracking endpoint is implemented and has meaningful privacy controls, but no real active shipment journey or delivery reliability is evidenced.

## 1. Production baseline
| Component | Rows |
|---|---:|
| Shipment status history | 41 |
| Allowed status transition definitions | 15 |
| Shipment event receipts | 0 |
| Shipment event sequence records | 0 |
| Customer service requests | 0 |
| Support tickets | 0 |
| Support ticket messages | 0 |
| Support ticket events | 0 |
| In-app notifications | 5 |
| Notification preferences | 0 |
| Notification outbox | 0 |
| Notification deliveries | 0 |
| Notification retry events | 0 |
| Operational exceptions | 0 |
| Exception timers | 0 |
| Exception escalations | 0 |
| Exception signal events | 0 |

The 41 historical status records and five in-app notifications do not prove current live shipment tracking, successful external notification delivery or a working customer-support operation. There are no durable event receipt/sequence rows to demonstrate an active event-ingestion path.

## 2. Public shipment-tracking endpoint
The deployed `public-shipment-tracking` Edge Function:
- Accepts only POST and validates a `KRIM-` tracking reference as exactly 32 hexadecimal characters after normalization.
- Looks up the shipment by `krim_shipments.public_tracking_token`; it does not expose a broad shipment-number search.
- Returns shipment number/status, origin/destination/current location labels, creation/ETA/delivery timestamps and up to ten non-GPS tracking events.
- Excludes raw GPS events from the public event list.
- Only considers GPS sessions for non-terminal shipments, and rechecks partner assignment, exact leg/organization, driver assignment/user, active driver membership, active organization, verified driver/licence, native platform and integrity of the archived consent notice hash.
- Returns GPS coordinates only when an authorized active session has a recent position; classifies GPS freshness and suppresses terminal-shipment coordinates.
- Sets `Cache-Control: no-store` and uses generic lookup/service errors.

These controls reduce exposure, but the endpoint is unauthenticated and uses a service-role key internally. The source reviewed does not show request throttling, abuse monitoring or a token-rotation/revocation path. A 32-hex-character format is not itself proof of 128 bits of cryptographically random entropy. Verify token generation, uniqueness, non-reuse, secure storage, logging redaction, rotation and revocation before treating the reference as a bearer credential. Add per-IP and per-token rate limits, abuse alerts and response minimization. Wildcard CORS is not an authorization control.

The endpoint can display an ETA stored on the shipment; this audit does not establish that ETA values are confidence-scored or recalculated from reliable live carrier data. UI must label ETA as an estimate and suppress or qualify stale/unsupported values.

## 3. Customer and partner shipment visibility
- Shipment status history has an authenticated SELECT policy for the owning customer organization or a user with an active partner assignment.
- Tracking events have scoped SELECT policies for the owning customer organization, active partner assignment, authorized operations users and the exact assigned driver.
- Event receipts and sequence tables are empty; idempotent event ingestion, replay handling and ordered event processing have no production evidence.
- GPS sharing is intentionally disabled by source-level approval gates in the driver app and edge functions; public tracking should not imply live GPS is available.
- Status and milestone history must be sourced from authorized state transitions. Manual milestone coordinates must never be represented as device-verified GPS.
- Do not display partner internal notes, private evidence references, customer PII, internal exception comments or raw GPS history to public tracking users.

## 4. Customer support controls and P1 insertion risk
Positive controls:
- Customer ticket read access is owner-scoped by `user_id=auth.uid()`.
- Customer replies lock the ticket and require ownership, enforce body length, reject replies on closed tickets, and write a support event and audit event.
- Admin ticket listing, thread access, replies and transitions require authenticated AAL2 and platform-admin permission.
- Customer-visible admin replies cannot be sent to resolved/closed tickets without reopening.
- Admin resolution/closure requires a reason and writes event/audit history.
- Ticket messages and events are owner-read; internal messages are excluded from the customer message policy.
- Ticket creation checks that the caller owns the user_id, that any linked organization is accessible, and that any linked shipment belongs to that organization.

**P1 — Customer-controlled support-ticket fields:** `support_tickets` grants authenticated INSERT. Its INSERT policy checks ownership and organization/shipment linkage, but does not constrain all other inserted columns. Unless a column-level grant or trigger not visible in the reviewed policy/grant evidence prevents it, a customer may attempt to set operational fields such as status, priority, assigned_to, assigned_organization_id, escalation level/reason and response/resolution/closure timestamps during ticket creation. The SLA trigger sets due dates, but the policy itself does not restrict these fields. Replace direct broad INSERT with a narrow SECURITY DEFINER ticket-creation RPC or enforce a strict server-side allowlist/trigger; set status, priority, assignment, escalation and SLA fields server-side only. Staging must prove client-supplied privileged fields are ignored/rejected.

**P2 — Excess support-ticket grants:** authenticated has INSERT, SELECT, UPDATE and DELETE table grants, but only owner SELECT and owner INSERT policies were found. UPDATE/DELETE are currently denied by RLS in the absence of policies, but unnecessary grants should be removed or explicitly justified to reduce future policy-regression risk.

## 5. Notifications and delivery semantics
- In-app `notifications` are scoped to the user's own rows for SELECT and UPDATE.
- Outbox and delivery tables have authenticated SELECT grants but organization-scoped SELECT policies; delivery visibility derives from the parent outbox organization.
- Outbox and delivery mutation is service-role-only in the reviewed grants.
- No notification preference rows, outbox rows, delivery rows or retry events exist in production.
- The previous CRM/notification audit found Telegram as an implemented internal founder-alert path, but actual delivery remains unverified; Resend is not send-ready and external customer messaging has not been verified.
- Provider acceptance must not be labelled as human receipt. Distinguish queued, provider-accepted/sent, delivered (only when provider confirms), bounced/failed and read where the channel supports it.
- Previously identified retry risks remain: immediate send/retry race can duplicate alerts; worker crash can strand processing claims without leases/reclaim; overlapping retry generations need consolidation; missing Cloudflare client-IP context can weaken throttling.
- No user notification preferences exist. Implement essential transactional vs optional marketing categories, channel-level opt-in/opt-out, quiet hours and locale preferences without suppressing critical safety/service alerts. Marketing consent must remain distinct from privacy acknowledgement and transactional updates.

## 6. Exception management and service recovery
There are zero exception records, timers, escalations and signal events. This means the platform has no production evidence of detecting, acknowledging, assigning, resolving or escalating a delayed pickup, missed milestone, damaged/lost cargo, failed handover, customs hold, failed delivery or customer-impacting incident.

Before pilot:
- Define event-to-exception mappings, severity, owner, partner responsibility and customer-visible status.
- Start timers from authoritative shipment/leg events; deduplicate signals and use idempotent event IDs.
- Escalate by severity and elapsed time with leases/retry protection; stop timers atomically on resolution/cancellation.
- Require evidence and independent review for critical/high-impact resolution; retain immutable cause, action and decision history.
- Keep customer communication factual: confirmed facts, current estimate, next update time and support reference. Never invent location, cause or recovery commitment.
- Add customer-impacting service recovery, claims, damage/loss and complaint workflows; financial compensation/refunds remain deferred to the final finance phase.

## 7. Required staging-only verification
1. Public tracking token entropy, uniqueness, lookup throttling, invalid/revoked/rotated token, enumeration resistance, no-store/cache, response redaction and terminal-shipment privacy.
2. Customer A cannot read customer B shipment history, tracking events, tickets, internal messages, notifications or private evidence.
3. Partner A cannot read another partner's shipment; driver access only exact assigned leg; operations access requires explicit tracking permission.
4. Event ingestion: duplicate event ID, same-payload retry, conflicting replay, out-of-order event, concurrent sequence allocation, failed downstream write and reconciliation.
5. ETA: missing, stale, past, implausible, changed and unconfirmed ETA; ensure UI clearly distinguishes estimate from confirmed appointment.
6. Ticket creation: try spoofed user, organization, shipment, status, priority, assignment, escalation and timestamps; all privileged fields must be server-set or rejected.
7. Ticket lifecycle: customer reply, internal note confidentiality, AAL1 denial, AAL2 admin reply, reopening, resolution reason, close, reopen and audit consistency.
8. Notifications: preference changes, consent withdrawal, duplicate event, provider timeout, accepted-but-not-delivered, bounce, retry race, worker crash/lease expiry, rate limiting and locale/quiet hours.
9. Exceptions: signal ingestion, duplicate signal, severity, timer start, delayed escalation, ownership transfer, independent critical resolution, cancellation and post-resolution late signal.
10. End-to-end customer journey using synthetic staging records only: request → quote → confirmed partner assignment → authoritative milestones → exception if injected → customer updates → verified POD → final customer notification. Do not create a production shipment or send real customer messages.

## 8. Remediation order and release gate
1. Harden support-ticket insert fields and remove unjustified UPDATE/DELETE grants.
2. Add tracking token entropy verification, throttling, abuse monitoring and rotation/revocation.
3. Implement durable shipment event receipt/sequence processing and replay/reconciliation tests.
4. Correct customer-facing ETA confidence/freshness labels and ensure no false live-GPS claim.
5. Fix notification worker lease/reclaim, retry race, provider delivery semantics and channel preferences.
6. Complete exception signal/timer/escalation lifecycle and customer communications.
7. Run staging cross-tenant and complete customer journey tests.
8. Only after market, corridor, partner, driver, warehouse, customs and legal release gates pass, seek explicit approval for a limited live pilot.

## 9. Change control and release gate
Read-only audit only. No tracking lookup, ticket, notification, exception, shipment or customer communication was created. No production data, schema, functions or policies were changed. Production migration reconciliation remains unresolved; no production DDL or function/policy fix should be applied until the migration crosswalk and sanitized schema manifest are reconciled.

**Release status: NO-GO for reliable customer tracking, live GPS claims, automated customer notifications, exception response SLAs or customer-support service-level promises.** Tracking and support infrastructure exists, but live evidence is nearly absent and the support-ticket insert policy requires hardening.
