# KRIM Customer Journey — Step 9: Booking Confirmation vs Dispatch Readiness

**Audit date:** 2026-11-13  
**Disposition:** **DESIGN BOUNDARY IDENTIFIED — preserve dispatch gates; create a separate partner-confirmed booking transition.**

## Read-only production findings

### 1. Shipment transition catalogue

The live `krim_shipment_status_transitions` rows inspected show:

| From | To | Allowed | Permission |
|---|---|---:|---|
| quoted | confirmed | yes | shipment.update |
| confirmed | assigned | yes | shipment.assign |
| assigned | dispatched | no | shipment.dispatch |

No `quoted → assigned` or `requested → confirmed` row was returned.

The current transition catalogue therefore expresses a sequence in which a quoted shipment becomes confirmed, then assigned. The current readiness trigger intercepts the transition to `confirmed` and demands the full execution readiness evaluator. The generic transition function is not a suitable shortcut around that trigger.

### 2. Readiness enforcement trigger

`krim_shipment_readiness_enforcement` is a BEFORE UPDATE OF status trigger. For any change into `confirmed`, `assigned` or `dispatched`, it invokes `krim_internal_evaluate_shipment_readiness` and raises an exception unless the result is exactly `ready`.

The evaluator:
- treats payment as `not_required` only for shipment states `draft` and `requested`;
- for other states, requires either a legacy `payments` row with `status='paid'`, or a completed Razorpay company-owned credit in `krim_financial_transactions`;
- requires compliance result `clear`;
- requires document result `clear`;
- blocks while customs records are neither cleared nor cancelled;
- checks partner assignment only for later execution states (not_required for draft/requested/quoted/confirmed).

This is an execution-readiness evaluator, but it is wired to booking confirmation as well. It is the root architectural mismatch for a partner-direct model.

### 3. Dispatch has a separate capacity gate

The additional private BEFORE trigger `trg_krim_guard_dispatch_capacity_confirmation` runs when shipment status becomes `dispatched`. It requires:
- at least one accepted partner assignment;
- each accepted assignment to have a matching capacity-leg binding;
- binding status `confirmed`;
- a linked capacity reservation;
- reservation status `confirmed`.

This is a legitimate dispatch control and should remain in place. It is separate from the erroneous use of KRIM-owned freight payment as a prerequisite to commercial booking confirmation.

### 4. Shipment transition function

`public.krim_transition_shipment` locks the shipment, reads the current status, checks the configured transition catalogue, checks the required permission, validates reason where required, and updates status/metadata. It does not itself provide a special partner-direct confirmation path. Any new path must preserve this transition policy and authorization model rather than allow arbitrary direct status updates.

### 5. Additional shipment status side effects

The shipment table has separate triggers for:
- readiness enforcement (before status update);
- status event emission;
- capacity release for terminal states;
- operational snapshot refresh;
- status audit;
- status history;
- dispatch capacity confirmation (before dispatch).

These effects should be retained and regression-tested. A correction must not bypass event, audit, history, snapshot or capacity triggers.

## Recommended architecture

### A. Booking confirmation
Create a dedicated, permission-checked server transaction for the customer-selected partner offer and partner acceptance. It should:
1. lock shipment, opportunity, partner quote, customer quote, assignment, partner organization, selected capability and linked shipment leg in a consistent order;
2. validate exact cross-record IDs, customer ownership, quote amount/currency, quote validity, partner current verification/compliance and capability coverage;
3. validate the assignment is the one offered to this partner and has not expired or been cancelled;
4. validate the selected real shipment leg belongs to this shipment and has a compatible requested transport mode;
5. atomically mark assignment and partner quote accepted, customer quote accepted, linked leg assigned/accepted, and shipment confirmed;
6. write required tracking/audit/quote events;
7. retain existing capacity commitment trigger behavior and rollback everything if it fails.

### B. Execution / dispatch readiness
Do not change the existing dispatch capacity gate. Before the shipment can be dispatched, require:
- partner accepted assignment and confirmed capacity reservation/binding;
- applicable compliance clearance;
- required documents;
- customs clearance when applicable;
- any legally required payment evidence.

For partner-direct freight payments, payment proof must be sourced from a partner/customer evidence workflow only if legally and operationally required, clearly labelled as partner-reported/verified evidence, and never represented as a KRIM payment or Razorpay settlement. The legal/tax and operational owner must define the required proof and who verifies it.

### C. Status policy
The cleanest design may require separating commercial booking from physical shipment execution more explicitly. Do not add new statuses or change `krim_shipment_status_transitions` until every status consumer, trigger, report, SLA, notification and edge function has been inventoried. Existing `confirmed` may remain the booking-confirmed status if the readiness trigger is changed to a booking-specific invariant rather than the full dispatch evaluator.

### D. Safe implementation sequence
1. Inventory every caller of `krim_transition_shipment`, direct shipment status update, and all status consumers.
2. Define the exact booking-confirmation invariants and the separate dispatch-readiness invariants.
3. Write a migration proposal that changes only the confirmation-specific guard; retain dispatch readiness and capacity controls.
4. Create migration-parity staging (current staging is empty).
5. Test partner-direct flows with no KRIM payment record, with partner payment evidence, with failed compliance/documents/customs, with missing capacity binding, and with mismatched partner/quote/leg IDs.
6. Test unauthorized direct RPC and direct table update attempts.
7. Deploy only after all tests and explicit approval.

## Safety boundary

Read-only production catalogue/function/trigger inspection. No production rows, functions, triggers, transition rules, grants, migrations, bookings, assignments, quote acceptances or shipment statuses were changed. No merge or deployment. Staging remains empty.

## Exit decision

**Step 9 complete.** The correct fix is not to remove payment/readiness enforcement globally. It is to stop applying the *execution readiness* evaluator to the *commercial booking confirmation* transition, while preserving separate dispatch and capacity gates. Implementation remains blocked on exhaustive caller/status-consumer inventory and staging.
