# KRIM Booking Lifecycle — Downstream Status Consumer and Side-Effect Audit
Date: 2026-11-11
Branch: `audit/workspace-rls-review-2026-11-11`
Status: READ-ONLY PRODUCTION REVIEW — NO CHANGES

## Findings from live production

### 1. Shipment status has multiple transactional side effects

A shipment status update is not a simple field change. Live triggers on `krim_shipments` include:
- BEFORE UPDATE readiness enforcement for `confirmed`, `assigned`, and `dispatched`.
- BEFORE UPDATE dispatch-capacity guard.
- AFTER UPDATE status event creation in `krim_events` (pending processing).
- AFTER UPDATE operational snapshot refresh.
- AFTER UPDATE status audit and status history.
- AFTER UPDATE capacity release on terminal shipment states.

Changing the meaning or timing of `confirmed` affects readiness evaluation, event consumers, snapshots, audit/history, and potentially capacity release. The new state machine must retain these side effects and test their event payloads/order.

### 2. Partner assignment status also has coupled side effects

Live assignment triggers:
- enforce quote/opportunity/shipment/partner/leg identity consistency before writes;
- on transition to `accepted`, create and validate a shipment-level capacity commitment;
- on `offered -> rejected`, cancel a linked customer quote only when that quote is already `accepted`;
- write assignment audit history;
- release capacity when assignment reaches terminal states.

A redesign that stops creating an accepted customer quote before partner acceptance must also change the rejection trigger: it currently will not cancel a pending `draft` or `sent` customer quote or its `presented` version. Otherwise rejected partner offers can leave a stale customer-facing quote.

### 3. Capacity reservation has additional safeguards

The partner reservation RPC's reservation insert/update invokes:
- a BEFORE trigger to attach a matching partner capacity commitment, where a unique matching active lane/mode/time commitment exists;
- a BEFORE trigger to lock the physical capacity resource and availability, verify organisation ownership, verification and availability state, unit match, and prevent resource overbooking across overlapping availability records;
- an AFTER trigger to synchronize capacity commitment counters.

This means the reservation operation is more than inserting a reservation row. Keep it inside the same transaction as confirmed binding creation, assignment linkage, schedule update and event/audit writes. Test the commitment-counter path and multiple matching commitment rejection.

### 4. Quote creation and status audit effects

A customer quote insert emits a quote-created audit event with shipment, amount, currency and initial status. Therefore, the alternate award wrapper that inserts a quote already marked accepted creates an audit record that can misleadingly look like an accepted commercial quote before partner acceptance. A replacement should create the quote in its genuine pending/presented state and emit later status events for partner acceptance, customer acceptance and expiry/rejection.

### 5. Known downstream status consumer

The live private claim-submission function allows claims only for shipments in `confirmed` or `closed` and associates the claim with an `accepted` or `completed` partner assignment. If the meaning/timing of `confirmed` changes, claim eligibility must be checked against the intended commercial and service milestones. Do not silently make claims available before a shipment is genuinely confirmed or remove post-delivery claim eligibility.

### 6. View and consumer discovery limitations

- The queried public views did not return a view definition directly referencing the three main quote/assignment/opportunity tables. This does not rule out indirect dependencies through RPCs, materialized views, client-side queries or event consumers.
- A targeted function-definition search identified the claim submission function, readiness evaluator, dispatch guard and quote acceptance function among the relevant status consumers. It was not a complete dependency graph.
- Notification/event processors, analytics, dashboards, scheduled jobs and external webhook consumers still require a repository and live function/caller inventory before implementation.

## Important operational consequence

The current award path attempts to set shipment status to `confirmed`. The live shipment readiness BEFORE trigger evaluates payment/compliance/documents/customs and can reject the transition if readiness is not `ready`. The readiness evaluator marks payment missing for statuses beyond `draft` and `requested`, and the partner assignment as not required while shipment status is `quoted` or `confirmed`.

This confirms that `confirmed` is currently overloaded: award/quote code uses it as an early commercial milestone, while readiness enforcement treats it as a later execution-ready milestone requiring payment. The coordinated design must resolve this before altering either RPC.

## Required coordinated correction

1. Define explicit meanings for shipment `quoted`, `confirmed`, `assigned`, `dispatched` and partner opportunity `shortlisted/awarded`.
2. Make both award RPCs create an offer, not a customer-accepted quote or paid booking.
3. On partner acceptance, atomically accept assignment and create the shipment-level capacity commitment.
4. On partner capacity reservation, atomically confirm reservation + leg binding + assignment link + schedule and events.
5. Only then permit customer quote acceptance; require matching assignment, partner quote, capacity commitment, confirmed binding and reservation.
6. Define payment initiation/verification and the shipment status that follows payment; align readiness enforcement and transition table.
7. Update rejection/expiry/cancellation triggers to close pending customer quotes and versions correctly.
8. Preserve audit/event/snapshot/capacity-release side effects and make notifications reflect real transitions only.
9. Update claim eligibility and every dashboard/API/mobile consumer of these statuses.
10. Add rollback-safe migration, function grants review, concurrency/idempotency tests and full end-to-end tests before production deployment.

## Release safety

Read-only production review only. No production or staging SQL, data, functions, triggers, grants, payment settings, Edge Functions or operational records changed. No paid staging branch created.
