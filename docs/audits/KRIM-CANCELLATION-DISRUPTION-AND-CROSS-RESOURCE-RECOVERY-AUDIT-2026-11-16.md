# KRIM Cancellation, Disruption and Cross-Resource Recovery Audit — 2026-11-16

## Scope
Read-only review of live production transition metadata, cancellation/exception routines, shipment and assignment triggers, related resource counts, and customer/operations UI routes. No production business function was executed and no production data was changed.

Repository files inspected:
- `public/shipments/cancellation.html`
- `app/operations/shipment-control.html`
- `app/operations/exception-management.html`
- `public/operations/exception-desk.html`
- `public/customer-os/assets/shipment-operations.js`

## Live production snapshot
| Resource | Rows |
|---|---:|
| Shipments | 18 |
| Partner assignments | 0 |
| Capacity reservations | 0 |
| Driver assignments | 0 |
| Dispatch authorizations | 0 |
| Shipment dispatches | 0 |
| Warehouse shipment allocations | 0 |
| Shipment-leg custody transfers | 0 |
| Notification outbox | 0 |
| Event workflow dispatches | 9 |
| Operational notification runs | 0 |

The empty operational tables mean no live records were available to prove end-to-end cancellation/release behavior. They do not prove the code will behave correctly when resources exist.

## Database controls observed

### 1. Generic shipment transition
- `krim_transition_shipment(bigint,text,text,jsonb)` is SECURITY DEFINER with `search_path = pg_catalog, public`.
- Effective authenticated EXECUTE privilege is false in the live database snapshot; it is not a customer-facing RPC in its current privilege state.
- The function locks the shipment, checks the configured transition table, checks the required permission when configured, checks a reason only when transition metadata requires it, then updates shipment status.
- The generic transition function itself does not visibly orchestrate all related resource releases or partner/driver/warehouse/custody/dispatch cancellation.

### 2. Transition metadata risk
Live rows permit:
- draft → cancelled
- quoted → cancelled
- confirmed → cancelled
- assigned → cancelled
- dispatched → cancelled

All five require `shipment.cancel`, but none requires a reason.

The same transition table permits dispatched → exception with `shipment.update` and a required reason. In-transit → exception also requires a reason. The generic dispatched → cancelled transition is inappropriate as a universal path once physical custody/dispatch may have begun: it can misrepresent a shipment that is already with a carrier as simply cancelled.

The transition table is configuration, not proof that an authenticated caller can invoke the generic function. The function's current authenticated EXECUTE check is false. No attempt was made to change this.

### 3. Readiness and event triggers
Shipment status updates have multiple database triggers:
- Readiness enforcement evaluates execution readiness before transitions into confirmed, assigned or dispatched.
- Status event trigger inserts a `shipment.status_changed` event into `krim_events`.
- Audit/history and operational snapshot triggers record status history and health.
- Separate shipment terminal trigger releases held/confirmed capacity bindings and linked reservations for cancelled/completed/delivered/failed shipments, with release events and audit events.
- Assignment terminal trigger releases linked capacity reservation/binding when assignment changes to rejected/cancelled/completed/failed.
- Partner assignment audit trigger records assignment changes.
- Partner assignment quote-rejection trigger cancels a related customer quote when a partner assignment is rejected.

These are useful partial safeguards. They do not amount to a complete cancellation orchestrator.

### 4. Missing cross-resource cancellation proof
No inspected shipment status trigger was shown to:
- transition or revoke partner assignments;
- cancel driver assignments or driver trip obligations;
- revoke dispatch authorizations or cancel existing dispatch records;
- release warehouse shipment allocations, picks, or inventory reservations;
- close or reconcile custody transfers;
- invalidate customer quote and booking state in every cancellation path;
- create and verify notification delivery to customer, provider, driver, warehouse and operations;
- coordinate partial/multi-leg cancellation with only affected legs released.

Capacity release is implemented at shipment/assignment terminal triggers, but release of capacity alone is not proof that the full physical and commercial journey is cancelled.

### 5. Exception resolution is not cancellation
`krim_resolve_operational_exception` requires authentication, a meaningful resolution note and `compliance.manage`; it resolves the exception, closes open escalations, cancels pending/triggered timers and pending/in-progress actions, cancels queued/running/waiting escalation runs, and writes an audit event. This is an exception-resolution routine, not a shipment cancellation routine. It does not prove external actions already in flight were withdrawn or reconciled.

## UI finding and correction

### P1 — Legacy cancellation form was a nonfunctional simulation
`public/shipments/cancellation.html` contained a hardcoded shipment reference, a status selector including “Cancelled & Released”, and a submit handler that merely displayed an alert and redirected to the audit log. It did not call Supabase, persist cancellation, notify a carrier, release capacity, or write an audit record. Its wording could lead a user to believe a cancellation had been recorded.

**Correction committed:** the page is now an explicit “Control not enabled” notice. It states no action has been taken, does not offer a fake submit button, warns against generic cancellation after dispatch/in-transit, and links to the existing exception and customer shipment workspaces. This prevents the legacy form from falsely representing a completed operation.

## Required staging test matrix before enabling cancellation
1. Customer can request cancellation only for a shipment in their active organisation; cross-organisation IDs are rejected.
2. Cancellation reason is mandatory, bounded, stored in audit history and shown in the timeline.
3. Draft/quoted cancellation is idempotent and does not create provider-side cancellation claims.
4. Confirmed/assigned cancellation requires provider acknowledgement or a defined provider cancellation contract/timeout path.
5. Capacity reservation and binding release happens exactly once; duplicate/concurrent requests are safe.
6. Driver assignment is revoked and driver notified before cancellation is marked complete.
7. Warehouse pick/allocation/stock commitments are released through inventory-safe transitions; already dispatched goods enter return/exception flow.
8. Dispatch authorization is revoked only when dispatch has not occurred; actual dispatch requires disruption/return handling.
9. In-transit cancellation is blocked from generic transition and creates an exception/disruption/return case with reason, owner and customer/provider communications.
10. Multi-leg cancellation releases only affected leg assignments, capacity and custody; unaffected legs remain intact.
11. Notification events are idempotent and actual provider delivery/retry/dead-letter state is verified.
12. Finance/referral invoices, credits, claims and provider charges are reconciled without moving or holding freight funds.
13. Terminal state is not shown until all required provider/driver/warehouse/dispatch/custody acknowledgements and release checks are satisfied.
14. Recovery from partial failure is resumable and auditable; no resource remains silently reserved or physically in transit under a cancelled label.

## Release decision
**Do not enable production cancellation or display “cancelled and released” as a completed result yet.** The database has partial capacity-release triggers and a useful exception-resolution workflow, but no proven cross-resource cancellation orchestrator. The legacy mock form has been disabled at the UI level.

A future implementation should use an explicit cancellation request state machine, reason and requester, provider acknowledgement, pre-dispatch resource release, post-dispatch disruption/return handling, per-leg coordination, idempotent event/outbox delivery and a final reconciliation gate. Build only after migration history reconciliation; do not patch production triggers or transition rows directly.
