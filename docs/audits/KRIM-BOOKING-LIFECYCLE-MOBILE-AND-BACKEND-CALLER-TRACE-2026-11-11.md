# KRIM Booking Lifecycle — Mobile and Backend Caller Trace
Date: 2026-11-11
Status: STATIC SOURCE TRACE — NO DEPLOYMENT OR DATA CHANGES

## Additional callers identified

### Customer mobile app
`mobile/krim-customer/src/CustomerWorkspace.tsx` contains direct lifecycle and payment calls:
- `krim_accept_global_quote(p_quote_id)` — customer quote acceptance.
- `create-global-razorpay-order` — creates a payment order through the canonical server-side function.
- `verify-razorpay-payment` — verifies the returned Razorpay payment ID/order ID/signature.
- The app displays payment actions only when local shipment/quote state appears eligible; server-side order and verification functions remain authoritative.
- `krim_create_global_shipment_idempotent` — customer shipment creation.
This means the mobile app is a direct consumer of the same quote-acceptance RPC identified in the web audit. Any lifecycle contract change must update and regression-test mobile acceptance and payment UI together with the web pages.

### Partner mobile app
`mobile/krim-partner/src/PartnerWorkspace.tsx` contains:
- `krim_submit_partner_quote` — partner quote submission.
- `krim_respond_to_partner_assignment` — partner assignment acceptance/rejection.
No direct mobile reference to the award or customer quote acceptance RPCs was found in the inspected workspace source.

### Driver mobile app
`mobile/krim-driver/src/DriverWorkspace.tsx` uses a generic `runDriverAction(rpcName, args, ...)` wrapper, so simple literal-name search can miss its RPC calls. The inspected actions include:
- `krim_driver_record_trip_event` for pickup and in-transit milestones.
- `krim_driver_submit_delivery_pod` for delivery evidence submission.
The driver app does not directly call the partner quote award or customer quote acceptance RPCs in the inspected workspace. Driver actions are downstream of accepted dispatch and must remain blocked until the assignment lifecycle permits them.

## Payment endpoint inventory

- `create-global-razorpay-order` is the canonical global order-creation path.
- `verify-razorpay-payment` is the canonical payment verification path used by the customer mobile app and must be traced against all web invocations.
- `create-razorpay-order` is explicitly retired and returns a retirement error.
- `process-payment--` is explicitly retired and directs callers to canonical Razorpay checkout/verification.
- `razorpay-webhook` handles provider event reconciliation.
- Cashfree order creation, verification and webhook Edge Functions remain in the repository; they are legacy dependencies to map before retirement, not proof that Cashfree is active or safe to remove.
- Web checkout readiness and mobile UI are not authorization boundaries. The canonical order and verification functions enforce server-side checks for accepted partner assignment, capacity binding, quote/order binding and payment capability.

## Lifecycle and migration implications

1. The customer mobile app directly accepts quotes through `krim_accept_global_quote`; this is a confirmed caller and a release-blocking dependency for any RPC contract change.
2. The partner mobile app directly responds to assignments and submits partner quotes. It must be tested for accept/reject, retry and capacity reservation behavior.
3. The driver mobile app's dynamic RPC wrapper means inventory must include indirect/dynamic call names, not just literal `.rpc("...")` patterns.
4. Payment verification rechecks shipment state, quote binding, accepted partner assignment and confirmed capacity. Preserve these checks; do not loosen them to accommodate an earlier shipment transition.
5. Retired legacy payment endpoints should remain retired. Do not re-enable them or retry through them when a canonical payment status is uncertain.
6. Cashfree functions should not be deleted until deployed invocation history, configured provider webhooks, historic payment records and all references are reconciled.
7. No in-repository direct call to the service-role-only `krim_partner_respond_to_invitation` was identified in the inspected app/workspace sources. External service-role callers, deployed Edge Function code and external schedulers remain unverified.

## Still required before implementation

- Complete repository-wide search for every literal and dynamically constructed call to the seven lifecycle RPCs, capacity reservation RPC, payment order/verification functions and status transition functions.
- Inspect all current production Edge Function source/version and logs, plus external schedulers or integrations, for service-role callers.
- Trace web invocations of `verify-razorpay-payment`, webhook delivery configuration and all legacy Cashfree references.
- Verify the new quote-acceptance hardening migration in the actual production catalog and deployment history before assuming it is deployed. Repository presence alone does not prove deployment.
- Run staging integration tests across customer web + customer mobile + partner web + partner mobile + driver app + Razorpay test mode, with provider calls disabled or test-only.
- Keep production booking/payment fail-closed until those tests pass.

## Safety status

No production or staging schema, function, grant, secret, Edge Function, webhook, payment configuration, shipment, quote, assignment, capacity, or financial record was changed.
