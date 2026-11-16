# KRIM Referral Revenue Loop — Controlled Pilot Playbook

**Version:** 1.0  
**Date:** 16 November 2026  
**Operating model:** Non-custodial, partner-direct logistics referral pilot  
**Release status:** CONTROLLED MANUAL PILOT ONLY — not automated or production-finance certified

## 1. Purpose and success definition

Establish one auditable path for KRIM to earn its own referral income without collecting, holding, routing or settling customer freight funds.

A loop counts as completed only when all of the following are evidenced:

1. A real logistics partner's legal identity, authority, relevant operating capability and insurance are verified.
2. A written partner agreement is signed, including the exact referral-fee trigger and amount/basis.
3. A real shipper enquiry is qualified and the shipper explicitly consents to the introduction.
4. The partner accepts the referred opportunity and the customer contracts directly with the partner.
5. The partner performs the service and completion evidence is retained.
6. The contractual referral-fee trigger is met and independently checked.
7. KRIM issues the legally/tax-correct document after CA confirmation.
8. KRIM receives the referral fee into its own bank account and the receipt is matched to the agreement, invoice and bank statement.
9. The receipt and related costs are recorded in the correct KRIM legal-entity books; a reviewer reconciles the entry.
10. A monthly report distinguishes invoiced, collected, overdue, refunded/credited, expenses and net operating result.

A customer freight payment to the partner is NOT KRIM revenue. Shipment value, quote value, partner payout and GMV must never be included in KRIM turnover or profit merely because KRIM introduced the parties.

## 2. Hard commercial and safety boundaries

- Customer and logistics partner contract directly for the logistics service and pay freight directly to the partner.
- KRIM must not receive, pool, escrow, hold, split or settle freight money.
- KRIM earns only a separately agreed fee for a defined introduction/referral outcome. Do not add a coordination service or fee unless its actual scope, responsibility and tax treatment are separately agreed.
- No public claim of a partner's route, capacity, rates, service level or availability until verified for the exact scope and period.
- Do not activate automated freight checkout, partner payouts, refund workflows, revenue-recognition functions or legacy revenue-ledger displays for this pilot.
- Do not treat legacy shipment revenue, payment, margin or payout rows as proof of KRIM earnings.
- Do not invoice or describe the model as GST-exempt. Obtain written advice from an Indian CA/tax professional on GST registration threshold/applicability, nature/place of supply, intermediary treatment, commission invoicing, TDS and accounting before the first commercial fee invoice.
- No commercial pilot starts until the agreement, tax advice, partner diligence and customer-consent process are complete.

## 3. Stage-gated operating procedure

| Stage | Owner | Required evidence | Pass condition | If it fails |
|---|---|---|---|---|
| A. Partner diligence | Founder + reviewer | Legal name/registration, authorised signatory, address, permits/licences as applicable, insurance, references, service scope, lanes, subcontracting disclosure, bank beneficiary verification through secure channel | All applicable evidence checked; reviewer records decision | Keep partner as prospect; no matching or coverage claim |
| B. Contract | Founder + legal/CA reviewer | Signed agreement with partner legal entity, services, referral definition, fee basis, exact earning trigger, due date, evidence, cancellations/claims, liability, data/privacy, dispute and termination clauses | Both parties signed; tax/invoice treatment confirmed | No referral under a fee promise |
| C. Lead qualification | Founder/operations | Lead ID, source, shipper legal/contact details, pickup/drop, commodity, dimensions/weight, timing, mode, special handling, consent record | Complete enough to assess; consent to share with named partner recorded | Ask for missing information; do not share |
| D. Referral & acceptance | Founder/operations | Referral ID, named partner, timestamp, information shared, partner acceptance and customer acknowledgement | Partner confirms in writing it can assess/serve; customer chooses to proceed | No booking or promise |
| E. Direct contract & service | Customer + partner | Customer-partner contract/order, partner confirmation, delivery/POD or equivalent completion evidence, exceptions/claims | Service completion independently evidenced | Fee remains not earned unless agreement expressly says otherwise |
| F. Fee eligibility | Founder + reviewer | Agreement clause, referral ID, completion proof, fee calculation, cancellation/credit check | Exact contractual trigger and amount independently approved | Keep as disputed/pending; no invoice |
| G. KRIM billing | Founder/finance | CA-approved invoice/document type, invoice number/date, customer/partner counterparty, tax fields, currency, due date, linked referral and contract | Document checked against tax advice and agreement | Do not issue; obtain professional correction |
| H. Collection | Founder/finance | Bank statement/credit advice, payer identity, amount, currency, date, transaction reference | Cleared funds in KRIM's own account match invoice; no freight funds | Keep receivable outstanding; investigate mismatch |
| I. Bookkeeping & reconciliation | Finance reviewer | Invoice, fee calculation, bank evidence, expense evidence, journal/ledger entry, tax treatment | Correct entity, account, period and amount; independent review; no duplicate | Quarantine entry; do not report as collected profit |
| J. Monthly close | Founder + reviewer | Invoice register, receipts, overdue list, credit notes/refunds, expenses, tax liabilities, bank reconciliation | All balances reconcile; report signed off | Mark month unreconciled; do not publish profit |

## 4. Pilot register — one row per referral

Use a unique KRIM-REF-YYYY-NNNN reference. Never place identity documents, bank account numbers, PAN, Aadhaar or other sensitive evidence in a public spreadsheet or Git repository. Store sensitive evidence only in an access-controlled private location and record a secure evidence reference here.

| Field | Required value |
|---|---|
| Referral ID | KRIM-REF-YYYY-NNNN |
| Lead received at / source | |
| Shipper organisation and authorised contact reference | |
| Shipper consent timestamp and method | |
| Lane / service / commodity / handling | |
| Partner legal entity ID | |
| Partner verification reviewer / date / evidence reference | |
| Partner agreement ID / signed date | |
| Fee basis and exact trigger clause | |
| Partner acceptance timestamp / evidence reference | |
| Customer-partner order reference / date | |
| Service completion date / POD evidence reference | |
| Fee trigger satisfied? / reviewer / date | |
| Fee calculation / currency | |
| KRIM invoice/document number / issue date | |
| Due date / tax review reference | |
| Receipt amount / date / bank reference | |
| Bank reconciliation reviewer / date | |
| Related direct costs | |
| Net contribution after direct costs | |
| Status / exception / next action | |

## 5. Fee and status definitions

Use one status only, supported by evidence:

- prospect — no diligence completed.
- partner_verification_pending — evidence/review incomplete.
- partner_verified_contract_pending — diligence passed; no signed agreement.
- partner_active — agreement signed and scope approved.
- lead_new — enquiry captured, not qualified.
- lead_qualified — required details and consent recorded.
- referred — named partner introduction sent with consent.
- partner_accepted — partner confirmed acceptance for assessment.
- service_in_progress — direct customer-partner order exists.
- service_completed — completion evidence checked.
- fee_pending_validation — service completed; contract trigger not yet independently confirmed.
- fee_earned_unbilled — trigger met and reviewed; no KRIM invoice issued yet.
- invoiced_unpaid — legally correct KRIM invoice issued; funds not received.
- part_paid — partial cleared receipt matched.
- collected_unreconciled — cleared funds received but not fully reconciled.
- collected_reconciled — invoice, bank receipt and books independently matched.
- disputed / cancelled / credited — exception state; no unqualified revenue claim.

Do not mark a fee earned solely because a quote was issued, shipment was created, partner received freight payment, or a delivery status changed. Apply the signed agreement's precise trigger.

## 6. Revenue and performance reporting

Report separately:

- Qualified leads and consented referrals.
- Partner acceptance rate.
- Completed services.
- Referral fees earned (accrual view, if CA-approved).
- KRIM invoices issued.
- Cash actually collected and bank-reconciled.
- Overdue receivables and days to collect.
- Direct acquisition/support costs.
- Contribution after direct costs.
- Tax liabilities and other operating expenses.
- Net profit only after all applicable expenses, tax and accounting adjustments.

Never label the following as KRIM revenue: partner freight invoice totals, customer-to-partner payments, total shipment value, GMV, partner payable, uncollected referral fees or unverified legacy commission fields.

## 7. Technical implementation release gates

The live database currently contains finance functions and tables whose tenant isolation, organisation binding, accounting semantics and migration provenance are not yet safe. Known risks include an unscoped legacy revenue-ledger SECURITY DEFINER routine, finance-role and partner-payable exposure, writable finance configuration, incomplete double-entry enforcement, unsafe shipment-gross revenue-recognition semantics and refund tenant-binding issues.

Therefore this playbook deliberately does NOT call or enable those routines and does not write to production finance tables.

Before a software implementation is released:
1. Recover and reconcile the production migration history and exact migration source bodies.
2. Resolve the canonical KRIM legal-entity ↔ finance-organisation mapping.
3. Design a dedicated referral-fee receivable model distinct from freight invoices, shipment GMV and partner payables.
4. Enforce organisation-scoped RLS and server-side permission checks; remove broad browser access and unsafe SECURITY DEFINER grants.
5. Make fee eligibility evidence-backed, agreement-linked, reviewer-approved and idempotent.
6. Post only KRIM's own fee and approved expenses to balanced double-entry journals; enforce debit=credit in the same transaction.
7. Match actual bank receipts with unique idempotency keys; never infer collection from a provider webhook alone.
8. Test tenant isolation, duplicate events, partial payments, reversals, credit notes, refunds, wrong currency, wrong legal entity, stale evidence, replay and concurrency in isolated staging.
9. Obtain independent finance/security review and CA approval before enabling production invoicing or accounting automation.

## 8. First pilot acceptance test

The first pilot is not complete until one real referral passes every stage A–J with real partner, customer, agreement, service, invoice, bank receipt and bookkeeping evidence. Test fixtures and simulated payments may validate software only; they do not count as revenue.

**Current baseline (16 Nov 2026):** Prospect research exists; no verified/contracted partner, no confirmed live referral, no evidence of KRIM referral fee earned or collected, and no completed end-to-end finance loop. The first real-world tasks are partner verification, CA/tax confirmation and agreement execution. No outbound contact or financial transaction is authorised by this document.
