# Step 41 — Live partner-verification lifecycle recheck

Date: 2026-11-13
Scope: read-only inspection of the live KRIM production database after Step 40 identified a possible lifecycle/compliance state conflation.

## Result

The current deployed production function does **not** reproduce the risky behavior described in the Step 40 historical/static finding. The live definition of `public.krim_admin_review_partner_verification(bigint,text,text)` now sets, on approval:

- `partner_lifecycle_status='approved'`
- `partner_verification_status='verified'`
- `partner_compliance_status='pending'`
- `partner_onboarding_status='submitted'`

It records the verification case decision and an audit event. It does not set compliance to compliant, does not mark onboarding complete, and does not set a commercial activation timestamp in the inspected body.

The live compliance-review function is a separate AAL2 + platform-admin gated workflow. It requires an active registered-business organization with verified identity, four baseline checks, evidence validation, reviewer rationale and (for approval) a validity date. Only its approved decision sets `partner_compliance_status='compliant'`; its response explicitly returns `commercial_activation=false`.

The live capability-review function separately requires current compliance, active country and transport mode, private evidence owned by the original submitter, and separation of submitter/reviewer before it can activate a capability. The service-area review also checks current compliance, approved country operating pack, matching active capability and submitter separation.

## Reconciliation with Step 40

Step 40 reported a conflicting older function body that automatically set compliance to compliant during identity verification. The live production definition retrieved in this step is materially different and reflects the safer separation of identity verification, compliance clearance and capability activation.

Therefore, the earlier finding must be treated as a historical/source-version discrepancy, not as a confirmed current production defect. The exact deployment/change history that introduced the safer live function is not yet reconciled with the repository migration history. This does not resolve the broader 425-production-migration versus 265-branch-file history drift documented in Step 36.

## Decision

- Do not apply a corrective migration: the inspected live function already has the intended separation of states.
- Do not change production data, functions, schema, settings or secrets.
- Preserve the existing separation: identity verified -> compliance pending -> compliance independently reviewed -> capability independently reviewed -> service area independently reviewed.
- Before any partner is commercially listed, verify its current organization state, current compliance validity, active verified capability, approved service area/country operating pack and human-reviewed evidence.
- Continue migration-source reconciliation before proposing further production DDL.

## Verification boundaries

This was a read-only function-definition inspection. No partner records were changed; no RPC was invoked; no migration was applied; no customer or partner end-to-end transaction was run. The result confirms the inspected function definitions, not the operational readiness of any individual partner or the full marketplace.

## Next blockers

1. Reconcile the exact source commit/migration that produced the current live verification function.
2. Recover and reconcile the complete production migration history before schema changes.
3. Validate a real partner through the full human review chain only after an authorized partner application exists.
4. Run cross-tenant and lifecycle negative tests in a properly reconstructed non-production environment.
