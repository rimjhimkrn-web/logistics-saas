# KRIM authentication security follow-up — callback, partner and logout controls
**Date:** 2026-11-17  
**Status:** SAFETY DEFECTS PATCHED; END-TO-END CLOSURE STILL PENDING.

## Additional defects found during continuation
1. **Email confirmation callback bypassed role-checked sign-in.** After exchanging a valid email confirmation code, the callback provisioned customer/partner organizations and redirected partner, customer and enterprise users directly to workspace URLs. Email possession is not workspace authorization. The callback now exchanges the code, preserves a validated driver invitation token in session storage, and routes users to their role-specific sign-in page. It no longer provisions organizations or opens a workspace directly. Membership, organization, MFA and role checks occur in the sign-in journey.
2. **Driver-specific MFA challenge did not verify resulting AAL2.** The driver sign-in form verified a TOTP code and checked session existence but did not confirm the resulting assurance level. It now requires Supabase to report `currentLevel === "aal2"` before opening the driver workspace.
3. **Logout imported a missing module path and silently swallowed global sign-out failure.** `auth/logout.html` imported `./js/auth-core.js`, but the repository module is at the root `auth-core.js`; the logout code therefore could fail before executing. It now imports the correct module path, attempts global sign-out, falls back to local sign-out if global revocation fails, clears only KRIM MFA/invitation session markers (not all browser storage), and reports whether global revocation was confirmed.
4. **Partner-specific sign-in selected the first partner organization and did not recover a missing onboarding pathway.** It now rejects zero or multiple partner organizations, fetches the saved pathway field, recovers only a missing pathway from original signup metadata, never overwrites an existing mode, and fails closed when the pathway remains absent.

## Commits
- `6685a288a67deb4e924e3613cb2bce5d884432b7` — role-checked callback routing.
- `4da87a4c973f6ec1c64c22670f36a3347d5157b6` — driver MFA AAL2 check.
- `8b1e4ad4d2a2afe557e97bf34b9ced7bcbc42888` — repair logout module path and truthful revocation status.
- `ff499921bee2c92a3955be5774fb7b47bafd662d` — partner sign-in ambiguity and pathway recovery guards.

## Verification and limits
- The previous AAL2 guard commit and closure-gate documentation commit passed static link audit, production smoke checks and Pages deployment.
- The new callback/driver/logout/partner commits require CI completion and browser testing.
- No live test accounts, confirmation emails, password reset emails, MFA codes, invitation acceptance, or real session revocation were executed.
- No production database writes, DDL, RLS changes, grants or Auth project settings were changed.
- The Supabase Auth configuration cannot be reliably inferred from SQL catalog tables; the attempted `auth.config` inspection returned relation-not-found and was not treated as evidence of configuration.
- No claim is made that global session revocation, email delivery, rate limits, password policy, or leaked-password protection is fully configured until the actual Supabase Auth project settings and staging behavior are inspected.

## Required final closure tests
1. All customer, partner pathway, driver and enterprise callback routes resolve to role-checked sign-in, never direct workspace access.
2. Correct/wrong role, inactive membership, multiple partner memberships, cross-organization and user-metadata spoofing negative tests.
3. Partner callback interruption recovery, existing pathway preservation, missing/invalid pathway denial.
4. Driver invite token correct/wrong email, expired/revoked/replayed, and driver MFA invalid/valid/AAL2.
5. Logout global revocation succeeds; simulate global failure and verify local fallback and honest UI status; confirm unrelated local/session storage is preserved.
6. Password recovery valid/expired/replayed links, MFA-required and non-MFA accounts, password change, session revocation and retry behavior.
7. MFA enrollment concurrency, abandoned factor cleanup, verified factor reuse, challenge expiry/replay, and protected backend endpoint denial at AAL1.
8. Supabase Auth dashboard settings: site URL, redirect allowlist, email templates, password policy, leaked-password protection, rate limits, session lifetime, refresh-token rotation and MFA assurance policy.
9. Mobile and desktop tests; CI and deployed GitHub Pages verification.

**Closure rule:** do not mark authentication CLOSED — VERIFIED until all mandatory staging tests pass and the Auth configuration is independently confirmed. Continue to revalidate account, role, membership, MFA and session state on sensitive operations.

## Latest automated verification addendum
**Final code/test commit:** `7262e343b45e4393f631c1b86fba2ef9d702da26` (smoke-test assertion updated to match the hardened callback routing).
- KRIM production smoke checks: **PASSED** (run 43944374720).
- KRIM static link audit: **PASSED** (run 43944374592).
- GitHub Pages build/deployment: **PASSED** (run 43944373104).
- The earlier smoke failures were stale test expectations that still required the callback to provision an organization directly. The assertion now checks role-checked callback routing. No security guard was weakened to make the test pass.

## Staging environment requirement
The linked Supabase project is the production project. No separate isolated staging project was found. A Supabase development branch is available as a paid option at **US$0.01344/hour**. It must be explicitly approved before creation; production authentication tests remain prohibited. Once approved, use the branch for isolated end-to-end authentication tests and delete it after evidence is captured if no longer needed.

**Current classification:** frontend/code safety work and automated CI checks are complete for this patch set; the full authentication journey remains **NOT CLOSED — staging E2E and backend security verification outstanding**.
