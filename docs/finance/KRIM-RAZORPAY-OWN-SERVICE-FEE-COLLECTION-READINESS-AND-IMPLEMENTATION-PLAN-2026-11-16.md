# KRIM Razorpay — KRIM-Owned Service-Fee Collection Readiness & Implementation Plan
**Date:** 16 November 2026  
**Scope:** Read-only review of checked-in Razorpay Edge Function source and finance architecture.  
**Operating model:** Partner-direct freight; KRIM-only separately contracted service fees.  
**Decision:** Do not enable checkout. Build a separate fee-only flow after legal, merchant, entity and migration gates.

## 1. Executive finding

The checked-in Razorpay integration is currently a shipment/quote freight-checkout path, not a KRIM service-fee collection product. The canonical `create-global-razorpay-order` handler explicitly returns HTTP 503 unless both `KRIM_FREIGHT_COLLECTION_ENABLED=true` and the exact approval version `2026-11-15-v1` are configured. It then validates a confirmed shipment, accepted partner quote, accepted assignment, confirmed capacity binding/reservation and currency capability before creating the provider order.

The checked-in `verify-razorpay-payment` handler applies the same freight-collection approval gate to unpaid orders. The legacy `create-razorpay-order` endpoint returns HTTP 410 and is retired. The checked-in refund executor is separately gated by `KRIM_LEGACY_REFUND_EXECUTION_ENABLED` and its approval version.

**This is not a KRIM own-fee checkout flow.** No reviewed endpoint in this scope creates a Razorpay order from a signed KRIM referral/coordination/software service invoice without a shipment/partner-freight dependency. Do not repurpose the freight checkout or toggle its secrets to collect KRIM fees.

## 2. Checked-in source observations

| Component | Observed design | Release implication |
|---|---|---|
| `create-global-razorpay-order` | Full quote amount; requires confirmed shipment, accepted quote/partner assignment and confirmed capacity binding/reservation; feature-flagged | Freight checkout stays disabled under partner-direct model |
| `verify-razorpay-payment` | Verifies order/payment signature and shipment/quote/assignment/capacity binding; blocks new unpaid verification unless freight approval flag/version are enabled | Not suitable as KRIM fee verifier |
| `razorpay-webhook` | Verifies HMAC over raw body, requires event ID, stores provider events, checks duplicate processing, handles supported payment/refund events | Provider webhook foundation exists, but service-fee-specific invoice correlation and accounting remain unproven |
| `create-razorpay-order` | Retired with HTTP 410 | Do not route traffic to legacy endpoint |
| `execute-razorpay-refund` | Refund execution requires a separate explicit legacy refund flag/version and database claim | Do not enable refunds for unverified historic freight collections or use them as a fee pilot |

These are source-code observations, not a live merchant-account certification or proof that deployed Edge Function versions exactly match checked-in source. No provider API was called and no real order/payment/refund was created.

## 3. Separate service-fee payment product — target design

Create a new bounded domain that has no shipment freight amount as its source of truth.

### Authoritative business source
A KRIM fee may become payable only after:
1. A verified counterparty and signed agreement exist.
2. The agreement defines KRIM's actual service, fee amount/basis, currency, tax treatment, earning trigger, due date, cancellation/credit and dispute terms.
3. The qualifying referral/introduction or coordination service is evidenced and accepted under that agreement.
4. An independent reviewer confirms the trigger and amount.
5. A legally/tax-reviewed KRIM invoice or payment request is issued.
6. The payer, legal entity, invoice, amount and currency are bound server-side.

### Separate payment records
Design (do not create in production yet):
- `krim_service_fee_invoices`: legal_entity_id, finance_organization_id, counterparty_organization_id, contract_id, referral_id/service_record_id, invoice_number, currency, net/tax/gross amounts, issue/due dates, tax_review_reference, immutable fee snapshot, status.
- `krim_service_fee_payment_orders`: invoice_id, provider, provider_order_id, amount_minor, currency, idempotency_key, created_by, status and provider metadata reference.
- `krim_service_fee_payment_events`: provider event ID/type, signature verification result, raw-payload digest, received/processed timestamps, processing status and safe error code; raw sensitive payload should be minimised and access controlled.
- `krim_service_fee_receipts`: invoice_id, payment_order_id, provider payment ID, amount/currency, captured timestamp, provider settlement reference, bank-credit evidence reference and reconciliation status.
- `krim_service_fee_credit_notes` / refund requests: linked to the original KRIM invoice and own-fee payment only.
- Accounting source references: immutable invoice/receipt IDs linked to balanced journal posting; no partner freight or GMV fields.

The final table/column names must be reconciled against production schema and migration history before drafting a forward migration. Avoid duplicate canonical sources and do not copy card/bank credentials or full personal identifiers into these tables.

### Separate Edge Functions
- `create-krim-service-fee-order`: authenticated payer; invoice ownership and organization access; invoice status must be approved/unpaid; server reads amount/currency from invoice, never accepts client amount; provider/currency capability and KRIM merchant eligibility gates; unique idempotency; no shipment/quote/freight dependencies.
- `verify-krim-service-fee-payment`: verify provider signature, exact order/payment/invoice/amount/currency/counterparty, idempotent status transitions; never mark bank-settled merely from capture.
- `krim-service-fee-razorpay-webhook` or carefully separated webhook router: verify raw-body HMAC, provider event ID, persist event once, retry safely, correlate only to own-fee order, never invoke freight posting.
- Refund execution: separately authorized, maker-checker, invoice-linked, full/partial amount rules, idempotency, and provider webhook finality. Remain disabled until approved.

### Required states
`draft → review_pending → approved_to_issue → issued_unpaid → payment_pending → captured_unsettled → provider_settled → bank_reconciled`.
Exception paths: `payment_failed`, `part_paid` (if supported), `overdue`, `disputed`, `credited`, `refund_pending`, `refunded`, `reversed`.
Do not collapse provider capture, provider settlement, bank credit and accounting recognition into one `paid` flag.

## 4. Mandatory security and accounting controls

- Canonical legal-entity and finance-organisation binding by stable IDs, not display-name matching.
- Quarantine verification organisation 21; do not post live books to it.
- Resolve chart-of-accounts mappings before journal posting. Existing generic revenue mapping points to freight service revenue; partner-funds mapping points to KRIM cash/bank. Neither is safe for the initial partner-direct own-fee product.
- Authenticated users must not directly mutate financial posting/recovery records. Reconcile migration history first, then apply reviewed least-privilege forward migration.
- Invoice/order amount and currency are server-derived from immutable approved invoice snapshot.
- Unique constraints for provider order ID, provider payment ID, provider event ID, invoice idempotency and receipt source.
- Verify amount, currency, payer/counterparty, invoice and legal entity on every callback.
- Event processing must be retryable without duplicate receipt, ledger entry or refund.
- Capture does not equal settlement; settlement does not equal bank credit; bank credit does not itself determine tax or revenue recognition.
- Balanced journal entries, period lock, append-only audit, reversals, maker-checker and monthly bank reconciliation.
- Separate tax amount/liability and provider fees; never silently net gateway fees against revenue.
- No partner freight amount, partner payable, shipment GMV, escrow, split or payout in this service-fee payment domain.

## 5. Go-live gates

| Gate | Evidence required | Current state |
|---|---|---|
| Legal/tax | Actual GST rejection order reviewed; CA advice on fee service, GST registration/applicability, invoice type, TDS/TCS and intermediary/marketplace exposure | Blocked — rejection order not yet available in this review |
| Legal entity | Proprietorship documents, legal/trade-name and proprietor identity binding, address and tax identity verified | Not evidenced here |
| Bank | Dedicated KRIM account and account-holder/settlement name confirmed | Not evidenced here |
| Razorpay merchant | KYC, business category approval, live mode, own-fee collection permission, settlement account and statement access | Not evidenced here |
| Finance organisation | Canonical organisation approved; verification org quarantined; COA and mappings corrected | Blocked |
| Migration | Full repository/production migration reconciliation and isolated staging | Blocked |
| Service contract | Signed fee agreement and objective service/earning evidence | No live contracts recorded in prior inventory |
| Invoice | Legally reviewed KRIM own-service invoice workflow | Not operationally demonstrated |
| Ledger | Balanced own-fee receipt and fee/expense posting with reconciliation | No ledger transactions or entries in prior inventory |
| Acceptance | Controlled low-value own-fee test, provider settlement and actual bank credit independently matched | Not run |

## 6. Explicit non-actions

This review did not:
- enable any Razorpay or freight-collection secret;
- invoke an Edge Function;
- call Razorpay or create an order;
- create or change an invoice, receipt, ledger entry, tax rule or refund;
- apply a migration or alter production permissions;
- verify merchant KYC, live credentials or bank settlement.

## 7. Immediate next step

Obtain the GST rejection order/portal notice and complete legal-entity and bank-account verification. In parallel, keep the existing full-freight Razorpay path disabled. Once the legal/tax and merchant gates pass, implement the own-service-fee domain in a reconciled branch/staging environment, then test provider capture → settlement → bank credit → invoice matching → balanced ledger posting before any live rollout.

**Release decision:** KRIM may continue building the own-fee payment design, but is not yet approved to collect live commercial fees through Razorpay. Do not enable the freight checkout as a shortcut.
