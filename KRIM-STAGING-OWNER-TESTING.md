# KRIM staging owner-testing boundary

## Environment
- Staging Supabase project: `qrpcivhdxobiaofppbkl` (KRIM Logistics Staging, ap-south-1).
- Production project: `ebltviniygljwwseplph`; owner-testing pages must never use its URL or keys.
- GitHub Pages owner hub: `owner-testing.html`.

## Isolation controls applied
- Imported schema only; no production Auth users, table rows, Storage objects, provider credentials, or production webhook configuration were copied.
- Enabled RLS on all 397 application tables in `public`, `private`, and `krim_internal`; zero application tables were found with RLS disabled.
- Enabled RLS on `private.krim_driver_invitations` without adding client policies.
- Revoked table, view, sequence, and function privileges from `anon` and `authenticated` in application schemas; revoked inherited PUBLIC function execution. Kept `service_role` access for reviewed server-side operations.
- Changed PostgreSQL default privileges for `postgres` in application schemas so new tables, sequences, and functions are not automatically exposed to client roles.
- Seeded only the 11 static security-role definitions; no user or role assignment was copied.
- Deployed only `owner-testing-authorize` (JWT required). It requires a confirmed email, MFA AAL2, and exactly one active `platform_superadmin` assignment matching the signed-in user. CORS is restricted to the KRIM GitHub Pages origin.
- No payment, refund, webhook, SMS, email, Telegram, AI, or notification Edge Functions are deployed to staging.
- No Storage buckets or objects are configured.
- Owner hub previews are static/read-only: scripts, forms, links, and actions are stripped/disabled. It has no production live-page launch button.

## First-owner activation still required
1. In Supabase Dashboard, open **KRIM Logistics Staging → Authentication → Users**.
2. Create one owner account using the owner's own email and a password that is never shared in chat. Confirm the email.
3. The account must enroll a TOTP authenticator and reach AAL2.
4. Assign that user the single active `platform_superadmin` role in staging only. Do not copy a production user or production role assignment.
5. Verify `owner-testing-authorize` returns success for that account and denies every other account.

## Current status
The staging database is locked down and the static page inventory is ready. The owner account has not yet been created or assigned, so interactive owner access remains unavailable. The static preview must not be described as a working end-to-end staging environment.
