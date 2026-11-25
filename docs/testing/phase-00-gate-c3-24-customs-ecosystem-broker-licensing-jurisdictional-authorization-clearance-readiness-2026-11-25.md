# Phase 00 Gate C3.24 — Customs ecosystem onboarding, broker licensing, jurisdictional authorization and clearance readiness

**Date:** 2026-11-25  
**Immutable source baseline:** `72d75a18f985ceb09e468839435ee95700e11e46`  
**Method:** Read-only source/migration review reconciled with prior Production audit evidence. No SQL, RPC, customs case, broker assignment, document submission, filing, release, external authority portal or provider operation was executed. No Production/Staging state or deployment was changed.

## Executive decision

**FAIL / BLOCKED — NO-GO for customs-dependent shipment execution, India import/export activation, cross-border operational claims or any claim of customs clearance.**

KRIM has a substantial customs control foundation: authenticated shipment-scoped case creation, AAL2 broker assignment and document review, exact-jurisdiction licence checks, private evidence ownership/path checks, independent reviewer controls, a legally approved/effective jurisdiction requirement gate before submission, and an intentional separation between broker workflow and official customs release.

But these controls do not make customs operations live. Three critical blockers dominate:

1. **P0 compliance fail-open:** the shipment compliance evaluator can return `clear` when there are no compliance checks. Prior Production snapshot had zero compliance rules and zero checks, while six gate rows were `clear` with no reviewer actor.
2. **P0 no authority-release evidence workflow:** broker verification/submission is not government release. The controlled customs case transition does not allow `cleared`, and no callable, independently reviewed authority-evidence workflow was established.
3. **P0 India legal pack inactive:** all five India customs jurisdiction requirement rows were `research_pending`, inactive and without effective dates. No India customs submission should be represented as operationally enabled.

The broader global snapshot showed six market catalogue entries but all six operational activation controls blocked; 249 country operating packs all research-pending; zero corridor dossiers/controls/legs. These are historical audit snapshots, not refreshed by this gate.

## Scope and evidence

### Source reviewed
- Broker licence submission/review and jurisdiction binding migrations:
  - `supabase/migrations/20261107130000_customs_broker_license_evidence_and_review.sql`
  - `supabase/migrations/20261107140000_enforce_customs_broker_jurisdiction_license.sql`
  - `supabase/migrations/20261107181000_harden_customs_broker_license_review.sql`
  - `supabase/migrations/20261107182000_harden_customs_broker_assignment_lifecycle.sql`
  - `supabase/migrations/20261107183000_harden_customs_broker_license_submission.sql`
  - `supabase/migrations/20261107185000_customs_broker_assignment_admin_control_desk.sql`
  - `supabase/migrations/20261107185100_customs_broker_assignment_admin_control_desk_followup.sql`
- Document custody/review migrations:
  - `supabase/migrations/20261107150000_customs_shipment_document_tables.sql`
  - `supabase/migrations/20261107151000_customs_document_submission_and_review_rpcs.sql`
  - `supabase/migrations/20261107152000_customs_document_storage_and_broker_read_policies.sql`
  - `supabase/migrations/20261107190000_harden_customs_document_evidence_controls.sql`
  - `supabase/migrations/20261115174000_harden_customs_independent_review_and_evidence_revalidation.sql`
  - `supabase/migrations/20261115181000_harden_customs_document_and_license_review_evidence.sql`
  - `supabase/migrations/20261115181500_customs_document_review_jurisdiction_evidence_and_expiry.sql`
- Jurisdiction and authorization migrations:
  - `supabase/migrations/20261107170000_customs_jurisdiction_requirement_register.sql`
  - `supabase/migrations/20261107171000_scope_customs_requirements_read_access.sql`
  - `supabase/migrations/20261107180000_enforce_customs_broker_jurisdiction_licences.sql`
- Customs case, customer, operations and staging workspace source:
  - `app/customs/secure-workspace.js`
  - `app/customs/workflows/` (dashboard, cases, brokers, broker licence, declarations, documents, imports, exports, classification, HS classification, jurisdiction requirements, sanctions, free-trade zones and audit ledger)
  - `app/operations/customs-readiness.html`
  - `app/operations/staging/customs-trade-readiness.html`
  - `app/customer/customs-documents.html`
  - `app/partner/customs/index.html`
  - `app/platform-admin/customs-broker-review.html`
  - `app/admin/staging/page-14-customs-broker-licence-review.html`

### Prior audit records used
- `docs/audits/KRIM-CUSTOMS-COMPLIANCE-JURISDICTION-AND-OFFICIAL-RELEASE-EVIDENCE-DEEP-AUDIT-2026-11-16.md`
- `docs/audits/KRIM-CUSTOMS-REGULATORY-CLEARANCE-AND-DOCUMENT-CUSTODY-AUDIT-2026-11-16.md`
- `docs/audits/KRIM-CUSTOMS-REGULATORY-DOCUMENTATION-AND-CROSS-BORDER-EXECUTION-INTEGRATION-AUDIT-2026-11-16.md`
- `docs/audits/KRIM-CUSTOMS-REGULATORY-DOCUMENTATION-AND-CROSS-BORDER-EXECUTION-READINESS-AUDIT-2026-11-16.md`
- `docs/audits/KRIM-GLOBAL-COMPLIANCE-COUNTRY-ACTIVATION-CUSTOMS-AND-CORRIDOR-CONTROLS-AUDIT-2026-11-16.md`
- `docs/remediation-pending/2026-11-17-customs-and-shipment-compliance-gate-revalidation.md`

## Positive controls confirmed in source/prior audits

1. **Customs case creation:** authenticated shipment update authority, shipment row lock, active jurisdiction, process/value validation and advisory-lock duplicate protection; supplied shipment ID alone does not bypass customer organization scope.
2. **Broker admission:** licence submission requires active customs organization membership and compliance management permission. Evidence path is tied to customs organization and submitting user; private storage object owner and metadata are rechecked.
3. **Independent licence review:** AAL2 platform administrator, platform permission, reviewer note and submitter/reviewer separation; active customs organization and jurisdiction are rechecked; original private evidence object owner/path/MIME/size are revalidated.
4. **Jurisdiction-specific broker authority:** broker assignment and broker document verification require an active customs organization and an approved current licence for the exact customs jurisdiction.
5. **Assignment lifecycle:** AAL2 and authorized customer/platform/operations actors for assignment; broker acceptance requires active membership and compliance permission; duplicate open assignments are guarded; closure/revocation requires authorization and a reason/event.
6. **Document submission:** active submitting organization; customer shipment-update or accepted broker compliance-view authority; restricted document types, MIME/size and date ordering; private object owner/path metadata checks; event recorded.
7. **Document review:** AAL2, reviewer note, submitter cannot review own document; only accepted active broker with current jurisdiction licence may verify; customer/platform paths can reject under their authority; original private evidence is revalidated and events are recorded.
8. **Legal submission guard:** trigger blocks customs case submission unless a jurisdiction requirement is active, legally approved and currently effective.
9. **Clearance separation:** broker-side transition deliberately excludes terminal `cleared`; verified declaration/submission is not treated as government release. Preserve this boundary.
10. **Cross-border shipment guard:** prior audit found route/corridor controls require active exact corridor, approved dossier, mode match, mandatory approved controls with reviewed sources and approved operating packs for transit jurisdictions.

These are source and prior-audit observations. No runtime authorization, RLS or object-access tests were executed in this gate.

## Critical and high-priority findings

### P0 — Empty compliance check set is treated as successful clearance
Prior Production audit found `krim_internal_evaluate_shipment_compliance_gate(bigint)` counts failed/rejected/blocked, pending/review and expired checks. When all counts are zero, it sets the gate to `clear`; it does not require an applicable rule set, mandatory check categories or positive evidence that checks were performed.

Historical snapshot:
- Compliance rules: 0
- Compliance checks: 0
- Six compliance gate rows: all `clear`, risk low, `checked_by=NULL`

This is a fail-open decision: absence of screening is interpreted as success. The shipment readiness evaluator consumes this state.

**Required remediation:** versioned, shipment/jurisdiction/cargo-specific rule sets; derive the mandatory check set; require every mandatory check, evidence and source to be current and verified for the exact scope; zero/missing/incomplete/stale sets must return `blocked` or `review_required`, never `clear`. Persist evaluator/rule version, source references, input fingerprint, actor/worker and timestamp. Re-evaluate after relevant shipment, cargo, route or document changes.

### P0 — Compliance gate can be directly altered by customer-organization members
Prior global compliance audit found `krim_shipment_compliance_gates` RLS enabled, but authenticated users had direct SELECT/INSERT/UPDATE and a broad ALL policy based on organization access to the shipment's customer organization. The policy did not visibly require compliance-management permission, independent reviewer or trusted worker identity. The six `clear` rows had no checker identity.

**Required remediation:** revoke direct authenticated INSERT/UPDATE/DELETE; replace broad ALL policy with narrowly scoped read access if needed; permit writes only through a trusted internal evaluator or separately authorized compliance workflow. Add tenant and negative-role staging tests. Do not patch Production before schema/migration reconciliation.

### P0 — No official customs authority release evidence or independent clearance workflow
The controlled customs case transition allows internal states such as prepared, submitted, under_review, hold, rejected and cancelled, but not `cleared`. Its error boundary explicitly requires a separate authority-evidence workflow. Prior audit found no callable workflow that binds an authority-issued release record to the exact customs case/shipment/jurisdiction and independently verifies it.

A broker-verified declaration, filing receipt, internal document review or status update is not government release.

**Required remediation:** retain the broker-side no-clearance guard. Design a separate authority release evidence record with issuing authority, jurisdiction, official entry/declaration/release reference, release timestamp, original authority document/source, object owner and integrity/hash, exact shipment/case/leg binding, independent AAL2 verifier, correction/revocation/supersession history and immutable audit. Only the independently verified evidence can enable customer-visible customs-cleared status or downstream cargo release.

### P0 — India customs requirements are research-only and inactive
Historical Production snapshot contained five India requirement rows: export core documents, ICEGATE access/filing, IEC validity, import core documents and product-specific LPCO. All were `research_pending`, inactive and had no effective date.

The trigger appropriately blocks customs submission without approved/effective requirements. Therefore India import/export customs submission is not operationally enabled.

**Required remediation:** a qualified India customs/trade professional must validate primary official sources, applicability, commodity scope, exceptions, effective dates and required filings; record qualified reviewer, legal rationale, source version/evidence hash and next review date. Only explicitly approved and effective requirements may be activated. Never bulk-activate research rows or infer approval from a source URL.

### P1 — Compliance gate omits obligations, findings, holds and corridor controls
The prior evaluator reads `krim_compliance_checks` but does not incorporate all compliance obligations/fulfilments, unresolved findings, active holds and corridor control state. A green aggregate is not a complete operation-specific compliance decision.

**Required remediation:** one authoritative decision model for mandatory checks, obligations and evidence-backed fulfilments, findings/severity, active holds, jurisdiction requirements, corridor controls and source freshness. Each booking/dispatch/customs operation must enforce its own current prerequisites.

### P1 — Regulatory source freshness and legal governance are incomplete
Prior audit found no registered regulatory sources or source-review events. Requirement metadata includes source title/URL and checked time, but a URL/hash does not prove the authoritative instrument, current consolidated text, applicability to cargo/HS code, or legal interpretation. Next-review expiry/source version is not fully enforced as an activation condition.

**Required remediation:** store authority and exact instrument/notification/portal reference, jurisdiction/process, HS-code/commodity scope, exemptions, publication/effective/supersession dates, immutable source snapshot/hash, qualified reviewer/rationale, control mapping and next-review date. Superseded, withdrawn, unavailable or overdue sources must suspend affected operations pending review.

### P1 — Broker licence validity can be unbounded
The reviewed licence approval function permits NULL validity bounds, and broker assignment treats NULL bounds as open-ended. Some licence types may legitimately be perpetual, but that must not be assumed.

**Required remediation:** require validity bounds where the issuing authority supplies them, or explicit reviewer-approved perpetual/not-applicable basis with evidence and next verification date. Revalidate licence and organization status on assignment, acceptance, document verification and every consequential case action, including after assignment.

### P1 — No verified customs broker network or commercial engagement
Historical snapshot: zero customs broker licences, zero broker assignments and zero accepted broker engagements. The code's licensing guard does not establish that a real broker network exists. KRIM must not market brokerage, declaration filing, clearance, duty/tax advice or legal representation as its own service unless the relevant entity and licences authorize it.

**Required remediation:** onboard and independently verify an actual broker per jurisdiction; verify licence scope/validity, professional authorization, organization, insurance where applicable, signed engagement, customer authority, fees, responsibilities, liability, confidentiality, complaints and termination terms. Position KRIM as a coordination platform only within legally reviewed scope.

### P1 — Evidence bucket and document custody require further assurance
Customs documents and licence evidence use the shared private `krim-partner-verification` bucket with owner/path/MIME/size checks. Prior audit identified cross-domain policy complexity and a separate `pod-documents` bucket in inventory; full bucket policy review and real object lifecycle tests were not completed.

**Required remediation:** prove per-organization/user path isolation; verify no cross-domain/customs-to-partner leakage; strict byte-level MIME and size validation, malware/content scanning where feasible, immutable hash/object version, retention/legal hold, signed URL expiry/revocation/cache, replacement/supersession and audit export. Do not expose customs files to unrelated partners or shipment stakeholders.

### P1 — No end-to-end customs or trade-document operation exists
Historical Production snapshot:
- Customs cases: 0
- Broker assignments: 0
- Broker licences: 0
- Customs document submissions: 0
- Shipment compliance checks/decisions/findings/holds/obligations: 0
- Corridor compliance dossiers/controls/legs: 0

Prior audit found the Operations customs-readiness page is read-only preparation; its form validates fields in the browser but does not persist an operational workflow. No customs filing, government acknowledgement, inspection/duty assessment, authority release or customs-to-dispatch lifecycle was executed.

**Required remediation:** pilot one explicitly approved corridor and commodity with current country packs, exact mode/corridor approval, reviewed HS classification/restricted-goods screening, validated exporter/importer/declarant, accepted jurisdiction-licensed broker, source-linked document checklist, versioned private evidence, official system filing/acknowledgement, query/inspection/duty/hold handling, independently verified release evidence and shipment/leg dispatch gate. Test amendments, cancellation, rejection, seizure and post-clearance audit.

### P2 — Staging lifecycle, revocation and concurrency tests remain unexecuted
Test duplicate/conflicting licence and document submissions; licence expiry or broker suspension after assignment; broker revocation mid-case; assignment replacement; reviewer conflict; storage object deletion/replacement; signed-link expiry; authority release correction/revocation; concurrent case transitions; stale source/rule invalidation; customer/broker/admin AAL1/AAL2 and tenant isolation.

## Readiness matrix

| Area | Result | Boundary |
|---|---|---|
| Shipment-scoped customs case creation | PARTIAL PASS | Source/prior audit; no case created |
| Broker licence submission and independent review | PARTIAL PASS | Strong source controls; no real broker/licence |
| Exact-jurisdiction broker assignment | PARTIAL PASS / BLOCKED | Authorization code exists; zero live assignments |
| Customs document custody and review | PARTIAL PASS | Source checks; no object upload/review |
| Legal jurisdiction submission gate | PARTIAL PASS / BLOCKED | Gate exists; India requirement rows inactive |
| Regulatory source freshness/legal approval | FAIL / BLOCKED | No approved operating source set |
| Shipment compliance evaluation | FAIL / BLOCKED | Empty-check fail-open |
| Compliance gate write integrity | FAIL / BLOCKED | Direct authenticated write path in prior snapshot |
| Government customs release evidence | FAIL / BLOCKED | No controlled authority-release workflow |
| India import/export activation | FAIL / BLOCKED | Five research-only/inactive requirements |
| Country/corridor activation | FAIL / BLOCKED | Six market controls blocked; 249 packs research-pending; zero corridor dossiers |
| Live customs broker network | FAIL / BLOCKED | Zero licences and assignments |
| Customs document/filing E2E | NOT TESTED / BLOCKED | Zero live records; no authority connection evidenced |
| Customs-to-dispatch release enforcement | NOT TESTED / BLOCKED | No official release workflow or E2E proof |

## Required remediation and controlled test order

1. Preserve the no-broker-clearance boundary. Never allow a broker or customer document review to set official `cleared`.
2. Reconcile Production schema/migration history and create a sanitized schema manifest + complete migration crosswalk before proposing database changes.
3. In isolated Staging, fix the empty-check fail-open evaluator and direct gate-write privilege/policy issue; prove zero/missing checks never pass.
4. Incorporate obligations, findings, holds, corridor controls, jurisdiction rules and source freshness into operation-specific fail-closed decisions.
5. Complete qualified legal review of India requirements and one narrowly scoped commodity/corridor pack before activation.
6. Define broker licence perpetual/validity semantics and revalidate broker status at every consequential action.
7. Build the distinct official authority-release evidence workflow with independent review, immutable history and revocation/correction.
8. Review storage policies/object lifecycle and prove tenant isolation.
9. In Staging with synthetic records only, test wrong jurisdiction, wrong organization, inactive broker, expired/future/unbounded licence, self-review, wrong file owner/path/MIME/size, missing declaration, stale source, empty rules/checks, active holds, missing obligation fulfilment, corridor gaps, direct gate write attempts, broker revocation mid-case, duplicate/replayed submissions and authority-release replay/revocation.
10. Run one complete synthetic customs journey only after all prerequisites pass. Use official sandbox/test endpoints where available; never create real customs filings merely as a test.

## Safety and release boundary

No Production or Staging SQL/RPC, customs case, broker licence, broker assignment, document submission/review, authority filing, customs release, shipment status, compliance decision, external provider or deployment operation was executed. No real customer/broker was invited or onboarded. Historical counts are clearly identified as prior snapshots and were not refreshed here.

**Gate C3.24: FAIL / BLOCKED — NO-GO for customs-dependent execution, India import/export activation, cross-border operational claims or customs-clearance claims.**
