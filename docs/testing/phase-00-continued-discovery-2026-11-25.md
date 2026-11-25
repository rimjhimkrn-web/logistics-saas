# KRIM Phase 00 — Continued Discovery Findings

**Audit date:** 2026-11-25  
**Scope:** Web platform only; native applications excluded.  
**Mode:** Read-only inspection of GitHub source and Supabase metadata/function source. No production or staging data/schema/configuration was changed.

## 1. Repository route evidence

- Canonical route registry in `config.js`: 26 named workflow destinations.
- Public `sitemap.xml`: 36 listed URLs.
- Repository HTML source files: 1,017 (from the initial repository scan).
- These are three different counts and must not be added together. The 1,017 figure includes non-public, legacy, workspace, internal, redirect and possible duplicate pages.
- Route registry destinations must be checked for file existence and then classified by audience, auth requirement, environment, redirect status and deployment reachability.
- Sitemap is a public-discovery list, not a complete application route inventory.

## 2. Environment routing inspection

The shared `config.js` selects:
- Production Supabase project `ebltviniygljwwseplph` when environment is detected as production.
- Staging Supabase project `qrpcivhdxobiaofppbkl` for development and preview environments.
- GitHub Pages hostname is detected as production.
- Preview sets `KRIM_AUTH_DISABLED = true`.

**Review item:** Confirm this preview auth-disable flag is intended only for static previews and cannot be used as the acceptance-test environment. Authenticated acceptance tests need a protected staging hostname/route and a controlled staging identity path. Do not switch this flag or change the routing until the safe staging access design is reviewed.

## 3. Edge Function inventory and release review

Live Supabase inventory returned:
- Production: 22 active Edge Functions.
- Staging: 3 active Edge Functions.

Production inventory includes Razorpay functions, legacy Cashfree functions, public shipment tracking, notification workers, AI, driver tracking, admin control, growth operations and public contact inquiry.

### Specific review findings

1. **Cashfree remnants:** `create-global-cashfree-order`, `verify-global-cashfree-payment`, `create-global-cashfree-order` and related legacy Cashfree endpoints remain deployed/active in production inventory. `cashfree-payment-webhook` source currently returns HTTP 410 with a retired-provider response. This is not a complete removal of Cashfree. Review all callers, secrets, provider settings, database references and retry/fallback paths before disabling or deleting anything.
2. **Razorpay webhook:** `razorpay-webhook` has platform JWT verification disabled, as expected for a provider webhook, and its source checks the Razorpay HMAC signature and event ID before processing. It still requires dedicated negative tests for invalid signature, missing event ID, duplicate event, retry and out-of-order events.
3. **Notification retry worker:** `krim-notification-retry-worker` has platform JWT verification disabled but implements a custom cron-secret check and an authenticated platform-admin fallback in source. It needs explicit tests for missing/incorrect/valid cron secret, non-admin user, provider failure and idempotent retry.
4. **Public tracking:** `public-shipment-tracking` has platform JWT verification disabled and uses a high-entropy tracking token lookup. Test invalid, random, revoked, expired and valid tokens; confirm that no private customer or driver data leaks.
5. **Staging inventory/documentation mismatch:** Staging currently lists `krim-resend-email-worker`, while `KRIM-STAGING-OWNER-TESTING.md` says no email/notification Edge Functions are deployed. Update the documentation or function deployment only after confirming the intended staging boundary. Do not send real emails during testing.
6. **Function inventory difference:** Only `global-admin-control` is common by slug between production and staging; staging additionally has `owner-testing-authorize` and `krim-resend-email-worker`. This is an intentional isolation pattern in part, but staging does not yet contain the operational backend required for full ecosystem E2E tests.

All source observations above are review findings, not proof of exploitability or successful runtime behavior.

## 4. Existing automated test coverage interpretation

The production smoke workflow runs source-level workflow assertions and the complete static repository audit. The static-link workflow scans local links, route registry destinations, duplicates, redirects, placeholder wording and visible backend-reference signals.

These are valuable source checks. They do not execute every browser control, authenticate synthetic roles, validate tenant isolation, call every RPC, deliver provider notifications, settle payments or test long-duration service reliability.

No new browser, API, load or destructive test was executed in this continuation.

## 5. Phase 00 gap register additions

| ID | Finding | Priority | Required evidence |
|---|---|---|---|
| P00-R01 | 26 canonical routes vs 36 sitemap URLs vs 1,017 HTML files require classification | High | Classified route manifest with route owner and deployment status |
| P00-E01 | Preview mode disables auth; not suitable for authenticated acceptance testing without a separate controlled staging path | Critical | Verified staging auth path and environment-routing tests |
| P00-F01 | Production still has active Cashfree order/verification functions despite retirement intent | High | Call-site/secret/config inventory and approved retirement plan |
| P00-F02 | Public webhook/tracking and retry endpoints require endpoint-specific negative security tests | Critical | Request/response test matrix and execution evidence |
| P00-S01 | Staging Resend worker conflicts with staging isolation documentation | High | Reconciled deployment inventory and updated boundary documentation |
| P00-S02 | Staging lacks the operational Edge Function set needed for full E2E coverage | Critical | Approved staging function deployment plan with test-safe provider adapters |
| P00-C01 | Existing CI is primarily static/source-level and not full browser acceptance testing | High | Browser/API E2E test plan and verified execution reports |

## 6. Safety and current status

- No production rows, schema, secrets, payment settings or user accounts were changed.
- No staging rows, schema, secrets or permissions were changed.
- No synthetic accounts were created.
- No external email, Telegram, payment or webhook action was triggered.
- No production load or destructive test was run.

**Phase 00 remains IN PROGRESS.** Route classification, function/trigger body reconciliation, staging owner activation procedure review, CI artifact inspection and a consolidated blocker register remain outstanding.

**Release decision:** Not approved for unrestricted real-user onboarding on the basis of these findings. This is a discovery report, not a final readiness assessment.
