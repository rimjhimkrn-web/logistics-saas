# KRIM Customer Journey — Step 10: Shipment Status Writers & Transition Callers

**Audit date:** 2026-11-13  
**Disposition:** **MULTIPLE STATUS AUTHORITIES FOUND — one confirmed readiness inconsistency and several legacy/internal writers need access and lifecycle review.**

## Scope

Read-only inspection of live production Postgres function definitions and transition catalogue, plus targeted source inspection of customer quote acceptance, operations partner assignment, customer shipment workspace and driver inbox. This is a focused inventory, not yet an exhaustive repository-wide static call graph.

## 1. Generic transition API

`public.krim_transition_shipment(bigint,text,text,jsonb)`:
- locks the shipment;
- reads its current state;
- requires an allowed row in `krim_shipment_status_transitions`;
- checks the configured permission and required reason;
- updates shipment status and metadata.

This is the central generic state-transition API, but it is not the only writer. Several SECURITY DEFINER workflow functions update shipment status directly. Those direct writes still fire table triggers, but do not necessarily enforce the generic transition catalogue or its permission mapping. Each direct writer needs a documented authorization boundary and invariant review.

## 2. Live status writers that call the generic transition function

Production function catalog search found these callers:
- `krim_create_global_shipment_from_places` (two overloads);
- `krim_create_global_shipment_idempotent`;
- `krim_driver_record_trip_event`;
- `krim_internal_activate_shipment_after_verified_payment`;
- `krim_internal_authorize_delivery`;
- `krim_internal_dispatch_assigned_shipment`;
- `krim_internal_finalize_partner_assignment`;
- `krim_internal_start_shipment_transit`;
- `krim_internal.convert_commitment_to_shipment`.

Some functions call the generic transition only for certain branches; others also issue direct status updates. A caller match does not prove every path uses the helper.

## 3. Direct status writes found in live database functions

### A. Verified-payment activation
`krim_internal_activate_shipment_after_verified_payment(p_payment_id)`:
- locks payment, accepted quote and shipment;
- verifies paid status, quote linkage, amount/currency and shipment linkage;
- if shipment is draft, directly updates it to quoted and then confirmed;
- writes a payment-authorized audit event.

Because the readiness trigger is a BEFORE UPDATE trigger and the evaluator selects the currently stored shipment row, the first `draft → quoted` update sees the pre-update `draft` state inside the evaluator and marks payment not required. The following `quoted → confirmed` sees the stored `quoted` state and requires paid evidence. This path has a payment record, so the second transition can pass. Preserve the payment/quote linkage checks.

### B. Commitment conversion — inconsistent payment treatment
`krim_internal.convert_commitment_to_shipment(p_commitment_id,p_requested_by,p_idempotency_key)` directly updates a draft shipment to `confirmed` in one statement, then updates booking conversion, booking request and commitment records.

The readiness trigger invokes the evaluator before the update. The evaluator selects the still-stored pre-update shipment row, which is `draft`; its payment branch therefore returns `not_required`. This means this direct `draft → confirmed` route can avoid the payment requirement applied to `quoted → confirmed`, while still evaluating compliance, documents and customs. It is a distinct lifecycle route and must be explicitly reviewed; do not assume all confirmation paths share the same payment invariant.

**Required action:** decide whether commitment conversion represents an already-paid/otherwise-authorized commercial commitment or whether it must be brought under the new partner-direct booking-confirmation transaction. Validate function EXECUTE grants, caller authorization, and commitment ownership before changing it.

### C. Partner assignment finalization
`krim_internal_finalize_partner_assignment(p_assignment_id)`:
- requires shipment `confirmed`, assignment `accepted`, linked partner quote and committed capacity;
- marks opportunity awarded, assignment active and shipment assigned;
- writes audit event.

It uses a direct shipment status update, so it relies on the table trigger rather than the generic transition function. The readiness trigger also applies to `assigned`; its evaluator requires payment evidence and clear compliance/documents/customs. This means an assignment can be commercially accepted but finalization to assigned may still fail on the execution readiness gate. This reinforces the need to define exactly which status is booking confirmation and which is dispatch/execution readiness.

### D. Dispatch
`krim_internal_dispatch_assigned_shipment(p_assignment_id)`:
- requires shipment assigned and assignment accepted/active;
- requires a partner quote;
- runs shipment readiness evaluator and operations dispatch-readiness check;
- updates shipment to dispatched;
- records tracking, partner execution and audit events.

The separate BEFORE dispatch capacity trigger requires accepted assignment and confirmed capacity binding/reservation. Keep these dispatch controls. The function's own explicit readiness checks plus the table readiness trigger are overlapping gates and should be reconciled, not removed casually.

### E. Start transit
`krim_internal_start_shipment_transit(p_assignment_id)`:
- requires dispatched shipment and accepted/active assignment;
- requires a real shipment leg;
- directly updates shipment and leg to in_transit;
- writes tracking, partner execution and audit events.

### F. Driver trip events
`krim_driver_record_trip_event(uuid,text,text)`:
- requires authenticated active driver membership and a driver assignment owned by that user;
- validates the linked partner assignment, shipment, leg and matching IDs;
- allows pickup, in_transit and exception; explicitly does not allow delivery completion (requires authorized POD verification);
- on in_transit, updates shipment from dispatched to in_transit and updates leg;
- writes driver, tracking and partner execution events.

This is a direct status writer, but its linkage and driver membership checks are meaningful controls. Retain POD-based delivery authorization.

## 4. Application callers confirmed

- `public/shipper/quote-comparison.html` calls `krim_accept_global_quote`; it then re-reads quote, shipment and assignment and verifies exact IDs and persisted states. It currently expects shipment `confirmed` and assignment `accepted`.
- `public/operations/partner-selection-assignment.html` calls `krim_award_partner_quote` and `krim_respond_to_partner_assignment`; after actions it checks the returned assignment ID, partner quote, shipment and partner organization and refreshes the register.
- Customer OS shipment operations asset reads shipment state but no direct status mutation was found in the inspected section.
- Driver inbox reads driver assignments and routes the user to the driver acceptance workspace; it does not directly mutate shipment status.
- Dispatch pages inspected are mostly thin wrappers; actual dispatch mutation is in the protected database function.

## 5. Critical design consequences

1. Do not modify only `krim_transition_shipment`; direct writers would retain divergent behavior.
2. Do not treat every `confirmed` transition as the same business event. Payment activation and commitment conversion currently reach confirmed through different paths.
3. Partner assignment finalization to `assigned` is still subject to full execution readiness; it may block a partner-direct booking even after the partner accepted.
4. Dispatch has strong independent controls (execution readiness, operations readiness and capacity reservation). Preserve them.
5. Driver transit update is intentionally tied to a dispatched shipment and linked accepted/active partner assignment; retain this boundary.
6. Delivery completion remains separate and protected by verified POD authorization.

## 6. Required next work

- Enumerate all remaining database direct writers, their EXECUTE grants, callers, and authorization checks (including delivery authorization, payment webhook activation, commitment conversion and internal dispatch).
- Map every shipment status transition consumer: UI labels/actions, edge functions, event handlers, notifications, analytics, SLA rules, reporting and scheduled jobs.
- Decide one canonical commercial booking state and one execution/dispatch gate.
- Make partner-direct confirmation atomic with quote/assignment finalization, while keeping partner capacity and dispatch readiness checks separate.
- Correct the BEFORE-trigger readiness evaluator so it accepts the intended candidate transition context (rather than querying the old persisted state) and so booking and dispatch gates are evaluated at their proper lifecycle stages.
- Add tests for draft→confirmed, quoted→confirmed, confirmed→assigned, assigned→dispatched, dispatched→in_transit, partner rejection, payment-confirmed and commitment-conversion paths, including unauthorized direct RPC calls.

## Safety boundary

Read-only production catalog/function/transition inspection and GitHub source reads. No production row writes, function or trigger changes, transition catalogue changes, grants, migrations, customer bookings, partner assignments, quote acceptances, merge or deployment. Staging remains empty.

## Exit decision

**Step 10 complete; implementation remains blocked.** The status lifecycle is not governed by one authority. In particular, the BEFORE-trigger evaluator reads the old stored status, causing direct `draft → confirmed` conversion to evaluate payment differently from `quoted → confirmed`. The next task is complete writer/grant/caller inventory before designing the corrective migration.
