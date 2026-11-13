# Step 16 — Historic Razorpay order and payment reconciliation register

**Date:** 2026-11-13  
**Environment:** Production Supabase `ebltviniygljwwseplph`, read-only catalog/data inspection  
**Scope:** Existing `payment_orders`, legacy `payments`, `payment_webhook_events`, `krim_financial_transactions`, and refund requests.

## Executive summary

The production database contains **six newer Razorpay payment-order records** and **four legacy payment records**. There are also **four old unprocessed webhook events** (two `payment.captured`, two `order.paid`) that map to the two legacy paid payments. Only one row exists in the newer company financial transaction ledger: ₹35,000 INR credit for shipment 15. No refund requests are recorded.

This is a reconciliation inventory, not proof of current provider-side order/payment status. Razorpay API status, settlement/transfer evidence, and provider dashboard records have not been checked. No provider calls or database changes were made.

## A. Newer `payment_orders` — six records

| Shipment | KRIM order status | Amount | Provider order ID | Provider payment ID | Created |
|---|---|---:|---|---|---|
| KRIM-2026-00000010 | created | ₹25,000 | `order_TgJi7OIBeaR7fX` | — | 25 Sep 2026 |
| KRIM-2026-00000011 | created | ₹25,000 | `order_TgK2WV4vi4WeqB` | — | 25 Sep 2026 |
| KRIM-2026-00000012 | created | ₹25,000 | `order_TgYKpVz7LAAO2j` | — | 26 Sep 2026 |
| KRIM-2026-00000013 | created | ₹30,000 | `order_TgYpoSVJ6lWmV1` | — | 26 Sep 2026 |
| KRIM-2026-00000014 | created | ₹35,000 | `order_TgZAyEoW5IWN0g` | — | 26 Sep 2026 |
| KRIM-2026-00000015 | paid | ₹35,000 | `order_TgZLTuj9njbfJX` | `pay_TgZLYhQF6oenEG` | 26 Sep 2026 |

**Five `created` records total ₹1,40,000.** All six rows have `customer_organization_id = NULL`, `krim_quote_id = NULL`, and `partner_quote_id = NULL`. Their shipment rows are marked `confirmed`. This means these old orders do not have the quote/partner binding fields expected by the current stricter checkout verification path. Do not assume they can be safely paid or verified under current rules.

The single paid order's local record has `paid_at` 26 Sep 2026 06:38:17 UTC. The corresponding company-owned financial transaction is listed below.

## B. Legacy `payments` — four records

| Shipment | Local status | Amount | Provider payment ID | Provider order ID | Created |
|---|---|---:|---|---|---|
| 11 | pending | ₹25,000 | `pay_TZ5JS8uCCKrlIE` | — | 7 Sep 2026 |
| 11 | paid | ₹25,000 | `pay_TZ5esccrXNHf0E` | `order_TZ5eipjzVtiJ09` | 7 Sep 2026 |
| 14 | pending | ₹5,000 | `pay_TcEpQ7MxNc6CE2` | `order_TcEpB7Uc1oPUkc` | 15 Sep 2026 |
| 14 | paid | ₹5,000 | `pay_TcHDpni9KUIexp` | `order_TcHDidOsXqFxwn` | 15 Sep 2026 |

There are two separate payment attempts for each of shipments 11 and 14. The paid and pending records are distinct payment IDs. The pending rows must not be labelled duplicates, failed, or refundable until Razorpay confirms their final status. The two paid rows have local `paid_at` timestamps.

## C. Webhook backlog

Four webhook rows remain `processed = false`:

- `payment.captured` event `TcEpXov9phY1ZH` for payment `pay_TcEpQ7MxNc6CE2`, order `order_TcEpB7Uc1oPUkc`, ₹5,000.
- `order.paid` event `TcEpYBhACFa8hz` for the same payment/order, ₹5,000.
- `payment.captured` event `TcHDuryyICLOdc` for payment `pay_TcHDpni9KUIexp`, order `order_TcHDidOsXqFxwn`, ₹5,000.
- `order.paid` event `TcHDvIRaDrXO4b` for the same payment/order, ₹5,000.

The corresponding `payment.authorized` events are marked processed. The two captured payments are already represented as paid rows in the legacy `payments` table. Do not blindly replay or mark these webhook events processed: current webhook reconciliation may use a different canonical order table and could fail or create inconsistent accounting unless legacy mapping is explicitly established.

## D. Financial ledger and refunds

- `krim_financial_transactions` contains one Razorpay transaction: ₹35,000 INR, `payment`, `completed`, direction `credit`, ownership scope `company`, shipment 15, provider reference `pay_TgZLYhQF6oenEG`.
- No Razorpay refund request rows exist in `krim_refund_requests`.
- The absence of a refund request row does not prove no refund was issued directly in the provider dashboard. Check provider refund history for all paid payment IDs before closing the historic liability review.
- The legacy `payments` rows and newer `payment_orders` rows are separate persistence/accounting paths. Do not add or backfill ledger entries without matching provider settlement evidence and an accounting-approved mapping.

## E. Reconciliation actions still required

For every provider order/payment above, an authorized account operator should retrieve Razorpay's current order/payment/refund status and settlement report, then reconcile:

1. Exact provider order ID, payment ID, amount and currency.
2. Current provider state: created/attempted/authorized/captured/failed/refunded/partially refunded.
3. Settlement/transfer batch, fees, net amount, bank credit and settlement date where applicable.
4. Customer and shipment ownership/contract records, including whether any customer or partner was actually charged.
5. Any refunds, disputes, chargebacks or reversals.
6. Local row and ledger mapping; document any mismatch for manual accounting review.

Do not cancel the five newer `created` orders in bulk. Do not initiate refunds, create ledger rows, replay webhooks, update statuses, or alter provider settings as part of this inventory.

## F. Launch decision

**Partner-direct launch remains blocked on payment reconciliation.** The source-level server-side order-creation gate exists on the working GitHub branch but is not deployed. Existing provider-side orders are not invalidated by that source change. Keep new KRIM freight checkout disabled and preserve the signed webhook and controlled refund path for historical reconciliation until all historic obligations are resolved.

## Safety

Read-only SQL only. No customer contact, provider API calls, order cancellation, refund, webhook replay, database mutation, secret/configuration change, deployment, PR merge, or payment/ledger write was performed.
