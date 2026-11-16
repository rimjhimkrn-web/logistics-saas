# KRIM Customs, Regulatory Compliance and Shipment Release Deep Audit

**Date:** 2026-11-16  
**Environment:** Production Supabase, read-only inspection  
**Decision:** **NO-GO for customs-dependent shipment execution, cross-border activation or any claim of customs clearance.**

## Scope and safety boundary

Inspected customs cases, broker licensing and assignments, customs document submission/review, jurisdiction requirements, shipment compliance checks/decisions/findings/holds/obligations, corridor compliance dossiers/controls, shipment readiness/compliance gate functions and current production records.

No business RPC was invoked. No shipment, customs case, broker assignment, document, compliance decision, hold, release, or production schema was changed.

## Live production counts

| Record class | Rows |
|---|---:|
| Shipment customs cases | 0 |
| Customs broker assignments | 0 |
| Customs broker licences | 0 |
| Customs document submissions | 0 |
| Customs jurisdiction requirements | 5 |
| Shipment compliance checks | 0 |
| Compliance decisions | 0 |
| Compliance findings | 0 |
| Compliance holds | 0 |
| Compliance obligations | 0 |
| Obligation fulfilments | 0 |
| Shipment compliance gates | 6 |
| Corridor compliance dossiers | 0 |
| Corridor compliance controls | 0 |
| Corridor compliance legs | 0 |

All five jurisdiction requirement rows are India requirements. Each is `research_pending`, inactive, and has no effective date. Their source references are recorded, but they are not legally approved operational controls.

All six existing shipment compliance gates are marked `clear`, but each has **zero compliance checks**. The gate metadata confirms zero blocked, zero review-required and zero expired checks. This is a false-positive clearance state, not evidence that those shipments passed compliance screening.

## Positive controls confirmed

1. Customs broker assignment requires AAL2, authorized customer/platform/operations actor, an active customs organization, and an approved current broker licence for the exact jurisdiction.
2. Broker licence approval requires an independent AAL2 platform administrator, rejects self-review, checks validity dates and verifies the original private evidence object, owner, MIME type and size.
3. Customs document submission requires active organization membership; a broker must have an accepted assignment and compliance permission. Evidence is checked against private storage ownership and metadata.
4. Customs document verification requires an accepted active broker with a current jurisdiction licence, or the separately authorized customer rejection/platform-admin path. Issued/expiry dates and evidence ownership are checked.
5. Customs case transition requires AAL2. Broker-side progression requires accepted broker authority and a current jurisdiction licence.
6. Transition to `submitted` requires a verified customs declaration document.
7. Customs transition deliberately excludes `cleared`; its error text says clearance requires a separate authority-evidence workflow. This is a sound separation and should be preserved.
8. A database trigger blocks customs submission unless a currently effective, legally approved jurisdiction requirement exists.
9. Corridor shipment-write guard requires an active corridor, approved-for-activation dossier, mode match, nonzero fully approved mandatory controls with reviewed sources, and approved country operating packs.

## Findings

### P0 — Empty compliance check set is treated as a successful clear gate

**Evidence:** `krim_internal_evaluate_shipment_compliance_gate(bigint)` counts failed/rejected/blocked checks, pending/review checks and expired checks for a shipment. If all three counts are zero, it assigns status `clear`. There is no positive requirement that the shipment has at least one required check, that all required check categories exist, or that a policy/rule set was evaluated.

The production readiness evaluator calls this gate and carries its `clear` result into shipment readiness. The six current gate rows all have zero linked compliance checks and are nevertheless `clear`.

**Impact:** downstream systems can interpret absence of screening data as a passed screening. This is a fail-open compliance decision and can make shipment readiness appear better than the evidence supports.

**Required remediation:** implement a fail-closed evaluator. Derive required checks from a versioned applicable rule set and shipment/jurisdiction/cargo attributes. Require every mandatory check to exist, be current, be tied to the exact shipment and scope, and be in an accepted verified state. Missing rules, zero required checks, incomplete screening, stale source/rule versions or missing evidence must return `review_required` or `blocked`, never `clear`. Record the evaluated rule-set version and complete check coverage. Re-evaluate on relevant shipment/cargo/route/document changes.

### P0 — No official customs release evidence or independent release workflow

**Evidence:** the customs case transition RPC only allows `pending`, `prepared`, `submitted`, `under_review`, `hold`, `rejected` and `cancelled`. It expressly does not allow `cleared`. The readiness evaluator interprets a case with any status other than `cleared` or `cancelled` as customs pending. The current document workflow verifies documents through an accepted broker, but there is no separate official authority release record/workflow in the inspected customs model.

**Impact:** a broker-verified declaration or supporting document is not the same as government customs release. No system actor should mark a shipment customs-cleared merely because the broker completed its work or the declaration was submitted.

**Required remediation:** retain the no-clearance-through-broker-transition guard. Design a distinct authority-release evidence record with issuing authority, jurisdiction, declaration/entry reference, release date/time, source document and integrity metadata, independent verification actor, evidence object ownership, and revocation/correction history. The state transition must be separate from broker document verification and must not be enabled until legal and operational review approves the exact evidence standard for the jurisdiction.

### P0 — India jurisdiction requirement pack is research-only and inactive

**Evidence:** five India requirement records exist (export core documents, ICEGATE access/filing, IEC validity, import core documents and product-specific LPCO). All five show `legal_review_status='research_pending'`, `is_active=false`, and no effective date.

**Impact:** the platform has not approved the rules needed to operate these customs flows. The submission trigger appropriately blocks customs submission because no active legally approved requirement is available. This means India import/export customs processing is not operationally enabled.

**Required remediation:** have a qualified India customs/trade professional verify each requirement against current primary authority sources, applicability and exemptions; record effective dates, source version/reference, reviewer and next review date; only then activate approved requirements. Do not bulk-activate research rows or treat source URLs alone as legal approval.

### P1 — Compliance gate does not evaluate obligations, findings, holds or corridor controls

**Evidence:** the shipment compliance gate implementation reads only `krim_compliance_checks`. The schema also contains obligations, obligation fulfilments, findings, holds, decisions and corridor controls, but the inspected evaluator does not incorporate their status into its decision.

**Impact:** even after the zero-check issue is fixed, a shipment may have an outstanding obligation, unresolved high-severity finding, active hold or corridor control gap that is not reflected in the compliance gate unless another independent guard blocks the relevant operation. A single green gate is not currently a complete compliance assurance summary.

**Required remediation:** define a single authoritative decision model that includes applicable obligations and their evidence-backed fulfilments, unresolved findings by severity, active holds, jurisdiction requirements, corridor controls and source freshness. Every write path that relies on the gate must independently enforce the relevant conditions. A dashboard aggregate must not substitute for operation-specific authorization.

### P1 — Jurisdiction requirement freshness and source governance are not enforced as a full lifecycle

**Evidence:** the customs submission trigger checks active + legally approved + effective dates, but does not check `next_review_at`, source freshness, source record version or whether the referenced official source is still valid. The requirement rows have source title/URL and checked timestamp but are currently research-only.

**Impact:** a requirement could remain active after its planned review date or after its source changes, unless another process deactivates it. The trigger would continue to accept it if the stored status and effective dates remain valid.

**Required remediation:** make next-review expiry and source/version review part of the activation predicate. Expired review windows should suspend the requirement until a reviewer reconfirms it. Maintain immutable source snapshots or hashes and a complete legal-review history.

### P1 — Customs case status is not a sufficient customer-facing clearance signal

**Evidence:** the customs case status records workflow progress, while actual government release is intentionally outside the transition function. The readiness evaluator currently has a `cleared` status branch but no corresponding authority-release workflow in the inspected model.

**Impact:** a customer interface or integration could mislabel `submitted`, `under_review`, `broker_completed` or a broker-verified declaration as customs-cleared if it relies on loosely mapped status labels.

**Required remediation:** expose separate fields for broker workflow, authority decision, release evidence verification and cargo release permission. Only the independently verified authority-release record may produce a customer-visible `customs_cleared` state.

### P1 — Broker licence approval allows null validity bounds

**Evidence:** broker licence review rejects a future `valid_from` and an expired `valid_until` when supplied, but permits either date to be NULL. Broker assignment considers NULL bounds open-ended.

**Impact:** a licence with no start or expiry date may be treated as currently valid indefinitely. Whether a jurisdiction's licence has a fixed validity period depends on the authority and licence type, but an unbounded licence should not be silently accepted without an explicit evidence-backed legal basis.

**Required remediation:** require explicit validity bounds where the issuing authority provides them, or record a reviewer-approved `not_applicable/perpetual` validity basis with evidence and next verification date. Revalidate licence status and dates at every broker-sensitive action, not only assignment creation.

### P2 — Customs transition and document lifecycle need full staging replay/concurrency tests

The inspected functions use row locks and event records, but no live customs records exist. Staging must test duplicate document submissions, conflicting retries, licence expiry after assignment, broker revocation mid-case, assignment replacement, rejected-document resubmission, authority release revocation/correction and concurrent case transitions. No production test calls are appropriate.

## Required staging-only test suite

1. A shipment with zero compliance checks must never receive `clear`.
2. Missing mandatory rule, check category, evidence or current source must fail closed.
3. All mandatory checks verified/current produces a clear result only for the exact evaluated scope and rule-set version.
4. Expired check, expired source, unresolved high-severity finding or active hold blocks readiness.
5. Outstanding obligation without verified fulfilment blocks the relevant operation.
6. A compliance decision cannot be replayed with a different shipment, scope, evidence or rule-set version.
7. A corridor dossier with zero mandatory controls cannot be approved for activation.
8. A corridor control with missing/expired/unreviewed source blocks shipment creation.
9. Research-only/inactive jurisdiction requirement blocks customs submission.
10. Broker assignment without current approved jurisdiction licence is rejected.
11. Broker self-approval and evidence-owner mismatch are rejected.
12. Expired licence after assignment blocks further broker actions.
13. Broker-verified declaration permits only the documented submission transition; it does not produce customs clearance.
14. Only independent official authority-release evidence can set the separate customs-cleared state.
15. Wrong jurisdiction, shipment, organization, evidence owner, file hash, MIME or size is rejected.
16. Concurrent broker assignment and revocation/reassignment cannot leave multiple accepted assignments.
17. Revoked broker membership/assignment mid-session blocks document submission and case transition.
18. Tenant isolation and AAL2/permission revocation are enforced for every sensitive action.

## Remediation order

1. **P0:** fail-closed compliance evaluator and all dependent readiness consumers.
2. **P0:** design and independently verify authority-release evidence; do not enable a broker-side clearance shortcut.
3. **P0:** complete qualified legal review for India customs requirements before activating any import/export process.
4. **P1:** unify checks, obligations, findings, holds, corridor controls and source freshness in operation-specific gates.
5. **P1:** introduce source-review expiry and explicit broker licence validity handling.
6. **P1:** separate customer-facing broker workflow and government release states.
7. Execute the full staging suite with synthetic data, concurrency and retry tests.
8. Re-run production read-only counts and security review after approved remediation.

## Release boundary

No production DDL or RPC remediation was applied. The repository/production migration history mismatch and pending sanitized schema manifest remain blockers to production function changes. Do not apply/replay/baseline/squash migrations until full reconciliation. No live customs case, broker assignment, document submission or clearance test was created.

## Overall decision

**NO-GO for customs-dependent execution, import/export activation, or any claim of customs clearance.** The broker licensing and document evidence controls are meaningful, and the transition function correctly separates broker workflow from government clearance. However, the shipment compliance evaluator is fail-open when no checks exist, all five India requirement records are research-only/inactive, no official customs release evidence workflow is present, and all operational customs tables are empty.
