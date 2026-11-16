# KRIM authentication entry journey — first functional pass
**Date:** 2026-11-17  
**Scope:** Public access portal → customer/partner/driver registration → email confirmation callback → sign-in → organization membership → MFA → canonical workspace routing.

## Current result
**PARTIAL — frontend recovery fix committed; authenticated end-to-end acceptance is still required.** This work does not certify all identity and workspace paths as production-ready.

## Defect corrected
Partner registration stores the selected pathway in Supabase user metadata and the email-confirmation callback provisions the partner organization before calling `krim_set_partner_account_mode`. If organization provisioning succeeds but the mode RPC fails or the callback is interrupted, the user can return to sign-in with an active partner membership but a null `partner_account_mode`. The previous login recovery path only retried organization provisioning when membership was absent, so it could not repair this partial state.

The shared `auth/login.html` flow now:
- fetches `partner_account_mode` with the organization record;
- identifies the user's partner organization from active membership;
- retries `krim_set_partner_account_mode` only when the database mode is missing and the original signup metadata contains a supported pathway;
- uses the original stored partner profile;
- never overwrites an existing mode;
- fails closed with a support reference if recovery fails.

**Commit:** `56a93564976e6fca3d45a78e19ad29cbdf61d92d`

## Read-only backend controls verified
- Customer organization provisioning is SECURITY DEFINER and uses a per-user advisory transaction lock; it reuses an existing active customer/enterprise membership before creating a new organization.
- Partner organization provisioning is SECURITY DEFINER and uses a per-user advisory lock; it refuses ambiguous multiple active partner organizations and creates a pending verification case for a new partner organization.
- Partner mode selection is SECURITY DEFINER, requires exactly one active partner organization, validates mode/profile and prevents switching an approved/active partner into a non-commercial mode.
- Driver self-provisioning requires driver account metadata, is idempotent for one active driver organization and creates a limited driver organization; it does not approve driver evidence.
- Driver invitation acceptance requires confirmed matching email, a single-use unexpired token, and currently eligible registered/compliant carrier state.
- Organization membership SELECT policy is scoped to the authenticated user's own membership rows. Organization SELECT is scoped to active membership or AAL2 platform administrator permission.

## Remaining acceptance tests (must run in isolated staging)
1. Customer registration with immediate session and with email confirmation; verify exactly one customer organization and one owner membership.
2. Partner registration for registered-business, individual-interest and development-test pathways, each with immediate session and email confirmation.
3. Simulate interruption after partner organization provisioning but before mode selection; sign in and verify the new recovery path completes the original selected mode exactly once.
4. Verify existing non-null partner modes are never overwritten by stale user metadata.
5. Verify missing/invalid mode metadata does not create commercial eligibility or silently infer a pathway.
6. Driver self-registration and carrier invitation acceptance; verify invitation email binding, expiry, replay and revoked invitation denial.
7. MFA enrollment, challenge, aal1 denial where aal2 is required, and aal2 success.
8. Direct workspace URLs with signed-out, wrong-role, inactive-membership, multiple-membership and cross-organization users.
9. Confirm logout/session revocation, password recovery and email callback expiry behavior.
10. Run all role journeys on mobile and desktop and verify canonical GitHub Pages base-path behavior.

## Production boundary
No production database writes or authentication tests were executed. Do not create real test accounts in production, accept real invitations, change roles, or modify MFA/security settings as tests. Do not change database functions, policies or grants until migration reconciliation is complete. Frontend recovery does not replace backend authorization.

## Closure criteria
Mark this journey CLOSED — VERIFIED only after all staging acceptance tests above pass, CI and deployment pass, and independent negative authorization tests prove that a workspace URL or user metadata cannot grant access. Any real regression or security issue can reopen it.
