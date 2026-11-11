# KRIM Booking Lifecycle — Live Status, Constraint and Trigger Dependency Review
Date: 2026-11-11
Status: READ-ONLY PRODUCTION CATALOG REVIEW — NO CHANGES

## Scope

Inspected live production constraints, triggers, readiness evaluator, capacity reservation RPC and shipment transition rows for:
- `krim_shipments`
- `krim_partner_opportunities`
- `krim_partner_quotes`
- `krim_quotes`
- `krim_quote_versions`
- `krim_shipment_partner_assignments`
- `krim_partner_shipment_capacity_commitments`
- `krim_capacity_leg_bindings`
- `krim_capacity_reservations`

## 1. Existing statuses constrain the redesign

Live CHECK constraints currently allow:

- Shipment: `draft, requested, quoted, confirmed, assigned, dispatched, in_transit, delivered, closed, cancelled, exception`.
- Partner opportunity: `draft, open, shortlisted, awarded, cancelled, expired`.
- Partner quote: `draft, submitted, under_review, shortlisted, accepted, rejected, withdrawn, expired`.
- Customer quote (`krim_quotes`): `draft, sent, accepted, rejected, expired, cancelled`.
- Quote version: `draft, calculated, presented, accepted, expired, superseded, rejected, cancelled`.
- Partner assignment: `offered, accepted, rejected, cancelled, active, completed, failed`.
- Capacity binding: `pending, held, confirmed, released, expired, cancelled, failed`.

There is no explicit `pending_partner_acceptance` customer-quote status and no `offered` opportunity status. Do not write new statuses into these columns without a reviewed schema migration and all dependent code changes. Existing `draft` / `sent` customer quote and `shortlisted` opportunity states may support a partner-pending phase, but exact semantics must be confirmed with every consumer before implementation.

## 2. Critical readiness ordering conflict

Live `krim_internal_evaluate_shipment_readiness(bigint)` currently does the following:
- For shipment states `draft` and `requested`, payment is `not_required`.
- For later states, it requires a completed/paid shipment payment evidence record; otherwise it adds `verified_payment_missing` and returns `blocked`.
- It treats partner assignment as `not_required` while shipment state is any of `draft, requested, quoted, confirmed`.
- It only reports partner as assigned for `accepted` or `active` assignments after those early states.

The live `krim_shipment_readiness_enforcement` BEFORE UPDATE trigger invokes that evaluator for transitions to `confirmed`, `assigned` and `dispatched`, and rejects the transition unless readiness is `ready`.

This creates two conflicting lifecycle assumptions:
1. Award functions currently try to move `quoted -> confirmed` before partner acceptance and before customer payment.
2. Readiness evaluation for `confirmed` requires verified payment, while it does not require partner acceptance until the shipment moves beyond `confirmed`.

Therefore, do not simply change the award function to stop setting customer quote accepted and leave the shipment transition untouched. The canonical state design must decide precisely when payment is due and what `confirmed` means. A likely safer interpretation is to reserve `confirmed` for post-payment, post-partner-acceptance readiness, and keep pre-payment states in `quoted` (or introduce a new explicit state through a fully reviewed migration). This is a proposal, not an implemented change.

## 3. Capacity dependency chain

Live trigger `trg_krim_ensure_assignment_capacity_commitment` runs after assignment insert or status/partner quote updates. When assignment changes to `accepted`, it:
- requires positive shipment weight;
- requires a linked partner quote matching shipment and partner;
- inserts a committed capacity commitment in kg, tied to assignment;
- verifies matching partner, status committed, sufficient quantity and current validity;
- aborts the acceptance transaction if those conditions fail.

The separate `krim_partner_reserve_shipment_leg_capacity(...)` RPC then requires:
- authenticated active member of the assigned partner organisation and `shipment.update`;
- assignment status accepted or active;
- matching shipment leg and partner;
- current partner compliance and verified route capability;
- a verified, available vehicle or weight-capacity record covering the scheduled time;
- available capacity after existing held/confirmed reservations;
- a valid idempotency key.

It creates a confirmed reservation and confirmed capacity-leg binding, updates the shipment leg schedule and links the binding to the assignment, with reservation/binding events and audit event. It supports idempotent reuse.

This is a two-stage capacity model:
A. Partner assignment acceptance creates a shipment-level capacity commitment.
B. Partner schedule action creates a time-window-specific capacity reservation and leg binding.

Payment must require both stages to be current and matching. The Razorpay order function already checks the confirmed binding and reservation; retain that strict server-side check.

## 4. Assignment rejection trigger dependency

When an assignment changes from `offered` to `rejected`, the rejection trigger only cancels a linked customer quote if that quote is already `accepted`; it then cancels its latest accepted quote version and records an event.

This trigger exists because the current award wrapper prematurely creates accepted customer quote/version records before partner response. If the redesign stops doing that, rejection handling must be updated to close/cancel the pending `draft` or `sent` customer quote and its `presented` version, with an event, or the UI may retain stale payable offers. Test multiple quote versions and retry behaviour.

## 5. Shipment transition table inconsistency

Live `krim_shipment_status_transitions` contains:
- `quoted -> confirmed`: allowed.
- `confirmed -> assigned`: allowed.
- `assigned -> dispatched`: explicitly `allowed=false`.
- `dispatched -> in_transit`: explicitly `allowed=false`.
- `in_transit -> delivered`: explicitly `allowed=false`.

The separate internal dispatch function and driver milestone/POD workflows exist. This indicates the transition table is not a complete description of every privileged lifecycle path, or some transitions are intentionally internal-only. Do not broadly flip these rows to allowed. Trace every internal RPC and caller, and keep internal/service-role transitions guarded by their dedicated readiness, assignment, capacity, dispatch and POD checks.

## 6. Recommended canonical lifecycle design before coding

The database and all clients should agree on these business events:

1. Shipment request accepted for sourcing; status remains pre-confirmation.
2. Eligible partner quote shortlisted; customer-facing commercial offer is created as `draft` or `sent`, never `accepted`.
3. Partner assignment created as `offered`; opportunity remains `shortlisted` (or another existing non-awarded state) until explicit acceptance.
4. Partner explicitly accepts; assignment becomes `accepted`; the existing acceptance trigger commits shipment-level capacity.
5. Partner schedules the leg and reserves verified available capacity; binding and reservation both become `confirmed`.
6. Customer accepts the now-valid quote; quote and version become `accepted`.
7. Customer payment is initiated and verified; only then does shipment enter the status whose readiness contract requires payment (likely `confirmed`).
8. Operations activates assignment and dispatches only through guarded internal workflow; driver actions begin only after authorized dispatch.

This sequence is a target contract, not a claim that the live schema already implements it. Before choosing opportunity status and shipment status transitions, inspect every consumer of `awarded`, `confirmed`, readiness gates, notifications, analytics and billing.

## 7. Required implementation and regression work

- Reconcile `krim_award_partner_quote`, `krim_award_partner_quote_for_checkout`, `krim_accept_global_quote`, partner response RPC and assignment-finalization RPC as one transactional state machine.
- Preserve assignment acceptance capacity commitment and the separate confirmed leg binding/reservation.
- Update rejection trigger for pending customer quotes.
- Revisit readiness evaluator so pre-payment and pre-dispatch phases are not conflated; define payment, partner, compliance, document and customs gates by lifecycle stage.
- Reconcile shipment transition table with privileged internal dispatch/transit/POD lifecycle; do not enable generic client transitions.
- Update customer web/app, partner web/app, operations web, driver app and Razorpay order/verification/webhook.
- Add transactional concurrency, idempotency, expiry, cancellation, rejection, capacity exhaustion, payment failure and post-order state-change tests.

## Safety

This was a read-only production catalog review. No DDL, data, status values, trigger, function, grants, migrations, payment settings, Edge Functions or operational records were changed. No staging branch was created and no staging cost was incurred.
