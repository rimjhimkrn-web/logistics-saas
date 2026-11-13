# Step 21 — Separate historical payment reconciliation from new partner-direct bookings

**Date:** 2026-11-13  
**Branch:** `website/global-launch-readiness`  
**Scope:** Public customer payment-verification and shipment-confirmation pages, quote-comparison fail-closed behavior, and CI regression assertions. No production database or provider actions.

## 1. Changes completed

### Historical payment verification
Updated `public/payment-verification.html` to make its scope explicit:
- It is for historical Razorpay payment reconciliation only.
- It does not offer new KRIM freight checkout.
- New shipments follow the partner-direct model; customers arrange and pay freight directly with their contracted logistics partner.
- Removed the “current active checkout: Razorpay · INR” claim and replaced it with a clear statement that new KRIM freight checkout is disabled.
- Replaced the checkout return action with a new partner-direct enquiry route.
- Removed a dynamic return path that could send users from historical payment review back into the legacy `quote-result.html` checkout surface.
- Kept authenticated server-side payment verification intact for historic records; it remains read-only and does not create charges or mark orders paid.

### Historical shipment confirmation
Updated `public/shipment-confirmation.html` to identify it as a historical payment-linked booking-record review only:
- It is explicitly not the confirmation flow for new partner-direct shipments.
- It does not create or change shipment status.
- It retains the strict historical payment, quote, assignment and operational-readiness checks.
- It warns that a new partner-direct shipment must not be treated as operationally confirmed until the partner-direct quote, assignment acceptance, capacity and readiness lifecycle has been implemented and validated.

### Quote-comparison regression test
The quote-comparison page intentionally blocks acceptance while partner, assignment and booking-integrity hardening is incomplete. The smoke test incorrectly required that page itself to call the acceptance RPC. Updated the test to assert the correct fail-closed behavior instead. The canonical quote-review page continues to own the server-side `krim_accept_global_quote` action.

## 2. Validation

For commit `e2f8df995625142091e64e6cc13e31e40db29556`:
- KRIM production smoke checks: **PASS** (run 43362637720).
- KRIM static link audit: **PASS** (run 43362637977).

These are repository/source-level checks. They do not represent browser E2E, live partner booking, payment, dispatch or production deployment testing.

## 3. Critical lifecycle blocker remains

The real new partner-direct confirmation workflow is **not implemented or proven yet**. Prior audits found:
- Quote acceptance, partner award/assignment acceptance and shipment confirmation are not yet a single proven atomic partner-direct lifecycle.
- The existing shipment `quoted → confirmed` transition still has a historical KRIM-payment dependency.
- The partner quote-comparison page deliberately pauses customer acceptance pending integrity hardening.
- The production migration proposal for partner-review lifecycle/MFA is not applied and has not been proven in a populated staging environment.

The safe next engineering task is to design and validate a single transactional partner-direct acceptance RPC and its transition/readiness rules, including rollback/rejection/expiry and idempotency. This requires a populated staging environment and careful migration review. Do not remove the historical payment dependency or apply the proposed production migration blindly.

## 4. Explicitly not done

- No database migration applied; no production or staging data changed.
- No payment provider API calls, new charges, refunds, cancellations, payouts or webhook replays.
- No payment secrets or commercial launch flags changed.
- No merge or deployment.
- No real customer/partner records created and no live shipment test performed.

## Status

**Historical payment and confirmation pages are now clearly separated from the new partner-direct commercial model. Both source-level CI checks pass.** New partner-direct booking confirmation remains blocked pending the validated atomic lifecycle and staging verification. KRIM is not yet cleared for live commercial operation.
