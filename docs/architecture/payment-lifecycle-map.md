# KRIM Global Logistics OS — Payment Lifecycle Map

## Current provider policy
- Razorpay is the only enabled customer checkout provider.
- The customer-facing payment experience is quote-bound and uses the canonical `payment_orders` record.
- Future regional provider adapters are architecture slots only. They must not be enabled until merchant eligibility, market/currency support, settlement, fees, refunds, disputes, reconciliation and security checks pass.

## Customer payment lifecycle
1. **Shipment and quote**: Customer creates a real shipment and reviews an accepted, unexpired quote.
2. **Partner linkage**: The accepted customer quote must reference the selected partner offer, and the linked shipment assignment must be accepted.
3. **Server-created order**: `create-global-razorpay-order` authenticates the customer, verifies organization access, checks shipment/quote/assignment linkage, derives amount and currency from the accepted quote, and reuses a matching eligible Razorpay order when appropriate.
4. **Provider checkout**: Razorpay Checkout receives only the server-created order, server-returned amount/currency and public key ID. Browser fields never set the charge amount.
5. **Verification**: `verify-razorpay-payment` verifies the HMAC signature and independently checks the payment with Razorpay for order ID, captured status, amount and currency.
6. **Canonical financial record**: The verified payment order is marked paid and an idempotent `krim_financial_transactions` record is created. Webhook and browser retries must reconcile to the same provider reference.
7. **Downstream operations**: Shipment operations and partner settlement must rely on the verified financial state and the relevant workflow rules—not a browser success callback alone.

## Global rollout gates
- The current checkout route is INR-only. International cards, other currencies, local wallets and bank-transfer workflows must not be represented as enabled until implemented and tested for KRIM's actual merchant account and relevant markets.
- Provider failure or an unclear result must trigger status reconciliation before another payment attempt. KRIM must never automatically charge through a second provider because the first result is unclear.
- Provider IDs, order IDs, payment IDs, signatures, webhook event IDs and settlement references require uniqueness/idempotency controls where appropriate.
- Refunds, disputes/chargebacks, provider fees, settlement reconciliation and partner payouts require their own tested workflows before claiming production readiness.
- Historical migrations are kept immutable for reproducible database history; current schema and active code must not retain retired-provider runtime dependencies.

## Current verification status
- The order and verification Edge Functions are deployed.
- Real-money checkout, merchant live mode, international eligibility, refunds, disputes, ledger reconciliation and partner settlement still require separate end-to-end verification.
- No demo invoice, sample amount or fictional bank account is a valid payment source.
