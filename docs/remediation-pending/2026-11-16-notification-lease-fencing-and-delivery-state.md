# Notification worker lease, retry and delivery-state integrity

Date: 2026-11-16  
Status: live database reinspection; specification only  
Scope: `krim_internal` notification outbox and delivery functions

## Confirmed live function behavior

Inspected live definitions:
- `krim_internal.claim_notification_outbox(text,integer)`
- `krim_internal.validate_notification_delivery(bigint,text)`
- `krim_internal.complete_notification_delivery(bigint,text,boolean,text,text,text)`
- `krim_internal.schedule_notification_retry(bigint,text,text,text,integer)`
- `krim_internal.mark_notification_delivery_result(bigint,boolean,text,text)`

### 1. Expired processing leases are not reclaimed

The claim function selects only rows where `status='pending'`, `scheduled_at<=now()` and `next_attempt_at` is null or due. It changes status to `processing` and sets `next_attempt_at=now()+lease_seconds`.

There is no candidate branch for `status='processing'` whose `next_attempt_at` lease has expired. A worker crash after claim can therefore strand an outbox row indefinitely.

### 2. Worker identity is not a fencing token

The claim function stores `worker_id` in JSON metadata. Completion and retry compare only that string. There is no per-claim unique token or monotonically increasing generation. If a worker identity is reused, an old execution may be indistinguishable from a later claim by the same worker.

### 3. Delivery validation may create duplicate attempts

`validate_notification_delivery` checks that the outbox row is processing and the worker ID matches, then inserts a new delivery row. The inspected body does not first look for an existing active delivery for the same outbox attempt or enforce a unique attempt identity. Repeated validation calls can therefore create multiple delivery rows for one claimed outbox item unless a separate constraint/trigger prevents it; verify constraints before implementation.

### 4. Provider acceptance is incorrectly represented as recipient delivery

`complete_notification_delivery(..., p_success=true)` sets delivery status to `sent`, but also sets outbox `delivered_at=now()`. The separate legacy `mark_notification_delivery_result` sets both `sent_at` and `delivered_at` on provider success. Provider API acceptance or message-ID return is not proof that the recipient's device/mailbox accepted, displayed or read the message.

### 5. Competing completion paths

Both `complete_notification_delivery` and `mark_notification_delivery_result` can write delivery/outbox result state, but they have different worker-authentication and timestamp semantics. The legacy result function body does not require worker identity or verify an active claim. Its effective exposure must be checked through exact grants and callers before deciding whether it is reachable by untrusted roles.

### 6. Retry bookkeeping and state transitions need a single authority

The retry scheduler verifies the metadata worker ID and moves the outbox to pending with a delay and a retry event. The inspected body does not clear worker metadata when releasing the claim, does not require the row to be in processing, and does not compare a claim generation. The completion function's failure branch returns the outbox to pending but does not insert the same retry event. These paths can diverge in audit and stale-worker handling.

## Required remediation

1. Add a per-claim unguessable token or monotonic lease generation, distinct from worker ID. Every validate, complete and retry operation must present and match it.
2. Reclaim only expired processing rows using `FOR UPDATE SKIP LOCKED`, rotate the claim token/generation atomically, and increment attempt count exactly once per claim.
3. Make lease renewal explicit and conditional on current token/generation.
4. Give each outbox attempt a unique attempt identity. Ensure validation is idempotent and cannot create duplicate delivery rows for the same attempt; reconcile existing duplicates before adding constraints.
5. Separate states: queued, processing, provider-accepted/sent, delivered (only provider webhook/receipt evidence), bounced, failed, suppressed and dead-lettered as applicable.
6. Set `sent_at` on provider acceptance; set `delivered_at` only from a verified provider delivery event. Preserve provider message ID and event ID with deduplication.
7. Consolidate result writes behind one internal state-transition authority. Deprecate or harden the legacy result writer after enumerating all callers and grants.
8. Make completion/retry conditional on current claim token and expected status; reject stale workers even when their worker ID matches.
9. Use bounded exponential backoff with jitter, attempt limits, dead-letter visibility, provider-specific retry classification, and explicit suppression for permanent failures.
10. Ensure retries do not send duplicate messages after an ambiguous provider timeout; use provider idempotency keys where supported and reconcile provider message status before retrying.
11. Audit exact function ACLs, owners, SECURITY DEFINER search_path, Edge Function callers, cron secrets and provider webhooks. Keep internal routines outside exposed schemas and grant only required service identities.
12. Add staging tests for worker crash, lease expiry/reclaim, stale completion, repeated validation, duplicate webhook, provider timeout after acceptance, bounce, permanent failure, attempt cap, concurrent workers and audit consistency.

## Release decision

**NO-GO for reliable production notifications** until expired-lease recovery, fencing, attempt idempotency and provider-accepted-versus-delivered semantics are implemented and tested.

This document records inspection and required design only. No messages were sent, no notification rows were modified, and no production schema or function was changed. Migration and ACL changes remain blocked by migration-history reconciliation.
