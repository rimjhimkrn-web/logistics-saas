# KRIM shipment notification outbox handoff design — 2026-11-24

## Decision
The intent-aware identity resolver is now passing its isolated PostgreSQL 16 test suite. The workflow-to-outbox handoff is still **NO-GO** for production because live communication intents, routes, providers and recipient rows are not configured, and the existing workflow executor does not enqueue notifications.

## Verified production behavior
1. Active shipment workflows use these notification actions:
   - `prepare_customer_notification` for confirmed, dispatched, delivered and exception lifecycle workflows.
   - `prepare_partner_notification` for the assigned lifecycle workflow.
2. `public.krim_internal_execute_workflow_action(bigint)` currently marks those notification steps completed with `status=prepared` and `external_send=blocked_until_provider_and_recipient_ready`. It creates no outbox row and resolves no recipient.
3. `krim_internal.enqueue_communication_intent(...)`:
   - requires a non-empty idempotency key;
   - requires an active intent;
   - returns an existing outbox ID for an existing key;
   - selects only the first active route by route_order;
   - inserts one pending outbox row with `recipient_type='resolved'` and the supplied recipient reference;
   - does not resolve recipients or iterate them.
4. The production communication-intent, route, provider and recipient tables had zero rows at the time of the 2026-11-24 read-only audit.
5. Provider resolution requires an active matching provider and credential reference. No provider configuration was found.
6. Outbox has a partial unique index on non-null `idempotency_key`. Delivery rows have no unique constraint on `outbox_id`; repeated validation must not blindly insert duplicates.
7. The workflow action execution record already has lease fields and the claim function returns a lease UUID, but the current executor signature accepts only action_execution_id. The handoff must preserve the claim/lease ownership contract and avoid stale-worker completion.

## Approved-intent mapping for the current workflow catalogue
| Workflow code | Action type | Recipient type | Intent code |
|---|---|---|---|
| shipment.lifecycle.confirmed | prepare_customer_notification | customer | shipment.lifecycle.confirmed |
| shipment.lifecycle.dispatched | prepare_customer_notification | customer | shipment.lifecycle.dispatched |
| shipment.lifecycle.delivered | prepare_customer_notification | customer | shipment.lifecycle.delivered |
| shipment.lifecycle.exception | prepare_customer_notification | customer | shipment.lifecycle.exception |
| shipment.lifecycle.assigned | prepare_partner_notification | partner | shipment.lifecycle.assigned |

No default mapping is permitted. Unknown workflow/action combinations must fail closed and be quarantined or surfaced for operator review; they must never be converted to a guessed recipient type.

## Required handoff transaction
For each approved notification action, a future implementation should perform the following in one database transaction:
1. Lock and validate the workflow action execution and its current lease/claim token. A stale worker must not create or mark notification work.
2. Read the workflow code and shipment event context from the persisted workflow run/step and event, not from caller-supplied free-form values.
3. Resolve the exact recipient set using the intent-aware resolver. Do not use unverified organization contact rows.
4. For each resolved recipient, derive a deterministic idempotency key from immutable event ID + intent code + recipient user ID. Include an explicit version component so policy changes are deliberate.
5. Look up the active communication intent and configured route/provider. Require provider readiness and valid channel/destination controls before any external delivery attempt.
6. Call the existing enqueue function once per recipient with that recipient's organization ID and user ID reference. If there are no eligible recipients, record a durable no-recipient outcome rather than silently reporting a sent notification.
7. Persist the created outbox IDs in the workflow step/action result and mark the action succeeded only after durable outbox creation is confirmed. “Queued” or provider-accepted must not be called “delivered”.
8. On transaction failure, roll back the outbox rows and leave the workflow action eligible for bounded retry/dead-letter handling.

## Reliability and compliance gates
- **Idempotency:** enforce one outbox row per event × intent × recipient × policy version; test concurrent duplicate action execution.
- **Delivery uniqueness:** before changing delivery validation, add a safe uniqueness/idempotency design for delivery attempts. Do not simply add a unique outbox_id constraint if the product requires multiple legitimate channels per outbox.
- **Lease fencing:** pass and validate the claimed lease UUID (and worker identity) through execution/completion. A stale worker must not commit an outbox handoff.
- **Provider state:** distinguish queued, provider-accepted/sent, delivered, failed and cancelled states. Provider acceptance is not confirmed delivery.
- **Retry policy:** cap attempts, use bounded backoff, quarantine permanent failures, and recover expired leases without duplicate sends.
- **Channel safety:** resolve verified destination ownership, apply channel-specific suppression/legal requirements, and keep mandatory durable in-app service notices separate from marketing preferences.
- **Fallback:** route fallback and channel mismatch must be explicitly designed. The existing enqueue function chooses one route only, and provider channel constraints do not cover every outbox channel.
- **Operations:** add traceable event/action/outbox/delivery correlation, redacted error details, monitoring and human escalation.

## Tests required before merge
- Each of the five workflow-code mappings above, including mismatched action and unknown workflow.
- One and multiple recipients; no eligible recipient; duplicate assignments; duplicate workflow dispatch; concurrent execution.
- Suspended/inactive users, wrong organization, revoked identity, unverified identity, inactive partner verification/compliance.
- Role exclusions (customer finance; partner finance/member/driver) and allowed roles.
- Missing intent, route, provider, credential reference and destination.
- Lease expired/reclaimed between claim and execute; stale worker attempts to enqueue.
- Duplicate outbox call returns the same outbox ID; deterministic idempotency key uniqueness.
- Provider acceptance is not recorded as delivered; retry and dead-letter paths are bounded.

## Scope and status
This is an implementation design based on read-only production definitions and counts. It changes no production schema, rows, secrets, routes, providers, cron jobs or notification settings. Do not apply a migration or enable external sends from this document alone.
