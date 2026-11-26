# Phase 04.15 — Shipment Exception, Damage, Loss and Claims Audit

Date: 2026-11-26  
Scope: Read-only Production/Staging review of operational exceptions, claims, claim evidence, disputes, returns, RLS and Storage configuration. No incidents, claims, disputes, returns, uploads or status changes were created.

## Executive result

**FAIL — substantial schema and workflow components exist, but Staging does not have functional parity for customer claims and exception handling. Evidence upload policy is also not sufficiently isolated for claim documents. No runtime tests were performed.**

## Evidence inspected

- Tables: `krim_claims`, `krim_claim_events`, `krim_claim_evidence`, `krim_exceptions`, `krim_disputes`, `krim_dispute_cases`, `krim_dispute_decisions`, `krim_dispute_appeals`, `krim_dispute_evidence_links`, `krim_dispute_investigations`, `krim_shipment_returns`, return receipt and quality-review tables.
- Functions: `krim_report_operational_exception`, `krim_resolve_operational_exception`, `krim_claim_submit`, `krim_claim_add_evidence`, `krim_claim_review`, return request/respond/receive/review functions and exception escalation workers.
- RLS policies and flags on claim, dispute, exception and return tables.
- Private Storage bucket `krim-partner-verification` and object policies.
- Aggregate row counts: zero claims, zero operational exceptions, zero disputes and zero shipment returns in both inspected environments.

## Positive controls verified in definitions

1. Operational exception resolution requires authentication, `compliance.manage` permission scoped to the exception organization and a resolution note of at least five characters.
2. Exception resolution locks the exception row, rejects already-closed cases, resolves open escalations, cancels pending timers/actions and queued/running escalation orchestration, and writes an audit event.
3. Customer claim submission checks active customer membership and `shipment.update` permission, shipment/customer ownership, supported currency, claim type, amount bounds and description length.
4. Claim evidence registration checks claim state, claimant membership/permission, path structure, uploader ownership, MIME type and file size, and writes a claim event.
5. Claim review requires AAL2, platform administrator permission, a meaningful note, allowed decision values and approved amount not exceeding the claim amount. Review is row-locked and event-recorded.
6. Claim, evidence, event and dispute tables have RLS enabled; the three claim tables and dispute tables have FORCE ROW LEVEL SECURITY in both environments.
7. Claim and dispute read policies scope access to claimant/respondent organizations and authorized platform/operations reviewers.
8. Return workflows include idempotency keys, partner response, facility receipt and quality review structures.

## Findings

### F04.15-01 — Customer claims and exception RPC parity failure (CRITICAL)

Production exposes authenticated EXECUTE on the inspected customer-facing claim submission, evidence-registration and claim-review wrappers, and on operational exception report/resolve functions.

Staging denies authenticated EXECUTE on the claim submission/evidence/review wrappers and exception acknowledgement/return workflow functions. The targeted Staging function inventory did not surface the Production operational exception report/resolve functions. Several return workflow functions also deny authenticated execution in Staging.

This means the same customer/operations workflows are not callable with the same authenticated role in Staging. Do not bulk grant privileges: recover migration provenance, verify function bodies/callers and apply least-privilege changes only after security review.

### F04.15-02 — Claim evidence reuses partner-verification bucket (HIGH)

Claim files are stored in the shared private `krim-partner-verification` bucket under `claim-evidence/<claim>/<organization>/<user>/...`. Bucket policy is 10 MiB and allows PDF/JPEG/PNG. Claim-specific upload/read/admin-read/orphan-cleanup policies exist in Production.

This shares a bucket with partner, customs and other compliance evidence. Path-level policies are complex and need dedicated adversarial tests. A dedicated private claims-evidence bucket would reduce cross-domain policy coupling, but must be designed and migrated safely.

### F04.15-03 — Staging claim Storage policies are incomplete (HIGH)

Production has explicit claim-evidence Storage policies for scoped upload, party reads, platform-admin reads and orphan cleanup. The inspected Staging Storage policy set returned only general partner-verification policies and did not include these claim-specific policies. Staging claim upload/read parity is therefore not established.

### F04.15-04 — Claim submission is limited to confirmed or closed shipments (HIGH)

The claim submission function accepts only shipments whose current status is `confirmed` or `closed`. This may exclude claims for damage, shortage, theft or loss discovered while the shipment is still in transit, unless a separate incident/exception path is used and linked later. The business rule and statutory/contractual claim windows need validation. Do not silently widen the predicate without policy and legal review.

### F04.15-05 — Claim amount is a requested amount, not an enforceable liability or payout (HIGH)

The schema records claimed and approved amounts and a settlement status. The inspected claim review function records an administrative decision; it does not itself establish partner liability, insurance coverage, a binding settlement agreement or payment. A claim approval must not trigger a KRIM freight refund or partner payout. This is particularly important under KRIM's current partner-direct payment/referral model.

### F04.15-06 — Evidence verification and reviewer independence need stronger proof (MEDIUM)

Evidence registration creates evidence rows with `verification_status='pending'`, but the reviewed function excerpt did not prove a complete evidence-verification workflow, tamper-evident file hash, capture metadata, independent surveyor process or party rebuttal workflow. Claim review requires platform AAL2, but separation of duties between claim intake, evidence verification, investigation and final decision was not demonstrated.

### F04.15-07 — Dispute and appeal workflows are represented in schema, but full state transitions are not proven (HIGH)

Dispute cases, decisions, appeals, evidence links and investigations are present with party-scoped read policies. The full authorized write API, deadlines, independent adjudicator rules, appeal eligibility, conflict checks and final decision enforcement were not fully traced. Schema presence is not operational readiness.

### F04.15-08 — Return workflow requires facility/quality controls and parity (MEDIUM)

Return request/response/receipt/quality-review functions and idempotency structures exist in Production. Staging authenticated execution is denied for the inspected return functions. Runtime checks for facility authorization, returned item identity/quantity, custody, quarantine, quality decision and inventory reconciliation were not tested.

### F04.15-09 — No operational evidence or runtime coverage exists (HIGH)

Both environments returned zero rows for claims, exceptions, disputes and shipment returns. This is consistent with an unused/pre-launch workflow, but means there is no live sample evidence. No browser/API submissions, cross-tenant tests, evidence uploads, escalation timers, return receipts, concurrent retries or dispute appeals were executed.

## Required remediation / verification plan

1. Reconcile exact Production/Staging migration provenance for all claim, exception, dispute, return functions and Storage policies. Keep Production unchanged.
2. Restore only reviewed authenticated Staging RPC permissions and missing function/policy definitions after checking function source, auth, organization scope, AAL2, RLS and anon denial.
3. Consider a dedicated private claims-evidence bucket with scoped object paths, MIME/size limits, ownership checks, party reads, independent reviewer reads and orphan cleanup. Test object replacement/deletion and signed URL expiry.
4. Define incident reporting separately from customer compensation claims. Permit timely reports during transit, but keep claim submission/assessment subject to documented policy and legal review.
5. Add durable incident types: damage, shortage, loss, theft, tampering, delay, temperature excursion, refusal, failed delivery and safety incident. Capture event time, location, shipment/leg, custody holder, quantity/condition, evidence and immediate safety actions.
6. Establish claim timelines, evidence requirements, party response rights, independent surveyor review, decision/appeal workflow, conflict-of-interest checks and audit retention.
7. Separate claim approval from financial execution. Under current KRIM model, any customer-partner compensation is handled directly between contracting parties; KRIM must not hold freight funds or initiate freight settlement.
8. Test Staging: unauthorized reporters, wrong tenant/shipment, unrelated exception ID, forged storage path, wrong owner, MIME spoofing, oversized files, cross-party reads, admin AAL1, reviewer conflict, amount overclaim, duplicate claim, duplicate evidence, concurrent decisions, late claim, open-transit incident, return receipt mismatch and idempotent retries.
9. Add evidence-based monitoring for SLA escalation, missed response, claim aging, unresolved exceptions and repeat incidents.
10. Do not onboard real shipments until all critical Staging parity, security and runtime tests pass and CA/legal review validates the commercial claims/insurance terms.

## Status register

| Control | Status |
|---|---|
| Exception resolution auth/permission/row lock/audit | VERIFIED IN DEFINITION |
| Claim submit ownership/currency/type/amount validation | VERIFIED IN DEFINITION |
| Claim evidence ownership/path/MIME/size validation | VERIFIED IN DEFINITION |
| AAL2 platform claim review | VERIFIED IN DEFINITION |
| Claim/dispute RLS enabled and forced | VERIFIED |
| Production claim/exception RPC availability | VERIFIED |
| Staging claim/exception RPC parity | FAIL |
| Production claim-evidence Storage policies | VERIFIED |
| Staging claim-evidence Storage policies | FAIL / NOT PRESENT IN INSPECTED POLICY SET |
| In-transit claim/incident policy | NOT VERIFIED |
| Evidence integrity and independent survey process | NOT VERIFIED |
| Dispute/appeal state machine | NOT VERIFIED |
| Return runtime and custody controls | NOT TESTED |
| Runtime/cross-tenant/concurrency tests | NOT TESTED |

## Change control

Read-only audit only. No database writes, migrations, grants, bucket or policy changes, claim/exception/dispute/return records, evidence uploads, refunds, payouts, deployments or Production changes were made.
