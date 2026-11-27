# KRIM Staging Notification Worker Source-of-Truth and Queue Claim Audit — 2026-11-27

## Scope and safety
Read-only comparison of deployed Staging Edge Functions, Staging branch repository sources and Staging database RPC definitions. Project: `qrpcivhdxobiaofppbkl`. No function invoked, no queue claimed, no provider contacted, no email/Telegram message sent, no DB writes. Production untouched.

## 1. Deployed legacy Resend worker
Staging currently has `krim-resend-email-worker` ACTIVE v1, `verify_jwt=false`. Its deployed source:
- Requires POST and a custom `x-krim-cron-secret`.
- Requires Supabase URL/service-role key, Resend key and sender address.
- Does NOT contain the repository worker's explicit `KRIM_NOTIFICATION_EMAIL_SENDING_ENABLED=true` kill switch.
- Calls `krim_internal_claim_resend_email_batch(10)`.
- Sends to Resend and calls `krim_internal_finish_resend_email`.

Earlier source inspection established that the legacy claim routine selects pending/failed partner-verification email records and does not carry a test-lane/run exclusion. This deployed worker is a live-provider path and must remain uninvoked during tests.

## 2. Repository worker is a different implementation
Staging branch `staging/phase00-env-isolation` contains `supabase/functions/krim-notification-email-worker/index.ts`, blob SHA:
`47f597a4dd65c442d7e70f1eadfef4dc4899834b`.

Differences from deployed worker:
- Different slug and RPC contract; repository slug is not deployed in Staging.
- Repository worker has a deliberate `KRIM_NOTIFICATION_EMAIL_SENDING_ENABLED === "true"` gate and otherwise returns 503 `email_sending_disabled`.
- It calls `krim_claim_email_notification_delivery`, then cancel/eligibility/complete RPCs.
- It processes up to five deliveries per invocation and sends only Resend email for an explicit allowed event-type set.
- It still uses the shared notification outbox/delivery tables and the claim RPC does not filter a workflow test lane or fixture run.

**Conclusion:** these are not equivalent versions. The deployed function is older and lacks the repository's explicit send-enable gate. Do not redeploy, disable or replace until deployment ownership and all external callers are confirmed.

## 3. New repository RPC queue claim still has no lane boundary
Staging SQL source for `krim_internal.claim_email_notification_delivery(text,integer)`:
- Selects any due `channel='email'` outbox row in pending state, or expired processing state.
- Uses SKIP LOCKED and claims one row.
- No `runtime_lane`, `fixture_run_id`, workflow lineage or test/production queue predicate.
- It invokes `validate_notification_delivery` after claim.
The completion/cancellation routines update shared outbox and delivery state and append retry history. Thus the new worker's send-enable gate is useful but does not itself provide fixture isolation. Never turn that gate on for test traffic until queue isolation and provider sink behavior are verified.

## 4. Other repository notification paths
- `krim-notification-retry-worker` can send Telegram messages to founder-configured chat and claims founder inquiry/follow-up retry records. It accepts either the cron secret or an authenticated platform admin. It is not a customer workflow test runner.
- `krim-notification-provider-adapter` has an authenticated platform-admin Telegram test route that sends a real Telegram message when configured; Resend route only reports credential presence and explicitly says sending_enabled=false.
- `krim-public-contact-inquiry` writes public inquiry/outbox records, links to service-request qualification, and attempts immediate Telegram founder notification. Do not use it as synthetic workflow ingress for Phase 00.
- These sources have not been established as deployed Staging function slugs merely because their repository files exist.

## 5. Current Staging deployed Edge Function inventory
The latest Staging list shows five active functions:
- `owner-testing-authorize` v5, JWT required
- `global-admin-control` v2, JWT required
- `krim-phase00-provision-test-organizations` v2, JWT required
- `krim-phase00-test-user-invites` v3, JWT required
- `krim-resend-email-worker` v1, JWT not required (custom cron secret in source)

The repository `krim-notification-email-worker`, retry worker, provider adapter and public inquiry functions are not in this deployed list.

## 6. Required gates before notification/workflow test execution
1. Inventory external schedulers and manual callers for the deployed legacy worker; external configuration is still unverified.
2. Choose and explicitly approve the canonical email worker source/slug.
3. Add a database-enforced production/test queue boundary; a worker environment flag is not sufficient isolation.
4. Ensure test lane is excluded from every real email/Telegram provider path, including retry workers and direct ingress.
5. Use a non-delivering sink for test assertions, with delivery state and retry behavior observable separately.
6. Verify function source hashes and deployment version after any future Staging-only deployment.
7. Only then execute isolated workflow/notification tests.

## 7. Status
- Deployed legacy worker vs repository worker discrepancy confirmed.
- Repository worker has a send-enable gate; deployed legacy worker does not.
- Both queue models use shared operational tables and do not yet establish test-run lane exclusion.
- No invocation, provider call, queue claim, email, Telegram message, mutation or migration.
- Production untouched.
- Phase 00 OPEN — NOT APPROVED; Phase 01 not authorized.
