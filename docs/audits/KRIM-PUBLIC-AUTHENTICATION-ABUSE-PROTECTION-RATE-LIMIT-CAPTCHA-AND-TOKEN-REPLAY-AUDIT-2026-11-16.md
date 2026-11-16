# KRIM Public Authentication Abuse Protection, Rate Limits, CAPTCHA and Token-Replay Deep Audit — 2026-11-16

## Executive decision

**NO-GO for declaring public authentication and unauthenticated endpoints abuse-resistant.** The app has some useful protections: Supabase Auth handles credential verification and email confirmation; customer/partner signup validates required fields and terms; password-reset responses are intentionally neutral; the public contact endpoint applies per-email throttling and a trusted-proxy-IP limiter when Cloudflare supplies its client-IP header; and driver invitations use high-entropy one-time tokens stored as SHA-256 hashes.

However, the reviewed customer, partner and driver registration pages contain no CAPTCHA/Turnstile integration; the public contact IP throttle is skipped entirely when the trusted IP header is absent; public shipment tracking has no application-level rate limit or explicit body-size cap; login and recovery UX are inconsistent in how they expose errors; and live Supabase Auth provider/rate-limit/CAPTCHA configuration could not be inspected through the available project metadata. Therefore provider-side controls are **unverified**, not proven disabled.

This was a read-only review of repository source, deployed Edge Function source, database function definitions/grants, RLS flags and aggregate counts. No signup, login, password reset, public inquiry, tracking request, invitation creation/acceptance, provider call or rate-limit probe was executed. No data, Auth setting, database object or Edge Function was changed.

## 1. Evidence baseline

Repository HEAD at start of review:
- `c1f581efa33411cbfb82adde4c7f7bbef0ed62f7`
- Previous authentication lifecycle audit CI is now complete:
  - production smoke: success, run `43856011984`
  - static link audit: success, run `43856011980`
  - Pages deployment: success, run `43856011063`

Live Supabase observations:
- Project status: ACTIVE_HEALTHY; PostgreSQL 17.6.
- Public contact inquiries: **0**.
- Public inquiry IP-limit rows: **0**.
- Public tracking tokens: **18**.
- Driver invitation rows: **0** (from the previous lifecycle snapshot).
- The general API rate-limit counter table exists, has RLS enabled, and currently has **0** rows.
- A separate authenticated KRIM AI rate limiter exists (20 requests per 10-minute window per user).
- The project details API does not expose Auth provider rate-limit, password policy, CAPTCHA enablement or SMTP/security-notification settings. Those settings remain unverified.

## 2. Signup entry points

### Customer signup — `auth/signup.html`
Positive controls:
- Required business name, full name, email, password confirmation and Terms/Privacy checkbox.
- Email is trimmed/lowercased and HTML email validity is checked.
- Password minimum is 12 characters; input max is 72.
- Uses Supabase `auth.signUp` and an explicit same-site callback.
- If email confirmation is required, the page reports that a confirmation email was requested.
- Friendly error handling masks the common “already registered” condition with “may already exist” language and maps rate-limit errors to a wait/retry message.

Gaps:
- No CAPTCHA, Turnstile, proof-of-work or other bot challenge appears in the page source.
- No page-level attempt cooldown or device/session risk signal is implemented; button disablement only prevents an ordinary duplicate click in that browser.
- No verified server-side KRIM registration quota or account-creation abuse telemetry was found.
- Terms acceptance and account type are sent in user_metadata; that metadata is user-editable and must not be treated as verified consent or authorization evidence. A previous audit found a database trigger that records the terms event from this metadata, so the consent evidence can be forged at signup unless independently validated/attested by a trusted server-side flow.

### Partner signup — `auth/partner-signup.html`
Positive controls:
- Requires business name, full name, valid email, country/city/service category, explicit pathway and terms checkbox.
- Password minimum is 10 characters.
- Signup errors mask existing-account hints and recognize provider rate-limit errors.
- Organization provisioning and account-mode setup use authenticated server RPCs after signup; failure messages tell users not to create duplicate accounts.

Gaps:
- No CAPTCHA/Turnstile or server-enforced per-IP/per-device signup quota appears in the page.
- Password minimum differs from customer signup (10 vs 12).
- Account type, partner pathway and profile are placed in user_metadata. This can guide onboarding UX but must not confer partner organization access, verified status, commercial permissions or capability.
- Provisioning and mode setup are separate post-signup RPCs; partial failure is possible and requires the recovery flow already noted in the authentication lifecycle audit.

### Driver signup — `auth/driver-signup.html`
Positive controls:
- Explains that account creation does not approve a licence or assign shipments.
- Email confirmation is used.
- Carrier invitation acceptance is a separate authenticated workflow that rechecks the carrier and exact invited email.

Gaps:
- No CAPTCHA/Turnstile, explicit signup rate limit, or meaningful password-strength feedback appears in the page source.
- Password minimum is 10 characters, unlike customer signup.
- The page surfaces raw `err.message` to the user, which can reveal provider/internal error detail and produce inconsistent account-enumeration behaviour.
- The `invite` token is accepted in the query string and copied to sessionStorage for callback continuation. The token is high entropy and stored as a hash server-side, but query/session handling should be hardened against browser history, referrer, analytics and client-side logging exposure. Never put the raw token in logs or telemetry.

## 3. P1 — CAPTCHA / bot protection is absent from the reviewed public auth pages

A repository-wide path/source review of customer, partner and driver signup found no `captcha`, `turnstile` or `recaptcha` integration. The pages rely on client-side validation, email confirmation and Supabase Auth's own rate limits.

Impact:
- Email confirmation prevents unverified accounts from completing normal flows, but it does not prevent automated signup attempts or provider/email quota consumption.
- Client-side required fields and disabled buttons are trivial to bypass.
- Public registration can be abused to generate account/profile/organization provisioning attempts and consume email delivery capacity.

Required action:
- Enable Supabase Auth CAPTCHA using a supported provider such as Cloudflare Turnstile or hCaptcha, and validate the challenge server-side through Supabase Auth rather than trusting a browser-only result.
- Apply the CAPTCHA consistently to customer, partner and driver signup, and evaluate login/password recovery risk controls.
- Add monitoring for signup bursts, repeated failures, confirmation email volume, account creation and provisioning failures.
- Test accessibility and provide a fallback for legitimate users blocked by the challenge.

## 4. P1 — Public inquiry IP limiter is bypassed when the trusted IP header is missing

Deployed `krim-public-contact-inquiry` v20 (`verify_jwt=false`) was retrieved and inspected directly from the project.

Positive controls:
- POST-only; OPTIONS preflight handled.
- Declared content-length above 9,000 bytes rejected.
- JSON object shape, privacy acknowledgement and input lengths validated.
- Honeypot field returns a generic success without saving.
- Uses only `cf-connecting-ip`, not caller-supplied `X-Forwarded-For`.
- If the trusted IP header exists, a database limiter allows 10 requests per IP per 10-minute bucket, then returns 429.
- Database inquiry RPC serializes per-email attempts with an advisory transaction lock and limits each normalized email to 3 enquiries per hour.
- Rate-limit RPC failure returns 503, failing closed for that branch.

Critical gap:
- The Edge Function calls the IP limiter only inside `if (clientIp)`.
- If `cf-connecting-ip` is absent, the request proceeds without any IP throttle.
- The database IP limiter itself returns `limited:false` for null/blank IP and labels the reason `ip_unavailable`.
- No alternative trusted edge-derived client identity is used and no explicit alert is raised for repeated missing-IP requests.

Impact:
A deployment or ingress path that does not supply the Cloudflare header removes the IP layer entirely. Per-email throttling remains, but an attacker can rotate email addresses. This must not be treated as robust public abuse protection until ingress behaviour is verified and missing trusted IP metadata fails closed or is safely handled by a trusted platform-level rate limiter.

Additional note:
The endpoint's wildcard CORS is not an authentication bypass by itself, but the endpoint is public and does not need credentialed cross-origin access. Restrict browser origins to the official KRIM site where feasible; retain server-side abuse controls regardless of CORS.

## 5. P1 — Public shipment tracking has no visible application-level rate limiting or request-size cap

Deployed `public-shipment-tracking` v23 (`verify_jwt=false`) was inspected directly.

Positive controls:
- POST-only; no-store responses.
- Requires a 32-character hexadecimal tracking token (128 bits of token space).
- Looks up an exact token; invalid syntax is rejected.
- Does not return raw GPS event rows.
- GPS location output is gated by environment/legal approval, active tracking session, exact shipment/partner/driver assignment, driver verification, active membership, native platform and consent hash.
- Errors are generally bounded and do not expose database details.

Gaps:
- No `Content-Length` or bounded streaming-body parser check is present before `req.json()`.
- No per-IP, per-token, per-shipment or global application-level request limiter is present in the inspected source.
- No progressive delay or abuse telemetry is visible for repeated invalid-token lookups.
- Unknown tracking token returns 404 while malformed token returns 400; this is not a direct enumeration weakness with high-entropy tokens, but response timing and abuse metrics still need validation.
- Each valid lookup can trigger multiple database reads; a high-volume client can impose database load even without guessing a token.

Required action:
- Add a strict body-size limit before parsing and reject unsupported content types.
- Apply edge-level rate limiting to valid and invalid attempts using trusted ingress identity and a separate token hash bucket.
- Keep tracking responses non-cacheable and generic for unknown/revoked tokens.
- Add abuse telemetry for repeated misses, burst volume and per-token anomalies.
- Validate token generation entropy, rotation/revocation and whether tracking references are ever exposed in public logs/analytics.
- Load-test with synthetic tokens in staging, not production.

## 6. P1 — Login and recovery error handling is inconsistent

### Customer login
- Supabase `signInWithPassword` is used; membership and organization lookups fail closed.
- MFA factors and AAL are checked before workspace routing.
- Error text is surfaced through the page's UI; review the final catch path for raw provider errors and normalize credential/lockout outcomes.

### Partner login
- Uses Supabase password sign-in, checks active membership and organization type, then MFA.
- Catch path displays `error.message` directly. Normalize invalid credentials, banned/disabled accounts, rate limit and internal failures into safe user messages and server-side redacted security telemetry.
- It attempts partner organization provisioning when membership is absent and user_metadata says partner; backend authorization remains essential and the metadata must never be sufficient for partner approval.

### Driver login
- Uses Supabase password sign-in and verifies driver membership/profile/organization.
- Catch path displays raw error message.
- MFA challenge errors are also displayed directly.
- Add consistent attempt handling and generic authentication failure messages.

### Password recovery
- `auth/forgot-password.html` displays the same success response whether or not an account exists: “If this email belongs to a KRIM account…”. This is a positive enumeration-resistant UX control.
- It does not expose whether a reset message was actually delivered.
- Provider-side reset throttles, SMTP quotas, redirect allowlist and CAPTCHA configuration were not accessible in the project metadata and remain unverified.
- A UI button disable is not a server-side throttle.

Required action:
- Standardize all login/signup/recovery error messages and avoid raw provider error display.
- Keep internal error codes in redacted telemetry, never passwords, OTPs, recovery links, invitation tokens or full auth payloads.
- Verify provider rate limits and CAPTCHA in Supabase Dashboard/Auth configuration; configure email sending limits and alerts.
- Test repeated bad credentials, unknown email, known email, banned user, reset flooding, confirmation flooding and callback replay in staging.

## 7. P1 — Driver invitation token replay and leakage controls need a final pass

The secure UUID-based invitation path has strong controls:
- 32 random bytes, 64-character lowercase hex token.
- SHA-256 token hash stored in a private table.
- Exact invited-email match and confirmed email required.
- Invitation row locked during acceptance.
- Expiry, revoke and accepted state checked.
- Carrier eligibility revalidated at acceptance.
- Duplicate active driver membership rejected.
- The invitation is marked accepted in the same transaction as membership/profile changes.

Remaining concerns:
- Raw invitation token is delivered in a URL query parameter and then held in sessionStorage to survive email confirmation.
- Ensure the page has a restrictive referrer policy, no third-party scripts/analytics on token-bearing pages, no query-string logging and immediate URL cleanup after token capture.
- Add explicit concurrent double-acceptance and replay tests, token revocation immediately before acceptance, and expiry boundary tests.
- Legacy one-argument driver-invitation function remains in the database. It is not part of the new 32-byte hash workflow and was previously identified as non-executable by anon/authenticated; retire only after migration reconciliation, not by ad-hoc DDL.

## 8. Provider-side configuration — not verified

The project metadata endpoint returned project identity, region, status and database version only. It did not expose:
- Supabase Auth per-endpoint rate limits.
- CAPTCHA enablement/provider/secret state.
- Password policy / leaked-password protection.
- Email confirmation and recovery email rate limits.
- SMTP sender and deliverability settings.
- Auth redirect allowlist.
- Security notification templates and provider status.

Do not claim these controls are disabled. They are **unverified** and require a read-only inspection in Supabase Dashboard → Authentication → Rate Limits, Providers/Captcha, URL Configuration and Email Templates/SMTP. Do not paste secrets or API keys into chat.

## 9. Existing rate-limit implementation inventory

- Public inquiry email: 3 per normalized email per rolling one-hour query window, serialized with an advisory transaction lock.
- Public inquiry IP: 10 per trusted IP per 10-minute fixed bucket, only when `cf-connecting-ip` is present.
- Driver invitation creation: 10 per inviter/organization per hour.
- Authenticated KRIM AI: 20 per user per 10-minute window.
- General API rate-limit counter table exists but no rows were present; no general public-auth rate-limit endpoint was found in the reviewed code.
- Supabase Auth's own limits may add protection, but configuration is not visible to this audit.

These controls are separate and must not be presented as a unified anti-abuse system.

## 10. Required staging test plan — not run

1. Automated customer/partner/driver signup with missing, invalid and solved/unsolved CAPTCHA.
2. Signup bursts across one IP, rotating email addresses and distributed IPs.
3. Existing email vs unknown email response consistency.
4. Login password spraying and repeated invalid-password attempts; verify provider lockout/rate limit and safe response.
5. Password-reset flooding for known and unknown email; verify identical UI response and bounded email sends.
6. Confirmation-email resend limits and expired/replayed callback codes.
7. Missing `cf-connecting-ip`, malformed header, spoofed `X-Forwarded-For` and normal trusted-proxy path.
8. Public inquiry rate-limit boundary: 10th/11th IP request, 3rd/4th email request, concurrency and window rollover.
9. Public tracking oversized body, invalid content type, invalid JSON, malformed token, repeated unknown tokens, valid token burst and token revocation.
10. Driver invite wrong email, unconfirmed email, expired/revoked/replayed token, concurrent acceptance and carrier suspension between creation/acceptance.
11. Referrer/history/logging checks for invite-bearing URLs; ensure no third-party script receives token.
12. Verify rate-limit counters are atomic under concurrent requests and clean up old buckets without blocking hot paths.
13. Confirm all abuse telemetry is redacted and does not store raw passwords, OTPs, tokens, email bodies or IP addresses without approved retention/legal basis.
14. Run load tests only in isolated staging with synthetic identities and no live provider emails.

## 11. Remediation priority

**P0**
1. Make public inquiry IP throttling fail closed or use a trusted edge limiter when the trusted client IP is missing. Verify ingress headers in the actual deployed region/edge path.
2. Add request-size limits and rate limiting to public shipment tracking.

**P1**
3. Integrate Supabase Auth CAPTCHA/Turnstile for all public signup entry points.
4. Verify and document Supabase Auth provider rate-limit and password policy settings.
5. Standardize login/signup/recovery error responses and redact raw provider errors.
6. Add signup, login and reset abuse telemetry/alerts and server-side quotas where appropriate.
7. Harden invitation URL handling and test replay/concurrent acceptance.
8. Align password length policy across customer, partner and driver registration.

**P2**
9. Restrict CORS for public browser endpoints to official KRIM origins where compatible.
10. Add staging-only load and bot simulation suite.
11. Consolidate rate-limit primitives into a versioned, observable service and define retention/cleanup.

## 12. Release decision and change boundary

**NO-GO for public auth abuse-resistance certification.** Existing controls provide a useful baseline, especially email confirmation, generic password-reset response, inquiry per-email throttling and the secure driver invitation token. They do not yet demonstrate bot resistance, reliable trusted-IP enforcement across ingress paths, public tracking abuse limits or verified Supabase Auth provider configuration.

- No production DDL/DML, Auth setting, user, invitation, Edge Function, rate-limit counter or provider action was changed.
- No live signup/login/reset/inquiry/tracking/invitation test was executed.
- Production migration-history mismatch remains unresolved; do not apply schema/function fixes until migration reconciliation is complete.
- Financial collection, customer messaging and live operational logistics remain behind existing release gates.
