# KRIM Independent Referral Revenue Engine — Build Specification
**Date:** 16 November 2026  
**Status:** architecture and live-schema assessment only; no production schema or financial records changed.

## 1. Executive finding

KRIM can develop a legitimate referral-fee income stream without collecting customer freight payments. In the initial non-custodial model, the logistics partner contracts with and is paid directly by the shipper. KRIM earns only a separately agreed fee for a qualifying referral/coordination service, once the contract-defined trigger is independently evidenced and the fee is approved.

The current production schema is not sufficient to automate that lifecycle safely. It contains a basic customer referral attribution table, service-contract structures and partner capability records, but it does not yet prove an executable agreement → completion evidence → fee calculation → KRIM invoice → collected receipt → balanced journal path.

## 2. Live schema inspection

### Existing structures

`krim_customer_referrals` currently contains:
- referrer and referred acquisition-profile IDs;
- referral code;
- status constrained to created, accepted, converted, expired or suppressed;
- created/converted timestamps and JSON metadata.

It has no first-class fields for partner counterparty, partner agreement, fee schedule/version, fee amount/currency, service completion evidence, invoice, receivable, payment receipt, journal source or dispute/approval state.

Its current RLS policy requires authenticated organisation access to both the referrer profile's organisation and the referred profile's organisation for ALL operations. That may be too restrictive for legitimate cross-organisation referrals and needs explicit tenant/privacy review; do not broaden it casually.

`krim_customer_acquisition_profiles` provides organisation, source, discovery slug, display name, country/region/language, qualification/onboarding statuses and metadata.

`krim_service_contracts` provides organisation, counterparty organisation, contract number/type/status, effective dates, currency, service definition, commercial terms and metadata. It currently has zero rows.

`krim_service_contract_slas` provides measurable contract SLA definitions; it currently has zero rows.

`krim_partner_capabilities` contains one row. A capability row alone is not proof that the partner is verified, contractually authorised, available or eligible for a specific referral.

`krim_shipment_partner_assignments` currently contains zero rows. Assignment is an operational shipment workflow and should not be required for every marketing referral if the referral contract is for introductions only; it is required when the fee is tied to actual logistics service completion.

### Current blockers

- Zero referral rows.
- Zero service contracts and SLA rows.
- Zero shipment partner assignments in this table.
- One partner capability record, not sufficient to establish a verified and contracted partner network.
- No fee-specific, evidence-specific or invoice-linked lifecycle in the referral table.
- Existing finance organisation binding is unresolved.
- Finance invoice/ledger tables inspected earlier have zero live invoices, journal transactions and entries.
- Production migration lineage is unreconciled; no DDL may be applied until recovery and staging validation.

## 3. Commercial model: separate fee types

Do not use one generic commission field for all arrangements. The contract must choose a clear, auditable fee basis:

1. **Qualified introduction fee:** fixed amount for an accepted, consented introduction meeting objective qualification criteria. No claim that shipment completion is required unless contract says so.
2. **Completed-service referral fee:** fixed amount or percentage of a clearly defined partner service base, payable only after independently verified service completion.
3. **Coordination service fee:** fixed or milestone-based fee for a defined KRIM coordination deliverable, only if KRIM actually provides that service and legal/tax review approves the role.
4. **Software subscription:** separate product and billing domain; never label a referral fee as subscription revenue.

The signed agreement must specify payer, service provider, fee formula, base definition, exclusions, cap/floor, currency, tax responsibility, due date, evidence, dispute window, cancellation/refund, attribution window, repeat-business treatment and governing law. Percentage-based fees must state whether the base excludes taxes, surcharges, pass-throughs, discounts and refunds.

## 4. Target lifecycle

`captured → consent_verified → qualified → partner_routed → partner_accepted → service_evidence_pending → evidence_verified → fee_calculated → maker_reviewed → checker_approved → invoice_ready → invoice_issued → receipt_pending → receipt_verified → reconciled → closed`

Terminal/exception states include rejected, expired, withdrawn, duplicate, disputed, cancelled, reversed and written_off. Status changes must be event-driven, reason-coded and append-only. Do not let a client set a later state directly.

For introduction-only contracts, the completion evidence gate must match the signed introduction criteria. For completed-service referral contracts, it must include service completion proof. A shipment quote, partner opportunity, customer payment status or unverified POD is not sufficient evidence by itself.

## 5. Proposed bounded data model (design only)

Create through a reviewed forward migration only after migration recovery and staging reconstruction. Names are provisional and must be reconciled against the complete production schema before use.

### A. Referral attribution
Extend or replace the basic attribution structure with:
- unique referral identifier and immutable referral code;
- referrer identity and referred customer/organisation;
- partner organisation and relevant capability/lane;
- consent timestamp, consent source, privacy notice version and withdrawal state;
- attribution source, timestamp and attribution-window expiry;
- duplicate/suppression checks and fraud indicators;
- owner organisation / tenant binding and access classification.

Avoid exposing referred customer identity to a partner until valid consent and a legitimate operational need exist.

### B. Partner fee agreement
A first-class, versioned agreement record:
- KRIM legal entity and counterparty organisation;
- signed document storage reference/hash and signatory evidence;
- agreement type, jurisdiction and effective dates;
- currency and immutable fee formula snapshot;
- trigger definition and evidence requirements;
- tax/legal review state, reviewer and approval timestamp;
- status, suspension, termination and superseding agreement linkage.

No fee may be calculated from an unsigned draft or expired/suspended agreement.

### C. Referral service event
- referral and agreement IDs;
- partner acceptance event;
- contracted service/milestone type;
- shipment or service reference where applicable;
- evidence document references and hashes;
- independent verifier and review result;
- dispute and exception reasons;
- event timestamp and idempotency key.

### D. Fee assessment
- unique fee assessment ID and source event;
- agreement version and formula snapshot;
- base amount, exclusions, rate/fixed fee, cap/floor;
- calculated fee in integer minor units and ISO currency;
- calculation trace, rounding policy and FX source where needed;
- maker, checker, approval state and timestamps;
- reversal/supersession link.

Never recompute an already-approved fee from a subsequently changed agreement or rate card.

### E. KRIM billing and collection
- KRIM invoice and invoice-item references;
- invoice line links to the approved fee assessment;
- payment attempt/provider reference or bank-transfer reference;
- capture, provider settlement and bank-credit states kept distinct;
- receipt allocation and reconciliation evidence;
- credit note/refund references and reversal journal link.

The partner's freight invoice and payment stay between shipper and partner and must not be inserted into KRIM receivables or KRIM cash.

### F. Audit and access
- append-only lifecycle events with actor, action, timestamp, reason, source and before/after hashes;
- organisation-scoped RLS for referral data;
- minimum-necessary access for referrer, referred customer, partner, finance reviewer and platform administrator;
- maker-checker separation: creator cannot approve own fee, invoice adjustment or exception;
- sensitive approval requires appropriate privileged permission and MFA/AAL2;
- privileged functions live in non-exposed schema, fixed search_path, explicit auth/permission checks, strict tenant binding and narrowly granted EXECUTE.

## 6. Fee calculation examples (illustrative only)

**Fixed fee:** A signed agreement says a qualifying completed introduction earns a fixed INR fee. Once evidence is accepted, the system snapshots that fixed fee. No percentage of freight value is needed.

**Percentage fee:** A signed agreement says fee = a specified percentage of partner service value excluding GST and listed pass-throughs, with a cap. The system stores the source invoice/base evidence, exclusions, rate/version, calculation trace and cap application. It does not treat the partner's entire freight receipt as KRIM revenue.

No rates or prices are approved by this specification.

## 7. Accounting treatment — conceptual only

After the contract-defined trigger is met, the evidence is independently approved, and the CA-approved recognition policy permits recognition:
- create a KRIM receivable against the partner (if partner is the contractual payer);
- credit a KRIM referral/coordination revenue account;
- record output tax separately only as configured by a qualified adviser;
- when KRIM receives the fee, debit KRIM-owned bank/provider clearing and credit receivable;
- record gateway charges separately from gross revenue;
- credit notes/refunds use linked reversals and evidence.

The exact recognition date, invoice timing, GST treatment and TDS/withholding depend on the agreement, actual supplier role and professional advice. This document does not establish a GST exemption or tax rate.

## 8. Required automated controls

- Unique idempotency keys at referral capture, partner acceptance, evidence approval, fee assessment, invoice, receipt and journal.
- One active fee assessment per qualifying contract trigger; amendments create superseding versions, never silent overwrites.
- Duplicate referral detection by normalised contact/organisation, consent and attribution window, with human review for ambiguous matches.
- Partner status, capability, geography and agreement validity checked at routing and again at fee approval.
- No self-referral or related-party manipulation without explicit reviewed exception.
- No automatic fee if partner disputes completion or evidence is missing.
- No invoice until maker-checker approval and tax/legal gates pass.
- No paid status until provider/bank evidence is matched.
- No journal until canonical finance entity, chart mapping, open period and balanced posting checks pass.
- Bounded retries, dead-letter queue, operational alerts and safe manual recovery.
- No delete/update of posted financial events; use reversals and append-only audit.

## 9. Acceptance test matrix

1. Consent missing/withdrawn → referral cannot route or be monetised.
2. Duplicate referral → no duplicate attribution or fee.
3. Unverified partner/capability → cannot route as approved provider.
4. Expired or unsigned agreement → no fee assessment.
5. Partner opportunity/quote only → no completed-service fee.
6. Missing or invalid evidence → assessment remains blocked.
7. Valid evidence but contract trigger not met → no fee.
8. Fee calculation boundary, exclusions, cap/floor and rounding → deterministic result.
9. Agreement amended after event → existing snapshot unchanged.
10. Same event retried/concurrently delivered → one fee assessment only.
11. Creator attempts self-approval → denied.
12. Wrong tenant reads/updates referral or evidence → denied.
13. Partner sees unrelated customer referrals → denied.
14. Invoice attempt before approval/tax gate → denied.
15. Provider webhook duplicate/out-of-order → idempotent and no false receipt.
16. Provider capture without bank settlement → not shown as reconciled cash.
17. Journal unbalanced/closed period/wrong finance entity → rejected.
18. Credit note/refund → linked compensating events, no destructive edits.
19. Partner-direct freight invoice/payment → never creates KRIM cash, receivable or revenue.
20. Failed worker/retry exhaustion → dead-letter and reviewer alert; no duplicate financial event.

## 10. Delivery sequence and release decision

**Stage 0 — prerequisites:** recover exact production migration SQL, reconcile drift, reconstruct isolated staging, establish canonical legal entity and finance organisation, confirm CA/legal treatment.

**Stage 1 — commercial truth:** partner due diligence, signed agreement templates, consent/privacy wording, fee trigger catalogue and evidence standards.

**Stage 2 — application workflow:** referral attribution, partner acceptance, evidence vault, fee assessment, review queue and audit events. No financial posting.

**Stage 3 — billing:** KRIM invoice/receivable integration, provider/bank receipt reconciliation and credit-note handling. Keep freight checkout disabled.

**Stage 4 — accounting:** dedicated KRIM fee journal mapping, balanced/idempotent posting, period close and reconciled reporting.

**Stage 5 — pilot:** one verified partner, one signed agreement, one explicitly consented referral and one fully evidenced fee lifecycle in staging first; production pilot only after independent security, finance and legal sign-off.

**Release decision:** The current live database does not support an end-to-end automated referral revenue lifecycle. No production DDL, referral insertion, fee assessment, invoice issuance, payment activation, journal posting or partner payout was performed. This is a specification based on inspected live structures and known release blockers, not a claim that the engine is already operational.
