# KRIM Partner Onboarding-to-Capability Handoff Remediation — 2026-11-16

## Result

A low-risk applicant-journey improvement is implemented in the repository. After a successful registered-business verification packet submission, the onboarding page now reveals a clearly labelled next-stage panel linking to the dedicated Services & Capabilities workspace.

Commit: `3b137e979f1c8d42b62c97a681074ad58882f6c3`

Changed file: `public/partner/partner-onboarding.html`.

No production database, function, policy, storage object, Auth user, partner organization, verification case or capability row was changed. No applicant was contacted and no document was uploaded.

## Why this change was needed

The existing workflow intentionally separates:
1. business identity packet submission;
2. independent identity review;
3. independent compliance review;
4. evidence-backed capability submission;
5. independent capability review;
6. service-area, market/corridor and capacity readiness.

The initial multi-category onboarding RPC creates inactive pending capability declarations as part of the application packet. These rows do not carry the `submitted_by` and `evidence_paths` metadata required by the independent capability approval RPC. That is not a reason to bypass review or automatically approve them. The repository already contains a separate partner-facing capability submission page and RPC, `krim_partner_submit_service_capability_v2`, which accepts 1–5 private evidence paths and returns a pending, inactive capability record. Its submit control is gated until the organization is an active, verified and compliant registered business.

The gap was therefore the applicant-facing handoff: after submitting the business packet, applicants were told that capabilities needed separate evidence/review but were not given a direct next-stage link or a clear explanation that this step becomes available only after identity/compliance clearance.

## Implemented behavior

After the registered-business onboarding RPC returns successfully:
- the page shows a new "Next stage: service capability evidence" panel;
- it explains that the business packet is an application receipt, not approval;
- it explains that identity and compliance review happen first;
- it links directly to `public/partner/services-capabilities.html`;
- it states that each capability remains inactive until an independent reviewer approves it;
- it reminds applicants that service-area, country/corridor and capacity gates still apply;
- it provides a return link to the partner workspace.

The panel is hidden until a successful registered-business packet submission. It is not displayed for development/test or individual-interest pathways. Existing success/failure handling is otherwise unchanged.

## Security and operational boundaries preserved

- No reviewer decision can be made by an applicant.
- No capability is auto-approved or activated.
- The dedicated capability page still requires registered-business organization verification/compliance before allowing evidence-backed submission.
- The capability submission RPC remains responsible for validating organization membership, evidence paths and ownership.
- The independent platform reviewer and AAL2 gate remain unchanged.
- Hazardous-goods and refrigerated capability restrictions remain unchanged.
- No route, market, corridor, service-area, capacity, quote or shipment eligibility is inferred from this UI change.

## Verification status

Source-level checks:
- Confirmed the new panel exists once.
- Confirmed it is initially `hidden`.
- Confirmed it is revealed only in the successful registered-business submission branch.
- Confirmed the target page exists at `public/partner/services-capabilities.html`.
- Confirmed the capability page uses the dedicated `krim_partner_submit_service_capability_v2` RPC and checks the returned capability is pending and inactive.
- Confirmed no SQL migration, RPC definition, storage policy or production data was changed.

Not yet performed:
- Authenticated browser test of registered-business submission.
- End-to-end test of the approval transition from identity to compliance to capability evidence submission.
- Negative cross-tenant evidence ownership and applicant/reviewer separation tests.
- Automated storage cleanup/retry tests for partially uploaded capability evidence.
- Staging test using synthetic organizations and documents.

CI workflows for the commit must pass before this UI change is considered deployment-verified. A successful static link audit does not prove the authenticated workflow.

## Remaining blockers

1. Production migration history is still unreconciled (558 production migration rows versus 363 repository SQL files; substantial timestamp/name mismatch). No production DDL or RPC change is authorized until the sanitized schema manifest and migration crosswalk are complete.
2. The dedicated capability submission page uploads evidence objects before calling the submission RPC. If the RPC fails, the current error path warns that uploaded files may remain. A safe cleanup/retry design needs testing against actual storage delete policies and partial-upload failure cases; do not assume cleanup succeeded.
3. Business compliance checks remain a baseline, not a complete jurisdiction/mode/cargo-specific compliance matrix.
4. Partner approval still does not imply approved service area, corridor, capacity, assignment or bookability.
5. The partner acquisition workflow has not been browser-tested end to end.

## Release decision

This is an applicant guidance improvement only. It does not close the underlying staging-test or migration blockers. KRIM remains **NO-GO for partner commercial activation and real shipment execution** until identity, compliance, evidence-backed capabilities, service areas, market/corridor controls, capacity, contracts and end-to-end staging tests are independently complete.
