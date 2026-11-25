# Phase 00 — Notification retry claim, finish and recovery audit

Date: 2026-11-25  
Branch: `qa/phase-00-baseline-2026-11-25`  
Scope: read-only inspection of Staging Resend claim/finish RPCs, Production parity and function ACLs. No RPC invoked; no queue claimed; no provider contacted.

## Executive result

The Staging Resend worker has a bounded, row-locked claim and finish path with exponential retry delay and a five-attempt dead-letter threshold. However, the path has no demonstrated stale-`processing` / stale-`sending` recovery. A worker crash after claiming can leave records permanently in processing/sending because the claim query only selects pending/failed outbox and queued/failed delivery states.

This is a narrow partner-verification email worker, not a universal notification dispatcher. Production has no matching Resend claim/finish functions.

**Status: do not run this worker against live recipients; notification readiness remains NO-GO.**

## Staging claim behavior

`krim_internal_claim_resend_email_batch(integer)`:
- Accepts batch size 1–25 (default 10).
- Selects only email/Resend rows for `partner_verification_information_requested`.
- Requires user recipient type, UUID-shaped recipient reference, non-empty subject/body.
- Selects outbox status pending/failed and delivery status queued/failed.
- Respects next-attempt/scheduled time and both outbox and delivery attempt caps (<5).
- Orders by priority, schedule and ID.
- Locks outbox and delivery with `FOR UPDATE ... SKIP LOCKED`.
- Atomically changes outbox to processing and delivery to sending; increments both attempt counters.
- Returns recipient, message, payload, attempt number and idempotency key.

Positive: concurrent workers should not claim the same currently eligible row at the same time due to row locks and SKIP LOCKED.

Gap: there is no lease expiry, claimed-at predicate, heartbeat, or stale-processing reset in this claim function. It does not select processing/sending rows. A process crash after claim but before finish can strand the pair.

## Staging finish behavior

`krim_internal_finish_resend_email(bigint,bigint,boolean,text,text,text)`:
- Requires outbox ID, delivery ID and success flag.
- Locks the matching outbox/delivery pair.
- Only accepts the expected partner-verification email, with outbox processing and delivery sending.
- On success, marks both sent and stores a provider message ID (truncated to 160 chars); records a retry-event history row.
- On failure, stores bounded error fields; retries with exponential delays (60s, 120s, 240s, 480s...) capped at 3600s; after attempt five, marks outbox dead_letter and delivery failed.
- Records retry-event history for both success and failure.

Important: `sent` means provider API accepted the request, not confirmed mailbox delivery. No callback-driven delivered/bounced/complained transition was established in this path.

## Authorization and SQL hardening

Both RPCs:
- SECURITY DEFINER.
- Empty search_path.
- Explicit ACL shows EXECUTE only for postgres and service_role; no anon/authenticated grant in the inspected ACL.
- Must be called only from the trusted server worker using service role and protected cron secret.

This is an appropriate narrow internal RPC boundary at source/catalog level. Runtime ACL tests were not run.

## Environment parity

- Staging has the two Resend functions.
- Production has no exact matching claim/finish functions.
- Earlier source inspection found the deployed Staging Edge Function `krim-resend-email-worker` can make real Resend API calls when secrets and eligible queue rows are present.
- The deployed Staging worker source was not present in the QA repository at the time of prior provenance review.
- Therefore deployment/source provenance is incomplete and Staging is not safe to treat as a synthetic-only sandbox yet.

## Required remediation before any worker test

1. Retrieve and commit the exact deployed Staging Edge Function source and record deployed version/hash.
2. Add an explicit staging-project assertion, recipient allowlist/test sink and dry-run mode that performs no queue claim and no provider request.
3. Add a lease/heartbeat and recovery function for stale processing/sending rows, with row locks and an audited recovery reason.
4. Ensure retry attempts remain bounded and cannot reset endlessly through stale recovery.
5. Add idempotent provider callback ingestion; distinguish accepted/sent from delivered, bounced, complained and suppressed.
6. Verify provider idempotency semantics and behavior when a provider accepts a message but the worker crashes before recording success.
7. Add tests for wrong/missing cron secret, wrong HTTP method, wrong project, recipient not allowlisted, malformed queue row, duplicate invocation, concurrency, provider 4xx/5xx, timeout, crash-after-claim and crash-after-provider-acceptance.
8. Only after the sink and isolation controls are independently verified, run synthetic Staging tests. Do not run the current worker against real user recipients.

## Evidence boundary

Read-only function definition and ACL queries. No claim/finish RPC or Edge Function was invoked. No outbox/delivery rows were changed. No email or Telegram was sent. Production and Staging remained unchanged.
