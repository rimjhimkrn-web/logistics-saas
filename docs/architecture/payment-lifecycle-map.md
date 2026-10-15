# KRIM Logistics OS — Payment Lifecycle Map

## 1. Settlement Architecture
1. **Invoice Generation**: Automated tax invoices generated upon quote finalization (`/public/shipper/invoices.html`).
2. **Escrow Authorization**: Secure payment execution through Razorpay edge functions.
3. **Verification**: Cryptographic signature validation ensuring tamper-proof transaction recording.
4. **Settlement Ledger**: Funds reconciled into the partner earnings and settlement ledger (`/public/partner/settlements.html`).
5. 
