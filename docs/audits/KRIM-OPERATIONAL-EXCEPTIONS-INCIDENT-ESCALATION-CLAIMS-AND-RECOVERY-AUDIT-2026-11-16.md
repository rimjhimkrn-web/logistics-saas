# KRIM Operational Exceptions, Delays, Incident Escalation, Claims and Recovery Audit
**Date:** 16 November 2026  
**Scope:** Read-only review of production exception, timer, escalation, signal bridge, incident and claims tables; exception escalation policies; selected RPC/helper definitions; and prior notification/operations assurance findings. No exception, timer, escalation, incident, claim or evidence record was created or changed. No escalation worker, notification, customer contact or financial action was invoked.

## Executive decision
**NO-GO for operational incident-response and claims-resolution certification.** KRIM has a useful exception lifecycle foundation: severity-based escalation policies, signal bridge records, acknowledgment and resolution routines, audit events, timer/action cancellation on resolution, and a customer claim evidence/review workflow. But there are zero live operational exceptions, timers, escalations, incident records or claims. The three active policies create only a single escalation level and explicitly disable external notifications until verified. No customer or partner notification delivery, incident command process, recovery verification or claim settlement has been demonstrated.

## 1. Production baseline
Exact read-only row counts at the audit snapshot:

| Record | Rows |
|---|---:|
| Operational exceptions | 0 |
| Exception actions | 0 |
| Exception timers | 0 |
| Escalation policies | 3 |
| Escalations | 0 |
| Escalation runs | 0 |
| Escalation run events | 0 |
| Exception signal bridges | 0 |
| Exception signal events | 0 |
| System incidents | 0 |
| Claims | 0 |
| Claim events | 0 |
| Claim evidence | 0 |

The exception engine is configured but has never demonstrated a production case journey. The policy rows are active:
- Critical: immediate response/escalation (0 minutes), one level.
- High: 15-minute response, 30-minute escalation, one level.
- Medium: 240-minute response, 480-minute escalation, one level.
All three define platform-founder ownership and external_notifications=disabled_until_verified. No active low-severity policy was found in the three-row baseline.

## 2. Exception detection, signal bridge and assignment
### Positive controls
- Operational exception records carry shipment, leg, assignment, responsible partner, severity, status, root-cause, evidence-required and financial-impact fields.
- A trigger bridges operational exception insert/update into a signal bridge using a deterministic operational-exception:<id> deduplication key and records a snapshot of the source exception.
- Signal bridge events provide a separate status/event history.
- Exception acknowledgment locks the exception/escalation rows, checks authenticated identity and compliance.manage for the exception organization, rejects closed exceptions, assigns the current user if unassigned and writes an audit event.
- Resolution requires a non-empty reason of at least five characters, locks the exception, checks permission, updates status and audit history, resolves open escalations, cancels pending/triggered timers and pending/in-progress actions, and cancels queued/running/waiting escalation orchestration runs with a terminal event.
- Earlier control-tower audit found no live exception/timer/escalation/signal records; operations dashboard may show partial datasets and must surface partial status clearly.

### Findings
1. **P1 — No operational exception evidence:** all exception and signal tables are empty. Detection, assignment, acknowledgment, recovery and closure have not been proven on a real or staging shipment.
2. **P1 — Assignment/ownership model needs end-to-end proof:** the exception row supports a responsible partner and assigned user, but this review did not establish an enforced cross-tenant responsibility matrix for customer, carrier, warehouse, driver, customs broker and KRIM operations. Each exception must identify the accountable party, coordinating owner, response deadline and escalation contact without granting that party access to unrelated shipment data.
3. **P1 — Detection coverage is unproven:** no test evidence shows that missed pickup/delivery windows, milestone silence, route deviation, temperature/condition breach, inventory shortage, customs hold, capacity cancellation, POD dispute or provider outage reliably create a deduplicated exception. Signal-bridge schema alone is not a sensor or detector.
4. **P2 — Financial impact is not a liability decision:** exception financial-impact fields must not be treated as an approved charge, claim, refund or accounting entry. Finance remains deferred.

## 3. Escalation policies, scheduler and external notification
### Positive controls
- Three active severity policies exist with bounded escalation timing and a configured founder owner/action.
- The due-escalation function validates batch size (1–500), locks eligible exceptions with FOR UPDATE SKIP LOCKED, applies the selected active policy, avoids creating a second level-one escalation already open/acknowledged/resolved, inserts a durable escalation and writes an audit event.
- Acknowledgment is permission-checked and recorded; resolution closes associated escalations.

### Findings
1. **P1 — Only one escalation level is implemented in the reviewed processor:** although policy rows include max_escalation_level, the processor creates level 1 only. It does not advance unacknowledged level 1 to level 2 or later. The current three policies are configured with max level 1, but the schema/definition suggests broader levels than the live processor provides. Do not advertise multi-tier escalation.
2. **P1 — Escalation is not notification:** policy metadata explicitly sets external notifications to disabled_until_verified. The processor creates escalation rows and audit events; it does not send customer, carrier, driver, broker or founder messages. Prior notification audit found no outbox/delivery evidence and known retry/lease/race issues. A created escalation is not proof anyone received or acknowledged an alert.
3. **P1 — Response SLA versus escalation timer:** the processor shown selects by detected_at + escalation_minutes; it does not visibly enforce response_minutes as a separate acknowledgment deadline. Critical has both zero; high/medium have separate response and escalation values. Implement/test distinct response-breach and escalation-breach semantics.
4. **P1 — No end-to-end scheduler evidence:** the function is not callable by authenticated users, which is appropriate for a worker, but this audit did not verify a successful scheduled execution that creates an escalation from a due exception, nor recovery after worker failure. Verify cron ownership, last successful run, backlog age and retry semantics in a controlled test.
5. **P2 — Policy governance:** policy edits should be maker-checker controlled, versioned and effective-dated, with timezone/SLA clock rules, business-hours exceptions where appropriate, severity override audit and tested fallback when no policy matches.

## 4. Exception resolution and recovery
### Positive controls
- Resolution requires a meaningful note and current permission.
- Parent resolution stops active timers, actions and orchestration runs to prevent stale work continuing after closure.
- The trigger maps resolved/closed/cancelled source states to corresponding signal-bridge status.
- Audit records include prior and new state for the resolution action.

### Findings
1. **P1 — Resolution does not prove service recovery:** the routine accepts a textual resolution reason and closes linked timers/actions/runs. It does not itself require independent proof that service is restored, the shipment has a safe revised plan, customer/partner were informed, or downstream milestones resumed. High/critical exceptions need evidence-backed recovery verification and, where appropriate, a second authorized reviewer.
2. **P1 — No formal incident command lifecycle:** krim_system_incidents has zero records. The schema supports severity, service, summary, root cause and resolution, but no incident response journey was evidenced that binds incident commander, timeline, affected shipments/tenants, status page, communications, recovery test and post-incident review.
3. **P1 — Cancellation is not resolution:** a cancelled action/timer/run due to parent exception resolution is an orchestration stop, not proof the underlying customer/partner task was completed. UI must distinguish cancelled work from successfully completed recovery actions.
4. **P2 — Root-cause and learning loop:** require cause category, contributing factors, corrective/preventive action owner, due date, effectiveness verification and linked repeat-incident detection.

## 5. Customer claims and evidence
### Positive controls
- Claim submission requires authenticated active customer/shipper/enterprise organization membership, shipment.update, a confirmed/closed shipment owned by that organization, supported claim type, active currency, bounded amount and meaningful description.
- Claim submission links the most recent accepted/completed partner assignment and optional shipment exception; it records a claim number and immutable submission event.
- Evidence submission checks claim state, customer membership/permission, allowed evidence type, PDF/JPEG/PNG MIME, 1–10 MB size, user/org/claim-scoped object path, storage object uploader ownership and matching MIME/size metadata; it records a pending evidence row and claim event.
- Claim review requires AAL2, a platform/operations organization, admin.platform, meaningful reviewer note, valid decision and approved amount not exceeding the claimed amount; review changes are recorded as claim events.

### Findings
1. **P1 — No claims journey tested:** claims, events and evidence are all zero. No notice, respondent response, investigation, evidence challenge, decision appeal or resolution has been exercised.
2. **P1 — Reviewer independence is not explicit in inspected review function:** it checks AAL2 and platform permission, but does not visibly compare reviewer identity against claim submitter/claimant actor or require a second reviewer for high-value/sensitive claims. Add and test independent review/maker-checker governance.
3. **P1 — Evidence storage bucket purpose and lifecycle:** claim evidence is checked in the private krim-partner-verification bucket. This is private and owner-checked, but reusing a partner-verification bucket for claim evidence creates retention, access, classification and deletion-policy ambiguity. Confirm bucket policies and signed URL authorization, and consider a dedicated claims-evidence bucket only after migration reconciliation.
4. **P1 — Claim review is not payment/settlement:** approved or partially approved claim amount is a decision record, not a refund, partner debit, insurer recovery or payout. Financial execution is explicitly deferred and refund functions remain disabled.
5. **P2 — Respondent workflow:** the inspected customer claim submission stores respondent/responsible partner, but no complete partner response, negotiation, mediation, insurer/legal referral or appeal lifecycle was evidenced. Define response rights and deadlines and protect both parties' private evidence.
6. **P2 — Claim submission timing:** the function accepts claims against confirmed or closed shipments but no claim-notice window or contract-specific limitation period is visible in the reviewed definition. This needs legal/contract review, not an arbitrary technical cutoff.

## 6. Required staging-only acceptance tests
1. Create synthetic critical/high/medium/low exceptions from each supported detector; prove dedupe and exact shipment/leg/partner ownership.
2. Wrong tenant, revoked membership, wrong org type, insufficient permission and forged assignment must be rejected.
3. Response deadline and escalation deadline must trigger independently and correctly.
4. Critical escalation must be created immediately, then verified notification should reach the configured responsible owner; no delivered state without provider evidence.
5. Unacknowledged escalation should advance only through explicitly configured levels; acknowledgment should stop further escalation.
6. Worker crash, retry, duplicate scheduler run and concurrent processors must not lose or duplicate escalations; prove lease/reclaim.
7. Parent resolution must cancel outstanding timers/actions/runs, while preserving completed work and its audit evidence.
8. High/critical resolution must require required recovery evidence and independent approval.
9. System incident must link affected services/shipments, incident commander, event timeline, status communications and post-incident review.
10. Customer claim against wrong tenant/shipment/assignment/exception must be rejected.
11. Claim evidence wrong bucket, wrong owner/path, mismatched MIME/size, revoked uploader and cross-tenant access must be rejected.
12. Claim reviewer must be independent; self-review, stale claim, over-claimed amount, invalid currency and repeated decision must be rejected.
13. Approved claim must not cause refund, partner settlement or ledger posting until separate finance approval and controlled final-phase tests.
14. Full recovery journey: detect → acknowledge → assign → mitigate → communicate → verify recovery → close → root-cause review → corrective action.

None of these staging tests was executed in this audit.

## 7. Remediation order
1. Establish detector coverage and durable idempotent exception creation from actual shipment/warehouse/customs/tracking signals.
2. Separate response SLA from escalation SLA; implement configured escalation levels and worker recovery.
3. Keep external notifications disabled until provider source parity, consent, retry/lease and delivery semantics are verified.
4. Require evidence-backed independent recovery approval for high/critical exceptions.
5. Establish formal incident command and post-incident review.
6. Enforce independent claim review and complete respondent/appeal workflow; clarify claim evidence storage governance.
7. Keep claim approval separate from refunds, partner liability accounting and payouts; finance remains final phase.
8. No production schema/function/policy changes until the production/repository migration-history reconciliation is complete.

## 8. Change control and release decision
Read-only audit only. No RPC, scheduler, worker, notification or claim action was invoked. No customer/partner contact, financial operation or production data/schema change occurred.

The migration-history mismatch and sanitized schema-manifest gate remain unresolved. No migration replay or corrective production DDL is authorized.

**Release status: NO-GO for operational exception, incident-response, customer notification and claims-resolution certification.** The database has useful workflow foundations, but no live cases, one-level-only escalation, disabled external notifications, no verified recovery evidence and no exercised claims lifecycle.
