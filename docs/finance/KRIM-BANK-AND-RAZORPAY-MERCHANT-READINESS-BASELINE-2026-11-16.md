# KRIM Bank & Razorpay Merchant Readiness Baseline
**Date:** 16 November 2026  
**Environment:** Supabase production, read-only  
**Commercial model:** KRIM-owned service-fee collection only; customer pays logistics partner directly for freight.  
**Decision:** No live checkout approval.

## 1. Executive finding

The production public schema inspection found no dedicated bank-account or merchant-account registry table. The payment capability registry exists, but the India/INR Razorpay row is deliberately not enabled and does not establish verified merchant eligibility or settlement capability.

This means the application database cannot currently prove the destination bank account, merchant legal-name match, provider settlement readiness or bank reconciliation path. It does not prove whether the proprietor has separately opened a real-world business bank account or completed Razorpay onboarding; those require documentary/provider evidence outside this database review.

## 2. Live Razorpay capability flags

Read-only production query returned:

| Country | Currency | Integration | Checkout | Merchant eligible | Presentment | Settlement | Refunds | FX |
|---|---|---|---|---|---|---|---|---|
| IN | INR | implemented | false | false | true | false | false | false |
| IN | AED | planned | false | false | false | false | false | false |
| IN | EUR | planned | false | false | false | false | false | false |
| IN | GBP | planned | false | false | false | false | false | false |
| IN | SGD | planned | false | false | false | false | false | false |
| IN | USD | planned | false | false | false | false | false | false |

**Interpretation:** The integration status `implemented` for INR means a code integration exists; it is not an approval to collect money. The checkout flag, merchant eligibility, settlement, refunds and FX are all false. The other currencies are planned and disabled.

## 3. Bank and merchant data model finding

A search of production public tables for bank, merchant, Razorpay and settlement names returned only:
- `krim_payment_capability_registry`
- `krim_settlements`

No dedicated production bank-account or merchant-account registry was found in that name-based search. The capability registry stores country/currency/provider flags, supported methods, evidence reference, review time and notes. It does not contain a canonical bank account, beneficiary verification state, merchant KYC case, provider settlement account reference or bank statement reconciliation object.

The settlement table exists but prior live inventory returned zero rows. A table's existence does not prove a settlement workflow or verified bank credit.

## 4. Required founder-side evidence (securely retained outside GitHub)

### Business bank account
- Account opened in the proprietor/business configuration accepted by the bank.
- Exact account-holder name and trade-name representation.
- Bank-issued proof (cancelled cheque, statement header or bank letter).
- IFSC and account details verified directly in bank channel.
- Confirmation the account can receive Razorpay merchant settlements.
- Bank statement access for monthly reconciliation.

Do not paste full account numbers, net-banking credentials, OTPs, debit-card data or bank statements containing unnecessary personal information into ChatGPT, GitHub or public application forms.

### Razorpay merchant account
- Merchant KYC completed and business category accepted.
- Legal name, proprietorship/trade name and proprietor identity aligned with bank and registration evidence.
- Written confirmation that the account may collect KRIM's own referral/coordination/software service fees.
- Live-mode status confirmed from the authenticated Razorpay dashboard.
- Settlement account matches the verified KRIM bank account.
- Settlement cycle, fees, reserves/holds, dispute handling and statement/export access confirmed.
- Webhook endpoint/secret configured securely and signature verification validated.
- Provider support confirmation for any applicable marketplace/intermediary or third-party collection restrictions.

Do not share Razorpay key secrets, webhook secrets, OTPs or dashboard recovery codes.

## 5. Safe target payment path

The first payment product should be a separate KRIM own-service-fee flow:
1. Signed fee agreement and evidenced KRIM service.
2. CA-reviewed tax treatment and correctly issued KRIM invoice/payment request.
3. Server-authoritative amount, currency, payer, invoice and KRIM legal-entity binding.
4. Razorpay order for that invoice only; no shipment freight quote or partner payout.
5. Signed provider callback and idempotent payment capture record.
6. Provider settlement reference and settlement statement.
7. Actual credit to the verified KRIM bank account.
8. Invoice/receipt match, provider fee record and bank reconciliation.
9. Balanced journal posting in the canonical finance organisation after accounting/migration approval.

A captured payment is not a settled payment. A provider settlement is not proof of bank credit. A payment record is not automatically earned revenue or accounting profit.

## 6. Release gates and present status

| Gate | Present evidence | Status |
|---|---|---|
| Physical business bank account | Not established by the database query; founder confirmation and bank proof required | Founder evidence pending |
| Database bank/merchant registry | No dedicated registry found in public schema search | Not implemented |
| Razorpay merchant eligibility | Registry false | Blocked |
| Razorpay INR checkout | Registry false | Blocked |
| Razorpay settlement | Registry false | Blocked |
| Razorpay refund capability | Registry false | Blocked |
| Razorpay FX capability | Registry false | Blocked |
| KRIM own-fee order/verification flow | No separate reviewed implementation found | Design required |
| Canonical finance entity | Prior assessment found binding unresolved and Org 21 is a verification organisation | Blocked |
| Accounting and bank reconciliation | No ledger transactions/reconciliation rows in prior inventory | Not operationally demonstrated |
| GST and fee tax treatment | Actual rejection order and CA review not yet available | Blocked |

## 7. Explicit non-actions

No provider API calls, Razorpay dashboard changes, bank account changes, capability flag updates, payment orders, test payments, refunds, settlements, ledger entries or production schema changes were made. This review did not expose secrets or bank account identifiers.

## 8. Next required action

The founder should confirm whether a dedicated business bank account is already open and whether Razorpay merchant KYC/live activation is complete. If complete, provide only redacted proof showing the account-holder/trade-name match and provider onboarding status; never provide full account numbers or credentials. The GST rejection order remains separately required before any fee invoice or commercial collection is approved.

**Release decision:** Keep all checkout disabled. Do not change the INR capability flags to true until legal/tax, merchant eligibility, verified bank settlement, canonical finance organisation, migration reconciliation and end-to-end own-fee acceptance tests have passed.
