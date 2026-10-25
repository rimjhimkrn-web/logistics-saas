# KRIM Global Payment Options API

**Status:** deployed as Supabase Edge Function `krim-global-payment-options`, version 1. This is a read-only, authenticated capability-discovery endpoint; it does not create orders, collect payment details, or charge a customer.

## Request

- Method: `POST`
- Authentication: valid Supabase user JWT required.
- JSON body:
  ```json
  { "country_code": "IN", "currency_code": "INR" }
  ```
- Country and currency codes are normalized to uppercase and validated.

## Response contract

The response lists capability registry records for the requested country/currency pair. Each provider has:
- `checkout_configured`: registry says integration is implemented and checkout flag is enabled.
- `operationally_verified`: all required eligibility, presentment, settlement, refund, FX, evidence-reference and review-timestamp checks are present.
- `selectable`: true only when checkout is configured and operationally verified.
- `blockers`: explicit reasons the provider cannot be selected.

The API returns `Cache-Control: no-store`. It requires a valid JWT, uses a service-role client only on the server, and never returns provider secrets.

## Safety and current limitations

- Planned provider rows remain unavailable; this endpoint does not activate them.
- A provider/currency row is not proof of a provider contract, merchant onboarding, or successful settlement.
- Checkout order creation remains a separate server-side operation and must independently enforce the capability registry.
- Razorpay remains the only implemented checkout adapter currently identified by the expansion plan; its live readiness is not certified.
- Stripe, PayPal, Adyen, Checkout.com, bank transfers and regional wallets remain planned until each is separately integrated and tested.
- Do not use this endpoint as a payment-success signal or as accounting evidence.

## Verification still required

Run authenticated integration tests for: valid market/currency, absent registry record, invalid country/currency, expired JWT, provider disabled, missing evidence, and a verified enabled capability. Confirm the checkout order-creation endpoint independently rejects every disabled provider/currency combination. No production payment or payout is created by this API.
