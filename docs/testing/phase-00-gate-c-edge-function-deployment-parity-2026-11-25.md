# Phase 00 — Gate C: Edge Function Deployment Parity
Date: 2026-11-25
Scope: Read-only live Supabase project metadata and deployed Edge Function inventory.
Projects:
- Production: `ebltviniygljwwseplph` (`logistics-saas`)
- Staging: `qrpcivhdxobiaofppbkl` (`KRIM Logistics Staging`)

## Method
Queried the Supabase project metadata and deployed Edge Function inventories for both projects. No function source was invoked, no secrets were read, and no database, function, authentication, provider, or deployment setting was changed.

## Project health
- Production: `ACTIVE_HEALTHY`, PostgreSQL 17.6.1.165, region `ap-northeast-1`.
- Staging: `ACTIVE_HEALTHY`, PostgreSQL 17.11.0.018, region `ap-south-1`.

Both control-plane project status records report healthy. This does not prove website-to-project binding, endpoint reachability, runtime correctness, or deployed frontend environment selection.

## Deployed function inventory
- Production: 22 ACTIVE Edge Functions.
- Staging: 3 ACTIVE Edge Functions.
- Common function slug: `global-admin-control` only.
- Production-only inventory (21): `razorpay-webhook`, `krim-payment-capability-status`, `krim-public-contact-inquiry`, `krim-global-growth-operations`, `verify-razorpay-payment`, `krim-driver-tracking-session`, `create-global-razorpay-order`, `krim-auth-workspace-route`, `krim-notification-provider-adapter`, `krim-global-payment-options`, `public-shipment-tracking`, `create-global-cashfree-order`, `krim-payment-verification-status`, `krim-ai`, `verify-global-cashfree-payment`, `krim-driver-gps-update`, `execute-razorpay-refund`, `krim-notification-retry-worker`, `cashfree-payment-webhook`, `create-razorpay-order`, `process-payment--`, 
- Staging-only inventory (2): `krim-resend-email-worker`, `owner-testing-authorize`.

The live API response contained 22 Production function records and 3 Staging function records. One slug is common, so the observed set difference is 21 Production-only and 2 Staging-only. The full Production-only slug list is the 21 names enumerated above; the inventory should still be re-exported as a canonical machine-readable manifest in a later gate.

## Security-relevant configuration observations
- Several Production public/webhook-style functions have `verify_jwt=false`, including payment webhooks, public contact inquiry, public tracking, and notification retry worker. This is not automatically a vulnerability: each endpoint requires its own cryptographic signature, rate limiting, or application-level authentication review.
- Staging has only three deployed functions, so it cannot currently serve as an equivalent runtime environment for the Production frontend's broad function dependencies.
- Production still has Cashfree order creation, verification, and webhook functions despite the platform's intended Razorpay-only payment direction. Their presence does not prove that the frontend calls them, but they remain deployed attack surface and require explicit retirement/retention decisions.
- Function version numbers and hashes are environment-specific metadata; no source-to-deployed hash comparison was performed in this gate.

## Gate result
**BLOCKED — deployed function parity is not established.** Both projects are healthy at the control-plane level, but the deployed function inventories are materially different. Staging cannot be considered a representative integration-test environment until an approved function manifest, source provenance, deployment record, JWT policy, and endpoint dependency matrix are reconciled.

## Required follow-up
1. Build a canonical function manifest from the current repository and identify intended Production vs Staging deployment sets.
2. For each function, compare deployed source/version against the reviewed repository source and verify JWT policy.
3. Decide whether legacy Cashfree functions should be retired; do not delete or redeploy them as part of this audit.
4. Establish Staging deployment provenance and approved parity policy.
5. Only after environment identity and migration provenance gates pass, proceed to synthetic authenticated E2E tests.

## Safety boundary
No function invocation, secret access, SQL, DDL/DML, auth mutation, provider request, workflow dispatch, deployment, or Production/Staging write occurred.
