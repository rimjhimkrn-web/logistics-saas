# KRIM Exceptions, Claims, Disputes and Service-Recovery Deep Audit

**Date:** 2026-11-16  
**Environment:** Production Supabase, read-only inspection  
**Decision:** **NO-GO for treating exception resolution, claims adjudication, dispute resolution or financial recovery as production-operational.**

## Scope and safety boundary

Reviewed operational exceptions and escalations, claims and evidence, dispute cases/decisions/appeals, recovery plans/checkpoints, relevant RLS policies, database function definitions, escalation policy records, and representative customer/operations/admin frontend pages.

No business RPC was invoked. No production rows, decisions, claims, refunds, notifications, schema, policies or storage objects were changed.

## Production evidence

| Record class | Current rows |
|---|---:|
| Operational exceptions | 0 |
| Exception actions | 0 |
| Exception timers | 0 |
| Exception escalations | 0 |
| Escalation policies | 3 |
| Exception signal events | 0 |
| Claims | 0 |
| Claim events | 0 |
| Claim evidence | 0 |
| Disputes | 0 |
| Dispute cases | 0 |
| Dispute investigations | 0 |
| Dispute decisions | 0 |
| Dispute appeals | 0 |
| Dispute evidence links | 0 |
| Recovery plans | 0 |
| Recovery checkpoints | 0 |

There is no live operational history proving that any of these journeys has been completed end-to-end. Three escalation policies are configured, but no exception has exercised them.

## Positive controls confirmed

1. Exception read access is organization-scoped; actions and escalation records are readable only through the parent exception's organization.
2. Exception acknowledgement and resolution require an authenticated user and `compliance.manage` permission in the exception's organization; both lock the relevant rows and write audit events.
3. Exception resolution requires a non-empty explanation, stops open escalation rows, cancels outstanding timers/actions, and cancels queued/running escalation orchestration.
4. Due-escalation processing uses row locking with `SKIP LOCKED`, a bounded batch size and policy matching; it creates escalation/audit records rather than claiming a notification was delivered.
5. Claim submission checks active customer organization membership, shipment-update permission, customer ownership of the shipment, eligible shipment status, supported currency, and any supplied exception's shipment linkage.
6. Claim evidence upload checks MIME type, 10 MB size limit, storage object owner and metadata, claim state, claimant organization membership and a claim-specific storage path.
7. Claim review requires AAL2, an active platform/operations organization with `admin.platform`, a meaningful note, valid decision state and approved amount no greater than the claim amount.
8. Claim and dispute tables inspected have RLS enabled and scoped SELECT policies. No direct authenticated INSERT/UPDATE/DELETE policies were present in the inspected policy set.
9. The operations exception page accurately labels its form as preparation-only and does not pretend that its reference form is an operational write.
10. The admin claim page explicitly says a claim decision does not create a payment or settlement.

## Findings

### P0 — Dispute case workflow has no verified production write/API journey

**Evidence:** the production schema contains `krim_disputes`, `krim_dispute_cases`, `krim_dispute_investigations`, `krim_dispute_decisions`, `krim_dispute_appeals` and `krim_dispute_evidence_links`. The inspected public and private function inventory contains no dispute-case creation, investigation, decision, evidence-link, appeal or transition RPC. The customer dispute pages and finance dispute-management page do not contain a connected Supabase RPC/data workflow in the inspected source.

**Impact:** the existence of tables and pages does not establish an operational dispute-resolution process. With RLS and no direct write policies, the reviewed evidence does not show a supported authenticated write path for these dispute records.

**Required remediation:** define a complete dispute lifecycle before advertising it as available: create from an authorized customer/partner claim or shipment, bind claimant/respondent and shipment/assignment, accept evidence, independently investigate, issue reasoned decision, allow time-bounded appeal by eligible party, record independent appeal outcome, and close only after required obligations are fulfilled. Implement permission-checked transactional RPCs with audit events and staging tests. Keep the feature labelled unavailable/preparation-only until then.

### P1 — Claim approval can proceed without verified evidence

**Evidence:** `krim_claim_review` allows platform AAL2 reviewers to choose `approved` or `partially_approved` based on claim status, amount and review note. It does not require any claim evidence rows, nor does it check that evidence is verified, that required evidence types exist, or that unresolved evidence review is complete. The inspected function inventory exposes claim evidence addition but no separate claim-evidence verification RPC.

**Impact:** a claim can be approved without supporting evidence or independent evidence verification, even where the claim is for cargo loss/damage. The evidence table has verification fields, but the review decision does not consume them as a gate.

**Required remediation:** define evidence requirements by claim type and amount/risk. Require all mandatory evidence to be present, private-object verified, and independently reviewed before approval. Record verifier identity/time and immutable object hash. Permit a documented exception/waiver only with a separate elevated approval and reason. Ensure reviewer cannot approve their own evidence or claim submission.

### P1 — Claim submission permits zero-value claims

**Evidence:** `krim_claim_submit` rejects NULL, negative and extremely large amounts, but accepts `p_claimed_amount=0`.

**Impact:** zero-value financial claims can enter the claims queue and consume investigation resources or distort claim metrics. Some non-financial service complaints may legitimately have no monetary amount, but those should be modelled separately from monetary compensation requests.

**Required remediation:** require a positive amount for financial loss/damage/shortage/billing claims. If service-only complaints are intended to have no amount, distinguish them explicitly and require a zero-value non-financial claim type with separate outcome semantics.

### P1 — Claim submission can create a claim without a responsible partner/assignment

**Evidence:** claim submission selects the most recent accepted/completed shipment partner assignment, but does not require one to exist. If no matching assignment exists, `respondent_organization_id`, `responsible_partner_organization_id` and `assignment_id` may be NULL.

**Impact:** a claim can be accepted into the process without a respondent or responsible execution party. This weakens notice, evidence collection, responsibility determination and dispute handling.

**Required remediation:** require a valid shipment leg/assignment respondent for partner-liability claims. For claims against KRIM or for partner-independent service issues, model a distinct respondent category and assign an accountable case owner. Do not silently create unassigned liability claims.

### P1 — Supplied exception linkage checks shipment but not claimant/tenant relationship

**Evidence:** `krim_claim_submit` verifies that a supplied exception belongs to the shipment, but does not additionally assert that the exception's `organization_id` is the claimant organization or a permitted shipment participant, nor that the exception's partner/assignment linkage matches the claim respondent.

**Impact:** a customer who can claim against its shipment may reference an exception raised under another organization's scope. The foreign exception's description and signal context could then become attached to the claim, creating attribution and cross-tenant data-integrity ambiguity.

**Required remediation:** verify exception organization is the claimant or an explicitly authorized shipment participant; verify exact shipment leg, assignment and responsible partner consistency. Persist the validated relationship as a foreign-key-backed case linkage and expose only party-authorized details.

### P1 — Claim evidence uses the partner-verification storage bucket

**Evidence:** the claim evidence RPC validates storage objects in bucket `krim-partner-verification`, with a claim-specific object path. The admin claim page creates signed URLs from that same bucket.

**Impact:** partner verification and cargo-claim evidence have different data classification, retention, access and lifecycle needs. Sharing a bucket can create policy coupling and accidental cross-purpose access. The inspected database check proves owner/path/metadata, but not a dedicated claim evidence retention or legal hold lifecycle.

**Required remediation:** move claim evidence to a dedicated private bucket with explicit per-claim organization and party access policies, upload size/MIME constraints, immutable hash, malware scanning, retention/legal-hold policy and audited signed-URL access. Do not migrate existing objects until a tested access/retention plan exists.

### P1 — Claim review is not tied to independent evidence reviewer or case investigator

**Evidence:** the claim review RPC checks the claim state and AAL2 platform-admin permission and records `reviewed_by`, but it does not compare the reviewer with `submitted_by` on evidence rows, an investigator identity, or a prior evidence-verification actor.

**Impact:** the current design does not prove separation of duties between evidence submission, evidence verification, investigation and final adjudication. AAL2 and platform-admin permission alone are not independence controls.

**Required remediation:** introduce explicit investigator and evidence-verifier roles, enforce separation of duties for high-value/high-severity claims, and require an independent final reviewer. Record conflict-of-interest declaration and decision rationale.

### P1 — Claim approval is not the same as a payable or settled recovery

**Evidence:** claim review updates claim decision and approved amount and appends an event. The admin UI correctly says no payment or settlement is created. The schema includes `settlement_status`, but the reviewed claim-review path does not initiate or reconcile settlement. A separate Razorpay refund execution path is bound to payment orders and finance approval; it is not evidence that a carrier liability claim has been funded or paid.

**Impact:** customers or operations staff may interpret `approved` as money returned or compensation received. Partner-direct freight payments are outside KRIM's custody model, and KRIM must not imply it can refund freight funds it never received.

**Required remediation:** separate claim decision, liable party acknowledgement, settlement offer, payer commitment, payment instruction, provider confirmation and beneficiary receipt. For partner-direct freight, settlement must be between the responsible carrier and claimant unless a separately lawful, documented KRIM fee refund is involved. Never create a KRIM ledger entry for partner freight compensation that KRIM did not collect or pay.

### P1 — Exception resolution does not enforce evidence-required or action-completion gates

**Evidence:** `krim_resolve_operational_exception` requires a resolution explanation and `compliance.manage` permission, but does not inspect `evidence_required`, attached evidence, exception actions, shipment state, responsible partner acknowledgement or corrective-action completion before setting status to `resolved`. It cancels pending/in-progress actions and timers when resolving.

**Impact:** an exception marked as requiring evidence can be resolved without evidence, and unresolved corrective actions may be cancelled as a side effect of the resolution. This risks closing a case administratively while the underlying operational failure remains unverified.

**Required remediation:** distinguish operational mitigation, corrective action, root-cause determination and final closure. When evidence is required, require verified evidence and all mandatory actions completed or explicitly waived by an independent authorized reviewer. Never silently cancel unresolved actions on final closure; require an explicit cancellation reason and preserve them as terminal records.

### P1 — Escalation acknowledgement can be performed without a meaningful note

**Evidence:** `krim_acknowledge_exception_escalation` accepts `p_note` as optional; a null/blank note leaves the prior reason unchanged. It sets the acknowledging user as `escalated_to`, overwriting any prior intended recipient.

**Impact:** acknowledgement may not document what was accepted or the next response commitment. Overwriting `escalated_to` also conflates target recipient and actual acknowledging actor.

**Required remediation:** preserve the intended escalation recipient in its own field and record the acknowledging actor separately. Require a concise acknowledgement note or structured response commitment, with an immutable event record.

### P2 — Exception escalation policy records are not enough to prove timer/notification operation

**Evidence:** three active policy rows exist, but there are zero exception timers, escalation runs/events and escalations. The escalation worker creates escalation rows with metadata `notification_status='disabled_until_verified'`; no successful delivery is established by this workflow.

**Impact:** a policy configuration does not prove due-time processing, reliable scheduler execution, notification delivery or escalation recovery. Do not claim automated 24/7 incident response.

**Required remediation:** add staging tests for policy precedence, time zones, daylight-saving transitions, overlapping policies, due-time concurrency, retries, worker lease recovery, duplicate suppression and notification delivery receipts. Expose distinct states for queued, provider-accepted, delivered, acknowledged and resolved.

### P2 — Recovery plans/checkpoints have no live operational evidence

**Evidence:** both recovery plan and checkpoint tables have zero rows. The reviewed exception/claim/dispute journeys do not establish a recovery checkpoint tied to a real service incident or claim.

**Impact:** no evidence of tested service-recovery coordination, owner, RTO/RPO achievement or customer recovery updates.

**Required remediation:** define recovery plans for critical logistics services and incident classes, with accountable owner, measurable target, tested runbook, checkpoints, evidence and post-incident review. Do not describe an untested plan as an achieved recovery capability.

## Required staging-only verification suite

1. Claim submission from wrong customer organization, inactive membership or unauthorized user is rejected.
2. Claim for an unconfirmed/unowned shipment is rejected.
3. Claim exception linkage from another organization/assignment/leg is rejected.
4. Zero amount is rejected for monetary claims; explicit non-financial complaints remain separately classified.
5. Claim with no responsible partner is rejected or routed to a distinct KRIM/service complaint workflow.
6. Claim evidence wrong bucket, owner, path, MIME, size, hash, claim ID or tenant is rejected.
7. Evidence cannot be replaced after verification without a new immutable version and re-review.
8. Claim approval with no required evidence, pending evidence or self-reviewed evidence is rejected.
9. Claim reviewer cannot be claimant, evidence submitter or investigator where separation is required.
10. Duplicate claim submission with same idempotency key returns same case; conflicting payload is rejected.
11. Claim approval does not create a payment, refund or settlement.
12. Partner-direct compensation is not recorded as KRIM freight revenue or KRIM payout.
13. Exception requiring evidence cannot be resolved without verified evidence or approved waiver.
14. Exception with incomplete mandatory actions cannot be finally closed.
15. Escalation acknowledgement records actor separately from intended recipient and requires a response note.
16. Escalation scheduler concurrency/retry produces one escalation per policy level.
17. Dispute creation binds shipment, claim, parties and assignment; unrelated organizations cannot read or append evidence.
18. Investigation and decision actors are independent where required; decision requires verified evidence and reason.
19. Appeal is time-bounded, submitted by eligible party, and decided by independent reviewer.
20. Dispute close requires all decision obligations/settlement conditions fulfilled.
21. Tenant isolation, revoked membership, AAL1/AAL2 and permission revocation are tested across every RPC and evidence link.

## Remediation order

1. **P0:** implement and test the missing dispute write/lifecycle path before exposing dispute pages as functional.
2. **P1:** require verified evidence and separation of duties for claim approval.
3. **P1:** enforce respondent/assignment and exact tenant/exception linkage on claim submission.
4. **P1:** separate claim approval from liability acceptance, payer commitment and actual settlement.
5. **P1:** gate exception closure on evidence and corrective-action completion.
6. **P1:** separate escalation target from acknowledging actor and require acknowledgement context.
7. **P1:** create dedicated private claim-evidence storage lifecycle.
8. **P2:** prove scheduler, recovery checkpoints and notification delivery through staging tests.
9. Run complete staging end-to-end and tenant-isolation suite before any commercial claims/claims SLA are advertised.

## Release boundary

This audit is read-only. No production DDL or RPC remediation was applied. The production/repository migration-history mismatch and pending sanitized schema manifest remain blockers for production function changes. No claims, disputes, refunds, settlements, exception actions or customer communications were created.

## Overall decision

**NO-GO for production claims adjudication, dispute resolution, or evidence-dependent exception closure.** Exception acknowledgement/resolution and claims submission/review have meaningful permission and audit controls, but exception closure can bypass evidence/action completion, claim review can approve without verified evidence, and no dispute write lifecycle was identified. All live case/evidence/recovery counts are zero, so there is no operational proof of end-to-end recovery.
