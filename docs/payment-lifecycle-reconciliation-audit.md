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
## Test-key handling and further linkage checks

The founder confirmed that all payment-related Supabase secrets are currently test credentials. Keep the system in test mode through the manual verification phase; do not switch any payment provider to live credentials until the test matrix and reconciliation gates pass. At the planned live cutover, update each provider's API key/secret and webhook secret as a coordinated provider-specific change. Never paste secrets into chat, source files, GitHub commits, or screenshots. Keep test and live credentials separate, and confirm webhook endpoints are configured for the matching environment.

Further read-only inspection found that the newer private canonical payment transaction table contains 6 records, all linked to a payment_orders row, with 1 paid record. Its provider references and shipment/quote/partner-quote references matched their associated payment_orders rows for all 6 records. The paid order also has a canonical paid transaction with a provider payment reference and verification timestamp.

However, the public payment_orders snapshot has 6 rows with a global shipment ID but 0 rows with krim_quote_id, partner_quote_id, or customer_organization_id populated. These appear to be legacy/test rows from before quote binding became mandatory; this is a hypothesis, not a verified historical explanation. The current order-creation source requires an accepted quote and accepted partner assignment, while the verifier permits a narrow idempotent recovery path for already-paid legacy orders. Do not reuse these old rows as proof of a new checkout path. Investigate whether the test data should be archived or left intact only after a trace by record ID and audit history.

A second join against the newer business tables returned no shipment/quote matches between payment_orders and payments, and no paid-order matches to revenue_ledger or partner_payouts using shipment IDs. This is consistent with the current canonical payment path not yet being proven end-to-end through the legacy finance tables; it is not evidence that money has moved incorrectly. The legacy shipment_financials table contains one row marked customer-paid and partner-paid, but it has not been proven to correspond to the canonical paid order. No production financial rows were changed.

## Additional source regression guards

The repository smoke script now checks that canonical Razorpay creation uses the capability registry, that verification binds the payment to the exact provider order/amount/currency/captured status and accepted partner assignment, and that the webhook validates signature/event headers and matches amount/currency to the canonical order. These are static source checks only; passing them does not prove live provider behavior.
## Live-key activation guard deployed

The canonical order-creation Edge Function was updated and deployed as version 12. It now identifies Razorpay test versus live key prefixes and fails closed for an unknown key format. Test credentials may use the India/INR sandbox route. Live credentials are blocked unless the selected provider/currency registry row explicitly confirms merchant eligibility, presentment, settlement, refunds, and FX. The production smoke script now checks for these safeguards.

**Manual-test safety rule:** keep test keys during guided manual testing. Do not replace them with live keys at the start of manual testing, because a manual test could charge real money. Switch to live keys only after sandbox manual testing, automated negative tests, reconciliation, refund/settlement verification, and merchant eligibility approval are complete. At cutover, configure live API keys and live webhook secrets together and perform only an explicitly approved low-value production verification.