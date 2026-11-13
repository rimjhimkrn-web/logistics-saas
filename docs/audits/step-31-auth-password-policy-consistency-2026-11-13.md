# Step 31 — Authentication password policy consistency

Date: 2026-11-13
Branch: `website/global-launch-readiness`
PR #65 remains draft, unmerged and undeployed.

## Changes made

Aligned all five customer/partner/driver signup, password reset, and signed-in password-change flows to a 12-character minimum:
- Customer signup already enforced 12 characters; confirmed unchanged.
- Password recovery/reset already enforced 12 characters; confirmed unchanged.
- Partner signup HTML and JavaScript now both enforce 12 characters (previously 10).
- Driver signup HTML and JavaScript now both enforce 12 characters (previously 10).
- Signed-in password change now enforces 12 characters (previously 8).

Signup inputs use a 72-character maximum where present, consistent with the existing customer/partner signup forms. The change does not alter Supabase Auth project settings.

## Verification

Re-fetched all five source files from the PR branch after edits and verified:
- Customer signup: minlength and JS check 12.
- Partner signup: minlength and JS check 12.
- Driver signup: minlength and JS check 12.
- Password reset: HTML and JS checks 12.
- Signed-in password change: JS check 12.

## Not completed / manual project setting

The connected Supabase tools do not expose an Auth configuration read/update operation for the leaked-password protection toggle or minimum password length. Therefore this step did not change or claim to verify the live Auth dashboard setting. Project owner must open Supabase Dashboard → Authentication → Security and enable leaked-password protection, then verify password strength/minimum settings. Afterward, test signup, recovery and password-change flows before production release.

No production database, Auth settings, secrets, accounts, sessions, or emails were changed. No live sign-in or password test was performed.
