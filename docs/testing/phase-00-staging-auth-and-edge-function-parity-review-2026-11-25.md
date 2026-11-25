# Phase 00 — Staging Auth Configuration and Edge Function Parity Review
Date: 2026-11-25
Scope: Read-only inspection of connected Supabase project metadata and deployed Edge Function source. No project settings, database records, secrets, deployments, or providers were changed or invoked.

## Project health
Both connected Supabase projects report `ACTIVE_HEALTHY`:
- Staging: `qrpcivhdxobiaofppbkl`, project name `KRIM Logistics Staging`, region `ap-south-1`, PostgreSQL 17.11.
- Production: `ebltviniygljwwseplph`, project name `logistics-saas`, region `ap-northeast-1`, PostgreSQL 17.6.

## Edge Function inventory
The live read-only inventory returned:
- Staging: **3 active Edge Functions** — `global-admin-control`, `krim-resend-email-worker`, `owner-testing-authorize`.
- Production: **22 active Edge Functions**.

Important production-only functions observed in this comparison include `krim-auth-workspace-route`, shipment/driver/notification functions, Razorpay payment functions, public tracking, and the legacy Cashfree endpoints. This means staging does not currently have operational Edge Function parity with production. Authenticated staging can be used for carefully scoped auth checks, but full web-journey E2E that depends on these missing functions is not ready.

## Source-level review findings
### Staging `owner-testing-authorize`
- JWT verification is enabled.
- It validates the supplied access token using `auth.getUser(token)`.
- It requires a confirmed email and signed AAL2 claim.
- It checks that exactly one active `platform_superadmin` assignment exists and belongs to the authenticated user.
- CORS is restricted to the GitHub Pages origin and the KRIM staging host/subdomain pattern.
- No request was sent to this function.

### Staging `global-admin-control`
- JWT verification is enabled.
- Source checks the bearer token, validates the user, requires AAL2, and checks active platform-admin/superadmin role assignments before processing actions.
- Its CORS response currently uses `Access-Control-Allow-Origin: *`. Authentication and role checks still exist, so wildcard CORS alone is not proof of an authorization bypass; however, it is broader than necessary and should be narrowed to the approved staging origin(s) before wider test use.
- No request was sent and no admin action was invoked.

### Staging `krim-resend-email-worker`
- JWT verification is disabled, but source requires a custom `x-krim-cron-secret` checked against `KRIM_NOTIFICATION_CRON_SECRET`.
- It uses the service-role key and calls Resend's email API for queued partner-verification messages.
- This is a real external-delivery path, not a safe test sink. Do not invoke it during QA until the staging Resend key/from address are confirmed as isolated test credentials and the destination policy is controlled.
- No request was sent, no queue batch was claimed, and no email was delivered.

## Auth settings and redirect allowlist limitation
The connected Supabase project metadata tool exposes project identity, health, region and database version, but does not expose the Supabase Auth URL configuration, site URL, or redirect URL allowlist. The repository has no tracked `supabase/config.toml` to use as a source of truth. Therefore the exact Auth callback/redirect allowlist remains **NOT VERIFIED**. Do not infer it from front-end callback URLs alone and do not change it without explicit review.

## Readiness decision
- Staging project healthy: **PASS**
- Authenticated staging source mode: **PASS (source + CI only)**
- Owner testing function source checks: **PASS (source inspection only)**
- Staging Edge Function parity: **BLOCKED — 3 staging vs 22 production**
- Staging admin-control CORS least-privilege: **REVIEW REQUIRED**
- Staging Resend worker isolation: **BLOCKED pending test-only provider configuration**
- Supabase Auth Site URL / redirect allowlist: **NOT VERIFIED**
- Runtime Auth, MFA, callback, RLS/RPC and workspace tests: **NOT TESTED**
- Provider operations: **NOT PERFORMED**

## Next required step
Obtain a read-only view of the staging Supabase Auth URL configuration and redirect allowlist in the Supabase Dashboard (Authentication → URL Configuration). Record the exact Site URL and Redirect URLs, compare them with the staging callback routes, and do not save changes yet. Then decide which missing Edge Functions are required for the initial controlled web E2E scope and prepare a staging-only deployment plan with external email/payment/provider effects disabled or redirected to test sinks.
