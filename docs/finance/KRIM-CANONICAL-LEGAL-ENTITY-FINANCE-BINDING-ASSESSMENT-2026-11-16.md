# KRIM Canonical Legal Entity & Finance Organisation Binding Assessment
**Date:** 16 November 2026  
**Environment:** Production, read-only inspection  
**Decision:** Binding unresolved; no production configuration changed.

## 1. Live organisation records

Two relevant records were inspected in `public.krim_organizations`:

| ID | Type | Legal name | Display name | Currency | Status |
|---:|---|---|---|---|---|
| 1 | platform | KRIM Logistics | KRIM Global Platform | INR | active |
| 21 | finance | KRIM Finance Journey Verification | KRIM Finance Journey Verification | INR | active |

Org 1 is the platform organisation and currently carries the KRIM Logistics legal-name string. Org 21 is explicitly named as a finance journey verification organisation. The names and types do not establish that Org 21 is a registered legal entity, nor that its finance records belong to the proprietor's books. No evidence was found in this read-only inspection proving a formal legal-entity identifier, PAN/GST registration mapping, proprietor identity binding, registered address, or CA-approved accounting basis on either record.

**Finding:** Org 21 must be treated as a test/verification finance organisation, not as the canonical KRIM legal entity, until documentary and governance evidence proves otherwise. Org 1 is the likely platform identity anchor, but must not automatically be treated as a fully verified accounting entity merely because its legal_name field says KRIM Logistics.

## 2. Accounting period mismatch

One live accounting period exists:

- Organisation: 1
- Period: 1 April 2026 – 31 March 2027
- Status: open
- Metadata: India financial year / readiness setup

The period is attached to Org 1, while the existing chart of accounts and account mappings inspected below are attached to Org 21. No journal transactions or entries exist in the inspected ledger tables.

**Risk:** Posting to Org 21 would mix verification configuration with a period attached to Org 1. Posting to Org 1 would lack the corresponding confirmed chart/mapping foundation. Do not post journals or use either configuration for live bookkeeping until the canonical binding is approved.

## 3. Chart of accounts and mappings found under Org 21

Fourteen active INR accounts exist under Org 21:

| Code | Account | Type | Assessment |
|---|---|---|---|
| 1000 | Cash and Bank | Asset | Keep only for KRIM-owned bank balances with evidence |
| 1010 | Razorpay Payment Clearing | Asset | Use only for eligible KRIM-owned collections and provider reconciliation |
| 1100 | Trade Accounts Receivable | Asset | Suitable concept for KRIM-issued invoices |
| 1200 | Input GST Credit | Asset | Activate only with reviewed GST registration/eligibility and tax evidence |
| 2000 | Partner Payables | Liability | Not needed for the initial partner-direct model unless KRIM genuinely owes a partner |
| 2010 | Output GST Payable | Liability | Activate only after CA-approved tax configuration |
| 2020 | Customer Funds Held / Unearned Revenue | Liability | Do not use to imply KRIM holds partner freight money; initial model prohibits custody |
| 3000 | Proprietor Capital | Equity | Appropriate concept for sole-proprietor books subject to accountant setup |
| 3100 | Retained Earnings | Equity | Accounting presentation should be reviewed for sole-proprietor treatment |
| 4000 | Freight and Logistics Service Revenue | Revenue | Unsafe default for partner freight GMV; disable for initial referral model |
| 4010 | KRIM Platform Commission Revenue | Revenue | Rename/reclassify only after contract and CA review; referral/coordination fees need distinct source types |
| 4090 | Refunds and Customer Credits | Revenue/debit | Contra-revenue concept; must be linked to KRIM-issued invoice/credit note and provider refund |
| 5000 | Operating Expenses | Expense | Requires evidence, approval and cash/payment reconciliation |
| 5010 | Payment Gateway Fees | Expense | Requires provider statement and correct allocation |

Five active mappings exist under Org 21:
- bank → account 1010 Razorpay Payment Clearing;
- receivable → account 1100 Trade Accounts Receivable;
- revenue → account 4000 Freight and Logistics Service Revenue;
- partner_payable → account 2000 Partner Payables;
- partner_funds → account 1000 Cash and Bank.

**Critical design mismatch:** The generic revenue mapping points to freight service revenue, and partner_funds maps to KRIM cash and bank. These mappings are incompatible with a clean non-custodial partner-direct launch if reused without source-specific rules. Partner-direct freight paid to the carrier is neither KRIM cash nor KRIM revenue. Do not invoke posting routines that consume these generic mappings.

## 4. Canonical binding target (design only)

Before any live journal:
1. Confirm the proprietor's legal identity and business constitution from actual registration documents.
2. Confirm the exact legal/trade-name representation, business address and applicable PAN/GST details with a qualified CA.
3. Decide whether Org 1 becomes the sole canonical finance organisation or whether a new finance organisation is provisioned under a reviewed migration.
4. Mark Org 21 as non-production verification/test scope and prohibit operational posting to it.
5. Bind one legal entity to one canonical finance organisation through a constrained, auditable relation. Avoid name-string matching.
6. Attach one reviewed India financial year and base currency to that organisation.
7. Create an account catalogue for KRIM-owned referral/coordination/software income, receivables, own bank/provider clearing, expenses, tax liabilities and proprietor equity.
8. Remove partner-funds, partner-payable and freight-revenue mappings from the initial non-custodial posting path. Do not delete existing records; retire/revise only through a reviewed forward migration after schema recovery.
9. Ensure every journal source includes legal entity, finance organisation, source type/id, contract/invoice reference, currency, accounting date, idempotency key and evidence reference.
10. Require balanced debit/credit entries, locked periods, append-only audit events, reversal entries and maker-checker approval.

## 5. First safe accounting lifecycle for KRIM's own referral fee (illustrative, not posting instructions)

Assume a partner agreement establishes a fee owed to KRIM after independently evidenced completed service. The fee is in INR and tax treatment has already been reviewed.

- **Earned and invoiced:** debit KRIM trade receivable; credit the appropriate KRIM referral/coordination revenue account; record tax liability separately only as professionally configured.
- **Provider/bank receipt verified:** debit KRIM bank/provider clearing; credit trade receivable.
- **Provider fee:** record separately as expense with statement evidence, not by reducing gross revenue invisibly.
- **Credit/refund:** issue the appropriate credit note and record a linked reversal/credit; refund only after provider confirmation and reconciliation.

No entry should be created for the partner's gross freight invoice or the partner's direct customer collection. No example amount is posted or implied.

## 6. Release gates

- [ ] Documentary legal entity and proprietor details confirmed by qualified adviser.
- [ ] GST applicability and invoicing/tax treatment confirmed; no software-generated exemption.
- [ ] Canonical finance organisation approved and linked by stable ID.
- [ ] Org 21 explicitly quarantined as verification-only.
- [ ] Migration lineage recovered and staging reconstructed.
- [ ] Chart of accounts and mappings reviewed for sole proprietorship and non-custodial model.
- [ ] Posting routine tested for balanced entries, idempotency, concurrency, reversal, tenant isolation and period locks.
- [ ] Provider capture, settlement and bank credit reconciled independently.
- [ ] Independent finance/security review passed.

**Release decision:** No production finance writes, journal posting, invoice issuance, revenue recognition, tax posting, refund or settlement activation. This assessment is based on read-only production inspection; no production DDL, rows, grants, triggers or functions were changed.
