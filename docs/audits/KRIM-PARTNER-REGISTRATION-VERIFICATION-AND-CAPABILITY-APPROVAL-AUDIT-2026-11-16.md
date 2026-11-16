# KRIM Partner Registration, Verification and Capability Approval Audit — 2026-11-16

## Scope and method
Read-only review of live production function definitions and counts, plus repository source for:
- `auth/partner-signup.html`
- `auth/partner-signin.html`
- `public/partner/partner-onboarding.html`
- `public/partner/services-capabilities.html`
- `app/platform-admin/partner-verification.html`
- `app/platform-admin/partner-capabilities.html`

No partner account was created, no document uploaded, no review function called, and no production data changed.

## Live production counts
- Partner-type organisations: 3
- Partner verification cases: 1
- Partner capability records: 1
- Pending capabilities: 1
- Verified/approved active capabilities: 0
- Partner compliance evidence: 0
- Partner compliance reviews: 0
- Partner service-area records: 0
- Partner rate-card records: 1
- Partner shipment-capacity commitments: 0

These counts do not establish that any organisation is a verified, operationally bookable provider. The lone rate-card row must not be interpreted as a currently usable or accepted market offer without its status, effective dates, partner linkage and eligibility revalidated.

## Controls verified

### 1. Self-service partner organisation provisioning
`krim_provision_partner_organization`:
- Requires an authenticated `auth.uid()`.
- Serializes creation per user with an advisory transaction lock.
- Rejects multiple active partner organisations for one user and returns an existing active partner organisation if one is already linked.
- Creates a new partner organisation with lifecycle `verification_pending`, verification `pending`, compliance `pending`, and onboarding `in_progress`.
- Creates owner membership and owner/partner role assignments, a verification case, and an audit event.

This creates a workspace identity, not a verified carrier. The active organisation/member status is a technical onboarding state and must not be treated as commercial approval. All downstream partner actions must independently gate on verification, compliance, service capability, country and route approval.

### 2. Business verification submission
The onboarding page:
- Requires an authenticated session and resolves one active partner organisation.
- Prevents ambiguous multi-partner organisation selection.
- Uploads documents to the `krim-partner-verification` storage bucket under an organisation/user-specific path.
- Separates registered business from individual-interest and development/test pathways.
- Calls the multi-category onboarding RPC and explicitly tells the applicant that the submission is pending human review and commercial access remains restricted.

The database submission function checks the caller's active membership in the matching registered-business organisation, validates the declared categories and active country coverage, and validates document path shape. The legacy single-category submission function checks that document objects exist in the private bucket; the final approval function additionally checks that every stored verification document is owned by the recorded original submitter.

### 3. Verification decision controls
`krim_admin_review_partner_verification`:
- Requires authenticated user, AAL2 and `admin.platform`.
- Locks the verification case and only accepts open/in-review/pending-information cases.
- Approval requires registered-business mode, active logistics organisation, required business identity/location fields and at least one document.
- Approval checks private-bucket object existence and ownership by the original submitting user.
- Approval changes verification to verified and lifecycle to approved, but deliberately leaves compliance pending.
- Rejection restricts the organisation and marks compliance non-compliant.
- Writes a review decision and audit event.

The platform-admin page separately checks privileged access/MFA and requires an approval rationale. Signed evidence preview URLs expire after 60 seconds.

### 4. Capability submission and approval
The partner capabilities page distinguishes declared capabilities from approved ones and uploads supporting evidence for review. The administrator capability queue:
- Requires AAL2 and platform-superadmin access.
- Shows evidence-backed pending submissions and reports incomplete submissions separately.
- Approval requires registered-business mode, active organisation, verified organisation, eligible lifecycle and current compliance.
- Requires evidence paths in the organisation/user/capability path and verifies private storage ownership by the original submitter.
- Rejects standard approval for hazardous-goods and refrigerated capabilities pending specialist controls.
- Validates country, transport mode, effective dates and weight limits.
- Prevents the capability submitter from approving their own capability.
- Records an audit event.

## High-priority gap

### P1 — Verification-case approval does not visibly enforce submitter/reviewer separation
The inspected `krim_admin_review_partner_verification` body checks AAL2 and platform-admin permission, and validates that the evidence belongs to the original submitter. It does not visibly compare the case's submitter identity with the reviewing administrator before approving. This differs from the explicit submitter/reviewer separation in the capability approval function.

This is a separation-of-duties gap in the inspected function body, not proof that an actual self-approval has occurred. Before changing it, inspect all wrapper/internal review paths, existing triggers and audit requirements, then add an explicit reviewer-versus-submitter guard through a reconciled migration and staging tests.

## Additional controls to verify
1. Confirm every registered-business verification document upload is validated for owner, MIME type, size, count, and path both at upload and approval; confirm cleanup does not remove already-submitted evidence.
2. Confirm partner organisation role assignments do not confer operational authority before verification/compliance/capability gates pass.
3. Confirm each partner page and each RPC independently requires an approved capability for the exact service, active country, coverage area, route leg and time window.
4. Review the one rate-card record for current status, organisation, capability, effective period, currency and acceptance. Do not expose or use it as a bookable rate until verified.
5. Add explicit independent reviewer controls for organisation verification, compliance evidence, service capability, specialist service approvals and any changes to verified legal identity.
6. Stage-test rejection, pending-information, resubmission, expired evidence, reviewer conflict, revoked capability, country deactivation, and stale capacity.

## Release decision
The partner onboarding architecture has meaningful safeguards and keeps initial applicants pending. However, the live production snapshot has zero verified active capabilities, zero compliance evidence/reviews, zero service-area rows and zero capacity commitments. KRIM therefore has no evidence of an operationally activated partner network.

No production changes were made. Do not alter functions, policies or migrations until the repository/production migration history is fully reconciled. After reconciliation, address reviewer separation, validate every downstream action gate, and run full staging tests before enabling commercial use.
