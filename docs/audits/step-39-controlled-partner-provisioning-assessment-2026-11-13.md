# Step 39 — Controlled partner provisioning path assessment

Date: 2026-11-13  
Branch: `website/global-launch-readiness`  
Scope: read-only source review of partner signup, partner verification form and available public admin pages. No account, partner organisation, database record, or production setting was created or changed.

## Decision

For the first India pilot, use a **controlled, founder/admin-assisted provisioning process** only if the existing secured backend/admin workflow can create the organisation and attach the correct user membership with audit history. Do not create partner organisations by editing production tables manually, sharing credentials, or bypassing verification.

## Confirmed source behavior

1. Partner signup creates an individual login and explicitly separates that from business verification and activation.
2. The verification form requires an already-active partner organisation linked to the signed-in account. It tells unlinked applicants to stop and contact KRIM support.
3. The form distinguishes Development/Test, Individual/Independent interest, and Registered Business. Test and interest pathways are not commercial approval.
4. The form collects legal identity, operating authority, address, services/coverage and evidence, but selection/upload alone does not establish verified commercial capability.
5. The public admin directory contains general platform/security pages; this review did not establish a clearly exposed, documented partner-organisation provisioning screen or a safe end-to-end provisioning action.

## Safe pilot procedure

- Receive an applicant through the published partner channel; do not ask them to send passwords or OTPs.
- Ask the applicant to create their own partner login and confirm email/MFA.
- Independently collect and verify business identity, authorised representative, operating authority, service scope, geographic coverage and applicable licences/insurance.
- A platform administrator with the required elevated authorization must use a documented, existing backend workflow to create/link the partner organisation and membership. Record who approved it and why.
- Keep organisation lifecycle, compliance and capability status unapproved until human review is complete. Enable only evidence-backed service capabilities and actual coverage.
- Execute the partner agreement and separate commercial/referral schedule after legal/CA review.
- Test a low-risk customer enquiry and partner quote using authorized test accounts before accepting a live shipment.

## Hard stop conditions

Do not onboard commercially if the secured provisioning action cannot be identified, if the applicant's authority/evidence is incomplete, if the organisation is not active and compliant, or if the required service capability is not independently verified. Do not use Development/Test or Individual/Independent interest as a substitute for registered-business approval.

## Status and limitations

This is an operating-control recommendation, not proof that the required admin action currently exists or has been tested. No new self-service provisioning feature was added because creating an organisation/membership is a high-impact tenant-security operation and the correct production RPC, authorization contract and audit behavior were not established by this source review.

PR #65 remains open, unmerged and undeployed. The staging project remains empty; production migration-history recovery and safe staging validation remain separate launch blockers.
