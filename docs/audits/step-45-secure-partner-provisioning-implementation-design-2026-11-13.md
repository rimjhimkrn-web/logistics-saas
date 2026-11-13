# Step 45 — Secure partner provisioning implementation design

Date: 2026-11-13
Branch: website/global-launch-readiness
Status: DESIGN COMPLETE — implementation intentionally not deployed.

## Recommended implementation

Build a narrow, dedicated partner-provisioning workflow rather than extending the broad `global-admin-control` action surface.

### Request path

1. A platform administrator signs in and completes MFA (AAL2).
2. A small admin screen collects an existing Auth user ID, legal business name, country, registered-business application reference, and reviewer rationale. It must not collect or expose unnecessary identity-document contents in ordinary form fields.
3. A dedicated Edge Function validates the caller's authenticated identity and current AAL2 assurance, then calls one narrowly scoped database transaction.
4. The database transaction rechecks the caller's platform-admin authority and creates the organisation, initial organisation membership, pending partner lifecycle state and audit event atomically.
5. The applicant is linked to the organisation but receives only the least-privilege partner applicant/member role. No platform role is granted.
6. Existing independent verification, compliance, capability and service-area review workflows continue to control each subsequent gate.

## Database transaction requirements

The eventual migration should implement one private-schema transaction routine with a fixed, reviewed signature and:

- Resolve the actor from the authenticated request context; never trust a client-supplied actor ID.
- Require a currently active platform_admin/platform_superadmin assignment and AAL2 assurance at the database boundary, not just in browser code.
- Confirm the target Auth user exists and is eligible for the registered-business pathway.
- Validate country and organisation type against the canonical supported reference data.
- Create the organisation and its initial membership in the same transaction.
- Set identity verification pending, compliance pending, onboarding submitted, lifecycle pending/review, with zero approved capabilities and zero approved service areas.
- Reject duplicate active organisation memberships and duplicate provisioning requests; use an idempotency key or stable application reference with a unique constraint.
- Write an audit event containing actor, target user, organisation, request ID, reason/reference and action; never put identity documents, tokens or secrets in audit metadata.
- Return only the created organisation/membership identifiers and pending status.
- Revoke EXECUTE from PUBLIC/anon and grant only the required role; use an explicit fixed search_path and review SECURITY DEFINER necessity. Do not expose the routine in the public Data API.
- Enforce reviewer separation: the provisioning actor cannot approve the applicant's identity/compliance/capability evidence if the policy requires an independent reviewer.

## Edge Function requirements

- Dedicated function name, separate from general admin control.
- Authenticate with the caller's JWT; do not accept a user ID or role supplied by the browser as authority.
- Check `auth.getUser()`, MFA AAL2 and active platform role.
- Call the transaction through a user-scoped client so database-side `auth.uid()` and claims remain meaningful; do not use a service-role client to impersonate the actor.
- Validate input shape/length and return structured, non-enumerating errors.
- Apply request-size limits, CORS allow-list appropriate to the deployed KRIM origin, request IDs and rate limiting.
- Never log raw documents, email addresses unnecessarily, JWTs or secrets.

## Admin screen requirements

- Place under platform-admin and reuse existing session/MFA guard patterns.
- Require a real registered-business application and supporting evidence reference before provisioning.
- Show a confirmation summary and explain that provisioning is not approval or commercial activation.
- Do not expose a public self-service path until duplicate handling, abuse controls and support procedures are tested.
- Keep individual-interest and development-test pathways non-commercial and separate.

## Lifecycle state machine

Provisioned: organisation exists; member linked; identity=pending; compliance=pending; capability=none approved; service area=none approved; commercial activation=false.

Then, in order:
1. Identity review → verified or rejected.
2. Compliance review → compliant or rejected.
3. Capability review → one or more capabilities approved or rejected.
4. Service-area review → specific country/region/service coverage approved or rejected.
5. Commercial eligibility check → active only when all required gates and evidence are current.

No single provisioning action may skip or set any of these later approvals.

## Mandatory tests before any production rollout

- Unauthenticated request rejected.
- Authenticated non-admin rejected.
- Admin without AAL2 rejected.
- AAL2 admin with revoked/inactive role rejected.
- Unknown Auth user rejected.
- Unsupported country/business type rejected.
- Duplicate request is idempotent and creates no duplicate organisation/member.
- Concurrent duplicate submissions create exactly one organisation/member.
- Applicant cannot create or self-approve their own organisation.
- Provisioning actor cannot self-approve where separation is required.
- Membership belongs to the created organisation and applicant only.
- No commercial quote/booking eligibility before all required reviews.
- Cross-tenant reads and writes denied.
- Audit event is created atomically; transaction failure leaves no partial organisation/member.
- Existing customer signup, partner application and admin review paths remain regression-tested.

## Migration and rollout gate

Do not implement this against production yet. Production has 425 applied migrations, staging has zero, repository history has 12 duplicate version IDs and significant source drift. First recover canonical migration provenance or approve a separate disposable non-production baseline-reconstruction plan. Then implement and test this design in that environment, run security advisors and negative tests, review the exact migration, and obtain explicit production rollout approval.

## Step 45 verdict

The recommended path is a **dedicated AAL2-gated Edge Function + atomic private database transaction + minimal platform-admin screen**. It is safer and more auditable than direct SQL, broad role assignment, or adding another loosely scoped action to `global-admin-control`.

No code, migration, database record, role, membership, secret, partner approval, production setting, merge or deployment was changed in this step.
