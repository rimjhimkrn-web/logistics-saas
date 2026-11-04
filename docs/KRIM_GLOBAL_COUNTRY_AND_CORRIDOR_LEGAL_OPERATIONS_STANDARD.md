# KRIM Global Country & Corridor Legal Operations Standard

Version: 1.0  
Review date: 4 November 2026  
Status: Architecture and control standard — not a legal opinion, licence, or activation approval.

## 1. Governing rule

KRIM is designed as a global logistics operating system, but legal operation is authorised country by country, service by service, corridor by corridor, cargo by cargo, and role by role. A country appearing in a catalogue, a translated interface, an available currency, or a technically functioning API does not authorise commercial activity there.

The platform must support a global customer journey while refusing to quote, book, collect, dispatch, store, clear, settle, or market a service in a jurisdiction until the applicable controls are evidenced and approved. A country can be enabled for one service and remain disabled for every other service.

No universal licence or single global legal checklist exists. Local counsel and appropriately licensed providers must confirm applicability in each jurisdiction.

## 2. Country pack — mandatory data model

Every country pack must have a stable ISO 3166-1 alpha-2 jurisdiction key and versioned records for:

1. **Entity and presence:** foreign ownership, entity form, local incorporation/branch/representative requirements, beneficial ownership, local director/agent, permanent establishment and marketplace eligibility.
2. **Business and sector licensing:** freight forwarder, broker, carrier, transport operator, warehouse, customs representative, postal/parcel, maritime, aviation and other regulated activity boundaries.
3. **Transport modes:** road, rail, ocean, air, inland waterway and multimodal; operator licences, permits, safety rules, vehicle/vessel/aircraft requirements and subcontracting limits.
4. **Tax and invoicing:** indirect/direct tax, marketplace or deemed-supplier rules, withholding, e-invoice, invoice language/content, fiscal representation, registrations, filing frequency and record retention.
5. **Payments and FX:** local acquiring, payment institution/aggregator rules, custody/escrow restrictions, settlement, payout, currency conversion, capital controls, remittance and bank/provider approvals.
6. **Customs and trade:** importer/exporter registration, customs representation, declarations, tariff classification, origin, valuation, duties, sanctions, export controls, dual-use goods and product permits.
7. **Cargo admissibility:** prohibited/restricted goods, dangerous goods, batteries, temperature-controlled cargo, food, pharma, animals/plants, waste, high-value goods and end-use/end-user restrictions.
8. **Privacy and data:** controller/processor roles, lawful basis, notices, consent where required, data-subject rights, breach deadlines, data residency, international transfers, subprocessors and retention.
9. **Consumer and marketplace:** platform classification, mandatory disclosures, pricing/ranking/sponsored placement, cancellation/refunds, grievance handling, accessibility and unfair-practice rules.
10. **Employment and safety:** employee/contractor classification, driver qualifications, working time, minimum pay, social security, occupational safety, warehouse standards and accident reporting.
11. **Insurance and liability:** compulsory insurance, cargo/warehouse/operator cover, limits, exclusions, claims time bars, liability conventions and local insurer requirements.
12. **Contracts and dispute resolution:** enforceability, mandatory terms, electronic signatures, governing law, jurisdiction/arbitration, language, limitation periods and consumer rights.
13. **Competition and integrity:** antitrust, price coordination, platform neutrality, agent/principal disclosure, conflicts, anti-bribery, AML/KYC and recordkeeping.
14. **Cybersecurity and resilience:** local cyber rules, incident notification, critical infrastructure obligations, outsourcing controls, audit access and continuity.
15. **Environment and facilities:** emissions, waste, packaging, hazardous storage, environmental permits, land-use, fire/building and facility standards.
16. **Language and accessibility:** legally required languages, consumer-facing translations, local scripts, RTL, accessible service and record language.
17. **Local operations:** verified providers, facilities, customer support hours, emergency contacts, claims handling, service SLAs, route evidence and capacity.
18. **Regulatory change:** official authority, source URL, instrument/version, publication/effective dates, retrieved date, SHA-256 evidence, responsible reviewer, next review date and change-impact record.

Each control must store applicability (yes/no/conditional/unknown), rationale, legal source, local professional opinion where required, evidence reference, reviewer, approval date, expiry/review date, affected services, and fail-closed action. Unknown is not equivalent to not applicable.

## 3. Global service activation dimensions

Activation must be granular, not a single country switch:

- Country × service: marketplace, road carrier, rail, ocean, air, freight forwarding, customs representation, warehousing, fulfilment, payment collection, payout, insurance distribution and other service roles.
- Corridor × mode: origin, every transit jurisdiction, destination, border crossing, transshipment point and port/airport.
- Cargo × route: commodity/HS classification, dangerous-goods class/UN number, sanctions, end-user/end-use and permits.
- Party × transaction: customer, beneficial owner, shipper, consignee, payer, payee, carrier, broker, vessel/aircraft and subcontractors.
- Funds flow × currency: payer location, merchant of record, collecting provider, settlement account, beneficiary, conversion provider and destination.
- Data flow × purpose: data subject, controller/processor, hosting region, subprocessors, transfer mechanism and retention.

A route is eligible only when every applicable jurisdiction and every participating service has passed. Transit-country controls cannot be skipped. A route must be blocked if a required transit location or party is unknown.

## 4. Regional legal research queues

These are research groupings, not assertions that one law applies uniformly across a region.

| Research grouping | Minimum jurisdictional questions |
|---|---|
| European Union / EEA | EU-level consumer, privacy, platform, competition, customs, product and transport rules; member-state licensing, tax, employment, language and enforcement differences; EEA-specific status and transfer rules. |
| United Kingdom | UK entity and sector permissions, customs border model, VAT, consumer/platform rules, UK GDPR/data transfers, employment, road/air/maritime and insurance requirements. |
| United States | Federal and state-by-state licensing, broker/carrier classification, FMCSA/DOT, customs, sales tax, privacy, consumer, employment, insurance and payment rules. |
| Canada | Federal/provincial transport, customs, tax, privacy, consumer, employment, language and insurance requirements. |
| GCC / Middle East | Country-specific foreign ownership, commercial agency, transport/forwarding, customs, VAT, data residency, payment, labour, free-zone and local representative requirements. |
| ASEAN | Separate country packs for each member; customs/transit, local ownership, cabotage, transport permits, VAT/GST, data localisation/transfer, payment and language requirements. |
| Greater China | Mainland, Hong Kong and Macao must be separate jurisdictions; foreign investment, cybersecurity/data export, customs, platform, payment, licensing, sanctions and local partner controls. |
| Africa | Separate sovereign-country packs; regional trade arrangements do not replace national permits, customs, tax, foreign exchange, data, employment and insurance approvals. |
| Latin America and Caribbean | Country-specific customs, tax/e-invoice, consumer, data, payment/FX, transport permits, labour, language and local establishment requirements. |
| Australia and New Zealand | Separate country packs; transport, customs, consumer, privacy, workplace safety, biosecurity, tax and insurance requirements. |
| Japan and South Korea | Separate packs covering transport/forwarding licensing, customs, platform/consumer, privacy, payments, labour, language and local contracting. |

No regional research grouping may be used as a substitute for country-level approval.

## 5. International transport and trade overlays

Country packs must link to the applicable treaty, convention, code and national implementation—not merely record that a convention exists. At minimum, research applicability for:

- International road carriage: CMR where applicable, TIR where used, ADR and national road-carrier rules.
- Rail: CIM/COTIF and applicable regional/national rail and dangerous-goods rules.
- Ocean: SOLAS, MARPOL, IMDG, relevant liability/carriage conventions, port and flag-state requirements.
- Air: ICAO technical instructions, IATA DGR contractual requirements, air-carrier and security rules.
- Customs: WCO instruments, HS, valuation/origin rules, national customs systems and authorised representative requirements.
- Trade restrictions: UN, national and regional sanctions; export-control lists; dual-use and end-use restrictions.

Treaty membership, local implementation, scope, exclusions and contracting party must be confirmed by counsel or qualified trade compliance professionals. The platform must not infer legal coverage from a generic treaty label.

## 6. KRIM role classification — mandatory before activation

For every country and service, legal reviewers must classify KRIM's actual conduct as one or more of: software provider, marketplace operator, disclosed agent, undisclosed agent, broker, freight forwarder, contractual carrier, actual carrier, warehouse operator, customs representative, payment intermediary, insurer intermediary or other locally defined role.

The classification must follow real contract terms, customer representations, who sets price, who accepts cargo, who assumes liability, who issues invoices, who controls funds, who selects providers, and who performs regulated activity. Product labels or disclaimers do not override conduct.

If the role is uncertain, block the affected service pending written qualified advice. If the current legal entity is not eligible for the role, require an approved restructuring/local entity/provider model before activation.

## 7. Evidence quality and approval policy

Evidence hierarchy:
1. Current official legislation, regulator instruments, government guidance and official registers.
2. Qualified local legal, tax, customs, insurance or regulatory opinion scoped to KRIM's exact model.
3. Direct issuer/provider verification of licences, permits, insurance and operational capacity.
4. Independent audit or assurance evidence where required.
5. Internal policy and management attestations only for controls that can legitimately be self-attested.

A URL alone is not evidence of applicability. Store a dated source snapshot/hash, scope, reviewer, version and effective date. Legal opinions must identify jurisdiction, services, assumptions, entity, funds flow and date. A licence must be checked with its issuer where a register or verification process exists.

No AI output, translation, web search snippet or unsigned internal checklist may approve a legal gate. AI may identify research tasks and summarize source material, but a qualified human must determine legal applicability and sign off.

## 8. Runtime enforcement

Before quote, booking, payment, dispatch, warehouse receipt, customs submission, payout or external marketing, the system must evaluate the relevant control set. It must:
- resolve all jurisdictions and parties involved;
- check the correct service and transport mode;
- check evidence status, reviewer authority, effective dates and expiry;
- check provider and facility eligibility;
- check cargo and sanctions controls;
- check funds and data flows;
- record the decision, rule versions, evidence IDs and timestamp;
- return a human-readable block reason and escalation owner.

Default state is blocked. A timeout, missing record, stale source, unresolved alert, unknown jurisdiction, failed screening, expired insurance or provider suspension is a deny. No fallback to permissive mode is allowed.

## 9. Market launch sequence

1. Choose one legal entity and one precise KRIM operating role.
2. Choose one jurisdiction, one service and one narrow corridor.
3. Commission local legal/tax/customs/payment/insurance advice as applicable.
4. Verify provider, licence, insurance, capacity and contract evidence.
5. Implement local tax, payments, privacy, consumer and support configuration.
6. Complete security, accessibility, language, incident and operational tests.
7. Run a restricted pilot with explicit volume/value limits and human control.
8. Independently review evidence and activate with dual approval.
9. Monitor legal sources, expiries, complaints, incidents and service quality.
10. Suspend automatically or manually when a critical condition lapses.

## 10. Current KRIM implementation boundary

The existing market readiness register, versioned regulatory source register and fail-closed market activation control are the initial governance foundation. They do not yet implement every data dimension, every jurisdictional rule, every service-level activation or every corridor-level check described here.

As of 4 November 2026, the recorded readiness assessments remain pending, no market is approved for operational launch, and no global legal coverage is claimed. The next engineering phases must implement country packs, service/corridor-level decisions, party and cargo screening, licence/insurance expiry enforcement, and auditable runtime checks at every relevant transaction boundary.

**No global go-live claim:** KRIM may be architected for global expansion while remaining commercially disabled in jurisdictions and services that have not passed their own evidence-based legal and operational gates.
