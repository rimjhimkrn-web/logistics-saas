# Step 18 — Customer freight-payment surface and legacy provider reference audit

**Date:** 2026-11-13  
**Repository ref:** `website/global-launch-readiness`  
**Scope:** Recursive repository path inventory plus targeted inspection of customer checkout entry points, booking journey, payment-method page, customer payment history/verification pages, escrow settlement page, and payment Edge Function endpoints. This is a targeted high-risk surface audit, not a certification of every finance module.

## Executive result

The customer-facing checkout UI previously still presented an active Razorpay flow even though the intended commercial model is partner-direct. The backend order-creation source gate alone was not enough: the checkout page could still invite a customer to press “Continue to secure payment” and invoke the gated endpoint. That user-facing mismatch is now corrected on this branch.

The audit also found a public escrow demo page displaying fabricated balances, named bank integrations and a fake “release” success alert. Those unsupported representations have been removed.

## 1. Changes made on this branch

### A. `public/quote-result.html`
- Removed the external Razorpay Checkout.js script.
- Changed the page title and heading to partner confirmation rather than secure freight checkout.
- Replaced the pay button with a disabled “KRIM freight checkout is disabled” state.
- Changed provider/currency labels to partner-direct payment guidance.
- Made `setPayReady` fail closed and inserted an unconditional early return at the start of `startPayment()`, before the old order-creation invocation.
- The old payment implementation remains below the unconditional return as unreachable legacy code. It is not called by the current page path, but should be removed in a later cleanup after historical reconciliation and route-reference checks.

### B. `public/shipper/payment-checkout.html`
- Reworded the page as partner-direct payment guidance.
- The continue control is always disabled even when the quote/assignment read-only checks pass.
- Updated success copy to say customers arrange payment with the contracted logistics partner; KRIM does not collect or settle freight.
- The page still makes a read-only call to `krim-payment-capability-status`; it does not create a payment order.

### C. `public/finance/payment-methods.html`
- Changed India’s KRIM freight checkout status from “Integrated adapter / active” to “Disabled under partner-direct model”.
- Footer now explicitly says KRIM freight checkout is disabled and customers pay contracted logistics partners directly.
- Other payment methods remain pending/future and are not represented as enabled.

### D. `public/shipper/booking-request.html`
- Updated the journey step from “Checkout” to “Partner confirmation / Direct partner arrangement”.
- Existing booking guidance already says customers pay the contracted partner directly and KRIM does not collect or settle freight payments.

### E. `public/billing/escrow-settlement.html`
Removed unsupported demo content:
- Fabricated $84,920 escrow balance.
- Named JPMorgan/Citi escrow “active” claim.
- Sample carrier contracts, shipment references and locked funds.
- Fake button that displayed an alert claiming escrow funds had been released to a carrier bank account.
- Unsupported “KRIM System Technologies Ltd” footer identity.

The page now states escrow and automated payouts are not offered, KRIM does not hold customer freight funds, and customers pay the contracted partner directly. It warns users not to send KRIM funds for freight, escrow or carrier settlement.

## 2. Backend payment endpoint status observed in branch source

- `create-global-razorpay-order`: contains the Step 15 fail-closed gate. It returns HTTP 410 unless `KRIM_COMMERCIAL_LAUNCH_MODE` exactly equals `freight_checkout`. Do not set that value for partner-direct operations.
- `create-razorpay-order`: retired stub returning HTTP 410.
- `verify-global-cashfree-payment`: retired stub returning HTTP 410.
- `cashfree-payment-webhook`: retired stub returning HTTP 410.
- `razorpay-webhook`: retained for signed historical event reconciliation.
- `verify-razorpay-payment`: retained for historical payment verification.
- `execute-razorpay-refund`: retained for eligible historic refund obligations; do not disable until provider reconciliation is complete.
- `krim-payment-capability-status` and `krim-global-payment-options`: capability/read-only status services, not payment collection endpoints.

## 3. Read-only history and finance views

- `public/shipper/invoices.html` reads historical `payments` and newer finance records. Its current wording distinguishes historical records from current partner-direct freight payments and says a displayed status is not independent settlement proof.
- `public/payment-verification.html` invokes the authenticated payment-verification status function; it does not create a new payment.
- Customer settlement routes inspected are informational/workspace routes; no new customer checkout action was found in those inspected files.
- Finance/partner settlement labels and reports may remain for historical records or future workflows. They must not be interpreted as proof that KRIM currently holds or settles partner funds.

## 4. Deployment and safety boundary

All edits above are on the working branch and are not deployed. PR #65 remains draft/open/unmerged. The Step 15 server-side gate also remains branch-only. Existing Razorpay orders and payment/refund reconciliation paths are unchanged.

No provider API/dashboard calls, order cancellations, refunds, webhook replays, payment/ledger writes, database mutations, secret/config changes, production deployment, or PR merge were performed.

## 5. Remaining technical cleanup

1. Remove unreachable Razorpay checkout implementation from `public/quote-result.html` after confirming no historic route depends on it.
2. Search the remaining customer, finance, billing, partner and enterprise modules for links or handlers that imply active KRIM freight collection or escrow/payout.
3. Keep historical verification, signed webhook and controlled refund functions until all provider-side obligations are reconciled.
4. Run CI and a browser-level negative test proving both checkout pages remain disabled and no order-creation request is emitted.
5. Only after legal/tax review and provider reconciliation should the PR be considered for production release.

## Launch status

**Customer-facing freight checkout is fail-closed in the audited primary pages on this branch.** This is not yet a complete payment-system retirement: old code remains unreachable in one page, historic payment functions remain intentionally available, and the branch has not been deployed. The partner-direct operating model is still subject to CA/legal review.
