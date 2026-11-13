# Step 53 — Deployed Razorpay order function authorization and partner-direct block assessment

Date: 2026-11-13
Production project: `ebltviniygljwwseplph`
Function: `create-global-razorpay-order`
Scope: read-only deployed-source, database metadata, registry and repository-branch comparison. No production or repository source change in this step.

## Live deployment facts

- Deployed Edge Function is ACTIVE, version 24.
- Supabase function metadata reports `verify_jwt=true`.
- The handler also extracts the Bearer token and independently calls `supabase.auth.getUser(token)`; invalid/expired sessions are rejected.
- The deployed source uses a service-role client after user authentication. It checks that the caller has active membership in the shipment's active customer organization, using `krim_has_organization_access`.
- That helper checks active organization membership and active organization status. The Edge Function does not separately require a named customer payment permission.
- The deployed source has no `KRIM_COMMERCIAL_LAUNCH_MODE` / `freight_checkout` gate. It proceeds to shipment, accepted quote, accepted partner assignment, confirmed capacity binding/reservation, payment capability, existing order and provider-order logic.
- The deployed source therefore does not independently enforce the selected partner-direct commercial model. The UI's disabled checkout is not a security boundary.

## Important repository/deployment mismatch

The PR branch source file `supabase/functions/create-global-razorpay-order/index.ts` already contains an early server-side `KRIM_COMMERCIAL_LAUNCH_MODE` check returning HTTP 410 unless the value equals `freight_checkout`.

However:
- The deployed v24 source does not contain that guard.
- The PR branch source and deployed source are not byte-for-byte identical.
- The PR branch guard is conditional. A production secret/configuration value of `freight_checkout` would allow the function to continue. Secret values are not visible through the connected audit tools, so that condition cannot be ruled out.

**Conclusion:** The guard present in the PR branch is not deployed and cannot be treated as production protection. Even if deploying it, the safe partner-direct posture requires confirming the variable is absent/disabled or replacing the conditional opt-in with an unconditional fail-closed block until a formally approved operating-model change.

## Payment capability registry

The live INR/Razorpay row is:
- `integration_status=implemented`
- `checkout_enabled=true`
- `merchant_eligibility_verified=false`
- `presentment_supported=true`
- `settlement_supported=false`
- `refunds_supported=false`
- `fx_supported=false`
- `evidence_reference=NULL`, `reviewed_at=NULL`

This row is internally inconsistent with the selected partner-direct operating model. It should be disabled as a second, database-backed defense, but no update was made.

## Historical payment records

Read-only aggregate of `payment_orders` for Razorpay:
- 5 orders in `created` status, all with provider order IDs; oldest created 2026-09-25 and newest 2026-09-26.
- 1 order in `paid` status, with provider order ID, created 2026-09-26.

These records must be preserved and reconciled. Do not delete them, mark them failed, refund, or alter them as part of the checkout block. Existing payment verification, webhook reconciliation and authorized refund paths require separate review and must remain available for legitimate historical transactions.

## Safe production enforcement plan — approval required

1. Review and approve a production change window and rollback plan.
2. Preserve the historical payment ledger and verify the existing order/payment/refund paths remain available.
3. Deploy an early unconditional HTTP 410 partner-direct block in `create-global-razorpay-order` (or deploy a conditional gate only after the production value is independently verified absent/disabled). It must execute before any service-role DB operation or Razorpay network call.
4. Set the INR/Razorpay registry row `checkout_enabled=false` as defense in depth, using a reviewed migration/controlled SQL operation and recording the before/after values.
5. Verify by invoking the function with an authenticated test user in an approved non-production environment: expect 410, no provider request, no `payment_orders` insert, and no change to historical records.
6. Separately confirm the legitimate payment-verification/webhook/refund flows continue to reconcile historical orders; do not use live provider calls without explicit test authorization.
7. Re-read deployed function version/source and registry row after deployment; record evidence.

## Step 53 verdict

**PRODUCTION DIRECT-CALL CHECKOUT RISK CONFIRMED. PR BRANCH HAS A CONDITIONAL GUARD, BUT PRODUCTION V24 DOES NOT.** No function was deployed, no secret inspected or changed, no database row updated, no payment/provider call made, and no historical record changed. PR #65 remains unmerged and undeployed.
