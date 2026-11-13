# Step 40 — Existing partner-admin governance controls audit

Date: 2026-11-13  
Branch: `website/global-launch-readiness`  
Scope: read-only review of partner verification, compliance, capability and service-area admin pages plus their relevant migration contracts. No RPC was invoked and no production data was changed.

## Confirmed existing controls

1. `app/platform-admin/partner-verification.html` exists. It checks an active session, calls `global-admin-control`, requires a platform administrator role and presents an MFA-gated verification queue. Evidence previews use 60-second signed URLs. Decisions call `krim_admin_review_partner_verification`.
2. `app/platform-admin/partner-compliance.html` exists. It requires an authenticated AAL2 session and submits four baseline compliance checks through `krim_admin_review_partner_compliance`. Approval requires evidence for verified checks and rationale for not-applicable checks.
3. Separate partner-capability and service-area review pages/RPCs exist. This supports a distinct evidence-backed service approval layer.
4. The migration hardening file `20261113120000_harden_partner_review_mfa_and_approved_lifecycle.sql` adds a database-side AAL2 check to the verification queue/review RPCs and aligns capability review with the approved lifecycle state.

## Critical governance inconsistency found

The older definition of `public.krim_admin_review_partner_verification(bigint,text,text)` sets all of these on business-verification approval:
- `partner_verification_status='verified'`
- `partner_lifecycle_status='active'`
- `partner_compliance_status='compliant'`
- onboarding completed / verified / approved / activated timestamps.

However, the verification page itself says business verification is identity-only and that separate compliance and capability approval are still required. The separate compliance workflow also exists precisely to determine compliance. Automatically setting `partner_compliance_status='compliant'` at the business-verification stage risks presenting an unreviewed organisation as compliant before the independent compliance review has occurred.

The later MFA/lifecycle migration does not, in the reviewed source, correct this compliance-state assignment. Its lifecycle adjustment only changes the capability-review guard to accept both `active` and `approved`.

## Provisioning result

These pages establish that KRIM has administrative review tooling for already-created organisations. They do not establish a safe admin action to create a new partner organisation and attach the applicant's user membership. Therefore the missing organisation-provisioning step remains unverified.

## Required correction before live partner approval

1. Review the deployed function body and current state vocabulary against production before designing a corrective migration.
2. Change the business-verification approval transition so it records identity verification only; it must not set compliance to compliant or mark the organisation commercially active/activated.
3. Ensure the compliance queue can accept the post-verification state and that only the separate compliance approval can set `partner_compliance_status='compliant'`.
4. Keep capability approval and commercial access separate; verify that a partner cannot quote or receive assignments without an active, approved, compliant organisation and a verified capability covering the requested service/market.
5. Identify or implement a documented, MFA-protected, audited organisation creation + membership-link workflow. Validate it in a populated, safe staging environment before production use.

## Decision

Existing admin review surfaces are present, but the end-to-end onboarding control chain is **not yet launch-certified**. The compliance-state transition inconsistency is a critical issue to resolve before any partner is approved for commercial use. Do not approve a real partner or manually edit production organisation records until the deployed function and provisioning path are verified.

PR #65 remains open, unmerged and undeployed. This is static source/migration review only; no production RPC, migration, or customer/partner transaction was executed.
