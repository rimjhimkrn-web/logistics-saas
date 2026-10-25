# KRIM Payment Lifecycle Reconciliation Audit

**Audit date:** 2026-10-25  
**Scope:** Read-only production database checks and source review. No customer records, payment records, or money movement were changed.

## Current automated repository checks

- Production smoke check: passed after adding source-controlled copies of the three retired Cashfree fail-closed endpoints.
- Static link audit: passed.
- GitHub Pages deployment: was still running at the time this audit note was prepared; verify the run status before describing deployment as complete.

## Payment capability posture

The capability registry must remain the authority for activation. A provider/country/currency combination must not be enabled merely because an adapter exists. Merchant eligibility, settlement support, refund support, currency/FX support, webhook verification, and reconciliation must be confirmed before enabling live checkout.

The current registry snapshot previously inspected has only India/INR marked implemented and checkout-enabled; merchant eligibility, settlement, refunds, and FX were not verified in the registry. Other combinations remain planned and disabled. Do not advertise those combinations as available.

## Read-only reconciliation snapshot

A production aggregate query returned:

- `payment_orders`: 6 total; 1 marked paid and 5 marked created.
- `payments`: 4 total; 2 marked paid and 2 pending.
- `revenue_ledger`: 1 row marked reconciled.
- `partner_payouts`: 1 row marked paid.
- The join by Razorpay order ID produced no matched order/payment rows to compare, so the amount/currency mismatch count is not meaningful yet; **complete lifecycle linkage is unproven**.
- The initial linkage query reported 6 payment orders without a matching `payments` row, 3 payment rows without a matching `payment_orders` row, and 4 unprocessed webhook-event rows.
- No paid `payment_orders` row was missing its provider payment ID or `paid_at` timestamp in this snapshot.

These counts are not proof that the paid payment, revenue ledger, shipment, and partner payout refer to the same commercial transaction. The existing data model includes legacy and newer records; matching must be established by canonical order/payment references and idempotency keys before claiming reconciliation is complete. Do not manually mark unmatched rows as paid, reconciled, or settled.

## Security improvements already present in source

- The retired `process-payment--` endpoint fails closed with HTTP 410 and must not mutate financial or shipment state.
- The Razorpay webhook checks the provider payment ID, captured status, positive integer amount, amount equality to the canonical order, and currency equality before marking a payment order paid.
- The three Cashfree endpoints return HTTP 410 with `PAYMENT_PROVIDER_RETIRED`; they are not functional Cashfree integrations.

## Remaining blockers before real-world payment launch

1. Trace every existing payment row to a canonical payment order using provider order ID, provider payment ID, and idempotency key; explain legacy/orphan rows without destructive cleanup.
2. Trace the paid order through shipment, revenue ledger, commission calculation, partner payout, refund/chargeback handling, and webhook event processing.
3. Add automated negative tests for wrong amount, wrong currency, unknown order, duplicate event, replayed payment, invalid signature, and concurrent webhook delivery.
4. Confirm the active Razorpay merchant account's eligibility and live/test configuration separately from the code registry.
5. Implement and test one additional provider's real sandbox adapter only after merchant eligibility is confirmed. Keep all unverified market/currency routes disabled.
6. Verify refund and settlement reconciliation before any production payment expansion.

## Operating rule

Do not run live-money tests or tell the founder to begin end-to-end manual testing until the lifecycle trace and automated negative tests are complete. Passing repository smoke/link checks is necessary but not sufficient for global launch readiness.