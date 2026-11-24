# KRIM workflow retry attempt accounting fix — 2026-11-24

## Critical defect found during full-schema staging test
The production legacy executor increments `attempt_number` inside a PL/pgSQL block with an `EXCEPTION WHEN OTHERS` handler. When the executor raises after that increment, PostgreSQL rolls back the statements inside the protected block before running the exception handler. The legacy handler then records the action as failed, but the attempt increment is lost.

The proposed batch exception handler previously read the unchanged attempt count and scheduled retry without incrementing it. Repeated executor exceptions could therefore retry indefinitely without reaching `max_attempts`.

## Fix in PR #245
- The fenced batch now increments `attempt_number` itself when an executor exception is caught and the same lease/worker still owns the row.
- The increment is clamped to `max_attempts`; the existing retry/dead-letter branch then uses the corrected count.
- A stale lease assertion failure (`workflow_action_lease_stale_or_not_owned`) does not consume an attempt.
- If the lease has been replaced, the exception handler still exits without mutating the replacement worker's row.
- The isolated PostgreSQL fixture now mirrors the production claim behavior (claim does not increment attempts) and the executor's PL/pgSQL exception-subtransaction behavior.
- CI assertions now cover first exception → retry, repeated exception → dead-letter, correct attempt counts, and stale-worker non-mutation.

## Full-schema staging validation
A transaction on the connected KRIM staging database applied all three proposed migrations, inserted a synthetic workflow action whose real exception path fails on a missing shipment FK, and executed the actual staging batch/claim/recovery/quarantine functions.

Observed behavior:
1. First failed execution: action entered `retry_wait`, attempt count became 1, lease cleared, workflow step returned to `pending`.
2. After making the retry due and executing again: action entered `failed`, attempt count became 2 (max attempts), `dead_lettered_at` was set, a `krim_workflow_dead_letters` row was created with `failure_class='max_attempts'`, workflow run became `failed`, and lease was cleared.

All assertions passed. The transaction was rolled back. A follow-up read-only query confirmed zero workflow action, event, notification and dead-letter fixture rows; the proposed `notifications.event_id` column and renamed legacy executor did not persist.

## Release boundary
This validates the corrected retry/dead-letter path against the staging database's real schema and runtime functions. It does not authorize production migration deployment. Production migration-ledger reconciliation, broader RLS/API regression, real recipient provisioning and provider readiness remain separate gates.
