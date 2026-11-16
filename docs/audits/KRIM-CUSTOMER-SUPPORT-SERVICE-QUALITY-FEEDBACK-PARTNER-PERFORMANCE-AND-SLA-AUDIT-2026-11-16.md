# KRIM Customer Support, Service Quality, Feedback, Complaints and Partner Performance Audit
**Date:** 16 November 2026  
**Scope:** Read-only production PostgreSQL review of support tickets, messages, events, ratings, partner performance events/metrics, shipment SLA targets/breaches/remedies and support-related functions/policies; source review of customer support, ticket history, admin support desk and partner performance pages. No ticket, message, rating, SLA record, breach, remedy or performance metric was created or changed. No notification or external communication was sent.

## Executive decision
**NO-GO for global customer-support and service-quality certification.** KRIM has a usable authenticated support-ticket path, a restricted AAL2 platform-admin desk, customer-visible message history, event/audit records and a cautious carrier activity page. But all support, feedback, partner-performance and SLA evidence tables are empty. Several meaningful integrity gaps remain: ticket creation permits callers to set workflow/assignment fields directly; ratings are not bound by RLS to shipment ownership or completed status; support ticket creation does not link the customer organization or shipment in the current UI; support SLA targets are a fixed internal 48-hour/30-day rule rather than a contracted, market-specific SLA; and notification triggers only create in-app notification rows, not verified delivery.

## 1. Live production baseline
Exact read-only counts at audit time:

| Record | Rows |
|---|---:|
| Support tickets | 0 |
| Support ticket messages | 0 |
| Support ticket events | 0 |
| Shipment ratings | 0 |
| Partner performance events | 0 |
| Partner performance metric snapshots | 0 |
| Shipment SLA targets | 0 |
| SLA breaches | 0 |
| SLA remedies | 0 |
| Service-contract SLA definitions | 0 |
| ETA/SLA evaluation runs | 0 |
| ETA/SLA evaluation results | 0 |

No production support conversation, customer rating, partner scorecard, contract SLA, SLA breach or remedy has been demonstrated. Prior audits also found no verified partner operating population, no accepted assignments and no executed service contracts.

## 2. Customer support ticket creation and ownership
### Positive controls
- The support page requires a Supabase-authenticated session and inserts the ticket with the current session user ID.
- RLS requires `user_id = auth.uid()`; when an organization ID is supplied, the caller must have active organization access.
- When a KRIM shipment ID is supplied, the RLS check requires that shipment to belong to the supplied customer organization.
- Ticket reads are owner-scoped.
- Customer replies use `krim_customer_reply_support_ticket`, which locks the ticket, requires exact ticket ownership by the authenticated user, rejects terminal tickets and bounds message length.
- Ticket messages and event history are owner-readable; customer message policy explicitly excludes internal notes.
- The restricted support desk uses AAL2 and `admin.platform` permission for queue listing, thread access, replies and status transitions. Status/reply changes are written to ticket events and KRIM audit events.

### Finding SUP-01 — P1: direct ticket INSERT can set operational fields
Authenticated users have direct INSERT privilege and the RLS INSERT policy checks user ownership, optional organization membership and optional shipment/org relationship. However, the policy does not constrain caller-supplied `status`, `priority`, `assigned_to`, `assigned_organization_id`, `resolved_at`, `closed_at`, `escalation_level` or other workflow metadata. The BEFORE INSERT trigger only overwrites first-response and resolution due timestamps and appends a policy label to metadata. It does not normalize the other operational fields.

The current web form submits a limited set of fields, but a modified client can call the table API directly and attempt to create a self-assigned, urgent, already-resolved or otherwise manipulated ticket. RLS is row ownership, not column-level workflow authorization. Move ticket creation to a validated RPC or enforce server-side defaults/immutable workflow columns; do not trust browser form omissions.

### Finding SUP-02 — P1: customer support form does not attach KRIM organization or shipment
The live support runtime inserts `user_id`, category, subject, message, priority and optional `tracking_number`; it does not populate `krim_organization_id` or `krim_shipment_id`. The shipment reference is stored as free-text tracking_number. Therefore the current form does not create a durable tenant/shipment relationship for operations to use, even though the database supports one. Support triage cannot safely assume a typed tracking reference identifies the caller's shipment. Add a server-verified shipment lookup and bind the correct customer organization and canonical shipment ID, with a clear unlinked/general ticket path.

### Finding SUP-03 — P2: user-facing priority is self-selected
The form maps customer-selected P1/P2/P3 to urgent/high/normal. This can be useful as a requested urgency signal, but it should not be treated as KRIM's verified severity or SLA commitment. Keep customer-requested urgency separate from staff-assessed priority and require an auditable triage decision.

## 3. Support response, status lifecycle and notifications
### Positive controls
- Customer replies and admin replies are separate routines; admin internal notes are flagged `is_internal=true` and excluded from customer message reads.
- Admin list/thread/reply/transition functions check authentication, AAL2 and platform-admin permission.
- Status transitions require a reason when resolving or closing; terminal-state replays of the same status are rejected.
- Ticket changes produce ticket events and audit events.
- A trigger sets first-response due at 48 hours and resolution due at 30 days under the internal policy label `KRIM_INTERNAL_48H_30D_V1`.
- Status-change trigger creates in-app notifications for the ticket owner; customer reply and admin reply paths preserve message history.

### Findings
1. **P1 — Internal SLA is fixed, not contract-backed:** every ticket gets 48-hour first response and 30-day resolution deadlines, regardless of severity, user type, service contract, country, time zone, business hours, holidays or shipment criticality. These are internal defaults, not an SLA guarantee to customers or partners. There are no service-contract SLA rows or shipment SLA target rows in production.
2. **P1 — No SLA breach detection evidence:** no SLA breach rows, evaluation runs or results exist. This audit did not find evidence that the support ticket response/resolution deadlines are monitored by a durable scheduler and escalated when missed. A due timestamp is not an active SLA monitor.
3. **P1 — Notification trigger is not verified communication:** the trigger writes an in-app notification row when a ticket status changes; it does not prove push/email/WhatsApp delivery or that the customer saw it. The new-ticket trigger selects the first row from legacy `admin_users` and creates one in-app notification if one exists; it does not prove assignment to the correct support queue or on-call owner. Prior notification audit found no delivery evidence and known retry/lease/race issues.
4. **P1 — Reopen/resolve semantics need staging tests:** customer replies reject resolved/closed tickets. Admin transition can reopen by setting open/in_progress and clears resolved/closed timestamps, but no explicit customer confirmation or reopen reason is required for reopening. Verify status history, notification dedupe and SLA clock reset/continuation.
5. **P2 — No support capacity or coverage model:** no queue ownership, region/timezone schedule, language coverage, backup agent, holiday calendar or response staffing evidence was found.

## 4. Ratings, reviews and feedback integrity
### Positive controls
- Rating range is constrained to 1–5.
- One rating per legacy shipment/customer pair is enforced by a unique constraint.
- Customer can read only their own rating rows.
- The reviewed partner page correctly avoids claiming a certified carrier rating or public ranking.

### Finding QLTY-01 — P1: rating RLS does not bind the shipment to the customer
The `shipment_ratings` INSERT policy checks only `customer_id = auth.uid()`. The table references the legacy `shipment_requests` ID and optionally stores KRIM shipment and organization IDs, but the policy does not establish that the referenced shipment belongs to the submitting user/organization, is completed, or is eligible for feedback. A caller may attempt to rate another existing legacy shipment if its identifier is known. The foreign keys and 1–5 check do not prove customer entitlement. Replace with a server-side rating RPC that validates canonical shipment ownership, delivery completion, customer identity, partner attribution and one-time rating; make the linkage between legacy and KRIM shipment IDs explicit and consistent.

### Finding QLTY-02 — P1: no verified review/feedback lifecycle
No ratings or performance events exist. No reviewed source path establishes a full customer feedback moderation, response, dispute, abuse/fraud, edit window or verified-delivery eligibility process. Public ratings must not be enabled as a marketplace trust signal until shipment ownership, verified completion, moderation and anti-manipulation controls are proven.

## 5. Partner performance and service quality
### Positive controls
- Partner performance event and metric tables have RLS enabled and no direct authenticated INSERT/UPDATE/DELETE grants.
- Partner metric snapshots are readable only by the relevant partner organization; event visibility is scoped to the partner organization or the customer organization on the linked shipment.
- The reviewed carrier performance page verifies session, active membership, partner organization type, registered-business mode, verification, lifecycle and compliance.
- It only displays accepted/active assignments and associated tracking-event counts. It explicitly labels them as record-based indicators, not certified ratings, SLA scores, safety assessments or rankings, and does not infer success from missing events.

### Findings
1. **P1 — No evidence-backed performance scorecards:** partner event and metric tables are empty; no verified partners or accepted assignments exist. No on-time delivery, acceptance, completion, POD compliance, exception or claim metric has been calculated from a real operating sample.
2. **P1 — Performance event coverage and attribution need verification:** the partner page counts tracking events for visible assignments and counts only events whose normalized type is exactly `exception_reported`. This is an activity view, not a full exception/claims/SLA measure. Validate event taxonomy, partner attribution, multi-leg attribution, duplicate/replayed events, time zone and cancelled/voided events before any KPI calculation.
3. **P1 — No customer-visible comparative quality evidence:** there is no verified, populated and governed customer feedback/performance score that can support partner rankings or marketplace recommendations. Do not advertise a quality rating or service guarantee.
4. **P2 — Metric definitions need governance:** define numerator/denominator, exclusions, sample minimum, confidence interval, partner dispute/correction, audit provenance and calculation version before scores affect partner visibility or commercial eligibility.

## 6. SLA breach and remedy controls
- Shipment SLA target, contract SLA, breach and remedy tables exist with RLS enabled and no direct authenticated DML grants in the inspected snapshot.
- SLA breach visibility is scoped through the related contract counterparty or exception organization; remedies inherit party visibility through the breach/contract relation.
- Remedy records include approval status, approver, approved time and applied time, separating calculation from approval/application.
- However, there are zero SLA targets, contract SLA definitions, breaches or remedies. No actual breach evaluator, partner notice, dispute, independent approval or remedy application has been demonstrated.
- SLA remedy records are not proof of payment, refund, credit note or partner debit. Financial execution remains deferred.

## 7. Required staging-only acceptance tests
1. Attempt ticket INSERT with forged user ID, organization, shipment, priority, status, assignment, escalation and terminal timestamps; only server-approved fields should persist.
2. Submit a ticket with a valid customer shipment; verify canonical customer org and shipment linkage. Submit a guessed foreign shipment ID and ensure rejection.
3. Submit a ticket with free-text tracking number only; label it unverified until a trusted lookup resolves it.
4. Customer A must not read/reply to Customer B ticket; partner/driver/warehouse/customs roles must not access unrelated tickets.
5. Customer cannot read internal notes or messages from another ticket.
6. AAL1, non-admin, wrong-tenant admin and revoked platform admin cannot list or mutate support tickets; AAL2 authorized admin can.
7. Duplicate reply retries and concurrent status transitions must not create duplicate customer-visible messages or contradictory states.
8. Verify first-response/resolution SLA clock, business hours, timezone, pause rules, reopen rules, overdue detection, escalations and notification delivery.
9. In-app notification, email or push provider acceptance must not be represented as human receipt.
10. Attempt rating for another customer's shipment, an uncompleted shipment, a cancelled shipment and a shipment with no verified delivery; all must reject.
11. Verify one-time rating per eligible shipment, correct partner/leg attribution, edit window, moderation, abuse controls and customer privacy.
12. Verify partner performance calculations against source assignments/events/POD/exceptions/claims; replayed events and multi-leg shipments must not inflate or misattribute metrics.
13. Verify SLA breach measurement, exclusions, notice, dispute, approval and remedy lifecycle without any live financial posting.
14. Verify data export/deletion/retention for tickets, messages, ratings, attachments and support audit history.

None of these staging tests was executed.

## 8. Remediation order
1. Replace direct support-ticket INSERT workflow with server-validated creation; prevent client-controlled workflow fields.
2. Resolve canonical shipment/org association during ticket creation; preserve safe unlinked ticket creation where appropriate.
3. Replace rating INSERT policy-only flow with a server-side completed-shipment/customer-ownership validation path.
4. Define tiered, contract-aware support SLAs and prove scheduler/overdue/escalation behavior.
5. Verify support notification routing, outbox/retry/lease and actual provider delivery separately.
6. Populate performance metrics only from verified source events; govern calculations and disputes before exposing rankings.
7. Keep SLA remedies distinct from claims, refunds, credits and finance execution.
8. Do not make production schema/function/policy changes until the migration-history mismatch is reconciled.

## 9. Change control and release decision
Read-only audit only. No RPC, notification worker, ticket creation, reply, rating, SLA evaluation, claim or financial action was invoked. No production records or schema were changed.

The migration-history mismatch and sanitized schema-manifest gate remain unresolved. No migration replay or corrective production DDL is authorized.

**Release status: NO-GO for global customer-support, ratings/reviews, partner-quality scoring and contractual SLA certification.** The support desk has a credible foundation, but its ticket creation fields and rating entitlement need stronger server-side integrity, all relevant production evidence tables are empty, and notification/SLA execution remains unverified.
