# KRIM Claims, Disputes and Exception Closure Integrity Follow-up
Date: 2026-11-16

## Executive result

**NO-GO for production claims/dispute handling or exception closure as a complete customer remedy workflow.** Read-only production inspection confirms the earlier claims/disputes audit findings and identifies a further closure-control gap.

### Confirmed P0/P1 findings

1. **P1 — zero-value claims are accepted.** `private.krim_claim_submit` rejects null/negative amounts but accepts `0`; the table constraint also permits `claimed_amount >= 0`. A zero-value claim can be submitted and enters `submitted`.
2. **P1 — claim submission can proceed without a responsible partner assignment.** The function selects the latest accepted/completed partner assignment, but does not require one to exist. It inserts nullable partner/respondent and assignment references when none is found. This can create a claim with no accountable logistics respondent.
3. **P1 — claim review can approve without verified evidence.** The review function checks AAL2, platform-admin permission, reviewer note length and amount bounds, but does not require any evidence row, a verified evidence state, or a verifier independent from the submitter. Evidence added by the claimant is marked `pending`; no claim-evidence verification RPC was found in the inspected public/private function inventory.
4. **P1 — exception resolution cancels unresolved corrective actions.** `krim_resolve_operational_exception` changes all pending/in-progress exception actions to `cancelled` and stops pending/triggered timers and queued/running escalation runs. It does not require actions to be completed, failed with a documented disposition, independently waived, or evidenced before the exception is marked resolved. This can close the parent incident while corrective work remains outstanding.
5. **P1 — no operative dispute-case lifecycle was found.** `krim_dispute_cases` has party-scoped read access and a unique dispute number, but the inspected live public/private routines expose no dispute creation, evidence, investigation, decision, appeal or state-transition lifecycle. The table was empty at audit time.

## Production evidence

### Claim submission
- Requires authenticated active customer/shipper/enterprise organization membership and `shipment.update`.
- Shipment must belong to the customer organization and be confirmed or closed.
- Optional exception ID is checked against the shipment.
- Currency must be active.
- Claimed amount check is `>= 0`, not `> 0`.
- Partner assignment lookup is optional and has no failure branch if no assignment is found.
- New claim records preserve claimant/respondent/assignment fields, but the respondent and assignment can be NULL.

### Claim evidence
- Evidence is limited to PDF/JPEG/PNG, maximum 10 MB.
- Storage path is scoped to claim ID, organization and uploader.
- Object must exist in the private `krim-partner-verification` bucket and match owner, MIME and size metadata.
- Evidence is inserted with `verification_status='pending'`.
- The reviewed function inventory did not identify a claim evidence verification/rejection routine or a separate evidence-verifier authorization workflow.
- Evidence table read policy scopes access to claimant/respondent organizations and platform/operations administrators.

### Claim review
- Requires AAL2, platform/operations organization and `admin.platform`.
- Requires a review note of at least 10 characters.
- Approved amount must be positive and not exceed claimed amount.
- Does not query `krim_claim_evidence` before approving or partially approving.
- Does not enforce reviewer separation from the claimant or evidence submitter.
- No appeal transition or independent appeal review routine was found.

### Exception resolution
- Requires authentication, `compliance.manage` for the exception organization and a resolution string of at least five characters.
- Marks the exception resolved and resolves open/acknowledged escalations.
- Cancels pending/triggered timers, pending/in-progress actions, and queued/running/waiting escalation runs.
- The resolution RPC does not require evidence or a per-action disposition before cancelling outstanding work.
- Exception escalation acknowledgement still permits an empty note and overwrites `escalated_to` with the acknowledging user; this previously identified P1 remains.

### Dispute and live data state
At audit time, production contained:
- Claims: 0
- Claim evidence: 0
- Claim events: 0
- Operational exceptions: 0
- Exception actions: 0
- Dispute cases: 0

Zero records means there is no real-case execution evidence; it does not prove the workflows work.

## Required remediation — not applied

1. Require a strictly positive claim amount in both RPC and database constraint; define currency precision and permitted claim caps.
2. Require a valid responsible partner assignment and respondent organization, or implement an explicit no-assignment resolution path that routes to platform review without silently creating an unowned claim.
3. Add independent evidence verification with immutable verifier identity, timestamp, decision, reason, object integrity/hash and storage ownership checks. Require a defined evidence threshold before approval; explicitly document any permitted evidence-waiver exception.
4. Enforce reviewer separation from claimant, respondent, submitter and evidence verifier; preserve AAL2 and audit every transition.
5. Add claim appeal/reopen workflow with independent reviewer and bounded deadlines.
6. Implement dispute-case creation, evidence, investigation, decision, appeal and closure lifecycle with party-scoped access and independent authority.
7. Change exception resolution so open corrective actions cannot silently be cancelled. Require each action to be completed, failed with evidence and owner, or separately waived by an authorized independent reviewer. Preserve timer/escalation history and record a resolution package.
8. Add staging tests for zero amount, missing assignment, wrong shipment/exception, forged respondent, pending/unverified evidence approval, reviewer conflicts, missing evidence object, duplicate submissions, appeal after closure, and exception closure with outstanding actions.
9. Reconcile migration history before any production DDL or policy/function change.

## Release impact

**NO-GO for customer claims, dispute resolution, and final exception closure as a production-grade remedy process.** The current code has useful tenant checks, private evidence upload controls, AAL2 claim review and audit events, but those controls do not yet form a complete independently evidenced resolution lifecycle.

## Evidence boundaries

Read-only inspection of live function definitions, table constraints, RLS policies and aggregate row counts. No claim, evidence, dispute or exception record was created or modified; no workflow RPC was executed; no schema, storage object or policy was changed.
