# C3.53 — Global partner verification, compliance, capability, service-area and operational activation readiness

**Programme:** KRIM GLOBAL PLATFORM — AI QUALITY ASSURANCE, SIMULATION & RELIABILITY PROGRAMME  
**Phase:** 00 — Infrastructure Audit  
**Gate:** C3.53  
**Baseline:** `72d75a18f985ceb09e468839435ee95700e11e46` (immutable source baseline)  
**Audit date:** 2026-11-25  
**Method:** Read-only static source and migration review. No live database, Auth, Storage, provider or application mutations.

## Verdict

**FAIL / BLOCKED — NO-GO for representing any partner, mode, service, location, capacity or corridor as operationally available until its complete eligibility chain is proven in isolated Staging and independently verified.**

This is a source-level audit, not a runtime test, penetration test, legal/compliance certification or confirmation of current live database state.

## Scope reviewed

- Partner verification administration: `app/platform-admin/partner-verification.html`
- Partner compliance administration: `app/platform-admin/partner-compliance.html`
- Capability review: `app/platform-admin/partner-capabilities.html`
- Service-area review: `app/platform-admin/partner-service-areas.html`
- Staging review previews: `app/admin/staging/page-02-partner-verification.html`, `page-03-partner-compliance-review.html`, `page-04-partner-capability-review.html`
- Partner submission surfaces: `public/partner/services-capabilities.html`, `public/partner/service-coverage.html`, `public/partner/compliance-evidence.html`
- Relevant migrations for verification evidence, separation of identity verification from compliance activation, compliance review/evidence, capability submission/review, country/mode validation, current-compliance gating and marketplace visibility.

## Positive source controls — PARTIAL PASS

1. **Identity verification is separated from compliance activation.** Migration `20261107090000_separate_partner_verification_from_compliance_activation.sql` changes identity approval to verified/approved with compliance pending and onboarding submitted, rather than immediately asserting completed/compliant/active.
2. **Verification approval has evidence gates.** The reviewed approval RPC requires core business identity/location metadata and at least one document in the private partner verification bucket, and records the decision.
3. **Compliance review is privileged.** The compliance review RPC requires authenticated AAL2 and platform-admin permission, locks the organization row, validates a registered-business organization with verified identity, requires a country jurisdiction and exactly four baseline check entries, and records review/audit state.
4. **Compliance evidence submission has stronger ownership checks.** The partner submission RPC validates the manager's organization permission, category uniqueness, path shape, Storage object owner, MIME type and file size.
5. **Capability submission is pending by default.** The reviewed RPC requires partner-manager permission, active organization/mode, a recognized active country, bounded service/evidence input and private evidence objects; it creates inactive pending capability state and an audit event.
6. **Capability approval is evidence- and eligibility-gated.** The admin review function requires verified registered-business identity, current compliance, active country and transport mode, submitted evidence and an approval rationale. It records before/after state and audit event.
7. **Commercial actions have a current-compliance helper.** `private.krim_partner_compliance_is_current` requires active organization, registered-business mode, verified identity, eligible lifecycle, latest approved review and a future non-null validity deadline. Related migrations apply this gate to selected capacity, assignment and marketplace/rate visibility paths.
8. **Service capability and coverage are distinct from mere signup.** The source model has separate organization, compliance, capability and service-area governance surfaces; legacy public verification pages redirect to the authenticated partner workspace rather than claiming a verified workflow.

## P0 — release blockers

1. **No complete deployed eligibility proof.** No isolated Staging evidence proves that every partner-facing commercial and operational entry point checks the same current chain: organization active + verified identity + current compliance + approved capability + active country/mode + effective dates + exact route/leg coverage + available capacity + required vehicle/driver/facility eligibility.
2. **No exhaustive route/leg-to-capability proof.** Static migrations show exact-leg capability and capacity controls in selected flows, but no complete caller-to-RPC matrix proves that all quote, rate-card, marketplace, assignment, dispatch, warehouse, customs and enterprise paths enforce identical eligibility and fail closed.
3. **No runtime proof of revocation/expiry propagation.** Expired compliance, suspended/restricted partner, withdrawn/expired capability, inactive country/mode, service-area change and capacity exhaustion have not been tested against existing marketplace visibility, accepted assignments, future dispatch and cached/client state.
4. **No operational evidence that service-area claims are grounded.** A coverage declaration or approved capability is not proof of actual partner availability, capacity, pricing, equipment, operating hours, customs authority or corridor readiness. No verified partner/corridor inventory or operational fulfilment evidence was established in this gate.

## P1 — important findings

1. **Compliance validity is optional at review input but mandatory for commercial eligibility.** The compliance review function permits `p_valid_until` to be null; the current-compliance helper requires a non-null future `valid_until`. An approval without a deadline can therefore set organization compliance to compliant while the commercial eligibility helper still returns false. This is fail-closed, but creates a misleading approval state and likely onboarding/operations confusion. Require a bounded validity date for approval or explicitly model non-expiring jurisdictional decisions.
2. **Compliance review evidence-owner validation is weaker than the submission RPC.** In the admin review loop, verified evidence paths are checked for organization-prefixed path shape and object existence, but the reviewed code does not repeat the submitter/Storage-owner, MIME and size checks performed by the evidence-submission RPC. The authoritative evidence-table relationship and all write paths need verification.
3. **The four-check compliance model is fixed.** The workflow hard-codes business registration, tax registration, operating authority and liability insurance. Jurisdiction-, mode-, cargo- and service-specific obligations are not represented by this baseline set; applicability and reviewer rationale need a controlled jurisdictional ruleset.
4. **Verification and capability evidence paths are not uniformly bound to immutable evidence records.** Some reviewed checks rely on path strings in metadata/JSON and Storage object existence. Evidence versioning, supersession, deletion protection, reviewer-visible provenance and retention are not proven end to end.
5. **Approval and operational activation are separate but not fully explained by user-facing status.** The code intentionally separates identity approval, compliance approval and capability approval. The UI and public/customer surfaces must avoid treating any one of these statuses as a general “verified/available” badge.
6. **Global service-area completeness is unverified.** Country and transport-mode catalogue references exist, but no end-to-end proof covers region/subregion normalization, geospatial boundaries, time-zone/operating-hour constraints, cross-border permissions, customs jurisdiction, currency, route directionality or effective dates.
7. **AAL2 and administrator authority need deployed ACL confirmation.** Static function checks exist, but complete function-owner, SECURITY DEFINER, search_path and EXECUTE grant/caller inventory remains open under C3.44/C3.51.
8. **No browser or workflow test was executed.** Admin queues, partner submissions, rejection/resubmission, evidence replacement, expiry, service-area approval and commercial gating remain NOT TESTED.

## Required acceptance tests in isolated Staging

- Submit valid, incomplete, malformed, duplicate, wrong-organization and wrong-owner verification documents; verify no approval on invalid evidence.
- Verify identity approval leaves compliance pending and does not expose commercial opportunities.
- Exercise all four compliance categories, duplicate/missing checks, verified/not-applicable/pending/rejected states, invalid evidence, wrong owner, missing validity and expired validity.
- Verify only AAL2 authorized reviewers can list/review; test AAL1, wrong tenant, non-admin and anonymous denial.
- Submit capabilities across road/rail/air/ocean/warehouse/customs and multiple active/inactive countries/modes; test missing evidence, wrong organization, unsupported service and duplicate submissions.
- Approve/reject/re-submit capabilities; verify evidence and audit provenance, effective dates and immediate marketplace/quote/assignment changes.
- Test service-area boundaries, exact-leg corridor fit, route direction, time zone, country status, capacity, vehicle/facility and driver eligibility.
- Suspend/restrict partner, expire compliance/capability, deactivate country/mode and exhaust capacity; verify every affected commercial and dispatch path denies or safely withdraws eligibility.
- Confirm all customer-facing availability, rates and service claims are based on currently verified partner capability and capacity—not generic platform coverage.
- Capture reproducible browser traces, RPC request/response, database before/after state, audit events and negative-test evidence.

## Status

| Area | Status | Basis |
|---|---|---|
| Identity verification source controls | PARTIAL PASS | Evidence and admin review guards found; runtime not tested |
| Compliance evidence submission | PARTIAL PASS | Ownership/MIME/size checks in reviewed RPC |
| Compliance decision and expiry | PARTIAL PASS | AAL2, four-check and audit controls; nullable validity mismatch |
| Capability submission/review | PARTIAL PASS | Pending-by-default, country/mode/evidence and review guards |
| Service-area / exact-leg coverage | BLOCKED | Full end-to-end route and operational proof absent |
| Revocation/expiry propagation | NOT TESTED | No isolated runtime tests |
| Commercial/dispatch eligibility across all paths | BLOCKED | Exhaustive call-path matrix and deployed negative tests absent |
| Real partner operational readiness | NOT TESTED | No verified partner capacity or live fulfilment evidence established |

## Safety boundary

No Production or Staging SQL/RPC, Auth, Storage, organization, partner, capability, compliance, service-area, payment, notification, provider or deployment action was performed. No credentials or secrets were read. No synthetic users were created. Findings describe the immutable source baseline only; dated historical database snapshots are not asserted as current state.

## Exit criteria

Do not declare partner acquisition or activation safe until the P0 acceptance matrix is implemented and passes in proven isolated Staging, evidence ownership and expiry/revocation behavior are verified, all commercial/dispatch paths are mapped, and an independent reviewer confirms the results.
