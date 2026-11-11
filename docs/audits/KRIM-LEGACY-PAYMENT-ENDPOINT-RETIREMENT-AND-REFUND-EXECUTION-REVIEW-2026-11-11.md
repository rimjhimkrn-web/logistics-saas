# KRIM Legacy Payment Endpoint Retirement and Refund Execution Review — 2026-11-11

## Scope
Read-only review of live Supabase Edge Function source for legacy payment endpoints and refund execution, plus production function-source references to legacy payment RPCs and EXECUTE grants. GitHub code search returned no indexed matches for the legacy endpoint names in the default branch; this is not proof that no caller exists. No production changes, endpoint invocations, refunds or database writes were performed.

## 1. Legacy provider endpoints are already retired at runtime
The following functions remain listed as ACTIVE in Supabase, but their retrieved live source is a deliberate HTTP 410 tombstone:
- `create-razorpay-order` — returns `PAYMENT_ENDPOINT_RETIRED`.
- `process-payment--` — returns `LEGACY_PAYMENT_ENDPOINT_RETIRED`.
- `create-global-cashfree-order` — returns `PAYMENT_PROVIDER_RETIRED`.
- `verify-global-cashfree-payment` — returns `PAYMENT_PROVIDER_RETIRED`.
- `cashfree-payment-webhook` — returns `PAYMENT_PROVIDER_RETIRED`.

These functions are technically deployed/ACTIVE but do not perform payment writes in their current live source. Keep them as explicit tombstones until all external webhook registrations, old client versions, deep links and historical payment references are checked. Do not describe them as deleted or disabled in Supabase.

## 2. Legacy database payment RPCs
Production functions:
- `krim_internal_prepare_payment_for_accepted_quote(bigint)`
- `krim_internal_authorize_shipment_after_payment(bigint,text)`

Both are executable only by `service_role` among the inspected roles; anon and authenticated cannot execute them. A catalog scan for other database function bodies calling these RPCs returned only the two functions themselves, so no other SQL-function caller was identified. This does not discover Edge Function, application, scheduled or external callers.

## 3. Refund execution review
The live `execute-razorpay-refund` function:
- requires an authenticated Supabase user;
- delegates AAL2, finance permission, reviewer identity, requester/reviewer separation, full-amount and payment-state checks to `krim_claim_razorpay_refund_execution`;
- requires a claimed `execution_pending` request, INR, positive integer amount, payment ID and stable idempotency key;
- sends the refund to Razorpay with the same idempotency key and exact request body on retry;
- deliberately leaves uncertain/non-success provider responses pending for reconciliation;
- does not itself mark the payment order refunded; it expects the signed provider webhook to record final state.

This is a sound fail-closed pattern at the API boundary. Remaining tests: duplicate/concurrent claim attempts; webhook arriving before the HTTP response; webhook retry after refund ledger failure; provider success with missing/invalid refund ID; idempotent retry after timeout; and refund event replay.

## 4. Remaining unresolved caller inventory
The current GitHub code-search index returned no results for the five legacy function names. Because the search index may be incomplete and only covers the default branch, this cannot certify the absence of callers. Before tombstones are removed, inspect all repository branches, app bundles/releases, historical versions, provider dashboard webhook destinations, scheduled jobs and any external clients.

The legacy database `payments` table and service-role-only RPCs remain in production. No evidence in this pass establishes that historical records can be deleted or that the legacy domain is safe to drop. Preserve historical rows until a retention and reconciliation review is complete.

## 5. Current architecture decision
- Keep legacy endpoint tombstones in place; do not remove yet.
- Keep the legacy payment table and service-role-only RPCs until all callers and historical data are mapped.
- The active modern paid writers remain `razorpay-webhook` and `verify-razorpay-payment`; both still write `payment_orders.status='paid'` before calling the shared financial reconciler in a separate request.
- The next correction remains a single atomic, server-only paid transition + financial ledger reconciliation routine used by both modern writers. Refund finalisation should similarly use a durable idempotent transaction.

## Conclusion
The Cashfree and older Razorpay Edge endpoints are not live payment processors anymore: their deployed code returns HTTP 410. They remain deployed as tombstones. The refund execution function is designed to preserve pending state under uncertain provider outcomes and use a stable idempotency key. The main P0 remains unchanged: the two modern Razorpay paid writers need one atomic database transition. No production state was changed.
