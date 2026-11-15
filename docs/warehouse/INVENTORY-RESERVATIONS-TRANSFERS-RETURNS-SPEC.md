# KRIM Warehouse Inventory Control — Workflow Specification

Status: Design specification; not a deployed workflow  
Date: 2026-11-15  
Scope: India-first warehouse operations, globally extensible by facility/jurisdiction configuration.

## Safety boundary

The current production movement RPC permits only approved `receipt` and `pick` movements. Direct `dispatch`, `transfer`, `return`, and `adjustment` movements are explicitly blocked. Preserve this fail-closed behaviour until the workflows below are implemented and tested. Do not grant direct table writes or enable movement types by changing a string allow-list.

Latest direct production snapshot: 0 approved facilities, 0 warehouse tasks and 0 inventory rows. Therefore a genuine warehouse E2E cannot currently be run.

## Required data model

Use canonical identifiers and immutable movement history. Exact table/column names must be reconciled with the live schema before migration.

### Reservations / allocations
A reservation must bind:
- organisation, facility, inventory item and shipment/leg;
- quantity and canonical unit;
- quality state (released stock only);
- source storage location / lot;
- status: held, committed, picked, released, expired, cancelled;
- expiry, idempotency key, creator and audit timestamps.

Invariants:
1. Reserved quantity cannot exceed available released quantity.
2. Available = on-hand minus active reservations and other committed allocations.
3. All quantity calculations use a canonical unit; conversions require an approved conversion record and independent review.
4. Lock the inventory balance and reservation aggregate in a stable order within one transaction.
5. Expiry/release must be idempotent and audited.
6. A shipment/leg cannot consume the same reservation twice.

### Transfer
A transfer is a parent operation with source and destination facility/location, items, quantities, reason, evidence, status and idempotency key. Each item must have a source lot and quality status.

Lifecycle:
- draft → submitted → approved → dispatched → received → closed;
- exception/shortage/damage path: dispatched → exception → reconciled or returned;
- cancellation only before dispatch.

Controls:
- Source and destination must be active, approved facilities in authorised organisations.
- Source stock must be released and unreserved quantity sufficient.
- Dispatch atomically decreases source on-hand and records an outbound movement while creating an in-transit transfer balance.
- Receipt records actual received quantity; any shortage/damage is a separate exception, not silently erased.
- Destination receipt creates destination inventory with preserved lot traceability and a pending quality state unless an approved policy explicitly permits status preservation.
- Independent reviewer approves discrepancies and final receipt; creator cannot approve own operation.
- No negative stock, no direct balance editing, and no cross-tenant visibility.
- Every state change writes an append-only event and audit record.

### Returns
A return must reference an original outbound movement, shipment, order or customer return authorisation. Unreferenced returns must enter a separately controlled exception workflow.

Lifecycle:
- requested → authorised → received_quarantine → inspected → dispositioned → closed.

Permitted dispositions:
- restock (only after independent QC release);
- repair/rework;
- supplier/customer return;
- scrap/write-off (requires elevated approval and evidence).

Controls:
- Returned goods always enter quarantine/pending quality; never auto-release.
- Capture reason, condition, quantity, unit, lot/serial, photos/documents and receiver.
- Independent QC decision and reviewer separation.
- Restock creates a new traceable movement and only adds released stock after approval.
- Scrap/write-off requires reason, evidence and role-based approval.
- Financial refund/credit is a separate finance workflow; warehouse receipt does not itself issue money.

### Picking / allocation
- Pick tasks must reference an active reservation or explicit authorised wave allocation.
- Pick quantity cannot exceed remaining reserved quantity.
- Short pick creates a reasoned exception and releases/adjusts unpicked reservation quantity.
- Pick retries replay only when every material field matches the original operation.
- Picking remains blocked for hold, pending or rejected stock.

## Required RPC boundary

Implement narrowly scoped SECURITY DEFINER RPCs with `search_path = ''`, fully qualified objects, explicit auth UID checks, organisation membership and permission checks, AAL2 for privileged review, and anon EXECUTE revoked.

Candidate operations (names are proposals, not existing live functions):
- reserve inventory / release reservation;
- submit transfer / approve transfer / dispatch transfer / receive transfer / reconcile transfer exception;
- authorise return / receive return / inspect return / disposition return;
- create allocation / pick allocation / record short pick.

No client should directly insert/update/delete inventory, reservations, transfer, return, movement or audit rows.

## Idempotency and concurrency

- Every command requires a caller-generated idempotency UUID scoped to organisation and operation.
- Store a canonical request fingerprint. Same key + same payload returns the original result; same key + changed payload fails.
- Lock inventory rows and relevant reservation/transfer rows with deterministic ordering.
- Enforce unique constraints for operation keys and one active reservation consumption per allocation line.
- Use serializable or equivalent row/advisory locking where aggregate invariants require it.
- Include bounded retries for serialization/deadlock errors; never silently retry external side effects.

## Security and privacy

- RLS scopes reads to active organisation membership and assigned operational scope.
- Cross-organisation transfer visibility is explicit and limited to source/destination parties.
- Evidence objects live in private buckets; validate exact path, owner, MIME, size and existence at review time.
- Reviewers cannot approve work they created, submitted, received or completed.
- Audit events record actor, organisation, object, prior/new state, reason, evidence references and correlation/idempotency key.
- Do not store unnecessary personal data in notes or event metadata.

## Required automated tests before enabling

1. Unauthenticated and anonymous calls denied.
2. Unrelated organisation and non-member denied.
3. Missing permission denied.
4. Pending/held/rejected stock cannot be reserved or picked.
5. Reservation contention cannot over-allocate stock.
6. Concurrent transfer/pick cannot create negative inventory.
7. Same idempotency key/same payload replays; changed payload rejects.
8. Transfer dispatch debits source once; receipt credits destination once.
9. Shortage/damage reconciles without silently losing quantity.
10. Return enters quarantine and cannot be picked until independently released.
11. Creator cannot approve own transfer/return/QC.
12. Evidence path, ownership, MIME, size and existence are verified.
13. Cancellation/expiry/recovery paths preserve stock invariants.
14. Audit/event rows exist exactly once for successful state changes.
15. Mobile/browser UI shows truthful state and prevents duplicate submission.

## Operational acceptance test

After an approved facility and authorised staff exist, test one real SKU/lot through:
receipt → independent QC release → reservation for a shipment leg → pick → dispatch handover → delivery or transfer/return exception → reconciliation.

Capture test IDs, actor roles, timestamps, movement IDs, inventory balances before/after, audit events, screenshots and deployment SHA. Only then mark the workflow operationally validated.

## Rollout plan

1. Review current schema, permissions, task triggers and existing idempotency constraints.
2. Add reservation/transfer/return tables and constraints in a reversible migration.
3. Implement guarded RPCs and audit events.
4. Add role-scoped UI and evidence upload.
5. Add SQL regression tests and smoke checks.
6. Run synthetic fixtures inside rollback-only transactions.
7. Deploy to production while feature flags remain off.
8. Test with a real approved facility and operator.
9. Enable only the validated workflow for that facility; do not globally enable by default.
