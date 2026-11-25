# C3.59 — Global customs, trade compliance, classification, broker and clearance readiness

**Programme:** KRIM GLOBAL PLATFORM — AI QUALITY ASSURANCE, SIMULATION & RELIABILITY PROGRAMME  
**Phase:** 00 — Infrastructure Audit  
**Gate:** C3.59  
**Immutable source baseline:** `72d75a18f985ceb09e468839435ee95700e11e46`  
**Audit date:** 2026-11-25  
**Method:** Read-only review of immutable customs migrations, workspace pages and dated 16 Nov production/customs audit artifacts. No customs RPC, external authority lookup, production query or operational workflow was executed.

## Verdict

**FAIL / BLOCKED — NO-GO for customs-dependent shipment execution, regulatory filing, duty/tax representation, cross-border activation or any claim of official customs clearance.**

KRIM has a meaningful internal customs workflow foundation: broker licensing and jurisdiction binding, independent AAL2 reviews, private document custody, jurisdiction requirement gating, shipment compliance records, and separation of broker document verification from government release. The most serious defects remain fail-open compliance evaluation when zero checks exist, customer-side direct write exposure over compliance gate rows in the dated audit, research-pending/inactive India requirement packs, absence of a callable authority-release evidence workflow, and no approved corridor/country operating evidence. HS classification, sanctions, duties and government-system filing are not proven authoritative operational services.

## Scope reviewed

- Customs workspace: case management, declarations, document custody, broker directory/licence review, HS classification, jurisdiction requirements, sanctions, imports, exports, free-trade zones and audit ledger.
- Customer customs documents, partner customs entry and operations customs-readiness surfaces.
- Migrations for broker assignment, jurisdiction-specific licensing, private document submission/review, evidence custody, requirement register, independent review, document jurisdiction evidence and expiry.
- Dated 16 Nov customs compliance/official release, regulatory clearance/document custody, cross-border execution integration, country activation/corridor controls and customs page audits.

## Positive source controls — PARTIAL PASS

1. **Broker assignment is scoped and controlled.** The reviewed workflow requires AAL2 and an authorized customer/platform/operations actor, active customs organization and an approved current broker licence for the exact jurisdiction. Open proposed/accepted assignments block a second assignment.
2. **Broker licence approval is independent.** Review requires AAL2 platform-admin permission, meaningful review note, reviewer distinct from submitter, active customs organization and jurisdiction, valid licence dates and revalidation of original private evidence owner/path/MIME/size.
3. **Customs document submission is permission-bound.** Customer submitters require shipment-update authority; non-customer submitters must be the accepted active broker with compliance permission. Document type, MIME, size, date ordering and shipment/organization/uploader storage path are constrained.
4. **Document verification is separate from submission.** Review requires AAL2, meaningful note, submitter distinct from reviewer, accepted active broker, current licence for the customs jurisdiction, valid document dates and original private evidence ownership/metadata. Customer and platform-admin paths can reject, but do not substitute for broker verification.
5. **Jurisdiction requirement gate fails closed for submission.** The customs submission trigger requires a currently effective, legally approved jurisdiction requirement. India seed requirements are explicitly marked research-pending/inactive and must not be treated as legal approval.
6. **Broker case transitions do not confer official clearance.** The controlled transition function deliberately excludes `cleared`; broker verification or declaration submission is not a government release.
7. **Corridor shipment-write guards have an approval design.** The reviewed guard requires active corridor, approved-for-activation dossier, mode match, nonzero fully approved mandatory controls with reviewed sources, and approved country operating packs. No such operational approvals were evidenced in the dated snapshot.
8. **Customs evidence and audit events are recorded.** Licence and document review routines write actor, organization, decision and note events; private storage evidence is revalidated at review rather than trusting UI metadata alone.

## P0 — release blockers

1. **Empty compliance check set can be marked `clear`.** The dated 16 Nov audit of `krim_internal_evaluate_shipment_compliance_gate(bigint)` found it counts blocked/rejected, pending/review and expired checks, then writes `clear` when all counts are zero. It does not require a non-empty applicable rule set or prove every mandatory check exists and passed. An unconfigured shipment can therefore look compliant. This is a fail-open design. Current immutable baseline and dated evidence do not establish a later independently verified correction.
2. **Compliance gate rows had a customer-side direct-write integrity exposure.** The dated audit found authenticated customer-organization members could directly INSERT/UPDATE shipment compliance gate rows under an organization-membership policy, including rows with `checked_by=NULL`. This can undermine the trusted evaluator and falsely mark a shipment clear. Current grant/policy state was not re-queried; treat as an unresolved high-priority issue pending current schema and caller/ACL proof.
3. **No official authority-release evidence workflow exists in the inspected source.** Broker document verification and case submission are internal workflow states. The transition RPC deliberately excludes `cleared`; the dated function search found no callable workflow binding government authority, jurisdiction, official release reference, original authority evidence, exact customs case/shipment/declaration, independent verifier, timestamp, correction/revocation history and a controlled terminal transition.
4. **India customs requirements are research-only and inactive.** Dated 16 Nov snapshot found five India requirement records (IEC, import documents, export documents, product-specific LPCO/NOC, ICEGATE filing) with `research_pending`, inactive status, no reviewer/effective date. Source URLs do not constitute legal approval. The submission trigger therefore correctly blocks customs filing; India customs operations cannot be represented as enabled.
5. **Country and corridor operating approvals are absent in dated evidence.** Dated audit reported all 249 country operating packs research-pending, zero approved country packs, zero corridor dossiers and zero corridor controls. Six market catalogue rows are not operational activations. Customs case creation's country-active check does not independently prove market, country operating pack, corridor dossier, controls or legal route authority.
6. **No operational customs supply or completed execution evidence.** Dated 16 Nov snapshot reported zero shipment customs cases, broker assignments, broker licences, customs document submissions, corridor dossiers/controls, shipment document requirements/documents and compliance checks. These are historical counts, not current live assertions. No later Staging journey is evidenced in this gate.
7. **HS classification, sanctions, duty/tax and government filing are not proven authoritative.** Workspace pages and classifiers are not evidence of a maintained official tariff schedule, jurisdiction/cargo-specific classification ruling, binding tariff information, current export-control/sanctions list, tax/duty calculation engine, ICEGATE/customs API integration, filing acknowledgement or authority status. No current official data source, update SLA, version provenance, human reviewer or successful provider transaction was evidenced.
8. **KRIM role boundaries must not imply that KRIM itself is the licensed declarant/broker.** The internal platform can coordinate authorized stakeholders. No evidence establishes that KRIM holds customs broker authorization, is an importer/exporter of record, or may file/represent a shipment for a customer. Filing must be performed by the legally authorized importer/exporter or properly licensed and authorized broker, under documented mandate.

## P1 — regulatory, data and workflow gaps

1. **Compliance evaluator coverage must include all applicable checks.** Required rule set must be derived from origin, destination, transit countries, process, commodity/HS code, end use, origin of goods, mode, value, party roles, restrictions and current legal effective dates. Missing, ambiguous, stale, unreviewed or conflicting rules must block/review, never clear.
2. **Compliance gate table needs canonical write ownership.** Only trusted server-side evaluator/authorized compliance workflow should mutate gate status. Revoke customer direct DML, require evaluator provenance, actor, rule-set version, check coverage and immutable decision events; add negative tests for forged `checked_by`, status and risk.
3. **Obligations, findings, holds and corridor controls need full evaluator integration.** Dated audit identified that the evaluator did not fully incorporate obligations, findings, holds and corridor controls. A green gate must not coexist with an unresolved legal hold, missing obligation or unapproved corridor.
4. **Customs terminal state and evidence lifecycle need formal design.** Preserve distinct states for prepared, submitted, accepted/received, under review, hold, rejected, released and cancelled. An authority-issued release must be independently verified, tied to the exact declaration/case/shipment/jurisdiction, support correction/revocation/supersession, and never be inferred from broker completion.
5. **Broker licence expiry/revocation must invalidate downstream authority immediately.** Test assignment, document review and pending declarations after licence expiry, suspension, organization deactivation or jurisdiction change. Existing accepted assignments must not remain operationally valid merely because approval occurred earlier.
6. **Document supersession and completeness need validation.** Verify current-version rules for commercial invoice, packing list, certificate of origin, permits, bill of lading/air waybill/road note, insurance, product certificates, dangerous goods declarations, customs declaration, duty receipt and inspection certificate. Replaced, expired, rejected or withdrawn evidence must not remain silently current.
7. **Document content correctness is not proven by file metadata.** Ownership, MIME, size and dates do not prove document authenticity, issuer authority, exact goods, quantity/value, consignee, origin, classification or customs declaration match. Require accountable human checks and external authority verification where appropriate.
8. **HS code classification needs a versioned human-reviewed decision record.** Capture nomenclature edition, jurisdiction, tariff item, product composition/function/use, classification rationale, source/version, effective date, reviewer, confidence/dispute and supersession. AI/classifier output is advisory and cannot self-approve tariff classification.
9. **Sanctions/export-control screening requires authoritative lists and matching controls.** No source evidence establishes official list ingestion, update freshness, exact legal person/entity resolution, alias/beneficial-owner matching, false-positive adjudication, licensing/exemption, screening evidence, escalation or audit. Do not describe a static sanctions page as screening.
10. **Duty/tax calculations require jurisdiction and transaction inputs.** Customs value, valuation method, currency/FX, origin/preferential origin, tariff classification, duty measures, excise/VAT/IGST, cess, fees, exemptions, trade remedies, free-trade agreement rules and effective date must be versioned and independently validated. Do not show zero duty or a calculator estimate as a payable/official assessment without verified rules and inputs.
11. **ICEGATE and other government system integration is not verified.** No credentials, authorized account linkage, API contract, filing receipt, acknowledgement, retry/reconciliation, certificate validation or authority outage behavior was tested. Do not claim electronic filing or real-time clearance.
12. **Customs case creation should inherit full route activation checks.** Active country alone is insufficient. Require approved country operating pack, corridor dossier/control set, active market, shipment route and process scope before operational use.
13. **Free-trade-zone and transit/re-export semantics require jurisdiction-specific rules.** Avoid applying generic import/export document checklists to bonded warehouses, FTZ, transshipment, temporary admission, re-export, repair/return or transit movements.
14. **Broker mandate and customer authorization need durable evidence.** Bind the accepted broker assignment to customer mandate, scope, shipment, jurisdiction, process, effective dates, fee and revocation; validate the mandate on every submission/review.
15. **Tenant and role isolation remains untested.** No two-customer/two-broker negative tests were executed for customs case IDs, documents, licences, assignments, HS decisions, declarations, holds, duty details or authority evidence.
16. **No notification, SLA or operational escalation proof.** Broker response deadlines, authority queries, inspection appointments, document deficiencies, holds and release notices need time-zone-aware timers, responsible owner, retries and customer/partner acknowledgement.

## Required isolated Staging acceptance tests

- Prove empty or missing compliance check set yields `review_required`/blocked, never `clear`; missing one mandatory category, stale rule, unapproved source, expired rule or conflicting control must fail closed.
- Attempt customer direct INSERT/UPDATE of compliance gate rows, forged evaluator identity, false `clear`, altered risk/checked_by and cross-tenant writes; all must be denied.
- Exercise compliance for import, export, transit, re-export, multiple transit countries, mode, cargo/HS, origin, destination, end-use, parties, value and exemptions; verify every required check is present and versioned.
- Verify holds, findings, obligations, sanctions hits, corridor control failures and inactive market/country pack block booking/dispatch and customs submission.
- Verify India requirement rows remain inactive until professional review; test effective date, supersession, next-review expiry and source version. Do not activate production requirements as part of QA.
- Test broker licence submit/review with same reviewer, AAL1, non-admin, wrong jurisdiction, expired/future dates, wrong organization, missing/deleted/replaced/wrong-owner evidence and revoked membership.
- Test assignment with customer mandate, exact shipment/jurisdiction/process, broker acceptance, duplicate assignment, revocation, licence expiry and organization suspension.
- Test customs document submission/review for wrong tenant/shipment/case, unsupported type, invalid dates, wrong path/owner/MIME/size, deleted evidence, submitter self-review, stale licence and replacement/supersession.
- Confirm broker document verification or declaration submission can never set official `cleared`.
- Test authority release only with mock, non-production authority evidence; require exact case/declaration/jurisdiction, independent AAL2 verifier, original evidence integrity, authority reference, timestamp, correction/revocation and replay controls.
- Test HS classification with ambiguous descriptions, mixed materials, bundles, parts, end-use, country-specific tariff differences, nomenclature version changes and human disagreement; classifier must return advisory/review state where uncertain.
- Test sanctions screening with exact/alias/near-match/false positive, list version/freshness, beneficial-owner and licensing exception cases using synthetic entities only.
- Test duty/tax calculations with tariff version, valuation, currency/FX date, origin, preference, exemptions, trade remedies and rounding; reconcile against approved test vectors from a qualified customs professional.
- Verify government integration remains clearly NOT CONNECTED unless a sanctioned sandbox/provider test proves identity, request, acknowledgement, duplicate/retry and reconciliation.
- Capture browser traces, RPC inputs/outputs, compliance rule versions, check coverage, gate rows, evidence metadata, broker mandate, authority evidence, audit events and repeatable negative tests.

## Status

| Area | Status | Basis |
|---|---|---|
| Broker assignment and jurisdiction licensing | PARTIAL PASS | Source authorization and licence controls; no Staging journey |
| Broker licence maker-checker and evidence | PARTIAL PASS | AAL2, distinct reviewer, private evidence revalidation |
| Customs document custody/review | PARTIAL PASS | Tenant/role/evidence checks; no full lifecycle execution |
| India regulatory requirement pack | BLOCKED | Dated five rows research-pending/inactive |
| Shipment compliance gate | FAIL | Zero checks can yield clear; dated direct-write exposure unresolved |
| Country/corridor customs activation | BLOCKED | Dated snapshot has no approved operating packs/dossiers/controls |
| HS classification | NOT VERIFIED | No authoritative versioned classification decision evidence |
| Sanctions/export controls | NOT VERIFIED | No authoritative list/update/matching E2E evidence |
| Duty/tax calculation | NOT VERIFIED | No validated tariff/valuation/FX/tax computation evidence |
| Government filing/ICEGATE integration | NOT TESTED | No connected filing/acknowledgement evidence |
| Official authority release/clearance | BLOCKED | No controlled authority-evidence workflow |
| Customs end-to-end operations | NOT TESTED | No isolated Staging journey |

## Safety boundary

No Production or Staging SQL/RPC, customs case, broker assignment, licence, declaration, document, compliance check, hold, duty calculation, sanctions query, authority release, government filing, external authority/provider call, notification or deployment was performed. No secrets or personal importer/exporter records were read. No synthetic users or customs cases were created. The operational counts and live function findings cited from 16 Nov are historical snapshot evidence, not current-live assertions.

## Exit criteria

Do not enable customs-dependent bookings, filing, duty/tax representations or clearance status until the compliance evaluator is fail-closed and its rows are server-owned; country/jurisdiction requirements and corridor controls are legally approved; broker mandates/licences and document custody pass tenant-negative Staging tests; HS/sanctions/duty sources are authoritative, versioned and independently validated; government filing is proven only in an authorized sandbox; and a separate authority-issued release evidence workflow passes independent verification. Until then, KRIM may coordinate document collection and broker workflow as a clearly labeled internal preparation service, but must not claim official clearance.
