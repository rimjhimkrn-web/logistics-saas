# KRIM Customer Ecosystem — Phase 1 Entry & Access Audit
**Audit date:** 2026-10-23  
**Scope:** Public entry → customer registration → email confirmation → sign-in → organization membership → MFA → customer workspace → recovery/logout  
**Repository:** `rimjhimkrn-web/logistics-saas`  
**Status:** **BLOCKED — repository checks pass; live end-to-end acceptance evidence is still required.**

## Executive result

The Phase 1 source audit found one confirmed deployment-base defect in the customer booking authentication handoff and one inconsistent client-side password minimum. Both have been corrected in source and guarded by the production smoke test. No production database records, schemas, secrets, or customer pages were deleted.

## Evidence completed

- Inventoried **1,122 repository paths** from the GitHub tree.
- Audited **17 entry/access/workspace pages** and **158 literal local links**. The follow-up scan found **zero unresolved literal local links** across those pages.
- Reviewed the homepage, public access portal, customer signup, sign-in, email callback/verification, MFA enrollment, password recovery/reset, logout, customer workspace and canonical booking request.
- Added Phase 1 authentication and route assertions to `scripts/krim-production-smoke.mjs`, including public/privileged access separation, active membership checks, MFA routing, email callback/provisioning, password recovery, global logout, custom-domain booking return paths and consistent password minimum.
- GitHub Actions production smoke test passed on commit `894a8716741198070d4d37f622044675c2f57b1f`: https://github.com/rimjhimkrn-web/logistics-saas/actions/runs/39967243066

## Corrections made

### 1. Booking authentication handoff was tied to the GitHub Pages prefix

**Finding:** `public/shipper/booking-request.html` used hardcoded `/logistics-saas/` paths for login, workspace navigation, manifest, terms and its rate-calculator follow-up. Those paths are not portable to a root-mounted custom domain such as `krimlogistics.com`.

**Correction:** Changed these destinations to relative paths that work from the booking page in either a GitHub Pages project path or a root-mounted deployment. The sign-in page now accepts only exact same-origin booking return paths for both deployment shapes; it does not accept arbitrary redirect destinations.

### 2. Password minimum was inconsistent

**Finding:** Customer signup required 10 characters while the reset form required 12.

**Correction:** Customer signup now requires at least 12 characters in both password fields and in client-side validation, aligned with the reset form. The Supabase Auth server-side password policy still needs configuration verification; a browser form alone is not a security boundary.

## Global interface standardization

- Approved and recorded the canonical interface standard in `docs/KRIM_GLOBAL_INTERFACE_STANDARD.md` and the product decision record in `docs/decisions/2026-10-23-global-interface-standard.md`.
- Added `core/krim-global-interface.css` with shared navy/blue/cyan tokens, consistent surfaces and cards, form controls, action buttons, focus visibility, status feedback and mobile spacing.
- Applied the shared interface layer to the nine Phase 1 identity pages: access portal, signup, sign-in, forgot password, reset password, auth callback, MFA enrollment, email verification and logout.
- Added smoke-test guards so these pages cannot silently lose the shared shell or stylesheet.
- This is the first controlled adoption batch, not a claim that all 1,122 repository paths have already been visually migrated. The same standard is mandatory for every subsequent page/workspace batch.

## Source-level route and access observations

- The public homepage points to the public access portal; no privileged administrator route was found in homepage/access-portal link attributes.
- The customer access card links to canonical `auth/signup.html` and `auth/login.html?role=customer`.
- Signup writes customer/company metadata through Supabase Auth and uses the auth callback for email-confirmation flow. Organization provisioning is requested through the established customer provisioning RPC; a returned authenticated session is routed to MFA enrollment.
- Sign-in queries active `krim_organization_members` membership before workspace routing and rejects platform-administrator access through the public sign-in route.
- Password recovery targets the canonical reset page; reset requires a recovery session, enforces MFA when indicated, updates the password and requests global sign-out.
- MFA enrollment requires a session and verifies an authenticator challenge. Logout requests global Supabase sign-out.
- These are source observations and automated source guards—not proof that email delivery, provider settings, RLS or every live RPC succeeds.

## Outstanding acceptance gates

Phase 1 **must remain open** until the following are tested against the deployed site and live Supabase configuration:

1. New customer registration with email confirmation enabled and with immediate-session signup, if that configuration is supported.
2. Email delivery, valid confirmation, expired/invalid confirmation and resend recovery.
3. Customer organization provisioning: confirm exactly one intended organization/membership is created and the user reaches the correct workspace.
4. First-login MFA enrollment, correct/incorrect codes, subsequent MFA challenge and refresh/session persistence.
5. Password reset: valid, expired and reused links; correct/incorrect MFA; updated-password sign-in; session revocation.
6. No-session, no-active-membership, wrong-role and multiple-workspace routing paths.
7. Sign-out, browser back/refresh after sign-out and sign-in again.
8. Test the booking → sign-in → return-to-booking journey on both the GitHub Pages project URL and the custom domain after deployment completes.
9. Verify the Supabase Auth server-side password minimum is at least 12 characters and review the available password-protection settings.

## Change control

- No database migration or production data mutation was performed in this audit.
- No duplicate page was deleted.
- Confirmed route and policy fixes were made in existing canonical files; the smoke test now guards against regression.
- The production smoke test passing is necessary but not sufficient to close Phase 1.

## Exit decision

**Phase 1 status: BLOCKED — live acceptance tests outstanding.**  
**Repository/static checks:** PASS (including the global-interface regression gates).  
**Deployed browser end-to-end tests:** NOT YET PERFORMED.  
**Live Supabase provisioning/MFA/recovery evidence:** NOT YET CAPTURED.  
Do not mark Phase 1 VERIFIED until all required live tests pass and their evidence is recorded.
