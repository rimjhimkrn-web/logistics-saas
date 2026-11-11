# KRIM Booking Lifecycle — Web, Mobile and Payment Caller Map
Date: 2026-11-11
Branch: `audit/workspace-rls-review-2026-11-11`
Status: SOURCE-LEVEL CALLER TRACE — NO CODE OR DATABASE CHANGES

## Canonical flow currently expected by payment gates

The payment server functions currently require this chain:
1. Customer quote is accepted and linked to the shipment/customer organisation and partner quote.
2. Matching shipment-partner assignment is `accepted`.
3. Assignment has a shipment leg and capacity binding.
4. Capacity-leg binding is `confirmed` and points to a reservation.
5. Reservation is `confirmed` and matches the same partner organisation, shipment and leg.
6. Quote validity, amount/currency and payment capability are revalidated before Razorpay order creation; verification repeats the quote, assignment and capacity checks.

This is a strong downstream payment gate. It does not repair an earlier workflow that marks a customer quote accepted before the partner accepts.

## Customer-facing web callers

### `public/partner-selection-assignment.html`
- Calls `krim_award_partner_quote_for_checkout`.
- Immediately receives a customer quote ID and tells the user the partner acceptance is still pending.
- Refreshes the assignment row; checkout remains disabled unless assignment is accepted and its capacity binding is confirmed.
- This is the direct UI for the alternate award path that currently creates customer quote and quote version as `accepted` while the assignment is still `offered`.
- Required change: server should return a pending award/offer state and must not create an accepted/payable customer quote until partner acceptance and required capacity gates have passed. UI response contract and state labels must change with it.

### `public/shipper/quote-comparison.html`
- Reads matching assignment status before enabling customer acceptance.
- Calls `krim_accept_global_quote` and locally changes quote/shipment display after the RPC succeeds.
- Its client-side pre-check is helpful UX, not an authorization boundary; the server RPC must enforce the same partner and capacity requirements.

### `public/customer-os/assets/quote-operations.js`
- Also calls `krim_accept_global_quote`.
- It tells users partner assignment, final booking and payment still require their own verified states.
- Must be updated to reflect the canonical partner-first sequence and server-returned state.

## Operations web caller

### `public/operations/partner-selection-assignment.html`
- Customer/operations award action calls `krim_award_partner_quote`.
- It expects an assignment row with status initially `offered`.
- Partner response action calls `krim_respond_to_partner_assignment`.
- It reports award and partner response separately.
- This path must not mark the shipment confirmed or opportunity awarded in a way that implies a completed commercial booking before partner acceptance. Preserve a clear offer/decline/accept state.

## Partner web caller

### `public/partner/accepted-loads.html`
- Partner accept/decline calls `krim_respond_to_partner_assignment`.
- After acceptance, the page exposes schedule/reserve capacity for assignments in `accepted` or `active`.
- Capacity RPC: `krim_partner_reserve_shipment_leg_capacity`, with departure, arrival and an idempotency key.
- UI requires backend response containing reservation ID, binding ID and confirmed status.
- This web workflow is currently the identified partner-facing capacity reservation caller.

## Mobile callers

### Customer app — `mobile/krim-customer/src/CustomerWorkspace.tsx`
- Accept quote: `krim_accept_global_quote`.
- Create payment order: `create-global-razorpay-order`.
- Verify payment: `verify-razorpay-payment`.
- App locally requires accepted quote and confirmed shipment before invoking order creation; server remains authoritative.
- Must align quote acceptance UI/state with the canonical partner-first flow and display pending partner acceptance/capacity states rather than offering premature acceptance.

### Partner app — `mobile/krim-partner/src/PartnerWorkspace.tsx`
- Submit quote: `krim_submit_partner_quote`.
- Accept/decline assignment: `krim_respond_to_partner_assignment`.
- No call to `krim_partner_reserve_shipment_leg_capacity` was found in the inspected PartnerWorkspace source. The mobile partner flow therefore does not expose the same schedule-and-reserve capacity step identified in the web accepted-loads page.
- Required: add a secure capacity scheduling/reservation experience to mobile, or deliberately route the partner to the web capacity workflow; do not allow the customer to pay before the required confirmed binding/reservation exists.

### Driver app — downstream only
Earlier source trace identified `krim_driver_record_trip_event` for pickup/in-transit and `krim_driver_submit_delivery_pod` for POD. These belong after dispatch and must not be reachable as a consequence of an offer or premature customer quote acceptance.

## Payment Edge Functions

### `create-global-razorpay-order`
Server reads accepted customer quote, then requires:
- matching accepted assignment for the quote's partner quote;
- assignment shipment leg and capacity binding;
- binding status `confirmed` and linked reservation;
- reservation status `confirmed` and exact partner/shipment/leg linkage;
- valid amount, currency, quote expiry and enabled payment capability.
It blocks when the partner has not accepted or capacity is not confirmed.

### `verify-razorpay-payment`
Repeats exact quote identity/status/expiry/amount/currency validation, accepted assignment validation and confirmed binding/reservation checks before reconciling payment. Existing paid retries have separate idempotent handling.

### `razorpay-webhook`
Verifies webhook signature and event ID, records/retries webhook events and reconciles provider events. Must be regression-tested against premature/invalid orders and state changes after order creation. It must never infer partner acceptance solely from a paid provider event.

## Coordinated change list (implementation contract)

1. Define authoritative statuses and event ordering for partner quote, opportunity, assignment, customer quote/version, shipment, capacity commitment and capacity binding.
2. Change both award RPCs and any trigger dependencies atomically; ensure an offer is not represented as accepted/awarded/confirmed prematurely.
3. On partner acceptance, atomically validate partner eligibility and quote validity, accept assignment, confirm partner capacity commitment, and expose customer quote acceptance/payment readiness only when required binding and reservation states are confirmed.
4. Apply the same gate to `krim_accept_global_quote`; no authenticated RPC path may skip the partner-first lifecycle.
5. Update all listed web and mobile callers and their response-state handling. Add capacity reservation to mobile partner experience or explicit supported handoff.
6. Revalidate order creation, payment verification, webhook reconciliation and post-order cancellation/rejection races.
7. Add tests for every route: customer web, customer mobile, partner web, partner mobile, operations web, driver downstream, payment order, payment verification and webhook.

## Release blockers and safety

- No code implementation was made in this trace.
- No staging branch created; no staging cost incurred.
- No production or staging SQL applied.
- No live Edge Function deployed.
- No shipment, quote, assignment, capacity or payment record created/modified.
- The separate staging project remains blank. End-to-end tests cannot yet be honestly reported as passing.
- Do not merge the partial quote-acceptance migration or enable live booking/payment until both award paths and all callers pass the coordinated test suite.
