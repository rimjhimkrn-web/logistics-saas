# KRIM Logistics — India Legal Readiness Research Register

**Research snapshot:** 17 November 2026  
**Status:** Preliminary regulatory research only — not legal or tax clearance  
**Environment:** Development branch `ai/partner-gateway-warehouse-routing`; no production deployment

## Operating model under review

KRIM is considering an initial referral/marketing/coordination model in which independent logistics partners contract with customers and provide the transport/logistics service; customers pay those partners directly; KRIM receives a separately agreed fee for its own permitted services. KRIM would not initially collect freight consideration, hold partner funds, settle freight payments, operate vehicles/warehouses, or act as a customs broker.

This is a proposed structure, not a conclusion that KRIM is outside GST, e-commerce, consumer-protection, transport, agency, or payment regulation. Actual website functionality, contracts, customer journey, control over supply, invoicing, and funds flow must be reviewed together.

## Official primary sources identified

| Topic | Primary source | What it establishes / why it matters | Current review status |
|---|---|---|---|
| GST — electronic commerce operator definition and registration | [CBIC GST Sectoral FAQs](https://cbic-gst.gov.in/hindi/sectoral-faq.html) | CBIC describes an ECO by reference to owning, operating or managing a digital/electronic facility or platform for e-commerce, and discusses section 24 registration. This is a risk flag; a CA must apply current law and notifications to KRIM's exact model. | Identified; current-law opinion pending |
| GST — TCS | [CBIC, CGST Act section 52](https://taxinformation.cbic.gov.in/content-page/explore-act/1000325/1000001) | Section 52 links TCS to taxable supplies by other suppliers where consideration is collected by the operator. Not collecting customer freight consideration is relevant to TCS analysis, but does not by itself decide ECO status or KRIM's own GST registration. | Identified; CA opinion pending |
| Consumer e-commerce rules | [Consumer Protection (E-Commerce) Rules, 2020 — official notification](https://consumeraffairs.gov.in/public/upload/files/E%20commerce%20rules_1732703966.pdf) | Rules apply broadly to goods/services bought or sold over digital/electronic networks and to marketplace/inventory models. Counsel must determine whether KRIM's precise lead/referral/coordination activity falls within the definition and scope. | Identified; legal opinion pending |
| E-commerce Rule 4(1) amendment | [Consumer Protection (E-Commerce) (Amendment) Rules, 2021 — official notification](https://consumeraffairs.nic.in/sites/default/files/Consumer%20Protection%20%28E-Commerce%29%20%28Amendment%29%20Rules%2C%202021.pdf) | The 2021 amendment substitutes Rule 4(1) with a conditional nodal-officer requirement where the e-commerce entity is a company/foreign company/qualifying office, branch or agency. It should not be misread as a blanket statement that every e-commerce entity must be incorporated as a company. Counsel must confirm the complete current rule and KRIM's status. | Identified; legal opinion pending |
| E-commerce amendments effective 2027 | [Consumer Protection (E-Commerce) (Amendment) Rules, 2026 — official Department of Consumer Affairs Gazette PDF](https://consumeraffairs.gov.in/public/upload/files/E%20Commerce%20Amendment%20Rules%202026_1789128659.pdf) | Notified 9 September 2026; effective 1 January 2027. Adds/changes requirements concerning legal/contact disclosures, grievance handling, National Consumer Helpline participation, search-result manipulation, sponsored-listing disclosures, price reductions, seller identification and dark-pattern self-audits, among other matters. KRIM must design for the effective date if covered. | Identified; implementation assessment pending |
| DPDP Act commencement | [MeitY / Gazette notification G.S.R. 843(E), 13 November 2025](https://egazette.gov.in/WriteReadData/2025/267647.pdf) | Commencement is phased: some provisions commenced on publication; a subset commences after one year; the main data-fiduciary obligations in sections 3–17 and related provisions commence after eighteen months. The exact provision-by-provision timeline must be followed. | Identified; privacy counsel review pending |
| DPDP Rules 2025 | [MeitY / Gazette notification G.S.R. 846(E)](https://www.meity.gov.in/static/uploads/2025/11/53450e6e5dc0bfa85ebd78686cadad39.pdf) | Rules have staged commencement: Rules 1, 2 and 17–21 on publication; Rule 4 after one year; Rules 3, 5–16, 22 and 23 after eighteen months. Build privacy-by-design now; verify the operative provisions on each launch date. | Identified; privacy counsel review pending |

## Important legal interpretation guardrails

1. **Do not use the ₹20 lakh threshold as the only GST test.** Compulsory registration provisions, ECO status, the nature of KRIM's own service, agency characterization, applicable notifications and the actual money flow need a written CA opinion.
2. **Do not assume that direct partner payment automatically removes KRIM from e-commerce regulation.** The definition and scope depend on what KRIM's digital platform actually does and the contracts/representations it makes.
3. **Do not say a proprietorship is automatically barred by E-Commerce Rule 4(1).** The 2021 amendment is conditional wording about nodal-officer appointment for specified entity forms. Counsel must review the full current rules, amendments and facts.
4. **Do not enable freight collection, escrow, split settlement, partner payouts or cross-border collections** until payments counsel/CA confirms the applicable RBI, GST, FEMA and contractual treatment.
5. **Do not describe KRIM as a carrier, freight forwarder, customs broker, insurer or warehouse operator** unless the business actually performs that regulated role and meets the applicable requirements.
6. **Do not treat a source URL as legal approval.** A primary source can be recorded as identified; a qualified professional must separately review and issue a written opinion before a legal gate is marked cleared.

## Decisions required before a controlled commercial pilot

- Written CA note on GST registration, ECO/agent status, section 24, section 52 TCS, section 9(5) applicability, KRIM's own referral/coordination fee, invoice format, and any TDS/TAN/accounting obligations.
- Written Indian legal opinion on Consumer Protection (E-Commerce) Rules applicability, business-form eligibility, customer disclosures, grievance officer requirements, contracts, liability allocation and the 2026 amendments effective 1 January 2027.
- Written transport-law opinion on whether KRIM's lead generation, booking, negotiation, dispatch coordination or control over carriage creates any common-carrier, goods-booking, agent/broker or other licensing obligation under applicable central/state law.
- Written payment-flow review confirming the exact permitted role of KRIM and any payment provider. Initial design remains direct customer-to-partner payment.
- Confirmed proprietorship identity, Udyam certificate particulars, address evidence/NOC if required, business bank details and current GST application status.
- Jharkhand/Ranchi review of applicable Shops & Establishments, municipal/trade and other local requirements for the actual premises and activity.
- Privacy/data mapping, notices, consent, retention, security, grievance and breach-response controls aligned to the DPDP commencement timetable and any continuing applicable IT/CERT-In requirements.

## Evidence discipline

- No source has been marked `source_checked` or `legal_reviewed` in the KRIM Staging regulatory-source register by this research note.
- No SHA-256 source snapshot has been generated and independently checked for the regulatory-source register.
- No professional legal/tax opinion has been obtained through this note.
- India remains inactive in the KRIM Staging country catalogue until all required evidence and approvals are independently recorded.

## Next operational sequence

1. Verify existing Udyam certificate details and GST application status with the proprietor (do not transmit identity documents, passwords or OTPs in chat).
2. Prepare the CA/lawyer briefing pack using the proposed model and exact website workflow.
3. Obtain written opinions and map each conclusion to the relevant requirement code in the Staging regulatory-source register.
4. Only then decide which registrations are mandatory and which commercial features may be enabled.


## GST law update verified during follow-up research — 17 November 2026

**Important correction/clarification to the preliminary GST discussion above:** the current text of CGST Act section 24(x), following the 2018 amendment, is “every electronic commerce operator who is required to collect tax at source under section 52” — not simply every person who operates any digital platform. The amendment is reproduced in the official India Code copy of the Central Goods and Services Tax (Amendment) Act, 2018: https://www.indiacode.nic.in/bitstream/123456789/11230/1/the_central_goods_and_services_tax_%28amendment%29_act%2C_2018.pdf

Section 52(1) generally requires an ECO (other than an agent) to collect TCS on specified taxable supplies made through it by other suppliers **where consideration for those supplies is to be collected by the ECO**. This makes the actual collection/payment flow material to the section 52 analysis. Official CBIC section 52 text: https://taxinformation.cbic.gov.in/content-page/explore-act/1000325/1000001

However, this does **not** establish that KRIM can automatically operate without GST:
- Section 24(vii) separately addresses persons making taxable supplies on behalf of other taxable persons, as an agent or otherwise.
- Whether KRIM is an ECO, an agent, a supplier of its own taxable referral/coordination service, or a combination depends on the real functionality, contractual authority, representations, pricing, control over the transaction and actual conduct.
- If KRIM is not required to collect TCS under section 52 and does not fall into another compulsory-registration category, the specific section 24(x) ECO registration trigger may not apply. This is a legal/tax conclusion for a CA to confirm against current notifications and the complete facts.
- The CBIC Sectoral FAQ currently surfaced in search still contains an older broad statement that every ECO must register. Do not rely on that FAQ sentence in isolation where the amended statutory wording is different. The Act and applicable amendments/notifications control.

**Practical design implication (provisional, subject to written CA/legal approval):** keep freight consideration entirely outside KRIM's possession and payment systems; do not authorise KRIM to collect or release partner funds; do not issue partner freight invoices; do not negotiate or conclude carriage contracts as the partner's agent; and do not represent KRIM as the carrier/service supplier. A separately contracted KRIM marketing/referral service still needs its own GST threshold/compulsory-registration and invoicing analysis.

This update is a statutory research correction, not a legal opinion or a launch approval.
