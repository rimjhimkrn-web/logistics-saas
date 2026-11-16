# KRIM Customs, Regulatory Documentation and Cross-Border Execution Readiness Audit
**Date:** 16 November 2026  
**Scope:** Read-only production review of customs cases, broker licensing/assignment, document submission/review, jurisdiction requirement register, regulatory source verification, corridor compliance and country operating packs; source review of authoritative customs RPCs and operations customs-readiness page. No customs RPC, broker workflow, document upload, regulator API or provider action was executed. No production data or schema was changed.

## Executive decision
**NO-GO for customs clearance claims, cross-border shipment execution or global regulatory readiness.** KRIM has a useful internal customs coordination framework: broker organizations need jurisdiction-specific approved licences; licence evidence is privately stored and independently reviewed; broker assignment is separate from broker acceptance; customs documents are shipment-bound and reviewed by an accepted licensed broker; status transitions require AAL2 and do not include a clearance status; corridor controls require reviewed sources, evidence and expiry; and the operations page explicitly says it is not customs clearance.

Live evidence is empty or unapproved:
- Customs cases, broker assignments/licences, document submissions and events: zero.
- Regulatory source records: zero.
- Corridor dossiers, controls and corridor legs: zero.
- All 249 country operating packs remain research_pending.
- Five populated jurisdiction requirements are India-only and all remain research_pending.
- No customs authority release evidence is present.

A critical fail-open issue remains in the internal shipment compliance gate: when a shipment has zero configured compliance checks, it reports clear. This must not be interpreted as customs or regulatory clearance.

## 1. Live production evidence

| Component | Current rows/state |
|---|---:|
| Shipment customs cases | 0 |
| Broker assignments | 0 |
| Broker jurisdiction licences | 0 |
| Customs document submissions | 0 |
| Customs document events | 0 |
| Jurisdiction requirement definitions | 5 |
| Regulatory source records | 0 |
| Regulatory source review events | 0 |
| Corridor dossiers / controls / legs | 0 / 0 / 0 |
| Country operating packs | 249 |
| Country operating pack status | 249 research_pending |
| Shipment document requirements | 0 |
| Shipment documents | 0 |

All five jurisdiction requirement definitions are for India:
- IEC validity and annual confirmation.
- Core import documents.
- Core export declaration and supporting documents.
- Product-specific licences, permits, certificates and NOCs.
- ICEGATE registration and electronic filing pathway.

Each has legal_review_status = research_pending; none has an approved legal review or an associated registered regulatory source. The listed source-check timestamp is 6 November 2026. A timestamp and URL are not evidence that a source is currently valid, reviewed or operationally implemented.

The six-market catalogue and global country-pack inventory are not evidence of six active customs regimes. Country packs remain research pending and corridor readiness is not approved.

## 2. Positive backend controls
### Broker eligibility and assignment
- Broker must be an active organization of type customs.
- Broker assignment requires AAL2.
- Customs case must have a jurisdiction country.
- Broker must hold a currently approved licence for that exact country; effective dates are checked.
- Only authorized customer shipment-update or platform compliance/admin actors may propose an assignment.
- A second open proposed/accepted assignment is blocked.
- Broker must separately accept or reject the assignment.
- Broker licence submission requires active customs organization membership and compliance.manage, current country, private evidence path, file metadata and PDF/JPEG/PNG up to 10 MB.
- Independent platform AAL2 reviewer cannot review their own licence; original private object ownership and metadata are revalidated before approval.

### Customs document custody and review
- Supported document types include commercial invoice, packing list, certificate of origin, import/export permits, bills of lading, air waybills, road consignment notes, insurance, product certificates, dangerous goods declarations, customs declaration, duty receipt and inspection certificate.
- Submission requires active submitter organization membership; customer shipment-update permission or accepted active broker assignment and compliance permission.
- Document path is bound to shipment, submitting organization and user; original private object owner/MIME/size is revalidated.
- Review requires AAL2, submitter cannot review their own file, and review note is mandatory.
- A document can be marked verified only by the accepted active customs broker with a current approved jurisdiction licence. Customer/platform actors can reject, not certify it.
- Issuing country and issue/expiry dates are checked; expired/future-issued evidence cannot be verified.
- Events are recorded with actor and organization.

### Customs case lifecycle
- AAL2 is required for state transitions.
- Accepted licensed broker is required for broker-side transitions.
- Only defined preparation/submission/review/hold/reject/cancel transitions are supported.
- A verified customs declaration is required before the case can move to submitted.
- The function explicitly rejects cleared/released as a target status and says authority evidence needs a separate workflow. This is correct: internal broker review is not government release.

### Regulatory and corridor evidence
- Regulatory sources have jurisdiction, issuer, source URL, version, publication/effective dates, retrieval timestamp, SHA256, evidence reference, review status and reviewer metadata.
- Source review is a distinct workflow.
- Legal/tax controls require qualified legal/tax opinion and legal review before approval.
- Corridor control approval requires a reviewed effective source, evidence reference, reviewer rationale and expiry where applicable.
- Corridor dossier approval requires all mandatory controls approved and current and every corridor jurisdiction's country pack approved with mandatory pack controls complete.
- Dossier owner cannot approve their own dossier; AAL2 platform administration and future review date are required.

These are useful foundations, but zero records and unapproved country packs mean they currently provide no operational clearance.

## 3. Finding CUS-01 — P0: internal shipment compliance gate is fail-open when no checks exist
The production function krim_internal_evaluate_shipment_compliance_gate(shipment_id) counts blocked, review-required and expired rows in krim_compliance_checks. If all three counts are zero, it sets the result to clear and writes that status to krim_shipment_compliance_gates.

It does not require at least one applicable check, a complete configured check set, an approved country pack, an approved corridor dossier, or customs authority release evidence before returning clear.

Therefore, a shipment with zero compliance-check rows can receive an internal clear status. This is not customs clearance and must not authorize route activation, partner dispatch, export, import or delivery.

**Required remediation:** distinguish not_evaluated, configuration_missing, review_required, blocked, expired and internal_checks_passed. Fail closed if there are zero checks or if the expected requirement set cannot be proven complete. The evaluator must not return a single ambiguous clear status. Any customs release state must be a separate authority-evidence workflow with authority reference, jurisdiction, declaration identity, timestamp, source/system, original evidence and independent validation. This is a P0 release blocker. No function was invoked to test the issue.

## 4. Finding CUS-02 — P0: no government customs release evidence workflow
The customs case transition RPC deliberately excludes cleared and released; it requires a verified declaration before submitted, but the workflow stops at submitted/under_review/hold/rejected. There is no production customs authority release record or government response integration demonstrated.

This is an important boundary: KRIM can coordinate documents and a licensed broker's internal work, but it cannot represent a shipment as customs-cleared merely because the broker verified documents or changed an internal case status.

Before any release claim, the system needs an authority-response workflow covering:
- authority and jurisdiction;
- customs declaration / bill-of-entry / shipping-bill or applicable filing reference;
- official filing channel and transaction/acknowledgement ID;
- authority assessment/hold/query and duty/tax payment state where relevant;
- release order / out-of-charge / let-export-order or equivalent official outcome;
- original authority evidence or independently verifiable API response;
- issue/release timestamp and validity;
- responsible declarant/broker and reviewer;
- correction, cancellation, amendment and revocation history.

Exact legal names and required artifacts vary by country and shipment type. A broker attestation is not equivalent to an authority release.

## 5. Finding CUS-03 — P1: India requirement register is a research scaffold, not an approved operating pack
Five India requirements are present but all have research_pending legal review and no registered regulatory source records. The system has no approved India country operating pack or corridor dossier. It cannot yet produce a complete, current, commodity-specific export/import checklist.

The requirement model must distinguish importer/exporter obligations, customs broker/declarant obligations, carrier obligations, permits/licences/NOCs, product-specific Participating Government Agency requirements, taxes/duties, origin rules, transit-country controls and authority release. The five current entries are not exhaustive for every commodity, customs regime, port, airport, land border, trade agreement or special economic/bonded zone.

For the first India pilot, legal/regulatory review should be scoped to a specific domestic or export/import lane, cargo class and filing role. Do not claim nationwide or global readiness from a small generic register.

## 6. Finding CUS-04 — P1: source freshness and legal authority are not operationally proven
Regulatory source metadata includes effective dates, retrieval timestamp and SHA256, and approval rules are thoughtful. But no sources are registered, no source review events exist, and no source refresh process is evidenced.

A URL/hash does not prove the page is an authoritative instrument, current consolidated version, legally applicable to the goods, or interpreted correctly. Each source should carry:
- official authority and exact instrument/notification/circular/portal reference;
- jurisdiction and process (import/export/transit);
- commodity/HS-code scope and exceptions;
- publication, effective and supersession dates;
- captured immutable evidence and SHA256;
- reviewer qualifications and legal rationale;
- next review date and automatic expiry/suspension;
- explicit mapping to the operational control and affected workflow.

A source that is withdrawn, superseded, unavailable or outside its effective period must cause affected operations to be held for review.

## 7. Finding CUS-05 — P1: broker network and assignment workflow are not live
There are zero customs broker organizations with submitted jurisdiction licences, zero approved licences, zero broker assignments and zero accepted broker engagements in the relevant tables. The code correctly prevents assigning a broker without a current approved licence for the jurisdiction, but no real licensed broker network has been verified.

KRIM must not market customs brokerage, declaration filing, clearance, duty/tax advice or representation as its own service unless the relevant legal entity and licences authorize it. The safe platform role is to coordinate customers with independently licensed brokers, with clear contract, responsibility, fee, liability, confidentiality and customer authorization terms.

## 8. Finding CUS-06 — P1: evidence bucket and document access lifecycle require full assurance
Customs licence and document RPCs use the private krim-partner-verification bucket and validate path, owner, MIME type and file size against the original object. This is stronger than trusting frontend metadata. However, a shared bucket creates cross-domain policy complexity and should not be treated as customs-specific isolation. The bucket inventory query found the private pod-documents bucket, while customs RPCs explicitly reference krim-partner-verification; complete bucket-policy review and actual object lifecycle testing remain necessary.

The audit did not upload/download files or test signed URL expiry/revocation. Require per-organization/user path isolation, strict MIME and size validation, malware/content scanning where feasible, retention/legal hold, immutable audit history, signed-link expiry, revocation and cross-tenant negative tests. Do not expose customs files to general partner verification reviewers or unrelated shipment stakeholders.

## 9. Finding CUS-07 — P1: no end-to-end customs or trade-document operation is evidenced
There are zero customs cases, declarations, documents, document events, broker assignments, licence records, shipment document requirements or shipment documents. The operations customs-readiness page is intentionally read-only preparation: it loads visible customs records and its form validates fields in the browser only; it does not save an operational workflow. The page accurately states that it is not customs clearance.

A full controlled pilot must demonstrate:
1. Shipment and corridor have approved market/country operating packs.
2. Cargo description, HS classification and restricted/prohibited-goods screening are reviewed by qualified personnel.
3. Exporter/importer/declarant identities and authorizations are validated.
4. Jurisdiction-licensed broker is independently verified and accepts the engagement.
5. Current applicable document checklist is generated and source-linked.
6. Invoice, packing list, origin, permits and transport documents are submitted with immutable private evidence.
7. Broker reviews and verifies documents; rejections and amendments are versioned.
8. Declaration is filed in the relevant official system; official acknowledgement is recorded.
9. Queries, inspection, duty/tax assessment/payment and holds are tracked.
10. Official release evidence is captured and independently validated.
11. Customs release is linked to the exact shipment/leg and checked before dispatch/continuation.
12. Amendments, cancellation, seizure, rejection and post-clearance audit scenarios are tested.

None of these end-to-end steps was executed.

## 10. Required staging-only test matrix
1. Zero configured compliance checks must never produce a pass/clear result.
2. Incomplete or stale expected check set must return configuration_missing/review_required.
3. A document marked verified by customer or unassigned broker must fail.
4. Expired/future-effective broker licence must block assignment, verification and transition.
5. Broker assignment must fail for wrong jurisdiction, inactive organization or non-customs organization.
6. Assignment proposer cannot self-accept as the broker unless separately authorized under the intended model.
7. A second open assignment and conflicting retry must fail safely.
8. Document submitter cannot review own submission; cross-tenant and wrong-org IDs must fail.
9. Missing object, wrong bucket/path/owner/MIME/size and expired evidence must fail closed.
10. Missing customs declaration must block submission to authority.
11. Internal submitted/under-review status must never be shown as authority cleared/released.
12. Authority acknowledgement, release, amendment, revocation and cancellation are immutable and idempotent.
13. Country pack not approved, mandatory source absent, source superseded or expired must block route activation.
14. Corridor dossier with zero mandatory controls must not be approved; every mandatory control must be current and evidenced.
15. Every corridor transit jurisdiction and mode must have matching approved pack and dossier coverage.
16. Cargo-specific restricted goods, permits, sanctions and dual-use controls must fail closed when classification/evidence is missing.
17. Test customer, broker, customs reviewer and platform admin access independently with AAL1/AAL2 and tenant isolation.
18. Signed URL expiry/revocation, private object download and retention/legal hold must be verified.
19. Test actual India filing references and official release evidence in a controlled sandbox or test environment; do not submit real filings as tests.
20. Verify customer-facing status labels distinguish document-ready, broker-verified, authority-submitted, authority-held and authority-released.

None of these staging tests was executed.

## 11. Remediation order
1. Fix the fail-open internal compliance evaluator in staging; no empty-check pass and no ambiguous clear.
2. Keep customs clearance/release as a separate authority-evidence workflow; do not add a UI status without verified evidence and independent review.
3. Complete one India pilot operating pack with qualified legal/customs review, official source evidence and commodity-specific scope.
4. Verify one licensed broker in the exact jurisdiction and complete a real signed engagement before offering the workflow to customers.
5. Build a complete customs document requirement matrix for the pilot cargo/lane, including amendments and expiry.
6. Complete private storage isolation, retention, malware/content and signed-link assurance.
7. Build official filing/acknowledgement integration only where authorized APIs or permitted operational processes exist; keep manual broker workflow clearly labelled.
8. Run full staging end-to-end acceptance and a tightly controlled real pilot before enabling any route/dispatch release gate.

## 12. Change control and release decision
Read-only audit only. No customs or broker RPCs were invoked; no licence/document was submitted or reviewed; no storage object, customs case, corridor dossier or country pack was created or changed. No production schema, function, policy or provider integration was modified.

The repository/production migration-history mismatch and sanitized schema-manifest gate remain unresolved. Do not apply ad-hoc DDL or replay/alter migrations until full reconciliation and explicit authorization.

**Release status: NO-GO for customs clearance claims, export/import execution, global regulatory readiness and cross-border shipment release.** The internal broker/document workflow has useful security controls, but no real operational evidence exists and the fail-open compliance evaluator must be fixed before any regulated execution.
