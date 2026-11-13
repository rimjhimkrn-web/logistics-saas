# Step 28 — Authentication, MFA and session security audit

Date: 2026-11-13
Branch: `website/global-launch-readiness`
PR: #65 (draft, unmerged, undeployed)

## Scope reviewed

Source-reviewed the primary sign-in flow, email confirmation callback, TOTP enrollment and challenge, password recovery/reset, account security/session actions, privileged admin sign-in/guard, and older route/session guard scripts. No live sign-in or recovery email was triggered.

## Verified source-level controls

- Primary public sign-in resolves active organization memberships and role mappings before selecting a workspace. A requested workspace is treated as a preference and checked against the user's authorized memberships.
- The normal login journey checks verified TOTP factors and routes users to enrollment or an AAL2 challenge before workspace navigation.
- Email confirmation callback validates the returned Supabase session, provisions customer/partner organization context, checks partner pathway metadata, and routes to MFA enrollment/challenge.
- Password recovery uses a generic response that does not disclose whether an email address belongs to an account.
- Admin UI calls the `global-admin-control` Edge Function to verify server-side privilege; its browser-side guard also calls that function. Client-side page hiding is not the authorization boundary.
- Account security page accurately describes its active-session action as local-browser sign-out rather than claiming to revoke all devices.
- Legacy `js/guards.js` and `js/session.js` rely on a client-side localStorage session/role object. They must not be treated as authoritative authorization. Backend RLS, permission checks and server-side role validation must protect all data/actions.

## Fix completed

### MFA post-challenge workspace routing

The dedicated `auth/mfa-challenge.html` route previously defaulted unknown or missing role metadata to the customer workspace and omitted operations/platform-admin from its destination map.

Changed it to:
- include operations and platform-admin destinations; and
- send unknown/missing role metadata back to sign-in rather than silently assigning customer workspace navigation.

Commit: `9bd97239481819d54d868bc2bf6a8f5074b4fe46`.

The updated file was fetched again and both the new role routes and safe fallback were confirmed in source.

## Remaining issues / test gates

1. The account reset form currently advertises a minimum of 8 characters, while customer signup requires 12 and partner/driver signup require 10. Align the password policy across all registration, reset and change-password journeys with the Supabase Auth configuration before launch; do not assume a frontend minlength is the backend policy.
2. The older localStorage-based guard/session scripts are unsafe if any protected route still relies on them. Before launch, inventory all script references and either retire these legacy guards or prove every sensitive route/action is independently protected by Supabase session, RLS and server-side permission checks.
3. The recovery, reset, MFA enrollment, MFA challenge and session-management flows need controlled tests for expired/used links, factor removal/re-enrollment, wrong/replayed codes, session expiry, token refresh, multi-tab behavior, account recovery and cross-role routing.
4. Confirm Supabase Auth settings: allowed redirect URLs for the GitHub Pages project path and any final custom domain, email templates, password length/strength, rate limits, session lifetime and MFA policy. These dashboard settings were not inspected in this source-only step.
5. Verify admin Edge Function AAL2 and platform-admin permission enforcement in deployed function source/config and database grants. No production SQL or Edge Function execution was performed in this audit.

## CI status

GitHub combined commit status returned no status entries and the workflow-run lookup returned no runs for commit `9bd97239481819d54d868bc2bf6a8f5074b4fe46` at audit time. No CI PASS is claimed for this latest change.

## Safety

- No production/staging database changes or SQL execution.
- No account sign-in, password reset email, MFA enrollment, session revocation or admin action.
- No secrets read or changed.
- No merge or deployment.

## Result

Step 28 completed as a source audit with one role-routing correction. This does not certify authentication security or launch readiness; controlled end-to-end testing and backend/configuration verification remain mandatory.
