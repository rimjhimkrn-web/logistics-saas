# KRIM Customs, Regulatory Documentation and Cross-Border Execution Integration Audit — 2026-11-16

## Scope and method
Read-only review of the live production customs/compliance catalogue, broker licence and assignment records, customs document submissions, jurisdiction requirements, corridor compliance controls/dossiers, shipment compliance checks/gates, relevant PostgreSQL function definitions and selected application pages/migrations. No RPCs were invoked. No customs case, declaration, document, broker assignment, market activation or shipment was created or changed. No external authority/provider was contacted.

## Executive decision
**NO-GO for live customs clearance, regulatory filing, cross-border booking or claims of operational customs coverage.** KRIM has a useful internal document-custody and broker-review foundation, but the live operational evidence is empty, India regulatory requirements remain research-pending, corridor approvals are absent, and there is no controlled authority-issued clearance evidence workflow. The shipment compliance evaluator remains fail-open when no checks exist, and the compliance gate table has a previously identified direct-write integrity exposure.

Internal document review, broker verification, declaration preparation or submission status must never be presented as customs authority acceptance, duty payment or release.

## 1. Live production evidence
Read-only counts at audit time:

| Object | Rows |
|---|---:|
| Shipment customs cases | 0 |
| Broker assignments | 0 |
| Broker licences | 0 |
| Customs document submissions | 0 |
| Customs jurisdiction requirements | 5 |
| Compliance checks | 0 |
| Compliance decisions / findings / holds | 0 / 0 / 0 |
| Shipment compliance gates | 6 (existing baseline; prior audit found all six marked clear with no checker) |
| Corridor compliance dossiers / controls | 0 / 0 |
| Shipment document requirements / documents | 0 / 0 |
| Document records / verifications | 0 / 0 |

The five jurisdiction requirement rows are India-only seeded research records: IEC validity, core import documents, core export documents, commodity-specific LPCO/NOC assessment, and ICEGATE access/filing. All five have `legal_review_status='research_pending'`, `is_active=false`, no reviewer identity/time, and no effective dates. Their source references include DGFT Foreign Trade Policy material and ICEGATE/CBIC portals, but source URLs and a recorded source-check date are not legal approval or proof of current applicability.

Earlier global market/corridor baseline remains unchanged: all 249 country operating packs research-pending; no approved country pack, corridor dossier or corridor control. Six market catalogue records are not operational activations.

## 2. Customs case and broker workflow
The controlled customs transition routine:
- requires authentication and AAL2;
- requires a meaningful transition note;
- binds the case to its shipment and country;
- requires an accepted, active customs broker and a current approved licence for the exact customs jurisdiction for broker transitions;
- requires a verified customs declaration before the case can move to `submitted`;
- permits only the internal states `prepared`, `submitted`, `under_review`, `hold`, `rejected`, and `cancelled`.

There is deliberately no transition to `cleared`; the function explicitly says clearance requires a separate authority-evidence workflow. This is correct separation of internal case handling from government release, but the missing authority-evidence workflow prevents a complete operational lifecycle.

Broker licence review and customs document verification have positive controls: AAL2, independent reviewer (submitter cannot review own evidence), active customs organisation/jurisdiction, current licence dates, meaningful review notes, uploader-owned private object and path/MIME/size metadata revalidation. Accepted broker assignment and jurisdiction licence are rechecked during document verification. These are static controls, not tested workflows; production tables are empty.

## 3. Authority-issued release evidence — P0/P1 design gap
No callable authority-evidence submission/review/verification path was identified that binds all of the following to the customs case:
- issuing government authority and jurisdiction;
- official release/assessment/order/reference number;
- authority-issued original evidence and private object ownership;
- exact customs case, shipment, declaration and broker assignment;
- independent AAL2 verifier, timestamp and review note;
- validity, revocation, replacement and supersession state;
- immutable evidence and lifecycle events.

Do not create or infer a `cleared` state from broker completion, an internally verified declaration, a typed reference, a submitted document or a shipment compliance gate. A future authority evidence record must be independently verified and must match the case, shipment, country, current broker/licence and all required current regulatory controls before a controlled clearance transition is allowed.

## 4. P0 — shipment compliance evaluator treats zero checks as clear
Live definition of `public.krim_internal_evaluate_shipment_compliance_gate(bigint)` counts blocked, review-required and expired rows in `krim_compliance_checks`. If all counts are zero, it writes `status='clear'` with low risk and no blocking reason.

The live check table has zero rows. Therefore an empty/unconfigured screening set is indistinguishable from a completed successful screening. This is fail-open. In addition, the prior authorization audit found six existing gate rows marked clear with `checked_by=NULL`; authenticated customer-organisation members have direct INSERT/UPDATE access under an organisation-membership policy. A customer-side write can therefore undermine the intended trusted evaluator.

Required remediation (not applied):
1. Resolve a non-empty, applicable, approved rule/control set for every shipment's origin, destination, transit countries, cargo/HS attributes, transport mode and customs process.
2. Treat missing, ambiguous, stale or unreviewed controls as `blocked` or `review_required`, never `clear`.
3. Revoke direct authenticated writes to the gate table; allow writes only through a trusted, audited evaluator/workflow.
4. Bind each evaluation to rule-set version, source evidence/version, shipment input fingerprint, evaluator version, actor/worker identity and evaluated time.
5. Re-evaluate on material shipment, cargo, route, jurisdiction, source or rule changes; reject stale gate results at booking/dispatch.
6. Test zero-rule, zero-check, missing-source, expired-source, changed-cargo, changed-route and direct-write attempts in isolated staging.

## 5. Regulatory source and requirement lifecycle
The India jurisdiction register is a research seed, not an approved rule engine. All five rows remain inactive and research-pending. The records have authority/source fields, applicability descriptions, source-checked timestamps and next-review timestamps, but no completed legal review, reviewer, effective dates or operational activation. The seed descriptions themselves correctly warn that generic import/export document lists are only a baseline and that commodity-specific permits, licences, certificates, NOCs and participating-government-agency checks may apply.

Required next steps:
- Use current official primary sources for DGFT/CBIC/ICEGATE and relevant commodity-specific agencies; preserve exact source version, publication/effective dates and retrieval evidence.
- Assign a qualified jurisdiction owner and independent legal/compliance reviewer; record scope, exceptions, exemptions, commodity classification, process, mode, origin/destination/transit, effective period and next review.
- Keep each requirement inactive until verified and approved; do not turn seeded research into an operational pass.
- Add change monitoring and expiry/re-review handling so a formerly approved rule becomes stale/blocked when its source or effective period changes.

## 6. Document completeness and waiver governance
The customer document page clearly states that upload/review is not a declaration, authority filing, duty payment or clearance. It supports common invoice, packing list, origin, permits, transport documents, insurance, dangerous-goods declaration, declaration copy and receipts. That is a useful evidence intake list, but it is not a complete jurisdiction- and commodity-aware checklist.

The previous customs audit identified that waived document requirements may be treated as satisfied. A waiver must not silently count as compliance evidence. Any future waiver should require a documented legal basis, reason, scope, approving independent AAL2 authority, effective period, evidence, audit event and jurisdiction/commodity restrictions. Non-waivable government or safety requirements must never be waived by a platform operator. Missing applicability data must fail closed.

Document version replacement, supersession, re-review on broker licence revocation/expiry, and evidence deletion/replacement should be covered by staging tests. A valid private object and a verified internal document do not establish that the document is legally sufficient or accepted by an authority.

## 7. Broker and responsibility boundary
The application distinguishes customer submission, accepted broker assignment and broker document verification. Maintain these boundaries:
- KRIM is the workflow/technology intermediary unless it separately holds a legally appropriate authorisation.
- The importer/exporter remains the responsible declarant/principal as applicable.
- Only an appropriately licensed and currently authorised broker may perform regulated broker tasks within the licence jurisdiction and scope.
- KRIM must not impersonate an importer, exporter, broker or government authority, or submit via ICEGATE without correct stakeholder identity and documented authority.
- Broker licence approval inside KRIM is an internal verification record, not government endorsement of KRIM or a substitute for checking the issuing authority.

## 8. Cross-border execution dependencies
Customs readiness is downstream of, and cannot replace:
- approved operating packs for every origin, destination and transit jurisdiction;
- an approved corridor dossier with mode-specific controls and current evidence;
- verified partner capability, service area, insurance and capacity for each leg;
- validated cargo/HS code, restrictions, sanctions, permits and product-specific approvals;
- route feasibility, terminal/port/airport handovers and accepted custody;
- verified broker appointment and current jurisdiction-specific licence;
- official declaration filing acknowledgement, assessment/duty evidence where applicable, and government release evidence.

None of these conditions is established by the current production data. No government single-window/ICEGATE integration or external filing receipt was verified.

## 9. Staging acceptance suite (not run)
1. Zero configured checks/rules never produce clear.
2. Missing country pack, transit pack, corridor dossier or mandatory control blocks.
3. Stale/expired regulatory source invalidates prior evaluation.
4. HS code/cargo/process/mode change forces fresh applicability evaluation.
5. Customer cannot insert/update/delete a compliance gate or set it clear.
6. Forged actor organisation, wrong-tenant shipment/case/document and cross-country broker licence are rejected.
7. Expired/revoked broker licence blocks assignment acceptance, document verification and subsequent case transitions.
8. Document uploader cannot review own submission; customer can reject only where authorised; customer cannot verify.
9. Missing/replaced/deleted private object or mismatched MIME/size/path blocks verification.
10. Duplicate/conflicting declaration submission and replay are idempotent and audited.
11. No waiver can bypass a non-waivable control; all allowed waivers have independent approval and expiry.
12. A submitted/under-review customs case cannot become cleared from internal notes, broker completion or document verification.
13. Only independently verified, matching, current authority release evidence permits a clearance transition.
14. Authority evidence revocation/supersession reopens or blocks the case and invalidates downstream execution.
15. Evidence and events remain tenant-scoped and immutable to ordinary users.
16. No route booking/dispatch proceeds while customs or corridor controls are blocked, stale or unresolved.

All tests remain unexecuted. No production writes or live customs activity were performed.

## 10. Release decision and remediation order
**NO-GO** for customs clearance claims, live customs filing, global cross-border booking, or operational market coverage.

Priority order:
- **P0:** fail-closed compliance evaluation; remove customer direct-write path to compliance gates; preserve no-clearance-without-authority-evidence boundary.
- **P1:** complete official authority-evidence lifecycle; approve and maintain India regulatory requirements from current official sources; make waiver governance explicit; bind compliance evaluation to shipment/cargo/route and current source versions.
- **P1:** staging-test broker, document, tenant, licence expiry/revocation, evidence ownership, declaration and authority release journeys.
- **P1:** complete country packs and corridor dossiers before partner/route execution.
- **Final integration phase:** only after legal authorisation, provider credentials and approved stakeholder identity, assess government/ICEGATE integration and external acknowledgement handling.

## Evidence and change boundary
This is a read-only audit report. No SQL DDL/DML, migrations, RPC invocations, storage changes, provider calls, external filings or production data changes were made. The production/repository migration-history mismatch remains unresolved; do not apply, replay, baseline or squash migrations or corrective production DDL until the full schema manifest and migration crosswalk are reconciled and separately authorised.
