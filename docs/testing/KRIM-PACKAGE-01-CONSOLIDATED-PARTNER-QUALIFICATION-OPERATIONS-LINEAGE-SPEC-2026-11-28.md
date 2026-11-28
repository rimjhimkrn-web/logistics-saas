# KRIM Package 1 — Consolidated Partner Qualification and Operations Lineage Correction Specification
Date: 2026-11-28
Branch: staging/phase00-env-isolation
Status: implementation-ready design; NOT implemented or approved for deployment
Scope: partner onboarding, capability review, network qualification, matching, opportunities, quotes, assignments, capacity, revocation and driver execution.

## 1. Executive decision
The defects are not independent UI issues. They form one lifecycle integrity problem: KRIM cannot reliably prove which submitted and approved partner capability/evidence version qualified a partner for a specific shipment/leg, and later workflow stages re-query current organisation capabilities instead of consuming one immutable decision.

Implement as a coordinated database/API correction only after migration provenance is reconciled and a disposable Supabase CLI test environment passes. Do not patch individual frontend screens or apply direct DDL as a shortcut.

## 2. Required end-to-end invariants
I1. Re-submitting unchanged or amended onboarding must never silently downgrade an already verified organisation or an unrelated approved capability.
I2. Every category/service declaration has an immutable submission version, submitter, idempotency key, submitted details and evidence manifest.
I3. Only an independently authorised AAL2 reviewer may approve/reject a specific immutable submission version; approval activates only the exact reviewed version.
I4. One canonical, versioned eligibility policy serves both network pre-qualification and actual matching.
I5. Every positive eligibility result identifies the exact capability submission/version, evidence digest, service-area/route, capacity availability/resource and evaluated service-time window.
I6. A positive decision is immutable and scoped to partner, shipment, shipment leg, service, route, requested service time and policy version.
I7. Match result, opportunity, quote version, awarded partner assignment and shipment/leg execution retain the same eligibility_decision_id. New qualification requires a new decision, never mutation of old evidence.
I8. Quote amendments create append-only quote versions; current quote projection may change but historical amount, currency, validity and eligibility link remain auditable.
I9. Quote acceptance and assignment finalization validate the referenced decision and current safety state; they must not substitute an unrelated currently-active capability from the same organisation.
I10. Revocation blocks new eligibility, quote, award and allocation using the revoked version, while preserving accepted/in-progress work and creating durable operations exceptions.
I11. Capacity reservations and commitments remain balanced through review, continuation, release, completion or reassignment; never delete rows or zero counters to hide impact.
I12. Driver assignments retain exact partner assignment, shipment and leg linkage; driver acceptance remains subject to current driver, licence, vehicle and document checks.
I13. Legacy records lacking lineage remain explicitly legacy/unattributed. Never infer historic capability from today's mutable organisation profile.
I14. Every state transition is tenant-scoped, permission-checked, idempotent where retryable, audited and concurrency-safe.

## 3. Target data model (logical design; names provisional)
A. capability submission history (append-only): capability_id, organization_id, submission_version, submitted_by, submitted_at, request_key, submission_details, evidence_paths/manifest_digest, status, reviewer_id, reviewed_at, review_reason, policy/review metadata. Unique capability/version and scoped idempotency keys. Evidence paths validated against private bucket, exact org/user/capability ownership and allowed content types.
B. immutable eligibility decision: decision_id, partner organization, capability_id, capability_submission_id/version, evidence digest, reviewer approval reference, service type/mode, service-area/route IDs and versions, capacity resource/availability IDs and versions, origin/destination and shipment/leg IDs, requested service timestamp, weight/units, policy_version, decision/result/reasons, evaluated_at.
C. append-only quote version: quote_id, version, opportunity, partner, eligibility_decision_id, amount/currency, validity, pricing snapshot, submitter/time and supersession relationship.
D. lineage references: eligibility_decision_id on match result, opportunity, quote/current projection and quote-version, partner assignment, capacity/assignment binding where relevant, driver assignment or execution context. Use restrictive foreign keys and composite constraints/trigger validation for same tenant/partner/shipment/leg; avoid loose references that permit cross-tenant or cross-leg linkage.
E. revocation impact/operations exception: capability/version, affected entity type/id, shipment/leg/assignment, severity, state, reason, created/resolved by/time, resolution evidence and audit history. One idempotent exception per affected work item/revocation.
F. transition audit: append-only capability submitted/amended/reviewed/approved/rejected/suspended/revoked/retired and decision/quote/assignment lineage events.

Final table and column names must be reconciled with actual Staging schema, naming conventions, RLS and existing RPC signatures before migration authoring.

## 4. Required transaction flows
### 4.1 Onboarding and amendment
- New declaration creates a draft/pending capability plus immutable submission version and evidence manifest.
- Idempotency key prevents duplicate submissions.
- Unchanged resubmission returns existing state without downgrade.
- Material amendment creates a new pending version; prior approved version remains historical and operational status follows explicit policy (do not silently reactivate or downgrade).
- Verified organisation profile is not reset by a category-level amendment. Organisation-level compliance changes use a separate reviewed transition.
- Review is bound to exact version; reviewer cannot equal submitter; reviewer AAL2 and active admin permission rechecked inside transaction.
- Approval activates exact version only after evidence ownership, expiry, country/mode and compliance checks.

### 4.2 Shared qualification and matching
- Canonical policy evaluates the shipment's requested service timestamp, not now(), and exact leg mode, route, origin/destination, weight and capacity unit.
- It returns structured eligible/ineligible reasons and exact source row/version references.
- NULL max weight, country-only coverage, location/route coverage, inactive service area, expired evidence, stale capability, reserved capacity and boundary-time cases fail/qualify consistently in both network status and matching.
- Network availability is true only if at least one candidate passes the exact downstream policy for the same request snapshot.
- Persist immutable decision before creating a positive match result/opportunity.

### 4.3 Quote, award, acceptance and assignment
- Partner quote submission references the opportunity's eligibility decision and validates exact partner/shipment/leg match.
- Every quote amendment appends a version; no in-place history loss.
- Award and customer acceptance lock and validate decision, capability version, partner, shipment/leg and current safety state.
- Assignment finalization validates both capability decision and existing capacity reservation/commitment/shipment-leg invariants.
- Lock order must be documented and consistent across revocation, quote award, acceptance and finalization to prevent races.

### 4.4 Revocation and operations impact
- Revoke exact capability/version with reason and audit.
- Immediately block new matches/quotes/awards/allocations that depend on it.
- Enumerate open opportunities and quotes for withdrawal/re-evaluation.
- Enumerate accepted assignments, capacity holds/commitments, driver assignments and shipments.
- Create idempotent durable operations exceptions; preserve accepted/in-progress/in-transit work.
- Authorised operations staff explicitly choose documented continuation exception, requalification or controlled reassignment.
- Capacity release/transfer uses existing audited lifecycle functions only.
- Driver acceptance is blocked when linked partner assignment is no longer valid; existing driver record remains for resolution/audit.

## 5. Permissions and security
- No direct anon/authenticated table DML for immutable history/decision/exception tables.
- Narrow SECURITY DEFINER RPCs only, empty/explicit search_path, schema-qualified references, fixed ACLs; anon EXECUTE denied.
- Enforce tenant/organization membership and permission inside every RPC, not just frontend.
- AAL2 for privileged reviewer/revocation/operations resolution actions.
- No self-review; record reviewer identity and policy decision.
- Evidence Storage bucket remains private; validate owner/path and never expose public URLs.
- Restrict deletes; preserve history with state transitions/retirement, not cascades.
- Ensure RLS, grants, policies and function ACLs are tested independently.

## 6. Isolated regression suite — required before Staging migration
A. Onboarding: first submit; idempotent retry; unchanged resubmit; coverage amendment; evidence replacement; verified org amendment; rejected resubmission; duplicate legacy category rows; concurrent submissions.
B. Review/security: AAL1 denied; AAL2 permitted; submitter cannot review own version; inactive reviewer denied; evidence wrong owner/path/bucket denied; expired/missing evidence denied; tenant isolation.
C. Eligibility parity: NULL max weight; country-only vs location coverage; route lane; inactive service area; stale dates; requested-service-time boundary; insufficient/reserved capacity; ambiguous capacity commitments; deterministic selection among multiple capabilities.
D. Lineage: exact capability A at match with B still active at acceptance; evidence replaced after match; immutable decision retained; wrong partner/shipment/leg FK rejected; legacy null lineage not inferred.
E. Quote: exact opportunity decision required; leg-specific mode/route/weight validated; resubmission appends version; amount/currency/validity history retained; retry idempotency.
F. Award/accept/finalize: revoked between each stage; missing decision blocked; capacity valid but capability lineage missing blocked; concurrent revocation/award serialised; idempotent retries.
G. Revocation: open quote withdrawal; accepted work exception; in-transit preservation; no auto-cancel; capacity counters balanced; operator resolution audited; duplicate RPC retry creates no duplicate exception.
H. Driver/execution: exact linked partner assignment; partner suspended after driver assignment; acceptance blocked appropriately; licence/vehicle evidence expires; execution history retained.
I. Regression/security: RLS/RBAC; SECURITY DEFINER ACL/search_path; notification side effects suppressed in synthetic lane; no provider/email/Telegram calls; cross-tenant isolation.
All tests run against a disposable local Supabase stack with synthetic identities and fixtures, never against Production or live Staging operational queues.

## 7. Migration and release gates
Gate 0 — migration provenance: reconcile all duplicate migration versions and 34 unmatched Staging ledger names; obtain trusted historical archive/schema snapshot or establish an authoritative forward-only baseline. Do not rename/replay by guess.
Gate 1 — local reproducibility: supported Supabase CLI + Docker local stack, reset/replay from approved baseline, migration lint/plan and full regression suite.
Gate 2 — review: inspect generated migration, grants, RLS, FK lock/cascade behaviour, rollback/forward-fix plan and data compatibility.
Gate 3 — Staging apply: explicit owner approval, verified project ID qrpcivhdxobiaofppbkl, backup/restore plan covering DB/Auth/Storage, controlled deployment window.
Gate 4 — independent verification: schema/function diff, ACL/RLS, test results, no real notifications, no cross-tenant leakage, synthetic E2E.
Gate 5 — release readiness: no critical/high defects; rollback/recovery and operator runbook; Production separately requires explicit approval.

## 8. Current execution boundary
This document is a design specification only. No SQL migration, DDL, DML, function invocation, notification or real onboarding was performed as part of this work. Production was not accessed.
Hard blockers remain:
- repository migration filename collisions and mismatch with applied Staging ledger;
- no available connected local CLI/Docker/disposable database runner to prove replay and regression tests;
- trusted historical migration archive/schema snapshot not yet supplied.
Until those blockers are resolved, do not create or apply database changes. Package 1 and Phase 00 remain OPEN; Phase 01 is not authorised.
