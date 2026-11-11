# KRIM Live Edge Payment Writer and Caller Audit — 2026-11-11

## Scope
Read-only inspection of the live Supabase Edge Function inventory and live function source, plus production EXECUTE/table grants. This audit distinguishes the deployed runtime inventory from the GitHub default branch. No function was invoked, deployed, disabled or modified; no payment, refund or database data was changed.

## Live payment-related Edge Functions
The production project currently lists these active functions:
- `create-global-razorpay-order` — version 24, JWT verification enabled.
- `verify-razorpay-payment` — version 24, JWT verification enabled.
- `razorpay-webhook` — version 28, JWT verification disabled as expected for a provider webhook; handler performs its own signature verification.
- Legacy `create-razorpay-order` — version 15.
- Legacy `process-payment--` — version 15.
- Legacy `create-global-cashfree-order` — version 13.
- Legacy `verify-global-cashfree-payment` — version 15.
- Legacy `cashfree-payment-webhook` — version 14.
- `execute-razorpay-refund` — version 6.
- `krim-payment-verification-status` and `krim-payment-capability-status` — read/status functions.

The current live source for the three global Razorpay functions was available and inspected. The four legacy Razorpay/Cashfree function source payloads were not returned as readable implementation source by the live retrieval endpoint in this pass; their presence must not be treated as proof that they are harmless or unused.

## Confirmed live status writers

### A. `razorpay-webhook`
The captured-event handler validates the signed event and checks the Razorpay payment ID, captured status, amount and currency against the stored order. It conditionally updates `payment_orders.status='paid'`, then calls the service-role-only database reconciler in a separate request. This remains a non-atomic two-step paid/ledger flow. Its refund handler separately updates `payment_orders.status='refunded'` after the provider refund event is verified and the approved refund request is matched.

### B. `verify-razorpay-payment` — second independent paid writer
This authenticated customer endpoint independently verifies the Razorpay payment/order/signature, retrieves the provider payment, and checks captured status, amount and currency. It then independently updates `payment_orders.status='paid'` before calling the same database financial reconciler. This is a second privileged status-writer path, separate from the webhook. It has conditional prior-status update and conflicting-payment-ID checks, but the paid update and financial insert remain separate requests. Therefore both paths need to be redirected to one canonical atomic transition/reconciliation routine.

### C. `create-global-razorpay-order`
Creates the local payment order after customer authentication, organization access, confirmed shipment, accepted quote, accepted partner assignment, and confirmed capacity binding/reservation checks. It is a creator, not a paid-state writer.

### D. `execute-razorpay-refund`
An active privileged refund execution function exists. The live source should be included in the final refund dependency review with the webhook and refund-request database functions. No refund was executed.

## Database privileges
- `anon` and `authenticated` cannot EXECUTE the three inspected `krim_internal_*` payment functions.
- `service_role` can execute them.
- `authenticated` has SELECT only on `payment_orders` and `payments` in the inspected table-grant listing.
- `service_role` has broad table privileges, including INSERT/UPDATE/DELETE.
This supports the conclusion that Edge Functions using the service-role key are the privileged REST status writers; the exact deployed function list must be inventoried, not inferred only from SQL function definitions.

## Important legacy exposure
The production inventory still exposes old Razorpay and Cashfree order/verification/webhook functions. Cashfree was previously identified as a discontinued provider preference, but these deployed functions have not been removed. They must be checked for external webhook registrations, historic order references, UI callers and scheduled integrations before retirement. Do not delete or disable them blindly.

The legacy `public.payments` table and its two SECURITY DEFINER functions are separate from the modern `payment_orders` path. Their EXECUTE privileges are restricted to service_role in the inspected roles. The old payment functions therefore are not directly callable by anon/authenticated, but any service-role Edge Function caller still needs tracing.

## Corrective architecture
1. One server-only database routine should accept validated Razorpay evidence and lock the canonical order.
2. In one transaction, validate the exact order/payment binding and current shipment/quote/partner/capacity state, transition to paid, bind immutable provider IDs, and insert or verify the unique financial ledger row.
3. Both `razorpay-webhook` and `verify-razorpay-payment` should call that same routine; neither should directly write `status='paid'`.
4. Refund state and refund ledger must also be atomic or use a durable idempotent reconciliation state machine.
5. Add tests for webhook-vs-client verification races, duplicate delivery, different payment IDs, provider amount/currency mismatch, ledger failure, refund failure and retry.
6. Retrieve/inspect all legacy live function source and trace callers before any retirement.

## Conclusion
The key newly confirmed finding is that **two independent live Razorpay paths can mark the same payment order paid**: the provider webhook and the authenticated verification endpoint. Both call the same financial reconciler only after the status update, so the non-atomic ordering risk exists in both. The next implementation should centralize both through a single atomic server-side transition, after legacy caller inventory is complete.
