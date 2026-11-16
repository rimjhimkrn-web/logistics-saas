# KRIM Worker, Scheduler & Automation Infrastructure Audit
**Date:** 16 November 2026  
**Scope:** Read-only inspection of production pg_cron schedules and run history, pg_net HTTP responses, deployed Supabase Edge Functions, notification worker source, relevant worker RPCs, and secret existence metadata.

## Executive decision
**Database scheduling is active and executing reliably for the inspected jobs. The founder Telegram retry worker is deployed and scheduled. Actual notification delivery and end-user automation outcomes remain unverified because there are no queued notification records and no recipient-confirmed test.**

This audit corrects one conclusion in the preceding event/notification audit: the checked-in repository function listing did not show the notification worker, but the production Supabase project does have an ACTIVE deployed function named krim-notification-retry-worker. Its production deployment/source parity with GitHub is a separate issue that must be resolved.

No jobs were manually invoked, no cron schedule was changed, no notification was sent manually, and no production data was modified.

## 1. Scheduler extensions and active jobs
Production has pg_cron 1.6.4, pg_net 0.20.4 and Supabase Vault 0.3.1.

Nine active cron jobs were inspected:

| Job | Schedule | Purpose |
|---|---|---|
| krim-workflow-runtime-minute | Every minute | Process workflow events, dispatches, actions and replay queue/sync |
| krim-growth-signal-worker | Every 5 minutes | Process growth signals |
| krim-inquiry-followup-reminder-queue | Every 5 minutes | Queue founder-only inquiry follow-up reminders |
| krim-exception-escalation-worker | Every 5 minutes | Create due exception escalations |
| krim-capacity-hold-expiry | Every 5 minutes | Expire capacity holds |
| krim-notification-retry-worker | Every 5 minutes | HTTP invoke deployed Telegram notification retry worker |
| krim-driver-tracking-session-idle-expiry | Every 5 minutes | Expire stale driver tracking sessions |
| krim-partner-assignment-expiry | Every 5 minutes | Expire partner assignment offers |
| krim-vehicle-evidence-expiry | Every 5 minutes | Refresh vehicle evidence expiry state |

All nine are active and use the database cron role. This is evidence of configured schedules, not by itself evidence that every business outcome succeeds.

## 2. Cron execution history
For the inspected job IDs, the available cron history showed:

| Job | Recorded runs | Succeeded | Failed | Latest observed run (UTC) |
|---|---:|---:|---:|---|
| Workflow runtime (ID 2) | 51,063 | 51,063 | 0 | 16 Nov 03:14 |
| Growth signals (ID 3) | 10,207 | 10,207 | 0 | 16 Nov 03:10 |
| Inquiry reminder queue (ID 13) | 4,536 | 4,536 | 0 | 16 Nov 03:10 |
| Exception escalation (ID 14) | 2,838 | 2,838 | 0 | 16 Nov 03:10 |
| Capacity hold expiry (ID 15) | 2,832 | 2,832 | 0 | 16 Nov 03:10 |
| Telegram notification retry (ID 17) | 2,765 | 2,765 | 0 | 16 Nov 03:10 |
| Driver session expiry (ID 18) | 240 | 240 | 0 | 16 Nov 03:10 |
| Partner assignment expiry (ID 21) | 216 | 216 | 0 | 16 Nov 03:10 |
| Vehicle evidence expiry (ID 22) | 212 | 212 | 0 | 16 Nov 03:10 |

The latest inspected minute's jobs all recorded successful cron execution. The notification job's recent pg_net response table contained 72 responses in the preceding 24 hours: 72 HTTP 2xx, zero 4xx, zero 5xx, zero timeouts and zero transport errors.

**Interpretation limit:** pg_cron success means the SQL command completed; pg_net 2xx means the Edge Function returned a successful HTTP response. Neither proves a Telegram message was actually sent to a human. The worker returns success when it safely claims and processes an empty queue too.

## 3. Deployed notification worker
Production Supabase reports:
- Function: krim-notification-retry-worker
- Status: ACTIVE
- Version: 14
- JWT verification: disabled at gateway
- Custom authorization: required in function code
- Scheduled invocation: every five minutes through pg_cron/pg_net

The worker requires a server-side cron secret (minimum 32 characters) and validates it by comparing SHA-256 digests. It also permits a signed-in user only after validating the session and checking platform-admin permission for organization 1. It requires server-side Supabase URL, anon key, service-role key, Telegram bot token, Telegram chat ID and cron secret. No secret values were retrieved or recorded in this audit.

Vault contains one matching cron secret; its length is 33 characters. Only existence and length were inspected, never the secret value.

The function uses service-role access only after its custom cron-secret or platform-admin authorization. It processes two bounded batches (10 each):
1. Founder Telegram alerts for new customer inquiries.
2. Founder Telegram alerts for due customer inquiry follow-ups.

It calls claim RPCs, sends Telegram sendMessage requests with a 12-second timeout, then calls finish RPCs to update the outbox record. It records provider message ID on success and a redacted generic error on failure. This is a real deployed worker, not merely a schema design.

## 4. Retry logic and operational gaps
New inquiry retry:
- Claims pending/failed founder-only Telegram messages.
- Uses row locks with SKIP LOCKED.
- Increments attempt count and sets processing.
- Maximum five attempts.
- Failed attempts schedule increasing delays (60, 120, 240, 480 seconds).
- Final failure becomes dead_letter.

Follow-up reminder retry:
- Claims only founder-only follow-up messages with a specific idempotency-key prefix.
- Uses row locks with SKIP LOCKED.
- Maximum five attempts.
- Failed attempts schedule 5, 10, 20, 40 minute delays.
- Final failure becomes dead_letter.

Both finish RPCs require the row to be in the processing state and validate the intended founder/channel/type scope. This is a useful claim/finish pattern.

Remaining gaps:
- No outbox rows, delivery rows or retry-event rows existed at inspection time. Therefore no actual provider send, failure retry, dead-letter transition or recovery has been evidenced.
- The worker writes delivery state into the outbox but the generic notification delivery and retry-history tables remain empty; monitoring must use the actual authoritative record or unify the data model.
- The worker does not expose provider-delivered confirmation; it treats Telegram's successful sendMessage response as sent/delivered. That is provider acceptance, not necessarily human receipt/read.
- No durable worker execution ledger is visible for each cron invocation; cron and pg_net logs provide invocation evidence but not a joined business outcome per notification.
- The deployed function is not visible in the checked-in Supabase functions directory listing. Establish source-of-truth parity and deployment automation to avoid production drift.
- Gateway JWT verification is disabled; function-level secret/admin checks are therefore security-critical. Keep this function private to its explicit authorization contract and regression-test wrong, missing, short, rotated and revoked secrets.
- Secret rotation must coordinate Vault and Edge Function environment values; test old/new overlap or a planned atomic rotation to avoid worker outage.
- A provider timeout after Telegram accepted the message but before the response reached KRIM can cause a retry and duplicate alert. Telegram sendMessage does not provide a general idempotency key; design an explicit duplicate-risk policy and alert fingerprinting.

## 5. Workflow runtime and other scheduled automation
The every-minute workflow runtime function is SECURITY DEFINER, validates worker ID and bounded batch sizes, then:
1. Locks pending events with SKIP LOCKED and dispatches them to matching workflows.
2. Materializes queued dispatches into durable runs.
3. Executes registered internal workflow actions.
4. Processes dead-letter replay requests and synchronizes replay outcomes.

This is the scheduled path that was not proven by the previous table-only audit. The large successful cron run count establishes that the function is being invoked regularly. The nine historical dispatch rows and completed runs establish some prior workflow execution. However, current queue/dead-letter tables are empty, and the audit did not observe a non-empty pending event or action being processed in real time. Do not infer full failure-recovery correctness from invocation counts.

The inquiry reminder scheduler queues founder-only Telegram outbox records when due follow-ups exist, and explicitly records that customer messages are not sent. This separation is appropriate for founder operations alerts.

The exception escalation scheduler creates escalation and audit records but its function metadata explicitly marks notification status disabled until verified. Thus escalation record creation is not equivalent to notifying an owner.

## 6. Priority remediation
**P0 — source and delivery verification**
1. Recover the deployed notification worker source into the repository (or prove it matches a committed version) and establish a repeatable deployment path.
2. In a controlled test environment, enqueue one synthetic founder alert, observe the cron/worker claim, confirm one Telegram message at the configured test destination, verify provider message ID and final outbox status, and test duplicate/retry behaviour. Do not use a real customer contact as the test.
3. Add a worker run ledger with invocation ID, queue type, claimed/sent/failed counts, duration, safe error category and correlation ID. Do not log tokens or full customer PII.
4. Add alerting for cron staleness, repeated 5xx/timeouts, pending queue age, repeated failures and dead-letter count.

**P1 — recovery and security**
5. Add staging tests for secret rejection, admin authorization, service-role isolation, queue concurrency, crash after claim, provider timeout after acceptance, max attempts and dead-letter review.
6. Confirm stale processing rows are reclaimed safely after a worker crash; the current claim logic selects pending/failed rows, so a row left in processing may need a separate lease/recovery path.
7. Ensure retry history and generic delivery observability are consistent with the actual outbox state machine.
8. Verify Telegram bot/chat configuration without exposing tokens, then document rotation and emergency disable procedures.

**P2 — broader channels**
9. Treat email, SMS, push and customer-facing notification channels as not enabled until each has a provider-specific sender, consent/preferences, verified callback semantics, delivery state and tested retry path.
10. Keep outbound customer webhooks disabled until signature, replay, SSRF, retry and endpoint suspension controls are tested.

## 7. Scope limitations
Read-only inspection only. This audit did not invoke cron functions manually, modify schedules, send test messages, reveal secrets, inspect provider dashboards, run staging chaos tests, or validate the human recipient's Telegram account. pg_cron and pg_net history are bounded by retention/extension configuration and may not represent lifetime history. The migration-history reconciliation blocker remains: do not apply/replay production DDL or migrations until canonical source recovery and reconciliation is complete.

**Final status:** scheduler infrastructure is demonstrably active; workflow runtime and Telegram retry invocation are demonstrably scheduled and returning successful execution/HTTP results. Founder notification delivery is not yet independently proven; email/customer notifications and full automated recovery remain unverified.
