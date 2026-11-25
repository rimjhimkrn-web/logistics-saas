# C3.33 — Global Legal, Licensing, Tax & Commercial Operating Readiness Audit

**Date:** 25 November 2026  
**Immutable source baseline:** `72d75a18f985ceb09e468839435ee95700e11e46`  
**QA branch:** `qa/phase-00-baseline-2026-11-25`  
**Method:** Read-only review of legal/commercial framework documents, public terms/privacy/refund pages, India launch gates, country/corridor controls and historical legal, tax, partner, finance and contract audits. No legal advice, government portal submission, legal opinion, partner/customer contact, contract acceptance, payment, tax filing or database mutation was performed.

## Executive verdict

**FAIL / BLOCKED — NO-GO for commercial freight booking, carriage/brokerage representation, customer freight collection, customs clearance, warehousing execution, or global service activation.**

KRIM has a thoughtful partner-direct commercial model and a jurisdiction-by-jurisdiction control architecture. Its public terms correctly distinguish platform facilitation from partner fulfilment, and the internal framework recognises that legal status follows actual conduct, contracts, funds flow, custody, documents and liability—not labels. But the evidence reviewed does not establish a legally cleared operating role, signed customer/partner contracts, an approved pilot corridor, current verified service capacity, a completed GST/tax setup for the chosen flows, or statutory licences/insurance for the exact activity. The platform's existence, Udyam registration, GST application/certificate, partner profile, country catalogue, or payment gateway does not itself authorise regulated logistics activity.

## Evidence reviewed

- `docs/KRIM_INDIA_COMMERCIAL_LAUNCH_GATES.md`
- `docs/KRIM_LEGAL_REGULATORY_AND_COMPLIANCE_FRAMEWORK.md`
- `docs/KRIM_GLOBAL_COUNTRY_AND_CORRIDOR_LEGAL_OPERATIONS_STANDARD.md`
- `docs/audits/KRIM-CUSTOMER-PARTNER-CONTRACTS-AGREEMENTS-AND-COMMERCIAL-TERMS-INTEGRITY-AUDIT-2026-11-16.md`
- `docs/audits/KRIM-CUSTOMER-PARTNER-COMMERCIAL-JOURNEY-AND-QUOTE-INTEGRITY-REVIEW-2026-11-16.md`
- `docs/audits/KRIM-CUSTOMER-PARTNER-COMMERCIAL-LIFECYCLE-AND-QUOTE-INTEGRITY-REVIEW-2026-11-16.md`
- `docs/audits/KRIM-GLOBAL-TRANSPORT-PARTNER-CONTRACT-INSURANCE-LIABILITY-AND-SLA-ASSURANCE-AUDIT-2026-11-16.md`
- `docs/audits/KRIM-GLOBAL-COMPLIANCE-COUNTRY-ACTIVATION-CUSTOMS-AND-CORRIDOR-CONTROLS-AUDIT-2026-11-16.md`
- `docs/audits/KRIM-PRICING-RATE-GOVERNANCE-TAX-AND-FX-P1-AUDIT-2026-11-16.md`
- `docs/audits/KRIM-CUSTOMER-PARTNER-COMMERCIAL-JOURNEY-AND-NONCUSTODIAL-REVENUE-AUDIT-2026-11-16.md`
- `docs/finance/KRIM-CANONICAL-LEGAL-ENTITY-FINANCE-BINDING-ASSESSMENT-2026-11-16.md`
- Public `terms.html`, `privacy.html`, `refund.html`, `legal-notice.html`, `partner-agreement.html`, and relevant legal/finance/partner/country/corridor workspace source paths.
- C3.20, C3.24, C3.25, C3.27, C3.29 and C3.32 Phase 00 findings.

## Positive controls

1. The legal framework explicitly states that legal role depends on actual activity and that a technology platform, partner licence, GST/Udyam registration or payment-gateway integration does not automatically authorise KRIM to act as carrier, common carrier, freight forwarder, customs broker, payment aggregator, insurer, warehouse operator or marketplace.
2. Public terms describe a partner-direct referral/coordination model: customer contracts with and pays the logistics provider directly; KRIM may separately earn a contractually agreed fee for its own service. They distinguish enquiries/quotes from confirmed bookings and warn that draft documents are not final contracts.
3. The India launch gate requires counsel opinions, CA review, carrier verification, a signed partner agreement, a selected lane, corridor dossier, insurance and operational sign-off before a pilot.
4. Country/corridor standard is granular: jurisdiction × service × mode × cargo × corridor; unknown applicability must not be treated as not applicable and missing controls should fail closed.
5. The public refund/terms pages recognise that partner-delivered services and KRIM platform services may have different contracting and refund responsibilities.
6. Historical pricing and revenue controls suspended KRIM freight revenue recognition pending tax split verification and favour a non-custodial partner-direct model.

## P0 — commercial/legal blockers

### P0.1 — KRIM's actual regulated role is not legally determined

The framework requires a written India legal opinion on marketplace/e-commerce entity, agent/broker, goods-booking intermediary, logistics service provider, common carrier and any combined role. The Carriage by Road Act, 2007 definition and section 3 analysis may be relevant to a person collecting, storing, forwarding or distributing goods for road carriage, including goods booking companies, contractors, agents and brokers. The exact application depends on the actual facts and activity. No signed opinion or activity-specific clearance was established in the reviewed evidence.

**Impact:** KRIM must not accept freight bookings, arrange/undertake carriage, issue transport documents or represent itself as a licensed carrier/broker until counsel confirms the role and any required registration/authority.

### P0.2 — No approved commercial pilot lane or verified operating partner

Historical India launch snapshot (5 November) recorded zero active verified India partner capabilities, zero approved India controls and zero approved corridor dossiers. Ranchi–Kolkata and Ranchi–Jamshedpur were draft candidates only. C3.20 historical partner snapshot recorded zero verified active capabilities, zero approved service areas, zero capacity commitments and zero executed contracts/SLA rows. These are dated snapshots, not refreshed live counts, but the later C3.20 audit did not evidence closure.

**Impact:** no route coverage, capacity, price, transit time or service guarantee can be marketed or booked as available.

### P0.3 — No complete signed customer–partner contracting lifecycle

The 16 November contracts audit found zero service contracts, SLA rows, payment terms, quote acceptances/versions/events, partner quotes, claims/disputes and invoices in the inspected snapshot. The public partner agreement is a negotiation framework, not an executed counterparty contract. A quote or opportunity row does not establish a binding shipment contract.

**Impact:** no evidence-backed allocation of custody, loss/damage liability, cargo exclusions, insurance, claims deadlines, subcontracting, service scope, rates, tax, cancellation, dispute forum or emergency duties.

### P0.4 — Funds-flow and KRIM revenue model must remain non-custodial

C3.25 identified a Razorpay captured-payment webhook path that can bypass the disabled freight-collection control. Historical finance audit found broad finance-table write permissions and no canonical journal/invoice/reconciliation proof; generic revenue and partner-funds mappings were incompatible with partner-direct funds. Razorpay gateway availability is not regulatory authorisation to collect, pool, hold, split or settle third-party freight funds.

**Safe interim boundary:** customer contracts with and pays the verified logistics provider directly. KRIM does not collect or hold freight funds, operate escrow, promise automatic partner payouts or take custody of partner freight money. KRIM may invoice only its own separately agreed and legally/tax-reviewed platform/referral/coordination fee after the service and contract basis are established. Keep freight collection, automatic 10/90 split and partner payout disabled.

## P1 — tax, licensing, insurance and consumer obligations

1. **GST and tax:** confirm current GST registration status and effective date from the actual certificate; obtain CA advice on KRIM's exact supplies, SAC/classification, place/time of supply, invoicing, input credit, returns, TDS/TCS, e-commerce operator classification, section 52 and section 9(5) notified services where applicable. Do not assume every marketplace is subject to every ECO collection rule. A GST number alone does not settle the model.
2. **Sole-proprietorship and legal identity:** align proprietor's legal name, KRIM trade name, business address, PAN, bank account, Udyam and GST records; ensure contracts, invoices, website disclosures, Razorpay merchant profile and accounting entity refer to the same contracting party. Udyam is not a transport licence or company incorporation.
3. **Road transport:** obtain counsel determination of common-carrier/goods-booking/agent/broker applicability and the required registration before the relevant activity. Verify carrier registrations, vehicle permits/fitness/insurance, driver licence, safety and state-specific requirements for the exact route and cargo.
4. **Other modes:** rail, air, ocean, multimodal forwarding, dangerous goods and international freight require separate mode-specific entity/provider authority, carrier contracts, documentation, insurance and jurisdictional review. A road partner's verification does not qualify other modes.
5. **Customs:** no customs brokerage or official clearance representation without jurisdiction-specific broker licence/authority, valid broker assignment and official customs release evidence. C3.24 found zero approved country requirements in the historical India review and a compliance evaluator that could return clear with zero checks. Customs services remain NO-GO.
6. **Warehouse:** do not offer storage/fulfilment until facility legal status, land/building/fire/environmental permissions, insurance, capacity, inventory controls, QC and operating contracts are verified. C3.23 found critical inventory reservation/transfer integrity defects.
7. **Insurance/liability:** verify actual policy schedule, insured entity, covered activity, geography, cargo, limits, exclusions, subcontractors, claims notice and insurer authorisation. A generic certificate or partner assertion is insufficient.
8. **Consumer/e-commerce:** counsel must map current Consumer Protection Act/E-Commerce Rules and amendments to KRIM's actual classification, including entity/contact/grievance details, seller/provider disclosures, pricing/ranking/sponsored placement, cancellation/refund, complaint timelines and dark-pattern controls. The legal framework notes 2026 E-Commerce Amendment Rules scheduled for 1 January 2027; verify the final Gazette/current commencement and applicability before relying on that date or implementing controls.
9. **Contract terms:** finalise versioned customer, partner, enterprise, driver, warehouse and broker terms; authorised signatories; electronic acceptance evidence; order/work-order binding; liability/cargo limits; claims; force majeure; subcontracting; data processing; dispute and governing law; taxes; cancellation/refund and service credits.
10. **Employment/contractor:** obtain advice on driver/worker classification, wages, working time, social security, occupational safety and contractor controls before KRIM directly engages personnel.
11. **Payments/AML:** document merchant of record, payer/payee, payment purpose, settlement path, refund/chargeback owner, KYC, sanctions and AML obligations. Obtain written provider approval for the exact flow; do not infer payment-aggregator permission from gateway credentials.
12. **International markets:** no global launch from a country catalogue. For each country/service/corridor/cargo, obtain local counsel/provider opinion, tax registrations, customs and transport authority, sanctions/export-control checks, data-transfer assessment, insurance and executed contracts. C3.24 and C3.19 recorded research-pending country packs and no activated corridors.
13. **Tax/accounting systems:** C3.25 found inconsistent finance organisation/period binding and generic mappings unsuitable for partner-direct revenue. No live journal posting, partner payable or tax invoice should rely on those unverified mappings.

## Immediate operating boundary

Until written legal/tax advice and evidence-backed approvals exist, KRIM may continue software development, internal demonstrations, non-binding partner discovery and carefully worded expressions of interest. It must not claim confirmed route availability, accept paid freight bookings, take custody of goods, issue carrier/forwarder/customs clearance documents, collect partner freight money, promise insurance/compensation or guarantee delivery. Any pilot should be limited to a named, verified partner and approved route/service/cargo with signed contracts and a controlled operating procedure.

## Required remediation sequence

1. Obtain a written India counsel opinion on KRIM's exact operating role and Road Act/common-carrier/goods-booking implications before commercial carriage arrangement.
2. Obtain CA opinion on GST status, fee model, invoice/SAC, place/time of supply, TCS/section 9(5) applicability, accounting and returns.
3. Reconcile proprietor/trade-name/address/PAN/GST/bank/provider identity and complete the appropriate registrations.
4. Choose one domestic pilot lane only after a real carrier's identity, legal authority, insurance, vehicle/driver controls, service area, capacity and operational contact are independently verified.
5. Execute final partner and customer contracts with route/service work orders, liability, insurance, claims, cancellation/refund, tax, data and dispute schedules.
6. Obtain corridor and country-pack legal approvals from qualified professionals; make activation fail closed and resolve the zero-check customs evaluator defect.
7. Keep partner-direct payment boundary; disable KRIM freight collection and payout pathways until payment/legal/provider and finance controls are remediated and tested.
8. Complete warehouse, customs, multimodal and emergency-response gates separately before marketing those services.
9. Review public legal pages with counsel, correct contracting-entity/grievance disclosures and keep draft/framework labels visible until signed versions are approved.
10. Establish a quarterly and event-driven legal-change review with official source, version/effective date, qualified reviewer, evidence hash, expiry and activation impact for each jurisdiction.

## Gate decision

**C3.33 FAIL / BLOCKED.** The legal/commercial architecture is directionally responsible, but there is no evidence-backed clearance for commercial freight operations or global service activation. This is a technical/documentary readiness audit, not legal or tax advice. Historical counts are not current live measurements; no current government registry, GST certificate, counsel opinion, insurance policy, partner capacity or contract was independently verified in this gate.

**Safety record:** No Production/Staging database changes, legal filings, GST returns, payments, contracts, partner/customer contacts, provider operations, government portal submissions or external communications were performed.
