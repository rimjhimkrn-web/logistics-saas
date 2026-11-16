# KRIM Customer Protection, Support, Claims, Consent and Incident Response Audit — 2026-11-16

## Scope and safety
Read-only review of production customer support, service requests, claims/evidence, disputes, refunds, consent, exception escalation, notification delivery and incident tables; selected database routines and RLS/privileges. No tickets, claims, refunds, consent events or notifications were created or modified. No business RPC was executed and no customer content or personal identifiers were exported.

## Live production snapshot

| Customer protection component | Rows |
|---|---:|
| Customer service requests | 0 |
| Support tickets | 0 |
| Support ticket messages | 0 |
| Support ticket events | 0 |
| Claims | 0 |
| Claim evidence | 0 |
| Claim events | 0 |
| Disputes | 0 |
| Dispute cases / investigations / decisions / appeals | 0 |
| Customer consent records | 0 |
| User consent events | 0 |
| Refund requests | 0 |
| Operational exceptions | 0 |
| Exception escalations / timers | 0 |
| Notification outbox / deliveries / preferences | 0 |
| System incidents | 0 |

These zero counts mean the workflows have not been demonstrated with live customer cases. They do not prove the code is unusable, nor do they establish that customer support or external notifications are operational.

## Controls observed

### Customer support
- Support ticket creation is RLS-scoped to the authenticated ticket owner, organization membership and shipment/customer-organization relationship.
- Customer replies use a SECURITY DEFINER function that checks `auth.uid()` owns the ticket, rejects closed tickets, records the message/event and writes an audit event.
- Admin list/thread/reply/transition functions require AAL2 and platform-admin permission.
- Admin replies and internal notes are separated by an `is_internal` flag; customer message read policy exposes only non-internal messages.
- Ticket status changes require a meaningful reason when resolving or closing.
- Ticket creation sets internal targets of 48 hours for first response and 30 days for resolution. These are database targets, not proof of a customer-facing contractual SLA or actual staffed coverage.

### Claims and evidence
- Claim submission checks active customer organization membership, shipment.update permission, shipment ownership and eligible shipment state, claim type, active currency and a meaningful description.
- Evidence upload checks the claimant organization, uploader identity, private storage object ownership, MIME type and file size (PDF/JPEG/PNG, maximum 10 MB); evidence is initially pending and emits a claim event.
- Claim review requires AAL2, an active platform/operations organization, admin.platform permission, a meaningful note and an approved amount not greater than the claim.
- Claim/evidence/event tables have RLS and no direct authenticated write grants; claim read policies scope the claimant, respondent and platform/operations reviewer.
- Earlier review identified a multi-leg assignment-selection weakness: claim submission chooses the latest accepted/completed assignment for the shipment, without an explicit leg/exception-specific assignment selector. A claim can therefore be attributed to the wrong partner on multi-leg shipments; it can also be created without an assignment/respondent. This must be fixed before multi-leg claims are relied on.

### Refunds and disputes
- Refund requests are empty. The previously inspected refund process is full-refund-only, approval and provider execution are distinct, and provider-side confirmation plus reconciliation is required before marking a refund completed.
- Dispute tables exist but contain no records. A complete operational dispute workflow, independent decision review, response deadlines and customer notification were not demonstrated in this read-only sample.

### Consent and privacy
- Canonical customer consent records are empty.
- `krim_customer_consents` has RLS but authenticated users also have direct INSERT, UPDATE and DELETE table privileges. Its organization-scoped ALL policy allows organization members to mutate consent records. This undermines the integrity of the consent register: consent grant/withdrawal history should be append-only and changed only through trusted consent functions, not directly edited or deleted by ordinary organization members.
- The inspected `krim_grant_customer_consent` function records consent types/version and an audit event, but its effective authenticated EXECUTE privilege check is false in the current grant snapshot. The customer consent workflow therefore needs a full grant/call-path verification before being represented as working.
- `krim_user_consent_events` allows authenticated users to insert events for their own user ID and does not allow direct update/delete. This is more consistent with an append-only event stream, but client-supplied event values and policy versions still need validation and a clear distinction between a user's assertion and a legally sufficient consent record.
- Earlier customer registration audit found signup checkbox data in user-editable auth metadata, not a canonical consent ledger. Do not treat mutable user metadata as proof of acceptance.

## Priority findings

### P1 — Canonical consent records can be directly rewritten/deleted
The customer consent table's direct authenticated write privileges and organization-level ALL policy allow consent rows to be inserted, updated or deleted outside the intended consent workflow. Revoke direct writes after migration reconciliation; use narrowly scoped trusted grant/withdraw functions that append immutable evidence including user, organization, consent type, exact policy version/hash, timestamp, capture channel and withdrawal event. Preserve historical versions rather than overwriting the grant.

### P1 — Consent function's actual caller path is not proven
The inspected public consent grant function is not executable by authenticated under the effective privilege check. Find the actual frontend/RPC call path and grants; do not assume the existence of a SECURITY DEFINER function means the customer can invoke it. Verify grant and withdrawal separately, including idempotency and version changes.

### P1 — Claims do not bind to an explicit shipment leg
Claim submission selects the latest accepted/completed partner assignment at shipment level. This is ambiguous for multi-leg transport. Require an explicit leg and corresponding assignment (or a validated exception-to-assignment mapping); verify that the respondent is the provider responsible for that exact event/leg. If no provider assignment exists, route the claim to a KRIM service complaint/dispute workflow rather than silently creating a provider liability record with null respondent.

### P1 — Support ticket and notification operation unproven
All support ticket/message/event and notification outbox/delivery/preference counts are zero. The support code has useful owner and admin gates, but no end-to-end ticket creation, customer reply, staff response, email/Telegram delivery, retry or customer receipt test has been evidenced. Do not claim 24/7 support, guaranteed response or automated notifications until staffing, channels and monitored delivery are tested.

### P2 — Incident and dispute workflows are unproven
System incidents, disputes, investigations, decisions and appeals are all empty. Define severity, incident commander, customer impact assessment, status page/communications, regulatory notification decision, evidence preservation, root cause and post-incident review. Dispute decisions need impartial reviewer separation, transparent reasons, appeal routes and auditable deadlines.

### P2 — Customer data minimization and communication preferences
Notification preference rows are empty. Define required transactional notices separately from optional marketing/referral communications; capture channel-specific consent where required, honour opt-outs and quiet hours, and avoid leaking shipment, claim or identity data in Telegram/email previews. Keep delivery receipts, provider IDs and retry outcomes, but never interpret an API 2xx alone as end-user receipt.

## Required staging test matrix
1. A user cannot create/read/reply to another user's support ticket, including by changing ticket, organization or shipment IDs.
2. A customer can never read internal support messages or staff-only event metadata.
3. Admin ticket access/replies require AAL2 and current platform permission; access is denied after membership/permission revocation and token refresh.
4. Ticket creation, reply, internal note, status transition, SLA timestamps and audit events are atomic and idempotent.
5. Customer-visible email/in-app notification is emitted only after the committed ticket event; failed delivery retries safely and is visible to support staff.
6. Customer cannot submit a claim for another organization's shipment or an ineligible shipment state.
7. Multi-leg claim requires exact leg/assignment; no assignment or ambiguous assignment must not create false partner liability.
8. Claim evidence must belong to the claimant and exact claim path; MIME/size/storage metadata are verified; unauthorized users cannot download evidence.
9. Claim reviewer cannot be claimant, respondent or evidence submitter where independence is required; all decisions require reason and immutable events.
10. Refund approval is not shown as refund completion; only provider-confirmed and reconciled refund state is final.
11. Consent grant and withdrawal record exact policy version, actor, time, purpose and evidence; ordinary members cannot update/delete historical consent.
12. Marketing consent is separate from terms/privacy/data-processing acknowledgements and transactional service notifications.
13. Consent withdrawal stops future optional marketing sends while retaining legally required records and essential transactional messages under reviewed policy.
14. Incident severity and customer impact trigger appropriate internal escalation and verified customer communications.
15. Dispute parties can see only their own case material; internal investigation notes remain restricted; appeal decisions are independent and audited.

## Release decision
**Customer protection is not production-proven.** The database contains zero support cases, claims, disputes, consent records, refunds, notification deliveries or incidents. Core support and claim security patterns exist, but consent-table write access is too broad, consent invocation is not verified, and claim-to-leg attribution is ambiguous for multi-leg shipments.

Do not advertise guaranteed support, claims handling, dispute resolution, refunds or automated notifications as live services until staffed operational ownership, end-to-end channel delivery and the staging matrix pass.

Migration history remains materially divergent between repository and production. Do not change production RLS, grants, functions, triggers or consent data until the encrypted schema export manifest has been produced and reconciled. The next implementation priority is append-only consent integrity, followed by exact-leg claim attribution and a fully tested customer support/notification journey.
