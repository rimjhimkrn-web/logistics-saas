# Phase 00 — Public API and unauthenticated Edge Function exposure audit
Date: 2026-11-25
Branch: qa/phase-00-baseline-2026-11-25
Scope: Read-only Production/Staging Edge Function inventories; deployed Production source inspection of all Edge Functions configured with `verify_jwt=false`; read-only PostgreSQL function EXECUTE catalog and public contact-inquiry RPC source. No endpoint invocation, no payment/provider operation, no Telegram send, no DB writes, no secrets read and no configuration changes.

## Executive verdict
The Production public/unauthenticated surface contains five Edge Functions with `verify_jwt=false`. This is not automatically a vulnerability: Razorpay uses HMAC webhook verification, the contact form has server-side validation and rate controls, the notification retry worker has a custom cron-secret or authenticated-admin gate, Cashfree returns a fixed retirement response, and public tracking uses a high-entropy bearer reference. However, two protections need further work: public tracking rate limiting (previous audit) and Razorpay webhook request-size bounds. The public inquiry IP throttle also fails open if the Cloudflare client-IP header is absent.

No callable anonymous SECURITY DEFINER RPC was found in the exposed `public` schema catalog snapshot. The seven functions with effective anon EXECUTE in Production are trigger functions (no-argument trigger signatures), not client-callable business RPCs. Staging had zero public-schema functions executable by anon at the time of this read-only query.

## 1. Edge Function inventory — Production vs Staging
Production Edge Function inventory: 24 deployed functions. The five with `verify_jwt=false` are:
1. `krim-public-contact-inquiry` — ACTIVE, v20, source SHA-256 `800ce40a9c5420715e795e681c5b74c9ca0ef5e55a1a5f9e8a473f07cce95012`.
2. `razorpay-webhook` — ACTIVE, v28, source SHA-256 `79f145769ba60c8d07e3d9a19806e77438f4708d5b641742afabbbaf562c923c`.
3. `cashfree-payment-webhook` — ACTIVE, v14, source SHA-256 `266fde9b7a93f938e6a3488d395298c5a19811c5d182993f7890a089aa4be65a`.
4. `krim-notification-retry-worker` — ACTIVE, v14, source SHA-256 `0910fce93f689bc10d3ce6b6ce0739fa7c931eef629466bd0981ab52d4ab8fe7`.
5. `public-shipment-tracking` — ACTIVE, v23, source SHA-256 `8952e857b62155fa4df8be6bcc86b086c15171ff0c5d0802e9fa054899b49158`.

Staging inventory: 3 functions:
- `krim-resend-email-worker` — ACTIVE, v1, `verify_jwt=false`, protected by its own custom cron secret in source.
- `owner-testing-authorize` — ACTIVE, v5, `verify_jwt=true`.
- `global-admin-control` — ACTIVE, v2, `verify_jwt=true`.

Staging does not currently deploy the Production public contact, Razorpay webhook, Cashfree retirement webhook, notification retry worker, or public tracking endpoint. Staging/Production Edge Function parity is therefore intentionally incomplete and must be managed as a release checklist, not fixed by blindly copying Production functions.

## 2. Public contact inquiry — protected, with one fail-open edge case
Source-observed controls:
- POST/OPTIONS only; wildcard CORS; `Cache-Control: no-store`.
- Rejects declared request body length over 9,000 bytes.
- Requires privacy consent.
- Honeypot field `website` returns a success-shaped response without processing.
- Validates name, email, organization and message length/format.
- Uses Supabase-provided `cf-connecting-ip` only; source comment explicitly rejects caller-supplied X-Forwarded-For.
- Calls `krim_check_public_inquiry_ip_limit` when that header exists.
- Database IP throttle hashes IP with SHA-256 and allows at most 10 requests per 10-minute window; old counters are purged after 24 hours.
- Database inquiry transaction serializes by email using advisory transaction lock and limits to 3 enquiries per email per hour.
- Records consent notice version `2026-11-11`, inquiry, acquisition profile, qualification case, event and founder notification outbox row.
- Does not create a booking or quote.
- Sends founder Telegram alert from the Edge Function when credentials exist; failures are reflected in outbox status/retry metadata.

Risk:
- If `cf-connecting-ip` is absent, the IP-throttle RPC is skipped. The per-email limit still applies, but an attacker can rotate email addresses. The RPC itself returns `limited=false` for a missing IP, so it is explicitly fail-open.
- Declared Content-Length alone is not a complete request-size control for chunked/streamed requests; add a bounded read of the actual body bytes before JSON parsing.
- Contact inquiry is a public endpoint that can trigger an external Telegram side effect after a successful submission. Do not use it for QA tests unless a test sink is configured and the user explicitly approves a controlled test.

## 3. Razorpay webhook — cryptographic signature verified; size bound not observed
Source-observed controls:
- `verify_jwt=false` is expected for a provider webhook.
- POST/OPTIONS only.
- Requires server-side Supabase URL, service-role key and Razorpay webhook secret.
- Reads the raw request body and calculates HMAC-SHA256.
- Uses a constant-time byte comparison for the received and expected signature.
- Requires `x-razorpay-event-id`.
- Parses JSON only after signature verification.
- Explicit allowlist of supported payment/refund event types.
- Unsupported events are acknowledged as ignored, not marked processed.
- Stores event before processing; duplicate event IDs are handled with a retryable 409 when concurrent insert occurs.
- Refund reconciliation validates provider identifiers, amount and INR currency and correlates against an approved KRIM refund request; source comments say it records provider outcomes and never initiates a refund.

Risk:
- No explicit request-body size cap is visible before `req.text()`. A correctly signed large body is unlikely to be supplied by an attacker without the webhook secret, but a size/time bound still protects availability and prevents oversized payload processing if provider configuration or secret is compromised.
- No live webhook was invoked and no signature was generated or tested.
- Earlier payment audit found four Production webhook events unprocessed. This review did not reconcile or replay them.

## 4. Notification retry worker — custom authentication gate observed
Source-observed controls:
- `verify_jwt=false`, POST only; no browser CORS.
- Accepts either a custom cron secret in `x-krim-cron-secret` or bearer token. Secret must exist and be at least 32 characters; digest comparison is constant-time.
- If cron secret does not match, validates Supabase user with `auth.getUser`, then checks `admin.platform` permission through RPC.
- Uses service-role client only after authorization.
- Processes bounded batches of 10, uses claim/finish RPCs, network timeout of 12 seconds and generic provider failure text.
- Calls Telegram sendMessage for founder inquiry/follow-up queues only; it is not a universal user notification worker.

Residual risks:
- Custom cron secret is a bearer credential; rotate through approved secret-management process if exposed and never log it.
- No invocation was made. No Telegram message was sent.
- Earlier notification audit already found this worker is not the universal nine-workspace notification delivery system.

## 5. Retired Cashfree webhook — fixed 410 response
Source-observed behavior:
- `verify_jwt=false`, OPTIONS accepted; all other methods receive a fixed JSON 410 response stating the provider is retired.
- Does not read a webhook signature, parse a payload, access Supabase, or contact Cashfree.
- This is a safe retirement response in the inspected version. The function remains deployed and should be retained or removed only after repository references, provider dashboard configuration, old payment records and rollback needs are reconciled. No removal was attempted.

## 6. Public PostgreSQL RPC surface
Read-only Production catalog:
- Public-schema functions total effective anon EXECUTE: 7.
- Public-schema functions with anon EXECUTE and SECURITY DEFINER: 0.
- Public-schema functions total effective authenticated EXECUTE: 178.
- Public-schema functions with authenticated EXECUTE and SECURITY DEFINER: 151.
- The seven anon-executable functions are trigger functions (e.g. trigger-maintenance and shipment-number generation functions), not callable RPC signatures.
Read-only Staging catalog:
- Public-schema functions total effective anon EXECUTE: 0.
- Public-schema functions total effective authenticated EXECUTE: 46.
- Public-schema functions with authenticated EXECUTE and SECURITY DEFINER: 45.

No anonymous callable SECURITY DEFINER RPC was identified in this catalog snapshot. This does not prove every authenticated SECURITY DEFINER function is safe; the earlier source-level RPC and authorization audits remain applicable. Staging grants differ materially from Production; do not synchronize them wholesale.

## 7. Supabase Security Advisor snapshot
- Production: 29 RLS-enabled/no-policy INFO findings and one WARN for leaked-password protection disabled.
- Staging: 30 RLS-enabled/no-policy INFO findings in the retrieved summary; private driver-invitation table is additionally present.
The no-policy INFO findings are not automatically exposed; prior ACL review found no effective anon/authenticated table privileges on those private/no-policy tables. Leaked-password protection should be enabled through a separately approved Auth configuration change, not during this read-only phase.

## 8. Required remediation / release gates
1. Make public inquiry IP throttling fail closed when the trusted edge IP is absent or invalid; return a temporary service error rather than silently skipping the IP control. Confirm the header provenance at the Supabase edge gateway.
2. Bound actual streamed request bytes in contact and Razorpay webhook handlers, not only the declared Content-Length.
3. Add endpoint-specific rate limiting/abuse telemetry to public tracking (previous report).
4. Ensure public inquiry CAPTCHA or equivalent abuse challenge is considered before broad paid acquisition; keep honeypot + IP/email limits as defense-in-depth.
5. Review privacy notice version/retention for the public inquiry flow and define retention/deletion process for inquiry, acquisition profile, qualification and notification records.
6. Add/verify structured privacy-safe logs and alerting for public inquiry spikes, invalid webhook signatures, repeated webhook retries, and public tracking abuse; never log raw tokens, webhook secrets, request bodies or personal data unnecessarily.
7. Add Staging deployment/test-sink versions of only the required endpoints after isolation controls exist. Do not enable live Telegram, email or payment provider actions in ordinary QA.
8. Reconcile retired Cashfree dashboard/webhook configuration and source references before any decommission.
9. Separately review all 151 Production authenticated SECURITY DEFINER functions by privilege, caller authorization, row scoping and side effects; catalog count alone is not a vulnerability verdict.
10. Enable leaked-password protection only after explicit approval of the Auth setting change.

## Evidence boundary
Edge Function inventories and deployed sources were retrieved read-only. SQL was limited to function privilege/catalog metadata and source text. No Edge Function was invoked; no real contact form, webhook, payment, refund, Telegram, email or other external provider operation was performed. No secrets were read, no DB records were changed and no configuration was changed.

## Verdict
- Anonymous callable SECURITY DEFINER RPCs: **NONE FOUND IN CATALOG SNAPSHOT**.
- Public contact inquiry: **SOURCE-OBSERVED CONTROLS; IP HEADER ABSENCE FAIL-OPEN RISK**.
- Razorpay webhook: **HMAC/IDEMPOTENCY SOURCE CONTROLS; BODY SIZE LIMIT NOT OBSERVED**.
- Notification retry worker: **CUSTOM CRON SECRET / ADMIN AUTH GATE SOURCE-OBSERVED**.
- Cashfree retired webhook: **FIXED 410 RESPONSE SOURCE-OBSERVED**.
- Public tracking: **RATE LIMITING NOT EVIDENCED; PREVIOUS LAUNCH BLOCKER REMAINS**.
- Production/Staging Edge Function parity: **INCOMPLETE; EXPECTED DIFFERENCES REQUIRE RELEASE CONTROL**.
- Public API surface overall: **PARTIALLY CONTROLLED; NOT READY FOR UNRESTRICTED PUBLIC LAUNCH**.
