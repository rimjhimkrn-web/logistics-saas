# Phase 00 — Notification provider adapters, retry workers and staging execution-risk audit

**Date:** 2026-11-25  
**Branch:** `qa/phase-00-baseline-2026-11-25`  
**Scope:** Live Edge Function inventory and deployed source inspection in Production and Staging; read-only database function/ACL review; QA-branch source parity check.  
**Result:** Production has a founder-only Telegram retry worker and an admin-only provider readiness/test adapter. Staging has a separately deployed Resend email worker capable of sending real partner transactional email if its secrets and queue are configured. That staging worker is not present in the QA repository tree. No worker was invoked and no provider call was made.

## 1. Live Edge Function inventory

### Production project `ebltviniygljwwseplph`
- `krim-notification-provider-adapter`: ACTIVE, version 18, `verify_jwt=true`.
- `krim-notification-retry-worker`: ACTIVE, version 14, `verify_jwt=false`.

### Staging project `qrpcivhdxobiaofppbkl`
- `krim-resend-email-worker`: ACTIVE, version 1, `verify_jwt=false`.
- It is one of only three active Staging Edge Functions in the inspected inventory.

These inventory states are live project evidence. They do not establish that secrets are configured, queues contain records, or delivery has succeeded.

## 2. Production provider adapter

Deployed source and QA repository source were inspected.

### Authentication and authorization
- POST only.
- Requires bearer token, then validates it with `auth.getUser()`.
- Checks `admin.platform` using `krim_has_permission` with organization ID 1.
- Invalid sessions, permission errors and non-admin users are rejected.

### Email / Resend branch
- Checks whether `RESEND_API_KEY` exists.
- Returns credential/readiness status.
- Explicitly returns `sending_enabled: false`.
- Does not dispatch email in this branch.

### Telegram test branch
- Requires Telegram token and chat ID.
- Sends a fixed founder/system-test message to the configured Telegram chat.
- This is a real external side effect if invoked with configured credentials.
- No invocation was made during this audit.

**Assessment:** Admin-gated readiness/test adapter, not a general customer/partner delivery adapter. Its Telegram test is not a synthetic-only mock; it sends to the configured chat.

## 3. Production Telegram retry worker

Deployed source and QA repository source were inspected.

### Authentication
- Function has `verify_jwt=false`, but implements custom authorization.
- Accepts a configured cron secret in either `x-krim-cron-secret` or bearer-token position.
- Requires the configured secret to be at least 32 characters and compares SHA-256 digests.
- If cron authorization fails, it validates a Supabase user and requires `admin.platform`.
- Requires Supabase URL, anon key, service-role key, Telegram token, chat ID and cron secret.

### Processing
- Uses service role to claim two narrowly scoped founder-only Telegram queues:
  - `customer_inquiry_received`
  - `customer_inquiry_followup_due`
- Claim functions use row locking with `FOR UPDATE SKIP LOCKED`, limit batch size, restrict recipient to founder/primary, and cap attempts at five.
- Sends queue message to configured Telegram chat.
- Finishes each row with provider message ID or a bounded error; retry/dead-letter logic is present.

### Important boundary
This is founder alert delivery, not the missing nine-ecosystem customer/partner/driver/warehouse/customs/finance/operations/enterprise/admin notification system.

### Recovery concern
The inspected claim functions set records to `processing`. The inspected worker/claim path does not itself reclaim stale `processing` records. A separate watchdog/recovery routine would need to be proven before claiming crash-safe retries. No such runtime recovery was established in this pass.

## 4. Staging Resend email worker — important execution risk

Staging currently has an active deployed function `krim-resend-email-worker` with `verify_jwt=false`. The deployed source was inspected.

### Controls present
- POST only.
- Requires `x-krim-cron-secret`; checks secret length and constant-time-style digest comparison.
- Requires service-role key, Resend API key and sender address.
- Claims a maximum batch of 10 through `krim_internal_claim_resend_email_batch`.
- Restricts queue claim to `partner_verification_information_requested`, email/Resend, user recipients, valid UUID recipient references, non-empty subject/body and attempt counts below five.
- Looks up the actual Auth user's email and requires it to be confirmed.
- Escapes HTML content, constrains workspace path to a relative path, uses Resend idempotency key, and records provider message ID/error through a finish RPC.
- Retries are capped at five; failure is recorded and eventually dead-lettered.

### Gaps / risk
1. **Real external send capability:** this is not a mock. If its secrets are configured and a matching queue item exists, invocation can send real email.
2. **No recipient allowlist or sink mode:** source does not restrict delivery to a designated QA mailbox/domain.
3. **No environment assertion:** source does not verify that it is running only against the intended staging project or an approved test mode before contacting Resend.
4. **No operator-visible dry-run flag:** the worker has no source-level dry-run/suppress-send mode.
5. **Deployment/source drift:** this function is deployed in Staging but no corresponding `supabase/functions/krim-resend-email-worker/index.ts` exists in the inspected QA branch tree. Its source/version cannot be reproduced from that branch.
6. **Delivery terminology:** successful Resend API acceptance is recorded as `sent`; this proves provider acceptance, not recipient mailbox delivery. Provider webhook/bounce/complaint reconciliation must be inspected separately.
7. **Stuck processing:** the claim marks outbox/delivery as processing/sending. The inspected worker does not itself recover stale claims after abrupt termination.

**Assessment:** Staging Resend worker is implementation evidence for one partner-verification email path, but it is not safe to invoke as a QA test until an isolated recipient sink/allowlist and reproducible source deployment are established.

## 5. Database function ACL review

Read-only catalog inspection in both projects confirmed the inspected internal claim/finish functions are executable by `service_role` and not by `anon` or `authenticated`. This is the expected boundary for these service-role worker RPCs.

- Production has founder Telegram claim/finish functions.
- Staging has those functions plus Resend email claim/finish functions.
- No grants or function definitions were changed.

The query did not invoke these RPCs.

## 6. Staging / Production parity and source control

- Production provider adapter and Telegram retry worker are represented in the QA branch source tree.
- Staging Resend worker is deployed but absent from the inspected QA branch source tree.
- The staging email worker's database RPCs exist in Staging but were not established as Production-equivalent.
- This is a deployment provenance and environment-parity gap. Do not copy staging migrations/functions to Production or assume a deployable source baseline from the active function alone.

## 7. Evidence status

| Claim | Evidence | Result |
|---|---|---|
| Production Telegram worker exists | Live Edge Function inventory + deployed source | PASS — existence/source only |
| Production Telegram worker has custom auth | Deployed source review | PASS — source only; runtime negative tests not run |
| Production email adapter sends email | Source says sending disabled | NOT IMPLEMENTED by this adapter branch |
| Production Telegram test sends externally | Deployed source has Telegram sendMessage call | REAL SIDE EFFECT AVAILABLE; NOT INVOKED |
| Staging Resend worker exists | Live Edge Function inventory + deployed source | PASS — existence/source only |
| Staging Resend worker can send real email | Source calls Resend API using configured secret | CAPABILITY CONFIRMED; NOT INVOKED |
| Staging Resend secrets configured | Secret values intentionally not inspected | UNKNOWN |
| Staging Resend worker is QA-reproducible | No source file in QA tree | FAIL — source provenance gap |
| Resend recipient is QA-allowlisted | No allowlist in inspected source | FAIL — control absent in source |
| Provider accepted = delivered | No evidence of mailbox delivery in worker | NOT PROVEN |
| Retry crash recovery | No stale-processing recovery in inspected path | NOT PROVEN |

## 8. Required remediation before notification E2E

1. Retrieve and commit the exact Staging Resend worker source to the QA branch with a provenance note and version/hash match, after review.
2. Add a strict staging-only environment assertion and mandatory recipient allowlist/test sink; fail closed if absent.
3. Add a dry-run mode that claims no queue rows and makes no provider call, plus tests proving it.
4. Add a worker lease/heartbeat and stale-`processing` recovery process with bounded, idempotent retry behavior.
5. Separate `provider_accepted` from `delivered`; reconcile Resend webhook events, bounces and complaints before showing delivery as complete.
6. Add automated negative tests for missing/short/wrong cron secret, wrong method, empty/malformed queue, unconfirmed user, non-allowlisted recipient, duplicate invocation, provider 4xx/5xx, timeout and worker crash after claim.
7. Add controlled positive tests using a dedicated sink mailbox only after the sink is verified.
8. Do not run the Production Telegram test or either retry worker as part of ordinary QA. They are real external-send paths.

## 9. Release decision

- Production founder Telegram retry path: **SOURCE REVIEWED; RUNTIME NOT TESTED**.
- Production provider adapter: **ADMIN-GATED; EMAIL SEND DISABLED; TELEGRAM TEST HAS REAL SIDE EFFECT**.
- Staging Resend worker: **REAL EMAIL CAPABILITY; NOT SAFE FOR QA INVOCATION YET**.
- Staging worker source provenance: **FAIL / MISSING FROM QA TREE**.
- Provider delivery receipts: **NOT PROVEN**.
- Nine-ecosystem notifications: **NO-GO**.

**No Edge Function was invoked, no queue row was claimed, no secret value was read, no database write was made, and no email/Telegram message was sent.**
