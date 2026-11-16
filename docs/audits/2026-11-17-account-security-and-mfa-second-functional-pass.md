# KRIM account security and MFA — second functional pass

**Date:** 2026-11-17
**Status:** PARTIAL — routing defect corrected; security journeys not end-to-end verified.

## Changes

1. Authentication callback now carries its already-selected workspace destination into the MFA challenge.
2. MFA challenge no longer derives a destination from editable user metadata or silently defaults unknown users to the customer workspace. It accepts only a same-origin allowlisted KRIM workspace index path; invalid or missing destinations return to sign-in.

Commits:
- `5e0aa45118f2f5d62103d6984f95f31c066c3c9b` — callback preserves selected workspace through MFA.
- `42516bc66f6eb46c88fcd13ac83d9fc29f68c049` — MFA challenge validates return destination and removes metadata-based routing.

## Read-only review findings

- Login's primary sign-in flow checks active organization memberships, resolves actual organization type and partner warehouse capability, verifies requested workspace against mapped memberships, and routes only to supported workspaces. It enrolls TOTP when absent and performs challenge verification before routing.
- TOTP enrollment removes only unverified abandoned TOTP factors, enrolls a new factor and requires a challenge/verify step. It accepts only same-origin allowlisted return paths.
- MFA challenge selects a verified factor and uses Supabase challenge/verify. Its prior post-verification routing used account metadata and defaulted unknown roles to customer; this was corrected as above.
- Password recovery page uses generic success language to reduce account enumeration. The separate `forgot-password.html` directly embeds a publishable Supabase key and has a different user message; consolidate onto the shared `config.js` client and generic response before declaring recovery complete. The publishable key is not a secret, but duplicated configuration is a drift risk.
- Password reset checks recovery session, checks required AAL2, verifies TOTP where required, enforces a 12-character minimum in the page, updates password and attempts global sign-out. The 20-second timeout warns that the password outcome may be uncertain; this behavior needs staging validation.
- `active-sessions.html` reads the KRIM session registry, but the current action signs out only the local Supabase session. The UI explicitly says it affects this browser only; it is not a verified remote-session revocation control.
- `backup-codes.html` and `passkey-management.html` are deliberately disabled pending secure backend integration. Do not advertise backup-code recovery as available.
- Generic account-action module has password-change, email-change, phone-change and step-up flows, but the password-change branch checks only an 8-character minimum, and client-side action pages must be checked against backend AAL/permission requirements. Avoid treating these as security-grade verified until tested.
- No production authentication settings, users, factors, sessions or passwords were changed during this audit.

## Required isolated staging acceptance

1. Enroll TOTP; reject invalid codes; verify factor appears verified; recover from abandoned unverified enrollment.
2. Verify existing factor challenge; reject expired/invalid/replayed challenge; confirm AAL2 after successful verify.
3. Exercise callback MFA with customer, partner, driver, warehouse, customs, finance, operations and enterprise users; ensure each returns only to the selected, backend-authorized workspace.
4. Tamper with `returnTo` (external origin, arbitrary path, protocol-relative URL, query/fragment tricks); ensure no open redirect and fallback to sign-in.
5. Password reset: valid, expired, reused and malformed recovery links; AAL2-required account; password policy; global session revocation; confirm reset email and redirect configuration.
6. Verify password change requires recent authentication/AAL2 where policy requires, and enforce one consistent password policy across all entry points.
7. Verify local logout, global logout, refresh-token revocation, expired sessions and server-side session registry behavior.
8. Test email and phone change confirmation, account lockout/rate limits, and recovery without exposing whether an email exists.
9. Verify backup-code and passkey controls remain unavailable rather than presenting nonfunctional actions.
10. Confirm Supabase Auth provider settings, redirect allowlist, SMTP/email templates and leaked-password protection through authorized configuration review.

## Production boundary and closure

No live-user MFA enrollment, password reset, logout, session revocation or account mutation was performed. No production DDL, Auth configuration or grants were changed. Mark CLOSED — VERIFIED only after staging acceptance, negative tests, CI/deployment and provider configuration review pass. A green static build is not proof of authentication security.