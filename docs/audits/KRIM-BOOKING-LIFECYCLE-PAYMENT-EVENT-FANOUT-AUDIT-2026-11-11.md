# KRIM Booking Lifecycle — Payment and Event Fan-out Dependency Audit
Date: 2026-11-11
Branch: `audit/workspace-rls-review-2026-11-11`
Status: READ-ONLY PRODUCTION CATALOG REVIEW

## Scope
Read-only inspection of production trigger definitions on:
- `krim_shipments`
- `krim_shipment_partner_assignments`
- `krim_quotes`
- `krim_capacity_reservations`
- `payment_orders`
- `payments`

This is a trigger inventory, not a full source review of every trigger function or every external consumer.

## Confirmed downstream fan-out

### Shipment status writes
`krim_shipments` has multiple status-update triggers:
- BEFORE: readiness enforcement.
- BEFORE: dispatch capacity confirmation guard.
- AFTER: shipment status event emission.
- AFTER: operational snapshot refresh.
- AFTER: status audit logging.
- AFTER: status history recording.
- AFTER: terminal capacity release.

Implication: changing shipment status semantics is not a local field update. A transition can be blocked by readiness/dispatch guards and can fan out into events, snapshots, audit/history and capacity release. The new lifecycle must use the canonical transition path and test each side effect exactly once.

### Partner assignment writes
`krim_shipment_partner_assignments` has:
- AFTER INSERT/UPDATE: assignment audit.
- AFTER INSERT/UPDATE OF status/partner quote/partner org: shipment-level capacity commitment.
- AFTER UPDATE OF status: customer quote cancellation on partner rejection.
- BEFORE changes to shipment/leg/partner/partner quote: assignment-to-quote integrity guard.
- AFTER terminal status: release capacity.

Implication: assignment acceptance/rejection already drives capacity and quote side effects. New RPC logic must not duplicate those writes or bypass their transaction. Rejection handling currently needs explicit validation for draft/sent customer quote and presented version, not only already-accepted quote state.

### Capacity reservation writes
`krim_capacity_reservations` has:
- BEFORE INSERT/UPDATE: attach matching capacity commitment.
- BEFORE INSERT/UPDATE: prevent physical-resource overbooking.
- AFTER INSERT/UPDATE/DELETE: synchronise commitment counters.

Implication: capacity reservation is a guarded transactional subsystem. The lifecycle must use its existing authoritative reservation path; do not create reservation/binding rows manually or update counters in a second code path.

### Quote creation
`krim_quotes` has an AFTER INSERT quote-creation audit trigger. Any revised checkout-award RPC that creates a quote will produce this audit event immediately. Its payload/status semantics must describe a draft/sent/presented offer accurately; do not insert an already-accepted quote before partner/customer acceptance.

### Payment fan-out
`payment_orders` has:
- BEFORE UPDATE timestamp maintenance.
- AFTER INSERT/UPDATE sync into `private` payment transaction records.
- AFTER UPDATE OF status customer paid notification.
- AFTER UPDATE OF status financial synchronisation.

`payments` has an AFTER INSERT/UPDATE OF status financial creation trigger.

Implication: payment status mutation is not merely a provider-status update. It can synchronise private payment transactions, notify customers and create/update financial records. Webhook retries and manual reconciliation must be idempotent across all these paths. Do not add a second ledger write in the new booking RPC. Payment state must be changed only by the verified payment path and existing financial triggers must be regression-tested.

## Migration design consequences

1. Define a single source of truth for each lifecycle milestone. RPCs should mutate the canonical row once and let the existing trigger own its documented side effect.
2. Preserve transaction boundaries: assignment acceptance + capacity commitment + assignment audit must commit or roll back together.
3. Reservation + binding + commitment counter sync must be tested as one logical operation.
4. Shipment transition + status event + snapshot + history + audit + capacity release must be tested for exactly-once behavior and rollback.
5. Payment order/provider event/payment transaction/financial record/notification paths need idempotency tests across duplicate webhook delivery and retry.
6. Partner rejection and expiry must close every pending customer quote/version and ensure open payment orders cannot later verify as a valid shipment payment.
7. Before code cutover, inspect function bodies for every trigger function listed above and map all consumers of their emitted events/outbox records. This catalog query does not prove downstream queue or external integration behavior.

## Remaining dependency inventory
Still required before a runnable migration:
- Full trigger-function source review and return/error behavior.
- Event/outbox consumers, cron jobs, Edge Functions and notification delivery.
- Quote-version actual table name, constraints, current-version rules and all mutation callers.
- Payment order state machine, webhook replay table, refund/void/reconciliation path and provider event handling.
- All direct UPDATE grants and service-role write paths for the state columns.
- Existing live production rows and duplicate/open-order data checks.

## Non-actions
Read-only catalog query only. No DDL, data updates, grants, function deployments, payment operations or staging bootstrap were performed. Production and staging remain unchanged; staging remains blank.
