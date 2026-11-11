# KRIM Booking Lifecycle — Caller and Payment Dependency Trace
Date: 2026-11-11
Status: REPOSITORY SOURCE REVIEW — NO CODE OR PRODUCTION CHANGES

## Scope and method

Reviewed the current `main` repository tree and source for the primary web booking pages, partner acceptance page, customer quote comparison, checkout readiness page, Razorpay order-creation Edge Function, Razorpay webhook and customer/partner mobile repository files. The current deployed Edge Function inventory was also read from production metadata. This is a static source trace, not a runtime test or proof that no external caller exists.

## Caller map

| Surface | Current source action | Backend path / implication |
|---|---|---|
| Operations partner selection | `public/operations/partner-selection-assignment.html` award action | Calls `krim_award_partner_quote`; partner response action calls `krim_respond_to_partner_assignment`. |
| Customer partner selection / checkout award | `public/partner-selection-assignment.html` | Calls `krim_award_partner_quote_for_checkout`; then polls assignment and capacity state. |
| Partner accepted loads | `public/partner/accepted-loads.html` | Calls `krim_respond_to_partner_assignment`; separately calls `krim_partner_reserve_shipment_leg_capacity`. Acceptance and capacity reservation are distinct actions in the UI. |
| Customer quote comparison | `public/shipper/quote-comparison.html` | Calls `krim_accept_global_quote`; performs a separate checkout-readiness check before exposing checkout navigation. |
| Customer OS quote operations | `public/customer-os/assets/quote-operations.js` | Also calls `krim_accept_global_quote`. |
| Checkout readiness | `public/shipper/payment-checkout.html` | Reads the exact quote, shipment and partner assignment; checks accepted assignment and capacity reservation; calls payment-capability status. It is a browser-side readiness display only, not a security boundary. |
| Razorpay order creation | `supabase/functions/create-global-razorpay-order/index.ts` | Server-side order creation checks confirmed shipment, matching accepted partner assignment, capacity reservation/binding, exact quote, payment capability and existing-order conflicts before calling Razorpay. This is an important independent fail-closed gate. |
| Razorpay webhook | `supabase/functions/razorpay-webhook/index.ts` | Verifies provider signature/event ID and reconciles payment/refund events against existing KRIM payment records. Its complete upstream order-creation lifecycle and all webhook side effects still require end-to-end tracing. |
| Customer mobile repository | `mobile/krim-customer/src/lib/customerRepository.ts` | No direct lifecycle RPC reference was found in the inspected file. This is not a full proof across every mobile screen/component. |
| Partner mobile repository | `mobile/krim-partner/src/lib/partnerRepository.ts` | No direct lifecycle RPC reference was found in the inspected file. This is not a full proof across every mobile screen/component. |

## Important source-level discrepancy

The customer selection page copy says checkout remains locked until the partner accepts. The backend checkout-award RPC currently creates the customer quote with status `accepted` before partner acceptance. The page subsequently polls assignment/capacity and locks the button, but that browser behavior does not undo the premature accepted database quote.

The partner accepted-loads UI first calls the assignment response action, then separately calls capacity reservation. The server-side order-creation function independently requires accepted assignment and confirmed capacity binding. Therefore, payment order creation is currently better guarded than the quote-award state semantics, but the accepted quote/shipment state mismatch remains a critical lifecycle defect.

The checkout page's client-side readiness checks must never be treated as authorization. Keep all acceptance, capacity, payment and ownership validation inside trusted backend functions.

## Secondary acceptance path

The service-role-only `krim_partner_respond_to_invitation` function was not referenced by the inspected current web pages, customer/partner repository files, or the Edge Function source paths reviewed through the current repository inventory. Its live production function is nevertheless present and callable by `service_role`. Treat it as a potential backend/service integration path until deployed function source, external scheduler/orchestration and logs are fully traced. Do not revoke or remove it based solely on no in-repository reference.

## Payment dependencies requiring migration compatibility

The existing Razorpay order function requires:
- shipment status `confirmed`;
- accepted partner assignment for the same shipment/partner;
- a matching confirmed capacity binding;
- accepted quote and exact amount/currency validation;
- payment provider capability and merchant eligibility gates;
- idempotent existing payment-order handling.

The proposed lifecycle correction must preserve these checks and ensure that the only path to `confirmed` is after explicit partner commitment and customer commercial acceptance. Do not loosen the Razorpay order function to make a premature shipment state pass. Do not create payment orders at award time.

The Razorpay webhook should only reconcile a legitimate order that was created through the guarded order function. During migration testing, test duplicate webhook events, stale payment events, conflicting IDs, amount/currency mismatch and state mismatch. Do not issue live payment requests during these tests.

## Caller inventory still required before implementation

1. Search every tracked file, including legacy pages, app workspaces, mobile app components, server scripts and tests, for all seven lifecycle RPC names and the capacity-reservation RPC.
2. Trace all production Edge Function invocations and any scheduled/external callers of the service-role-only invitation response RPC.
3. Trace every route to `create-global-razorpay-order`, `create-razorpay-order`, `verify-razorpay-payment` and webhook reconciliation, including legacy/duplicate payment paths.
4. Verify whether any UI, notification, automation, job or webhook treats `krim_quotes.status='accepted'` or shipment `confirmed` as proof of a confirmed booking.
5. Inspect the mobile app's complete tree, not just its repository modules, and confirm no hidden RPC callers.
6. Build a caller-to-RPC contract table with parameters, auth requirements, expected status transitions and retry behavior before migration.

## Safety status

- No production database or staging database was changed.
- No function, grant, transition, trigger, Edge Function, webhook, secret or payment setting was changed.
- No payment order or shipment was created.
- No migration was written or applied.
- Booking/payment must remain fail-closed pending the coordinated lifecycle correction and regression tests.
