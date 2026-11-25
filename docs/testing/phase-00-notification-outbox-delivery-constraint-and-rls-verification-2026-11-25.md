# Phase 00 — Notification outbox and delivery constraint/RLS verification

Date: 2026-11-25  
Branch: `qa/phase-00-baseline-2026-11-25`  
Scope: read-only PostgreSQL catalog, RLS policy and aggregate row checks in Production and Staging. No writes, function calls, queue claims or provider operations.

## Executive result

The notification schema has useful baseline controls, especially a partial unique idempotency index on outbox rows and status/channel checks. However, important integrity guarantees are not enforced by database constraints:

- A delivery row is not protected by a foreign key to its outbox row.
- Multiple delivery rows for the same outbox are permitted.
- Provider message IDs are not unique.
- Delivery attempt counts have no non-negative check.
- There is no constraint requiring every outbox row to have a delivery row, or requiring delivery/outbox state consistency.
- The outbox's idempotency key is nullable; uniqueness applies only when supplied.

The same definitions and gaps were observed in both environments.

## Environment parity and row snapshot

Production and Staging have matching table columns, constraints, indexes and RLS policies for the three inspected tables.

Snapshot counts in each environment:
- `krim_notification_outbox`: 0
- `krim_notification_deliveries`: 0
- `krim_notification_retry_events`: 0

At inspection time:
- No duplicate delivery `outbox_id` groups.
- No orphan delivery rows.
- No outbox rows with NULL idempotency keys.

These zero-row results are not proof of correctness under load; the queues were empty, so duplicate/orphan behavior could not be exercised.

## Enforced controls

### Outbox
- Primary key on `id`.
- Partial unique index on `idempotency_key` where not null.
- Foreign key `event_id → krim_events.event_id`, ON DELETE SET NULL.
- Foreign key `organization_id → krim_organizations.id`, ON DELETE CASCADE.
- Checks for non-negative attempt count and priority.
- Checks for allowed channel and outbox status values.
- Dispatch/status/organization/event/recipient indexes.

### Deliveries
- Primary key on `id`.
- Checks for allowed channel and status values.
- Indexes on `outbox_id` and `(status,next_attempt_at)`.

### Retry events
- Primary key on `id`.
- Foreign key `outbox_id → krim_notification_outbox.id`, ON DELETE CASCADE.
- Index on `(outbox_id,created_at DESC)`.

## Missing integrity guarantees

1. **Delivery-to-outbox foreign key absent.** The delivery table's `outbox_id` is NOT NULL but no FK to outbox was found. Database can therefore accept orphan deliveries if a writer inserts one incorrectly.
2. **No unique delivery identity.** There is no unique constraint on `(outbox_id,channel)`, `outbox_id`, or another delivery identity. Multiple deliveries for one outbox are allowed, including accidental duplicates.
3. **No provider message ID uniqueness.** Duplicate provider callbacks or accidental provider-ID reuse are not blocked by a unique constraint in these tables.
4. **No delivery attempt-count check.** Delivery `attempt_count` is NOT NULL with default 0 but no `attempt_count >= 0` check was found.
5. **No cross-table status invariant.** Outbox and delivery statuses are independently constrained; there is no constraint enforcing legal transitions or consistency between them.
6. **No mandatory delivery existence.** Nothing requires an outbox row to have at least one delivery record.
7. **Optional idempotency.** Outbox `idempotency_key` can be NULL. The partial unique index protects supplied keys only; producers must be required by contract to supply a stable key.

## RLS findings

All three tables have RLS enabled but not FORCE RLS.

Policies observed identically in Production and Staging:
- Outbox SELECT: authenticated user must have organization access, and `organization_id` must be non-NULL.
- Deliveries SELECT: access is inherited through the parent outbox organization; however, the policy explicitly allows `organization_id IS NULL`. This creates a global-style visibility path for deliveries linked to outbox rows without an organization. Confirm whether such global rows are intended; otherwise fail closed.
- Retry-event SELECT: requires an active membership row for the outbox organization and current user.

No INSERT/UPDATE/DELETE policies were present in the returned policy inventory. This is consistent with writes being performed through privileged server-side paths, but the complete table grants and every privileged writer still need separate review. RLS runtime tests with distinct synthetic JWT identities have not been run.

## Required remediation before runtime notification tests

1. Add and validate a delivery `outbox_id` foreign key with an intentional delete policy.
2. Decide the true delivery cardinality. If one delivery per outbox/channel/provider is intended, enforce a matching unique key; if retries are attempts on one delivery, retain a single durable delivery row and model attempts separately.
3. Add a non-negative delivery attempt check.
4. Define uniqueness and idempotency for provider callbacks/message IDs, scoped by provider.
5. Require stable non-null idempotency keys for all producers (or enforce this through a producer-specific database contract).
6. Define explicit legal state transitions and recovery semantics; use transactional RPCs rather than assuming independent status checks provide consistency.
7. Decide whether global/null-organization outbox deliveries should be visible to all authenticated users; default to deny unless an explicit global-recipient policy exists.
8. Test cross-organization reads, null-org rows, duplicate concurrent producers, orphan insertion rejection, duplicate callbacks, retry transitions and dead-letter recovery in isolated Staging.

## Evidence boundary

Catalog definitions, RLS policies and aggregate counts only. No rows were inserted, updated or deleted. No notification worker or RPC was invoked. No test identities were created. No external provider was contacted. Production and Staging remained unchanged.
