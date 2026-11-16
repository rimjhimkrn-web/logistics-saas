# KRIM Customs, Regulatory Clearance and Document Custody Audit
**Date:** 16 November 2026  
**Method:** Read-only inspection of live PostgreSQL function definitions, privileges, constraints and triggers. No customs cases, broker assignments, documents, compliance checks or shipment records were created or modified.

## Executive decision
**NO-GO for production customs clearance claims or unrestricted cross-border execution.** The customs module has meaningful controls around broker licensing, jurisdiction, private document evidence, independent review and legal submission approval. However, the current workflow does not expose a callable, auditable authority-evidence path to the terminal `cleared` status; shipment compliance evaluation can report `clear` when no compliance checks exist; and the document gate does not itself prove customs clearance or government acceptance.

KRIM's internal review, document verification, broker assignment and submission tracking must not be represented as official government customs clearance.

## 1. Customs case creation and authorization
Public invoker wrapper `krim_create_shipment_customs_case` delegates to `private.krim_create_shipment_customs_case`.
- Requires authenticated user and `shipment.update` on the shipment's active customer organization.
- Locks the shipment row.
- Requires an active country/jurisdiction.
- Restricts customs process type and rejects negative declared value.
- Uses an advisory lock to prevent duplicate active cases for the same shipment, jurisdiction and process type.
- Creates a `pending` case.

Positive control: the caller cannot create a customs case for a shipment in another customer organization merely by supplying its ID.

Gap: the creation path checks country active state but does not itself prove the country operating pack, shipment corridor dossier, corridor controls or applicable market are approved. Those independent route activation gates must remain mandatory before operational booking/dispatch.

## 2. Broker licensing and assignment
The public SQL wrappers are invoker functions with empty search_path and delegate to private SECURITY DEFINER routines. The private routines are executable by authenticated users but contain explicit authorization checks.

Positive controls:
- Licence submission requires active customs organization membership and `compliance.manage`.
- Licence evidence must exist in the private partner-verification bucket, be owned by the submitting user, and match MIME/size metadata and organization/user path scope.
- Licence approval/rejection requires AAL2, platform admin permission, a meaningful review note and a reviewer different from the submitter.
- Approval rechecks active customs organization, active jurisdiction, validity dates and original uploader-owned evidence.
- Broker assignment requires AAL2 and either customer shipment-update authority or platform/operations compliance/admin authority.
- Broker must be an active customs organization with a currently approved, effective licence for the exact jurisdiction.
- An open proposed/accepted assignment blocks a second assignment.
- Broker acceptance requires AAL2, active broker membership, compliance.view and a currently approved jurisdiction-specific licence.
- Revocation/completion requires AAL2, authorized customer/platform/operations actor and a meaningful note; lifecycle events are recorded.

Assessment: licensing and assignment have good maker-checker and jurisdiction binding controls. Staging must still verify revocation/expiry effects on already accepted assignments and documents, and ensure user-selected actor organization IDs cannot cross tenant boundaries.

## 3. Customs document custody and review
Document submission:
- Requires active submitter organization membership.
- Customer submitters need `shipment.update`; non-customer submitters must be the accepted active customs broker with `compliance.view`.
- Restricts document type, MIME type, size and validity date ordering.
- Requires an uploader-owned private object in the partner-verification bucket with shipment/organization/user path scope and matching metadata.
- Stores a pending-review submission and event.

Document review:
- Requires authentication, AAL2, meaningful review note and pending-review state.
- Submitter cannot review own document.
- Verification requires an accepted active customs broker, current jurisdiction-specific licence, valid issue/expiry dates and original private uploader-owned evidence with matching path and metadata.
- Customer can reject using shipment-update authority; platform admin can reject; only accepted broker can verify.
- Review event records actor and organization.

Positive control: document verification is independent of submission, and verification is not available to the submitting actor.

Staging requirements:
- Test wrong-tenant document IDs, forged actor organization, expired/revoked broker licence, superseded submissions, storage object deletion/replacement, metadata mismatch, duplicate submissions and reviewer identity conflicts.
- Verify bucket policies prevent cross-organization reads and unauthorized signed URL issuance.
- Confirm older verified documents are invalidated or superseded when a replacement is submitted, where the document type requires a single current version.

## 4. Legal jurisdiction gate
Trigger `trg_krim_customs_legal_review_gate` calls `private.krim_guard_customs_submission_legal_review()` before insert/update when a customs case enters `submitted`.
- Requires an active jurisdiction requirement for the case's country.
- Requires `legal_review_status='approved'`.
- Enforces effective-from/effective-until dates.

Positive control: customs submission is blocked without a currently effective, legally approved jurisdiction requirement.

Important limitation: this is a KRIM internal legal-readiness gate. It is not a customs authority's filing receipt, release order or proof of actual clearance.

## 5. Customs case lifecycle — P1 workflow gap
Constraint on `krim_shipment_customs.status` includes:
`pending, prepared, submitted, under_review, hold, cleared, rejected, cancelled`.

However, `krim_customs_transition_case` explicitly permits target statuses only:
`prepared, submitted, under_review, hold, rejected, cancelled`.
Its transition graph contains no path to `cleared`. The function's error text says clearance requires a separate authority-evidence workflow, but a search of public/private customs and clearance routine names found no separate callable clearance routine.

Consequences:
- The UI/API cannot complete the customs case lifecycle through the inspected controlled RPC set.
- A verified customs declaration is required before submission, but that is not the same as a government acceptance or release.
- No routine was found to bind an authority-issued release/clearance reference, issuing authority, jurisdiction, evidence object, verifier, timestamp and validity to the customs case before terminal clearance.

Required design:
- Separate `submitted`, `under_review`, `hold` and internal `document_verified` states from official `cleared`.
- Add an explicit authority-evidence record with issuing authority, jurisdiction, release reference, source evidence, uploader, independent reviewer, verification timestamp, and revocation/supersession state.
- Only an independent AAL2 authorized reviewer should be able to mark authority evidence verified.
- A controlled transition should set `cleared` only when current official evidence is verified, case/shipment/jurisdiction match, broker assignment and licence remain valid, and all required documents/controls pass.
- Record immutable lifecycle events and reject replay/conflicting authority references.
- Never infer official clearance from broker completion, a verified declaration, a local document check, or a manually typed note.

## 6. Shipment compliance gate — P0 fail-open risk
`krim_internal_evaluate_shipment_compliance_gate` counts failed, pending/review and expired compliance checks. If none exist, it writes `clear`.

Therefore a shipment with zero configured compliance checks is treated as clear by this evaluator. The existing production baseline found six readiness-gate rows marked ready but zero configured compliance rules/checks. This means the evaluator's `clear` output is not sufficient evidence that the shipment has passed applicable controls.

Required remediation:
- Resolve the applicable control set from active cargo, origin, destination, transit jurisdictions, mode, commodity/HS classification, hazardous/export-control flags, customs type and corridor.
- If no applicable rules are configured, return `review_required` or `blocked`, never `clear`.
- Require evidence-backed check rows for every mandatory control; track not-applicable decisions with reviewer, reason and source.
- Re-evaluate when cargo classification, jurisdiction, route, mode, partner, shipment documents or rules change.
- Prevent stale `clear` gate state from authorizing booking, dispatch or handover.

This evaluator is internal and service-role only, but its output must not be trusted until the rule-set completeness invariant is implemented and tested.

## 7. Shipment document gate — completeness limitation
`krim_internal_evaluate_shipment_document_gate` blocks required document requirements in `missing`, `submitted`, `expired` or `rejected` states. It returns `clear` when none of those conditions exist.

The requirement table permits `waived`; the evaluator treats waived requirements as satisfied. The current routine does not visibly prove that a waiver was independently authorized, reasoned, jurisdictionally valid or still current. Nor does a clear document gate prove customs clearance.

Required checks:
- Review who can create, modify, waive and delete requirements.
- Enforce AAL2, reviewer independence, reason, evidence/source and expiry for waivers.
- Ensure `satisfied_by_document_id` refers to a currently verified, non-expired document for the same shipment and requirement type.
- Re-evaluate gate after document expiry, rejection, supersession or route/cargo change.
- Keep document completeness, regulatory compliance and government customs clearance as separate gates.

## 8. Corridor and operating-market integration
Current broader operating baseline:
- Six market records are metadata only.
- All 249 country operating packs are `research_pending`.
- No approved corridor compliance dossiers and no corridor controls were recorded in the prior baseline.
- Shipment creation/transition paths require active corridor/dossier/control evidence.

Customs case creation and broker/document functions must not be interpreted as enabling a route or market. A country being active in the countries table is not proof that KRIM is authorized or operationally ready to serve that corridor.

Before any cross-border execution, require approved country operating packs, corridor dossier and controls, partner capability/compliance, applicable customs jurisdiction requirements, cargo-specific rules and verified operating partners.

## 9. Security and test matrix
Run only in isolated staging with synthetic organizations, brokers, licences, shipments and documents:
1. Anonymous and AAL1 attempts against every customs write/review function.
2. Customer, broker, platform and operations tenant boundaries; forged actor organization IDs.
3. Submitter self-review, broker license self-approval and cross-broker review.
4. Expired, suspended, revoked, wrong-country and future-effective broker licences.
5. Missing, replaced, wrong-owner, wrong-path and metadata-mismatched private evidence.
6. Duplicate active cases, duplicate assignments, conflicting retries and concurrent assignment.
7. Legal jurisdiction gate absent, pending, expired, rejected and approved.
8. Missing/empty compliance rule set must not evaluate clear.
9. Missing, submitted, rejected, expired, verified and waived document requirements; waiver authorization.
10. Attempt every possible customs status transition; prove only the dedicated authority-evidence workflow can set `cleared`.
11. Verify shipment dispatch remains blocked until all applicable route, compliance, document, customs and operational gates are satisfied.
12. Verify audit event completeness and evidence revocation/supersession.

## 10. Release decision
**NO-GO for live customs clearance or unrestricted cross-border operations.**
- Broker licence and document controls are promising and substantially permissioned.
- Legal jurisdiction approval is enforced before submission.
- The controlled case transition deliberately lacks a clearance route pending separate authority evidence, but that separate routine was not found.
- Compliance evaluation can fail open when no checks are configured.
- Document gate clear is not customs clearance and waiver governance needs verification.
- Country/corridor readiness remains unapproved in the broader operating baseline.

This review changed no production code, schema, grants, policies or business data. Do not implement production changes until the migration-history collision reconciliation and sanitized schema manifest are complete. Financial collection remains deferred to the final phase.
