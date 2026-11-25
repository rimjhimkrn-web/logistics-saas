# C3.36 — Global Customer Protection, Shipment Reliability & End-to-End Service Journey Audit

**Date:** 25 November 2026  
**Immutable source baseline:** `72d75a18f985ceb09e468839435ee95700e11e46`  
**QA branch:** `qa/phase-00-baseline-2026-11-25`  
**Method:** Read-only source and historical Production evidence review of customer booking/quote/payment, shipment lifecycle, tracking, POD, support, consent, claims, disputes, refunds, service quality, exception recovery and notifications. Reviewed existing audits and relevant migrations/functions. No business RPCs, tickets, claims, refunds, consent writes, tracking requests, file uploads, provider calls or shipment actions were executed.

## Executive verdict

**FAIL / BLOCKED — NO-GO for accepting or executing real customer shipments, promising end-to-end delivery, claiming operational customer-support SLAs, or representing claims/disputes/refunds/notifications as production-reliable services.**

KRIM has meaningful customer-facing workflow foundations: authenticated organization-scoped booking interfaces, quote/assignment separation, partner-direct payment guidance, private verified-POD access, shipment history, owner-scoped support patterns and AAL2 administrative review paths. The canonical shipment model also has transition/readiness triggers and event-history primitives.

But there is no proven successful customer-to-delivery journey. The historical 16 November Production snapshot had no verified active supply, accepted assignment, capacity, dispatch authorization, driver assignment, warehouse stock, customs release or POD. Customer protection and recovery tables were empty. Multiple source-level defects affect consent integrity, support ticket field control, claim evidence/leg binding, exception closure, dispute lifecycle, cancellation coordination, POD exact-leg binding, and notification delivery semantics/recovery. C3.22–C3.35 also retain upstream blockers in driver, warehouse, customs, finance, dispatch, environment and market activation.

## 1. Evidence reviewed

- `docs/audits/KRIM-CUSTOMER-PROTECTION-SUPPORT-CLAIMS-CONSENT-AND-INCIDENT-RESPONSE-AUDIT-2026-11-16.md`
- `docs/audits/KRIM-FIRST-REAL-SHIPMENT-OPERATIONAL-READINESS-AND-END-TO-END-SERVICE-ASSURANCE-AUDIT-2026-11-16.md`
- `docs/audits/KRIM-CUSTOMER-SHIPMENT-VISIBILITY-TRACKING-SUPPORT-EXCEPTIONS-AND-NOTIFICATION-RELIABILITY-AUDIT-2026-11-16.md`
- `docs/audits/KRIM-CANCELLATION-CLAIMS-REFUNDS-AND-EXCEPTION-RECOVERY-REVIEW-2026-11-16.md`
- `docs/audits/KRIM-SHIPMENT-LIFECYCLE-STATE-MACHINE-AND-EVENT-CONSISTENCY-P0-P1-AUDIT-2026-11-16.md`
- `docs/audits/KRIM-CUSTOMER-JOURNEY-AND-EPOD-INDEPENDENT-VERIFICATION-REVIEW-2026-11-16.md`
- `docs/audits/KRIM-CUSTOMER-SHIPMENT-QUOTE-PAYMENT-AND-EPOD-JOURNEY-AUDIT-2026-11-16.md`
- `docs/audits/KRIM-EXCEPTIONS-CLAIMS-DISPUTES-AND-SERVICE-RECOVERY-END-TO-END-DEEP-AUDIT-2026-11-16.md`
- `docs/audits/KRIM-CUSTOMER-SUPPORT-SERVICE-QUALITY-FEEDBACK-PARTNER-PERFORMANCE-AND-SLA-AUDIT-2026-11-16.md`
- `docs/audits/KRIM-NOTIFICATION-DELIVERY-AND-RETRY-RELIABILITY-P1-AUDIT-2026-11-16.md`
- `docs/audits/KRIM-DELIVERY-POD-DRIVER-TO-LEG-EVIDENCE-INTEGRITY-P1-AUDIT-2026-11-16.md`
- Relevant shipment, support, claims, consent, refund, POD and notification migrations; C3.19–C3.35 reports.

## 2. Customer-to-delivery journey: status and boundaries

| Journey stage | Evidence-backed assessment | Gate |
|---|---|---|
| Customer admission and organization scope | Authenticated membership and owner-scoped patterns exist; consent/admission and tenant-isolation runtime proof incomplete | BLOCKED |
| Booking request | Idempotent request pattern and endpoint/cargo validation exist; market/corridor/mode gate and canonical RPC/trigger compatibility unresolved | BLOCKED |
| Quote and provider award | Customer acceptance waits for accepted provider assignment and valid quote; no current partner quote/accepted assignment evidence | BLOCKED |
| Freight payment | Customer/provider direct-payment guidance; no KRIM freight custody/split or proof of partner bank settlement | BLOCKED |
| Capacity and dispatch | Exact-leg controls designed, but no operational capacity/dispatch; C3.26 legacy dispatch P0 remains | BLOCKED |
| Driver and vehicle | Invitation/evidence workflows exist; no operational driver/vehicle journey and C3.22 gaps remain | BLOCKED |
| Warehouse and customs | C3.23 warehouse FAIL; C3.24 customs FAIL; no operational facility or authority release | BLOCKED |
| Tracking and milestones | Public token endpoint has privacy controls and suppresses raw GPS; no live journey, GPS is disabled, event receipt/sequence evidence absent | BLOCKED |
| Delivery and ePOD | Private evidence and verified-only customer display; no POD records and exact driver-to-partner leg mismatch defect | BLOCKED |
| Exceptions and recovery | Case models exist, but no live incidents, actions, timers, escalations or recovery checkpoints; closure gates incomplete | BLOCKED |
| Support, consent and disputes | Owner-scoped patterns exist; consent, ticket field control and dispute lifecycle gaps remain | BLOCKED |
| Notifications | Founder Telegram queue only; no general customer/partner delivery proof; stale processing and false delivery semantics | BLOCKED |
| Refunds and financial reconciliation | Full-refund-only constraints and partner-direct model; C3.25 finance FAIL; no end-to-end refund/reconciliation proof | BLOCKED |

A booking request, quote, accepted quote, payment instruction, shipment status, event row, tracking response, uploaded POD, provider API acceptance or UI success message is not by itself proof of physical shipment execution, recipient notification, verified delivery or settled refund.

## 3. Historical operational evidence (16 November snapshots)

The first-real-shipment audit recorded:
- 10 legacy partner records, but 0 verified active capabilities, 0 approved service areas, 0 partner-submitted quotes and 0 accepted partner assignments.
- 0 capacity resources, reservations, driver assignments, dispatch authorizations, warehouse inventory, customs cases and POD records.
- 18 canonical shipments (8 draft, 3 quoted, 6 confirmed, 1 closed); 17/18 had null requested transport mode in that snapshot.
- 7 customer quote records, all expired and unlinked to a partner quote.
- 6 market controls blocked, 249 country packs research_pending, 7 corridors draft and zero approved corridor dossiers/controls.

Customer protection snapshot:
- 0 customer service requests, support tickets/messages/events, claims/evidence/events, disputes/cases/investigations/decisions/appeals, consent records/events, refund requests, operational exceptions/escalations/timers, notification outbox/deliveries/preferences or system incidents.

Visibility/support snapshot:
- 41 shipment status-history rows and 5 in-app notifications, but 0 durable event receipts/sequences, support tickets, notification outbox/deliveries/retries, exceptions, timers, escalations or exception signals.
- Public tracking function uses a high-entropy token, POST validation, no-store headers and excludes raw GPS from public event output. GPS sharing is intentionally disabled; endpoint presence is not live GPS tracking evidence.

Service-quality snapshot:
- 0 support tickets/messages/events, ratings, partner-performance events/metrics, shipment SLA targets/breaches/remedies, service-contract SLA definitions or SLA evaluation runs/results.

These are historical snapshots, not refreshed current counts. They demonstrate absence of operating evidence at audit time, not present-day live database counts.

## 4. P0 findings

### P0.1 — No successful end-to-end shipment assurance
No audited evidence demonstrates one shipment from eligible customer request through verified partner quote, accepted exact-leg assignment, reserved capacity, dispatch, custody, customs/warehouse where applicable, tracking, independently verified POD, customer notification and financial close. Multiple upstream gates are blocked. A real customer pilot is not safe.

### P0.2 — Dispute write/lifecycle path not verified
The deep audit did not identify a verified production dispute write/API journey. A complete case lifecycle is required: authorized claimant/respondent and shipment/assignment binding, evidence intake, independent investigation, reasoned decision, time-bounded appeal, independent appeal outcome and obligation-aware closure. Do not expose the dispute area as a functioning resolution service until implemented and staging-tested.

### P0.3 — Upstream critical blockers still prevent safe execution
- C3.23: warehouse transfer/picking can violate reservation-aware stock integrity.
- C3.24: customs compliance evaluator can return clear when zero checks exist; no authority-release workflow.
- C3.25: finance/payment controls and freight-collection kill-switch integrity fail.
- C3.26: legacy privileged dispatch path can bypass exact-leg authorization/readiness.
- C3.28–C3.32: admin role authority, event reliability, environment isolation and privacy/security gaps.
- C3.35: no activated market, country pack, corridor or multimodal service.
Do not weaken fail-closed gates to make a customer journey appear successful.

## 5. P1 customer-protection and reliability findings

1. **Consent integrity:** historical consent table policies permitted broad authenticated direct writes/deletes; signup acknowledgement is editable user metadata; consent RPC caller/grant path was not proven. Consent must be server-recorded, immutable/versioned by purpose, channel and jurisdiction, with withdrawal and audit trail.
2. **Support ticket privilege fields:** direct authenticated ticket INSERT can allow caller-supplied operational fields (status, priority, assignee, escalation and SLA timestamps) unless separately constrained. Ticket creation must use a narrow server-side allowlist/RPC; triage priority and assignment must be staff-controlled.
3. **Support context and SLA:** customer form did not consistently bind organization/shipment; fixed 48-hour/30-day internal targets are not contractual SLAs. No durable SLA breach evaluator or escalation evidence. Do not advertise response/resolution promises.
4. **Claim attribution and evidence:** claims do not consistently bind to an explicit shipment leg/responsible assignment; review may proceed without independently verified evidence; zero-value claims and claimant/tenant linkage concerns remain. Claim evidence used a partner-verification bucket rather than a dedicated governed claim-evidence lifecycle.
5. **Exception closure:** exceptions requiring evidence can be resolved without evidence; corrective actions may be cancelled as a side effect. Final closure must require verified evidence and completion/approved disposition of all mandatory corrective actions.
6. **Dispute and appeal lifecycle:** no proven end-to-end write path, independent investigation/appeal, or closure against actual obligations.
7. **Cancellation/recovery:** generic transition permits dispatched-to-cancelled without a required reason and does not itself prove coordinated release/stop of driver, capacity, warehouse, custody, notification and financial dependencies. In-transit cases must use controlled disruption/return recovery, not generic cancellation.
8. **POD exact-leg integrity:** driver POD wrapper did not compare driver-assignment shipment_leg_id with linked partner-assignment shipment_leg_id; reviewer also did not independently prove driver evidence leg equals POD leg. Enforce composite exact-shipment/leg/organization binding at submission and review.
9. **Notification truthfulness:** Telegram API acceptance is recorded as delivered, overstating recipient delivery. Worker crashes can strand outbox rows in processing indefinitely because stale-processing lease recovery is absent. Resend adapter does not send; general customer/partner notifications are not implemented/proven.
10. **Event and customer-visible status:** status history/event creation is distinct from delivery. Event receipt/sequence tables were empty in historical snapshot; idempotency, out-of-order/replay and reconciliation need staging verification.
11. **Ratings and partner performance:** rating RLS was not bound to shipment ownership/completed status; no rating/performance metric records. Activity counts or illustrative scorecards must not be represented as verified performance scores.
12. **Refund and financial closure:** current reviewed refund flow is full-refund-only; no actual refund or settlement evidence. Claim approval is not a payer commitment or settled recovery. C3.25 requires partner-direct non-custodial funds flow; KRIM must not collect freight or promise split payouts.

## 6. Positive controls worth preserving

- Customer booking page authenticates the user, requires an active customer organization, validates endpoint/cargo inputs and uses an idempotency key. These are preflight controls, not market/corridor authorization.
- Quote workflow separates provider assignment acceptance from customer quote acceptance and checks quote identity/status.
- Partner-direct payment guidance does not expose a freight payment SDK or claim KRIM escrow/split settlement.
- Customer ePOD display requires verified status, non-null verified_at and verified_by before offering temporary private-file links; actual database/storage authorization remains authoritative.
- Canonical shipment transition registry locks rows, checks allowed transitions/permissions/reasons and writes history; readiness triggers block execution states when prerequisites fail.
- Support customer reply checks ticket ownership, locks ticket and excludes internal notes from customer message reads; admin support paths require AAL2.
- Public tracking uses token-based lookup and suppresses raw GPS event data.
- Private evidence and separate admin verification controls exist in several POD and support flows.

These are code-level controls and have not been validated as a complete staging journey.

## 7. Required remediation and release sequence

1. Reconcile deployed Production schema/function/migration history with repository before any backend remediation; do not replay or baseline migrations blindly.
2. Resolve all P0 upstream gates: market/corridor and canonical booking contract (C3.35), customs zero-check and authority release (C3.24), warehouse reservation integrity (C3.23), dispatch exact-leg/readiness (C3.26), finance freight collection kill switch and permissions (C3.25), Admin authorization and environment isolation (C3.28/C3.31).
3. Create a single canonical customer shipment lifecycle and retire/isolate legacy `shipment_requests` callers after compatibility inventory. Bind required transport mode and exact route/corridor evidence atomically.
4. Harden consent, support-ticket creation, claim evidence/assignment/leg binding, dispute/appeal lifecycle, cancellation/recovery and exception closure with narrow transactional RPCs, immutable events, independent review and least-privilege grants.
5. Enforce driver-to-partner assignment composite exact-leg binding for POD at submission and independent review; validate private object ownership, integrity and verified-delivery authorization.
6. Implement a durable customer/partner notification outbox with leases, stale-processing reclaim, retry/dead-letter, idempotency, per-channel consent, provider webhook evidence and truthful queued/accepted/sent/delivered/bounced/read states.
7. Implement durable shipment event receipts/sequences, duplicate/conflicting replay and out-of-order handling; status timeline must distinguish operationally verified events from user-entered or stale data.
8. Define service-contract-specific SLA calendars by severity, jurisdiction, timezone, holidays and service hours; implement scheduled breach detection, accountable owners, escalation acknowledgement, customer communication and remedy evidence. Do not call internal defaults a contractual SLA.
9. Run isolated Staging synthetic adversarial tests: wrong tenant, wrong organization, revoked membership, forged ticket fields, missing/withdrawn consent, claim with wrong leg/assignment, evidence-free closure, disputed appeal, dispatched/in-transit cancellation, POD cross-leg mismatch, notification worker crash/reclaim, provider accepted-but-not-delivered, duplicate/out-of-order event, failed refund and recovery replay.
10. Complete one synthetic single-leg domestic journey and one synthetic multi-leg journey only after the relevant exact corridor, partner, capacity, legal and mode gates are demonstrably approved in isolated Staging. Capture each expected/actual result, DB/audit evidence, notification receipt and recovery path. Do not use real customer data or money.
11. Only after all tests pass, conduct a separately approved, tightly bounded real pilot with one verified partner and one exact route/service; manual operations and customer support coverage must be named and staffed.

## Gate decision

**C3.36 FAIL / BLOCKED.** KRIM has useful customer and shipment workflow foundations, but not a proven customer-protection or shipment-reliability service. Do not onboard real customers for live freight bookings, promise delivery/ETA/tracking, advertise customer support SLAs, represent claims/disputes/refunds as operational, or claim verified delivery until upstream gates and the end-to-end evidence requirements pass. Non-binding customer discovery and product feedback may continue without collecting freight or implying service availability.

**Safety record:** No Production/Staging writes, RPC calls, ticket/claim/refund/consent actions, public tracking requests, evidence uploads, provider calls, customer communications, bookings, dispatches or payments were performed. Historical evidence is dated; no live counts or runtime journey were asserted.
