# Page 85 — Partner Verification Review
Date: 2026-11-16

## Canonical route
- `app/platform-admin/partner-verification.html`

## Findings and changes
- Requires a signed-in administrator and a successful `global-admin-control` overview response containing platform administrator role; gateway requires MFA.
- Verification cases load through `krim_admin_list_partner_verification_cases`.
- Private document previews are requested as 60-second signed URLs from the private verification bucket.
- The page distinguishes business verification from compliance clearance and capability approval; approval alone does not grant commercial access.
- Changed malformed RPC response handling from silently treating non-array data as an empty queue to an explicit fail-closed error. This avoids a false “zero cases” display when the response contract is broken.

## Safety
- No document preview, approval, rejection, or verification mutation was triggered.
- Database RPC enforcement, AAL2, evidence ownership, and immutable decision audit remain authoritative and require production migration/function reconciliation.
- Frontend evidence-path checks are supplementary, not a substitute for server-side validation.

## Commit
- `38ac6bd127856daa800701a6c7d22dfcb6acd62b`
