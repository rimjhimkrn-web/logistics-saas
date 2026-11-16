# KRIM authentication and account security — closure gate
**Updated:** 2026-11-17  
**Status:** IMPLEMENTED SAFETY GUARDS; NOT CLOSED — VERIFIED.

## Changes committed
- `56a93564976e6fca3d45a78e19ad29cbdf61d92d`: recover incomplete partner pathway setup at sign-in without overwriting an existing selected mode.
- `56842d1d02f598389f02bcd25be3aea8163a019a`: record first authentication journey audit and required staging tests.
- `971decb19d4670635e559bb1e57e2a77218daba5`: main login MFA flow checks Supabase's reported current assurance level is AAL2 after successful TOTP verification.
- `cd8c3635e24f6b81e903af579ae85bb600ec49c4`: standalone MFA challenge checks current assurance level is AAL2 before redirect.
- `59e35b3d00dea00d9a9dfaf57c54a8c73653c4ae`: MFA enrollment checks current assurance level is AAL2 before declaring enrollment complete and redirecting.

## Controls inspected (read-only)
- Sign-in uses Supabase password authentication, reads active organization memberships, resolves organization types and routes only to a role already represented by active membership.
- Workspace selection in URL is treated as a preference and rejected if it does not match an active membership.
- Platform administration is excluded from public workspace sign-in.
- Users with multiple roles must explicitly choose a permitted workspace.
- Users without verified TOTP are sent to enrollment; users with verified TOTP but AAL1 are challenged.
- TOTP verification now explicitly checks the resulting session reports `currentLevel === "aal2"`.
- Enrollment removes abandoned unverified TOTP factors before restarting enrollment; this needs concurrency testing with multiple tabs/devices.
- Password recovery requires a recovery session, checks MFA when the account's next level is AAL2, enforces 12-character minimum, updates the password and attempts global sign-out.
- Logout attempts global sign-out and clears browser storage. Its failure behavior and storage-clearing scope need a dedicated browser test.
- Driver invitation acceptance was inspected in the previous partner audit: confirmed invited email, token hash, expiry, revocation, single-use and current carrier eligibility are checked.

## CI
The first partner recovery commit and its audit documentation passed static link audit, production smoke checks and Pages deployment. The three new AAL2 guard commits were pushed sequentially; their latest combined commit CI must be polled to completion before deployment is called green.

## Remaining mandatory proof
No real account was used and no live authentication challenge, recovery email, MFA enrollment, invitation, or session revocation was executed. The following are still required in isolated staging:
1. Registration + confirmation for customer, partner (all three pathways) and driver.
2. Interrupted partner callback recovery; idempotency; preservation of pre-existing mode.
3. Verified TOTP enrollment, invalid/expired code, repeated challenge, successful AAL2, and AAL1 denial at protected backend endpoints.
4. Multiple tabs during enrollment; already-enrolled factor; abandoned unverified factor cleanup.
5. Password reset valid/expired/replayed link; MFA-required and non-MFA accounts; password update; global session revocation.
6. Logout with network available/unavailable; confirm remote refresh-token revocation and correct local storage cleanup without damaging unrelated application state.
7. Driver invite correct/wrong email, expired/revoked/replayed token, and carrier compliance becoming invalid before acceptance.
8. Workspace deep links for signed-out, wrong-role, inactive membership, cross-organization and multi-role accounts.
9. Backend RLS/RPC negative tests: frontend redirects are not authorization. Every protected data read and mutation must deny wrong role, wrong organization, inactive membership, AAL1 where required, and revoked access.
10. Supabase Auth configuration review: site URL, allowed redirect URLs, email templates, password policy, leaked-password protection, rate limits, session lifetime, refresh-token rotation and MFA assurance policy.
11. Mobile + desktop browser testing and deployment smoke tests.

## Permanent-lock rule
A feature can be marked CLOSED — VERIFIED only after the tests above pass with evidence and production security review. Do not freeze dynamic eligibility, compliance, account status, token validity or permissions; these must be re-evaluated on each sensitive operation. Reopen only for an evidenced defect, security issue, provider change or legal/regulatory change.

## Production safety
No production DDL, grants, RLS policy edits, real-account tests, email sends, role changes or invitation acceptance were performed. The repository migration-history mismatch remains a blocker to backend changes. Frontend guards do not make the backend safe by themselves.
