# KRIM Cashfree sandbox integration

## Current scope
- Cashfree is sandbox-only. The Edge Functions deliberately reject non-sandbox configuration.
- Existing Razorpay checkout remains available.
- No credentials belong in this repository.

## Supabase Edge Functions
- Create order (JWT required): `create-global-cashfree-order`
- Verify payment (JWT required): `verify-global-cashfree-payment`
- Webhook (Cashfree signature required): `cashfree-payment-webhook`

Webhook endpoint to register in the Cashfree **Test/Sandbox** dashboard:

`https://ebltviniygljwwseplph.supabase.co/functions/v1/cashfree-payment-webhook`

Subscribe to payment success events. Cashfree dashboard event labels can vary; select the event that reports a successful payment (usually `PAYMENT_SUCCESS` / `PAYMENT_SUCCESS_WEBHOOK`). The handler validates the Cashfree HMAC signature and independently fetches the order and payments from Cashfree before updating the local payment record.

## Sandbox validation checklist
1. Confirm Supabase Function Secrets contain `CASHFREE_CLIENT_ID`, `CASHFREE_CLIENT_SECRET`, and `CASHFREE_ENV=sandbox`.
2. In Cashfree Test/Sandbox dashboard, register the webhook endpoint above and configure the signing secret according to Cashfree's dashboard instructions if a separate webhook secret is provided. Do not put secrets in GitHub.
3. Use a signed-in test customer with a confirmed shipment, accepted KRIM quote, and accepted partner assignment.
4. Open `public/quote-result.html?shipment_id=<shipment-id>`, then select **Test with Cashfree Sandbox**.
5. Complete a Cashfree test payment. The browser return is only a prompt to check status; the server-side verification response is authoritative.
6. Confirm the corresponding `payment_orders` row has `payment_provider='cashfree'`, matching `cashfree_order_id`, `status='paid'`, and a `cashfree_payment_id`.
7. Also test pending/failed/cancelled payments and duplicate webhook delivery. They must never be marked paid.
8. Check Supabase Edge Function logs for errors. Do not paste credentials, access tokens, or payment secrets into chat.

## Important limitations
- The webhook URL is deployed, but it is not registered in the Cashfree dashboard automatically by this repository change.
- A sandbox payment is not a real-money transaction.
- Do not enable production/live mode until Cashfree approves the merchant account and production credentials are separately configured and tested.
