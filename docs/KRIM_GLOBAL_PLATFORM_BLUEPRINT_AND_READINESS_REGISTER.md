# KRIM Global Logistics OS — Master Blueprint & Operational Readiness Register

Last reviewed: 5 November 2026  
Repository: rimjhimkrn-web/logistics-saas  
Initial operating focus: India  
Architecture objective: Global-ready, multi-country logistics operating system; market activation is evidence-gated.

This register is the governing checklist for platform completion. A page, table, Edge Function, catalogue record, or successful cron invocation is not by itself proof that a commercial logistics service is operational.

## 1. Platform architecture

KRIM is one connected operating system across six planes:

1. Global core: identity, organizations, membership, RBAC, audit, countries, markets, locations, routes, currencies, languages, time zones, units and regulatory configuration.
2. Logistics execution: customer requests, quotations, partner matching, capacity, bookings, multimodal legs, dispatch, warehouse handovers, customs, tracking, delivery evidence and exceptions.
3. Commercial and financial: tariffs, partner rates, customer pricing, payments, refunds, invoices, double-entry ledger, settlements, reconciliation, tax and multi-currency controls.
4. Intelligence: AI assistance, document intelligence, planning, matching, risk signals, ETA support, analytics and forecasting.
5. Automation and integrations: event workflows, queues, retries, dead letters, scheduled jobs, notifications, CRM, messaging, payment and external logistics integrations.
6. Governance and reliability: security, privacy, compliance, approval controls, monitoring, incident response, testing, backup/recovery and release management.

## 2. Nine user workspaces

| User type | Required operational scope | Current evidence-based position |
|---|---|---|
| Customer / Shipper | Registration, organization/profile, quote, booking, payment, shipment visibility, documents, support and claims | Core pages and request/tracking foundations exist; full customer lifecycle still requires end-to-end validation. |
| Partner / Carrier | Business onboarding, verification, capabilities, capacity, opportunities, quotes, assignments, fleet, dispatch, POD and settlements | Multiple partner category workspaces and verification foundations exist; no eligible verified carrier organization is currently recorded. |
| Driver | Invitation, identity/licence verification, assigned trips, milestones, POD, exceptions and safety | Invitation and document review foundations exist; zero driver profiles/approved drivers in the latest snapshot. |
| Warehouse / Fulfilment | Facility approval, inbound, receipt, putaway, inventory, pick/pack, dispatch, damage and evidence | Connected backend workflows and 12 operational pages exist; zero approved facilities and no positive transaction test. |
| Customs & Trade | Jurisdiction checks, declarations, documents, broker assignment, holds, clearance and audit | Workspace foundations exist; full jurisdiction-specific workflow and real broker validation remain. |
| Finance & Treasury | Payments, invoices, ledger, refunds, payouts, settlements, FX, reconciliation and approvals | Several financial foundations exist; real transaction, refund, payout and cross-border settlement validation remain. |
| Operations Control Tower | Network-wide shipment state, milestones, exceptions, SLA, escalation and route performance | Foundations exist; full live operations and exception ownership need completion. |
| Enterprise | Organization hierarchy, users, contracts, service scope, consolidated shipments, controls and reporting | Requires complete enterprise onboarding and end-to-end operational validation. |
| Platform Administrator | Private governance, market activation, verification, RBAC, finance controls, security, audit and incidents | Global admin control plane and several review modules exist; full governance/security audit remains. |

## 3. Globalization requirements

### Language and localization
- Maintain a language catalogue separately from languages approved for production use.
- Support locale-specific dates, times, number formats, first-day-of-week, directionality and typography.
- Translate every customer, partner, driver, warehouse, customs, finance, enterprise and admin journey—not only navigation.
- Require translation completeness, native-language review, accessibility and regression tests before activation.
- Store user and organization preferences; use deterministic fallbacks.

Database snapshot (4 Nov 2026): 27 language catalogue entries; 2 active languages (English and Hindi); 32 locale entries; 7 active locales; 0 translation rows. Catalogue presence is not proof of translated UI coverage.

### Currency and foreign exchange
- Separate currency display, quote currency, transaction currency, settlement currency and reporting currency.
- Preserve ISO currency codes and correct minor-unit precision.
- Store FX source, rate, effective timestamp, retrieval timestamp and audit provenance.
- Never estimate or fabricate exchange rates.
- FX conversion, cross-border collection, settlement and payout remain disabled unless the required provider, rate source, legal and reconciliation controls are verified.

Database snapshot: 28 currency catalogue entries; 6 active; 0 FX-rate rows. Active currency catalogue status does not mean FX or payment rails are operational.

### Country and local operating configuration
- Country, subdivision, address and telephone formats.
- IANA time zones and local business calendars.
- Metric and US customary measurements.
- Country-specific tax, customs, trade, privacy, consumer-protection and record-retention requirements.
- Market, route, mode, provider, pricing, payment and support activation must be separate gates.

The six existing country/market records are catalogue/configuration data, not evidence of six operational markets.

## 4. Workstream completion register

| # | Workstream | Required acceptance evidence | Current state |
|---|---|---|---|
| 1 | Identity, organizations and access | All nine user types can register/sign in; membership, MFA, RBAC, session and recovery tests pass | Partial; several secure auth and membership gates implemented |
| 2 | Global country/market core | Country-specific readiness workflow, local configuration and controlled activation | Partial; frontend market configuration fails closed for commercial activation |
| 3 | Languages and localization | Complete translated UI, locale formatting, RTL, persistence and QA across workspaces | Catalogue expanded; only English/Hindi active; translation table currently empty |
| 4 | Currencies and FX | Currency precision, trusted rate ingestion, stale-rate controls, multi-currency ledger and reconciliation | Catalogue expanded; no FX-rate rows; no live FX conversion |
| 5 | Customer onboarding and qualification | Real customer registration, profile, business verification where applicable and CRM handoff | Partial |
| 6 | Partner acquisition and onboarding | Real business/individual pathways, documents, eligibility, agreements, verification and audit | Foundations built; no verified commercial carrier organization |
| 7 | Provider capabilities and capacity | Verified service/mode/coverage, capacity resource review and availability tests | Foundations built; latest capability remains pending; no eligible capacity resources |
| 8 | Shipment, quote and booking lifecycle | Idempotent request, valid pricing, partner bids, customer acceptance, booking and state transitions | Backend foundations exist; no complete positive production journey verified |
| 9 | Multimodal route execution | Mode-specific legs, handoffs, route coverage, restrictions and milestones | Partial; real network coverage must be evidenced |
| 10 | Driver operations | Invitation, verification, assignment, trip events, POD and driver safety | Foundations built; zero approved drivers in latest snapshot |
| 11 | Warehouse and fulfilment | Approved facility, ASN/receipt, inventory, putaway, picking, dispatch and evidence | Workflows/pages implemented; zero approved facilities; positive transaction test pending |
| 12 | Customs and trade | Country-specific customs data, documents, broker assignment, holds and clearance | Partial |
| 13 | Tracking and visibility | Authorized tracking, real provider/device events, milestone provenance and customer visibility | Public token-based tracking function active; no claim of live GPS/AIS coverage |
| 14 | Finance and payments | Razorpay production payment verification, refunds, double-entry posting, settlements and reconciliation | Razorpay integration reported by founder; end-to-end real transaction still requires controlled test; no FX rates |
| 15 | Notifications and support | Provider credentials, consent, delivery receipts, retries, templates and escalation | Adapter and retry worker active; external delivery tests remain; workflow external sends are gated |
| 16 | AI assistant | Authenticated, rate-limited assistant, persisted conversations, role-safe context, tool authorization and evaluation | Edge Function v16 active; conversation persistence and 20 requests / 10 minutes per user added; signed-in end-to-end test pending; no AI actions recorded |
| 17 | Workflow automation | Event triggers, idempotency, leases, retries, dead-letter replay, observability and safe approvals | Six shipment lifecycle workflows active; three cron jobs active; latest cron runs succeeded; external notifications remain gated |
| 18 | Growth and CRM automation | Permitted source ingestion, provenance, qualification, CRM sync, consent-based outreach and human review | Growth worker scheduled; source ingestion not configured; outbound outreach and automatic partner activation disabled |
| 19 | Control Tower and Enterprise | Role-safe consolidated operational visibility, contracts, SLAs, reports and escalation | Partial; requires integrated live operational data |
| 20 | Platform governance | Private AAL2 admin controls, market approval, provider review, audit, incident and emergency procedures | Admin control plane and several review tools exist; full governance audit remains |
| 21 | Security, resilience and release | RLS/ACL review, function authorization, secrets, rate limits, dependency review, backups, recovery, load and E2E tests | Incomplete; see current security findings below |

## 5. Automation and AI safety boundaries

- AI assistance may explain, summarize, draft and recommend.
- AI must not invent prices, shipment events, provider status, FX rates, legal conclusions or payment status.
- AI must not approve providers, activate markets, move money, issue refunds or change permissions.
- Any future tool-using AI action requires a typed allowlist, user/role authorization, explicit confirmation for high-impact actions, idempotency and immutable audit evidence.
- External outreach requires source permission, terms review, privacy review, consent and applicable communications rules.
- Scheduled jobs must be monitored for run outcomes, retries, queue age and dead-letter growth.

## 6. Current automation evidence

- Six active shipment lifecycle workflows are registered.
- Three active pg_cron jobs run workflow processing every minute, growth signal processing every five minutes and inquiry follow-up queueing every five minutes.
- The latest inspected cron executions on 4 Nov 2026 were successful.
- Existing lifecycle steps primarily create durable checkpoints, prepare notifications and record exception/risk work. External sends are explicitly disabled until provider readiness.
- Growth operations report source ingestion unconfigured, outbound outreach disabled and automatic partner activation disabled.
- Historical automation log rows must not be mistaken for current successful customer communications.

## 7. Current security and operational caveats

- Latest Supabase Security Advisor snapshot: 53 authenticated SECURITY DEFINER function warnings, 5 RLS-enabled/no-policy informational findings, and a leaked-password protection warning. Each privileged function must be reviewed for its internal authorization checks; warnings must not be dismissed as harmless without review.
- Performance Advisor reported 16 multiple-permissive-policy warnings and unused-index informational findings. Do not bulk-remove indexes or policies without workload analysis.
- The AI rate-limit table is private, RLS-enabled and inaccessible directly to authenticated users; its public RPC checks auth.uid() and is not executable by anon.
- Legacy Cashfree Edge Functions remain deployed and must be assessed for safe retirement because KRIM's intended primary payment integration is Razorpay. Do not remove them until dependencies and live configuration are verified.
- A successful deployment, source-level check or cron return does not replace a signed-in browser test, a positive database workflow test or a controlled payment test.

## 8. Go-live gates

KRIM must not be described as fully operational until all applicable gates are evidenced:

1. A real customer can register, submit a valid shipment request, receive a genuine quote, accept it and complete a payment.
2. A real registered and verified provider with verified capability and approved capacity can accept and execute an eligible assignment.
3. A real verified driver can be invited, verified, assigned, record trip milestones and submit delivery evidence.
4. A real approved warehouse can complete receipt, inventory and handover workflows where applicable.
5. Customs and trade requirements are reviewed for the selected route and cargo.
6. Tracking data has a named source, timestamp, provenance and correct customer access.
7. Finance records reconcile from payment through invoice, ledger, partner settlement and refund handling.
8. Notifications are delivered by connected providers with consent and delivery evidence.
9. Security, privacy, legal eligibility, operational support and incident ownership are approved for the initial market.
10. Full regression, role-isolation, failure/retry, duplicate-event, mobile and recovery tests pass.

## 9. Execution discipline

For each workstream: inspect existing code and schema → identify gaps → implement the smallest safe change → commit source and migration → verify database/ACL/RLS → run negative and positive tests where test fixtures permit → record evidence and remaining blockers.

Do not fabricate test data as real network coverage. Do not activate a market, language, currency, payment rail, provider or route merely to make a dashboard appear complete.


## 10. Newly added blueprint domains — mandatory, not optional

The companion legal framework is now part of the governing blueprint:
- `docs/KRIM_LEGAL_REGULATORY_AND_COMPLIANCE_FRAMEWORK.md`
- It covers India-first legal structure, global country packs, mode-specific transport rules, cargo restrictions, tax, payment/FX, privacy, cybersecurity, labour, insurance, contracts, consumer protection and market activation gates.

The original blueprint was missing explicit workstreams. Add the following as independent platform capabilities and acceptance gates:

| # | Additional workstream | Required capability / acceptance evidence |
|---|---|---|
| 22 | Legal entity and operating-model governance | Per-country classification of KRIM as marketplace, agent, principal, carrier, broker, forwarder, warehouse operator or technology provider; legal counsel approval and entity eligibility. |
| 23 | Licences, permits and regulatory evidence | Issuer-verified licences, territories, scopes, expiry alerts, renewal blocks and immutable approval history for KRIM and every provider. |
| 24 | Country/corridor compliance engine | Origin, transit, destination, customer, partner, payment and data-jurisdiction rules evaluated before quote, booking, payment or dispatch. |
| 25 | Cargo admissibility and dangerous goods | HS code, restricted/prohibited goods, UN number, DG class, permits, end-use, sanctions, temperature, battery and hazardous cargo controls; fail-closed manual release. |
| 26 | Insurance and claims | Policy validation, territory/mode/cargo coverage, exclusions, limits, claims notice, incident evidence, liability and subrogation workflows. |
| 27 | Contracts and electronic execution | Versioned customer, partner, carrier, driver, warehouse, customs and enterprise contracts; signatures, authority, acceptance and audit evidence. |
| 28 | Tax and statutory reporting | Country-specific tax engine, invoice rules, GST/VAT/sales tax, TCS/TDS/withholding, e-invoice, customs duties, filings and reconciliation. |
| 29 | Sanctions, AML/KYC and export controls | Risk-based customer/provider/beneficial-owner screening, vessel/aircraft/party/destination/end-use checks, escalation, false-positive handling and approved human release. |
| 30 | Worker, driver and workplace safety | Employment/contractor classification, qualifications, working conditions, accident reporting, safety training and premises/warehouse controls. |
| 31 | Environmental and sustainability controls | Emissions methodology/provenance, waste, battery, packaging, hazardous storage, environmental permits and substantiation of environmental claims. |
| 32 | Insurance, liability and dispute resolution | Mode/country liability rules, claims limitation clocks, evidence preservation, dispute routing, arbitration/court enforceability and insurer notifications. |
| 33 | Vendor and subprocessor governance | Due diligence, data-processing terms, security assessments, residency/subprocessor map, service continuity, exit and breach obligations. |
| 34 | Accessibility and inclusive product quality | WCAG-aligned accessibility, keyboard/screen-reader support, low-bandwidth/mobile performance, language/RTL and assistive-technology QA. |
| 35 | Data governance and records lifecycle | Data inventory, purpose/legal basis, retention schedules, deletion/legal hold, data-subject requests, cross-border transfers and auditable exports. |
| 36 | AI governance and model risk | Role-aware retrieval, source provenance, evaluation, hallucination controls, prompt-injection defense, human approval, tool allowlists and action audit. |
| 37 | Business continuity and resilience | Tested backups/restore, disaster recovery, RTO/RPO, incident command, vendor outage fallback, queue recovery, business continuity and crisis communications. |
| 38 | Trust, fraud and marketplace integrity | Fake partner/document detection, account takeover controls, payment fraud, review integrity, pricing transparency, ranking neutrality and abuse response. |
| 39 | Product governance and release safety | Feature flags, jurisdiction gates, staged rollout, migration rollback, release approvals, regression suite, dependency/SBOM and vulnerability remediation. |
| 40 | Unit economics and commercial controls | Cost-to-serve, contribution margin, partner payable, refunds/claims, acquisition cost, corridor profitability and price floors; no uneconomic or unapproved booking. |
| 41 | Regulatory change management | Official source monitoring, impact assessment, accountable owner, effective-date alerts, policy/code change, regression and signed closure evidence. |

## 11. India-first legal blocker and launch decision

KRIM is currently described by the founder as a sole proprietorship. Do not treat the original 2020 Rule 4(1)(a) text as a continuing blanket company-form requirement: G.S.R. 328(E), 17 May 2021 substituted Rule 4(1) so that where an e-commerce entity is an Indian company, specified foreign company or qualifying foreign office/branch/agency, it must appoint a resident nodal officer or alternate senior designated functionary. This amendment does not itself automatically disqualify a sole proprietorship. Before commercial marketplace launch, obtain written Indian legal advice on KRIM's actual marketplace/service-provider classification and all applicable current duties. The 2026 amendments effective 1 January 2027 add further marketplace and consumer-facing duties. Separately obtain an opinion on common-carrier/booking/broker registration under the Carriage by Road Act, 2007. These are launch gates, not routine future enhancements. Official 2021 amendment: https://egazette.gov.in/WriteReadData/2021/227003.pdf.

GST treatment must be designed around the actual supply and funds flow; do not assume a flat TCS treatment. Payment aggregation/funds custody, customs-broker activity, foreign exchange and cross-border settlements each require separate legal classification and provider/bank approval.

## 12. Global readiness means controlled activation, not worldwide availability

Every country and route must have an activation dossier covering legal entity, tax, licensing, partners, mode, customs, cargo eligibility, insurance, payment/FX, privacy, security, support, contracts, language and operational evidence. A country, language, currency or transport-mode catalogue entry does not make that market/service active.

## 13. Continuous assurance and no-guarantee principle

No system can promise that there will never be a mistake or that laws will never change. KRIM's durable control is a continuous assurance cycle: official-source monitoring → legal applicability review → implementation → test evidence → independent sign-off → controlled activation → ongoing monitoring → incident/claim learning → periodic re-certification. High-risk changes require legal and operational approval before deployment.

## 14. Implementation status — global market readiness register (4 November 2026)

The first implementation slice of the legal and market-activation control plane is now deployed to the production Supabase project and committed to the repository.

- Added `krim_market_readiness_requirements`: a reusable global and jurisdiction-specific requirement register.
- Added `krim_market_readiness_assessments`: per-market evidence and review status.
- Added `krim_market_readiness_events`: append-only assessment change history, alongside the existing platform audit event.
- Added AAL2 + platform-permission protected RPCs to list and update assessments.
- Added the restricted administrator page at `app/platform-admin/market-readiness.html` and linked it from the private Control Centre.
- Seeded 12 global readiness categories and 10 India-specific legal/operational review tracks. The 6 existing market catalogue records now have 82 pending assessments.
- All 82 assessments remain `pending`. No evidence has been fabricated, no legal review has been represented as complete, and no market status or booking capability was changed.
- The requirement source-review status remains `draft` until official primary sources and qualified local advice have been checked and recorded.
- Direct anon/authenticated table access is revoked; RLS is enabled and forced. The two RPCs reject missing authentication and require AAL2 plus the platform administrator permission.

**Important interpretation:** the six records in `krim_markets` are catalogue entries. Their existing catalogue status is not evidence of an activated commercial market, local licensing, operational partner coverage, or legal approval. The readiness register does not activate a market.

**Verification boundary:** schema, seed counts, RLS flags, direct table grants, RPC execute grants, and unauthenticated rejection were checked. A signed-in AAL2 administrator browser session and a positive evidence-review workflow have not yet been tested. Security Advisor still reports the expected no-policy informational notices for the three tables (direct table access is intentionally revoked) and flags the two authenticated SECURITY DEFINER RPCs for manual review; their bodies enforce authentication, AAL2, and platform permission.

**Next implementation gates:** build source-version review and evidence attachment controls; test the full register as a real AAL2 administrator; then design a separate market activation decision engine that checks legal, tax, payment, service-specific licensing, verified partner capacity, customer protections, safety, and live operational controls. Do not activate India or any other market until its required evidence and counsel decisions are complete.

## 15. Regulatory source versioning and review workflow (4 November 2026)

The next compliance-control slice is implemented:

- Added `krim_market_regulatory_sources` for versioned official laws/regulator guidance, qualified legal/tax opinions, and licence/provider evidence references.
- Added `krim_market_regulatory_source_events` for append-only review decisions.
- Added administrator-only RPCs to list, register and review source versions. They require an authenticated AAL2 session and `admin.platform` permission.
- Official-source registration requires HTTPS. A source cannot be marked `source_checked` without an official URL and a recorded SHA-256 snapshot. A legal/tax opinion cannot be marked `legal_reviewed` without a qualified opinion record and evidence reference.
- Source versions are registered as new records; review status changes are audited and prior source versions are retained.
- Added the private page `app/platform-admin/regulatory-sources.html` and linked it from the private Control Centre.
- Production schema, RLS, grants, function ACLs, JavaScript syntax and unauthenticated denial paths were checked. The source register currently contains zero records; no legal source or opinion has been falsely marked verified.
- A real signed-in AAL2 administrator browser test remains outstanding. Supabase Security Advisor reports the three administrator RPCs among the authenticated SECURITY DEFINER warnings; each includes explicit identity, AAL2 and platform-permission checks, but the warnings remain open for manual code review. RLS-no-policy notices on the source tables are intentional because direct client table access is revoked; data access is through the guarded RPCs.

**Workflow rule:** source verification, professional legal/tax review, market assessment approval and commercial market activation are four separate controls. One must never be inferred from another.

## 16. Fail-closed operational market activation engine (4 November 2026)

The first operational activation control is deployed. It is separate from the existing country and market catalogues.

- Added `krim_market_activation_controls` with operational states `blocked`, `pending_second_approval`, `active` and `suspended`. All six existing market catalogue entries were initialised to `blocked`; their catalogue `is_active/status` fields were not changed.
- Added `krim_market_activation_events` for append-only activation requests, approvals and suspensions.
- Added the live gate evaluator. It checks active market/country status, active locations, mandatory market assessments (approved, evidence reference present, reviewer rationale present, not expired), a reviewed source for every mandatory requirement, qualified legal/tax opinion evidence for regulated categories, and at least one verified, active, in-date partner capability in the market country.
- Activation uses two-person control: one AAL2 platform administrator requests; a different AAL2 platform administrator approves; all gates are recomputed at approval time. Suspension is an audited administrator action.
- The shipment-creation database RPC now checks both origin and destination country against the operational activation control. The gate is recomputed at booking time so expired assessments or lapsed partner capability block new bookings even after prior activation.
- Legacy route-type booking overloads were aligned to the same authoritative gate. Direct authenticated INSERT/UPDATE on `krim_shipments` is not granted, so clients cannot bypass the guarded RPC with direct table writes.
- Added private Control Centre page `app/platform-admin/market-activation.html`.

**Production verification:** six market controls exist and all six are `blocked`; zero countries currently pass the operational gate. India has 22 mandatory assessments; the other five catalogue markets each have 12. All 82 assessments are still pending. There are zero verified active partner capabilities. Each market therefore reports blockers for partner capacity, mandatory assessments and reviewed source/legal-opinion evidence. The shipment creation function contains the operational gate; direct authenticated shipment INSERT is denied; activation RPC calls without an authenticated administrator context are rejected; new activation tables have forced RLS and no direct anon/authenticated table grants; administrator page JavaScript syntax passed.

**Important:** this is an enforcement foundation, not a claim that all booking/dispatch/payment workflows have been fully E2E tested. Existing catalogue flags and the existing India `market_activation` setting are not treated as sufficient authorisation. New bookings remain blocked in all six markets until evidence is completed and the two-person approval is performed. A real signed-in AAL2 administrator workflow and a controlled positive shipment test remain outstanding.

**Additional enforcement hardening:** a database trigger now checks operational activation on every shipment INSERT and on any origin/destination change. This covers internal quote-orchestration paths that insert shipments directly, not only the customer-facing shipment-creation RPC. The check is repeated at the database write boundary, and it dynamically re-evaluates current evidence expiry and partner capability status. Thus the enforcement is not dependent on every application caller remembering to invoke the market gate.


## 17. Global country and corridor legal operations standard (4 November 2026)

Added `docs/KRIM_GLOBAL_COUNTRY_AND_CORRIDOR_LEGAL_OPERATIONS_STANDARD.md` as the governing global design standard for country packs and corridor-level legal operation. It defines 18 mandatory country-pack domains, granular country × service × corridor × cargo × party × funds-flow × data-flow activation, regional research queues that do not replace country approvals, treaty and mode-specific overlays, actual-conduct role classification, evidence hierarchy, human legal sign-off, runtime fail-closed enforcement, and a controlled pilot sequence.

**Important boundary:** this is an architecture and control standard, not a country-by-country legal opinion or evidence of licences. The existing readiness/source/activation system remains an initial foundation; complete country packs, service/corridor enforcement, party and cargo screening, and all transaction-boundary checks remain implementation work. No market is approved for global operation. The system must be globally extensible while each unapproved jurisdiction/service stays blocked.


## 18. Global country operating pack engine (4 November 2026)

The global country pack foundation is now deployed in production and committed:

- Created one country operating pack for each of the 249 country catalogue entries; each pack starts as `research_pending`.
- Seeded 18 review domains per country (4,482 country controls): entity/presence, licensing, transport modes, tax, payments/FX, customs/trade, cargo admissibility, privacy/data, consumer/marketplace, workforce/safety, insurance/liability, contracts/disputes, competition/integrity, cybersecurity/resilience, environment/facilities, language/accessibility, local operations, and regulatory monitoring.
- Controls default to unknown applicability and pending review. No legal facts, licences, opinions, country approvals or service availability were fabricated.
- Added guarded AAL2 platform-admin RPCs to list country summaries, load one country's detailed pack, review controls and approve/suspend a country pack. Approval requires a reviewed jurisdiction-matching source, evidence reference, resolved applicability and reviewer rationale; designated legal/tax domains require a qualified legal/tax opinion marked legal-reviewed.
- Added append-only control and country-pack decision event tables. Country-pack tables have forced RLS and no direct anon/authenticated table grants; data is exposed only through guarded RPCs.
- Updated the operational market activation evaluator to require an approved country pack and all mandatory country controls to remain evidenced, source-backed and unexpired. A country pack approval alone does not activate a market; the separate market activation and partner/service readiness gates remain mandatory.
- Added private administrator workspace `app/platform-admin/country-packs.html`, linked from the Control Centre. The page loads country summaries first and fetches detailed controls only for the selected jurisdiction to reduce mobile bandwidth and rendering cost.

**Production verification:** 249 country packs; 4,482 controls; zero approved controls; zero approved country packs; zero active operational markets. All four country-pack tables have RLS enabled and forced, and direct anon/authenticated SELECT is denied. The administrator page JavaScript syntax passed. A real signed-in AAL2 browser workflow and positive legal-evidence review remain outstanding. Supabase Security Advisor flags guarded SECURITY DEFINER RPCs for manual review and reports RLS-enabled/no-policy notices for these private RPC-only tables; those notices are intentional, but the privileged function bodies still require ongoing code review.

**Interpretation:** KRIM now has a global country-pack structure, not 249 completed legal dossiers. Every pack remains pending until qualified jurisdiction-specific review and evidence are entered. Global readiness is designed in; global legal authorisation is not claimed.


## 19. Corridor compliance implementation record (4 November 2026)

The evidence-led corridor dossier engine and draft candidate catalogue are documented in `docs/KRIM_GLOBAL_CORRIDOR_COMPLIANCE_ENGINE.md`. This adds jurisdiction legs, twelve mandatory controls per jurisdiction, AAL2 platform-admin RPCs, append-only decision events and a private Control Centre workspace. Six draft origin-destination candidates were seeded from existing active locations; they are not route geometry, provider commitments, approved routes or bookable services. A private shipment-write trigger now rejects shipment creation or route/mode changes unless an exact active corridor has an approved dossier, matching mode, current reviewed sources, evidenced mandatory controls and approved current country packs. A negative test confirmed rejection for an existing shipment update without an approved corridor. No dossier or control is approved; positive route testing and signed-in AAL2 workflow testing remain outstanding.


## 20. India-first operational pilot readiness snapshot (4 November 2026)

India remains the initial commercial launch market. This section records the current production blockers and prevents catalogue or test records from being mistaken for live operating capacity.

**Production snapshot**
- India market catalogue record exists and is active as a catalogue entry; that does not mean its operational activation gate is approved.
- India country operating pack: 18 mandatory controls; 0 approved; pack remains `research_pending`.
- India market readiness: 22 mandatory assessment records; 0 approved; all 22 remain pending.
- India partner network: 0 active, verified and compliant partner organisations; 0 active verified India partner capabilities. Existing partner organisations are test/development or pending-verification records, not commercial providers.
- India route catalogue: seven origin-destination candidates are recorded as `draft` (Ranchi–Kolkata, Ranchi–Jamshedpur, Ranchi–Dubai, Ranchi–Frankfurt, Ranchi–London, Ranchi–Singapore and Ranchi–New York). They are not route geometry, provider commitments, approved routes or bookable services; commercial availability and operational authorisation remain false.
- Corridor shipment-write trigger is installed. A shipment requires an exact origin/destination corridor, active corridor status, approved mode-matched corridor dossier, current mandatory corridor controls and approved country packs. Missing evidence fails closed.
- No market/country/corridor approval has been fabricated to accelerate launch.

**Immediate India activation workstreams**
1. Obtain written Indian counsel/CA/CS advice on KRIM's actual platform role and funds flow: marketplace/e-commerce entity, service intermediary, agent/broker, principal logistics provider, common carrier, or combinations. The 2021 amendment to Consumer Protection (E-Commerce) Rules Rule 4(1) replaced the original blanket legal-form wording; it does not automatically exclude sole proprietorships. This does not remove the need for a full applicability and obligations opinion. Official amendment: https://egazette.gov.in/WriteReadData/2021/227003.pdf.
2. Obtain a written Carriage by Road Act assessment before KRIM undertakes goods booking, forwarding, brokerage or carriage activity. The Act's common-carrier definition expressly includes certain goods-booking companies, contractors, agents and brokers; Section 3 requires registration for a person engaging in common-carrier business. Official Act: https://www.indiacode.nic.in/handle/123456789/2043?locale=en.
3. Complete the GST/ECO/TCS and Section 9(5) assessment against the actual supply and collection model. Section 52 TCS depends on the statutory conditions and consideration collected by the operator; it is not a blanket percentage on all platform revenue. Official CBIC Section 52: https://taxinformation.cbic.gov.in/content-page/explore-act/1000325/1000001.
4. Obtain RBI/payment-provider advice on who contracts with the customer, receives funds, holds funds, splits/settles funds and refunds. Razorpay account activation alone does not authorise KRIM to act as a payment aggregator or hold customer funds.
5. Complete GST registration and invoice design, business address evidence, consumer disclosures/grievance officer, insurance/liability allocation, partner agreements, cargo exclusions, privacy/security and incident response.
6. Recruit and verify at least one genuine India road carrier with valid business identity, applicable common-carrier registration/authority, vehicle/driver/insurance documents, capacity and service coverage. A development/test partner is not eligible.
7. Complete the India country pack and India market readiness evidence with current official sources and qualified legal/tax opinions; then review and approve the specific pilot corridor dossier. A country pack approval, market approval and corridor approval are separate gates.
8. Conduct controlled end-to-end tests: customer enquiry/quote, partner response, quote acceptance, shipment creation, dispatch/driver assignment, proof of delivery, cancellation/refund, Razorpay webhook reconciliation, ledger and tax records, complaints and incident escalation.

**Permitted interim posture:** keep customer acquisition, non-binding enquiries and partner recruitment separate from confirmed bookings, transport commitments and customer-fund collection. Do not advertise unverified routes, rates, transit times or partner capacity. Whether even an enquiry-only public pilot requires additional disclosures must be confirmed by Indian counsel based on the live product and marketing.

**Launch decision:** India is not yet cleared for commercial shipment bookings. The blocking facts are evidence-based and measurable: 18/18 country controls pending; 22/22 India readiness assessments pending; zero active verified India partner capabilities; no approved India corridor dossier. Do not bypass these gates.

## India commercial launch gate register — 5 November 2026

The evidence-backed India launch sequence, release gates, stop conditions and current production snapshot are maintained in `docs/KRIM_INDIA_COMMERCIAL_LAUNCH_GATES.md`. The current decision is **not cleared for commercial shipment bookings**: India country controls 0/18 approved, India market readiness assessments 0/22 approved, active verified India partner capabilities 0, and approved India corridor dossiers 0. Ranchi–Jamshedpur and Ranchi–Kolkata remain draft candidates only. Do not equate existing shipment/quote records with fulfilled commercial operations.

The India pilot must pass legal/entity and carriage-registration review, GST/ECO/TCS review, payment/funds-flow approval, real carrier verification, route/cargo approval, insurance/contract controls, end-to-end financial and operational tests, and customer grievance readiness before any commercial activation. This register supersedes no legal advice and does not itself authorize operations.


## 9. Step 1 — Database & Booking Integrity (5 November 2026)

**Technical acceptance status: completed for the database and booking-control scope.** This does not certify a live commercial shipment journey; positive end-to-end testing remains assigned to Step 13 and controlled live acceptance remains assigned to Steps 14–15.

### Applied and verified controls

- Customer-submitted origin/destination data can no longer activate or upsert country catalogue records. Shipment creation resolves both country codes against the existing catalogue and fails closed when a country is absent.
- Expired quote acceptance now returns and persists the `expired` state instead of raising an exception that would roll back the expiry update. The customer quote interface handles that returned state, disables acceptance and directs the customer to request a fresh quote.
- The canonical five-argument customer shipment-creation RPC is executable by `authenticated` only, not `anon`. Its server-side checks enforce active organization access, `shipment.create`, distinct active locations, active country/market gates and valid shipment inputs.
- Readiness gates are server-maintained: direct authenticated INSERT/UPDATE/DELETE privileges were revoked; authenticated users retain SELECT only. Anonymous SELECT privileges were removed from partner quotes and shipment status history.
- Partner quote submission now requires the organization-scoped `quote.create` permission. That permission is granted to the `partner_user` role, and the submission RPC still requires a registered-business organization with active, verified, currently effective capability and valid route coverage.
- Open commercial opportunities and their shipment records are visible to registered-business partners only when the partner has an active verified capability that covers that specific shipment. Development/test partners are excluded from commercial opportunity visibility and bidding.
- Quote acceptance, partner quote award and assignment response use row locks and server-side organization/permission/eligibility checks. Awarding is serialized on the opportunity; assignment response rechecks capability and compliance. Shipment transitions remain behind the internal transition RPC and readiness enforcement.
- RLS is enabled on all seven booking tables reviewed: shipments, customer quotes, partner opportunities, partner quotes, shipment assignments, shipment status history and shipment readiness gates. Organization-scoped policies remain in place.

### Database and source verification

- Six Step 1 migrations are present in GitHub and confirmed in Supabase migration history:
  `prevent_customer_country_catalogue_activation`,
  `persist_quote_expiry_on_accept_attempt`,
  `enable_secured_customer_shipment_booking_rpc`,
  `secure_booking_readiness_and_anon_reads`,
  `enforce_partner_quote_create_permission`,
  `scope_partner_marketplace_reads_to_verified_capability`.
- Verified zero orphan customer quotes, zero orphan partner quotes, zero orphan assignments, zero assignment/quote shipment-partner mismatches, zero duplicate active partner quote groups, zero duplicate active assignment groups and zero duplicate open opportunities per shipment.
- Customer quote JavaScript syntax check passed.
- Current preserved database snapshot: 18 shipments (8 draft, 3 quoted, 6 confirmed, 1 closed), 7 customer quotes, 0 partner quotes and 0 assignments. Eight legacy `shipment_requests` rows remain preserved. Historical shipment records were not rewritten.

### Explicit test boundary

There are currently no verified active partner capabilities, partner quote rows or assignments to support a positive partner-award/assignment transaction. No fabricated partner, rate or booking was created, and no live booking, payment, shipment or partner activation was attempted. This is an intentional safety boundary, not a claim that live operations have been proven. Step 13 must run the full positive/negative end-to-end regression when eligible test fixtures and all nine workspaces are ready.


## 10. Step 2 — Global Foundation (5 November 2026)

**Technical foundation status: implemented.** The global reference layer is expanded across the full 249-country catalogue. This is architecture and reference-data readiness, not approval to offer services in every country.

### Applied reference-data upgrades

- ISO 3166-1 alpha-3 identifiers are populated for all 249 country records; all 249 codes are valid-format and unique.
- Country defaults now include a single current tender currency for 240 countries and a single IANA timezone for 217 countries. Countries with multiple currencies or time zones are not assigned an arbitrary default. Each active service location must continue to carry its own validated IANA timezone.
- Currency catalogue expanded to 154 current territory tender currencies. A three-character ISO 4217 numeric code is present for all 154 records. Only the existing six currencies (AED, EUR, GBP, INR, SGD and USD) remain active; all newly added currency records remain inactive.
- Currency precision on the six active currencies was checked: all currently active currencies use two minor-unit digits. A separate ISO 4217 alignment migration has been committed at `supabase/migrations/20261105173000_align_currency_minor_units_with_iso4217.sql`, but the Supabase migration action blocked its application. Therefore, do not activate any additional currency until that queued correction is applied and verified against the current ISO 4217 List One data.
- Language catalogue expanded to all 184 ISO 639-1 two-letter language codes. English and Hindi remain the only active languages; 10 languages are flagged right-to-left.
- Locale catalogue expanded to 257 records, with at least one country-specific primary locale record for all 249 countries. New locale records remain inactive until native-language translation, accessibility and workspace regression QA are complete.
- All 32 currently active locations have a valid IANA timezone. All six configured market records reference an active currency and a valid market timezone.
- The public Global Markets page now correctly labels operational activation as **gated**, not active, and explicitly separates global-ready architecture from actual service coverage.

### Readiness and fail-closed verification

- Six market catalogue records exist. Their 82 market readiness assessments have zero approvals.
- All 249 country operating packs exist, with 18 controls each (4,482 total); zero controls are approved.
- Seven corridor catalogue records exist; zero are active and zero compliance dossiers are approved.
- The regulatory source registry currently contains zero reviewed source records.
- The market activation gate was evaluated for all six configured markets. All six returned `eligible=false`. Each is blocked by zero verified active partner capabilities, missing/unapproved market assessments and unapproved country-pack controls/reviewed sources.
- No market was activated, no country control was approved, no regulatory conclusion was invented, and no international service coverage was represented as available.

### Reference-data provenance and activation policy

- Country identifiers and ISO 639-1 language codes: pycountry 24.6.1 ISO datasets.
- Country currency assignments, locale display names and formatting patterns: Unicode CLDR data through Babel 2.18.0. These are reference defaults, not legal or payment approval.
- Country timezone mappings and single-timezone defaults: IANA timezone database distributed through pytz 2026.2. Actual location-level timezone values remain authoritative for scheduling.
- ISO 4217 numeric codes for XCG and ZWG were cross-checked against SIX Maintenance Agency amendments 176 and 177. The queued currency-alignment migration must be applied before newly catalogued currencies can be activated.

**Step 2 boundary:** KRIM now has the global country, currency, language and locale reference foundation, with India remaining the initial operating focus. Market, corridor, provider, legal, tax, payment and customer-service activation remain independently evidence-gated. The reference catalogues must never be interpreted as proof of operational coverage.


## 11. Step 3 — Commercial Pricing & Rate Cards (5 November 2026)

**Acceptance status: incomplete.** The commercial pricing governance layer exists, but no production lane is priced or approved.

### Current production snapshot
- One global rate-card row exists: a zero-value, non-commercial India ROAD template in INR, draft, with no service tier. Zero global cards are active.
- Zero partner rate cards, rate lines, partner quotes, pricing calculation runs, quote items, quote pricing components, FX rates, tax rules and accessorial charges.
- Seven customer quote records exist; zero are currently valid sent quotes.
- Direct authenticated INSERT/UPDATE/DELETE access to the global pricing table is denied. Quote paths fail closed unless a matching active, effective, evidence-backed approved rate exists and market activation gates pass.

### Implemented controls
- Draft rate creation validates active country/currency references, supported mode/tier, positive base amount, minimum charge, effective dates and priority.
- Provider evidence must identify an active verified registered-business provider with verified capabilities for the lane and mode. Provider buy rate plus KRIM platform fee must reconcile to the customer rate. Dated cost evidence, tax-review reference, approval evidence, eligible market gates and duplicate active-card checks are required before activation.
- The static sample partner tariff catalogue was retired; the partner compatibility route now directs users to the authenticated, RLS-controlled commercial-rate register.

### Pending domestic-lane correction
Current rate-card creation rejects same-country origin/destination, and approval/activation expect two active markets. This blocks domestic India lanes. The correction is committed at `supabase/migrations/20261105190000_support_domestic_same_country_rate_cards.sql`, but it was not applied because the Supabase migration action was blocked by safety checks. Do not bypass the block or treat domestic rate-card support as live.

### Completion boundary
A real lane still requires a verified registered-business partner, dated carrier buy-rate evidence, an approved KRIM fee/margin, explicit charge basis/minimum, qualified tax review, applicable surcharge evidence and documented approval/effective dates. No commercial values, providers, tax rules, FX rates or coverage have been invented.

**Step 3 is not accepted as complete. Step 4 must not begin until the pending migration is applied and verified and the first genuine commercial lane is evidenced and approved.**


### Step 3 implementation update — 5 November 2026
- Added a private platform-admin Commercial Pricing & Rate Cards console at `app/platform-admin/commercial-pricing.html` and linked it in `app/platform-admin/index.html`.
- The console requires AAL2, uses the existing permission-checked administrator RPCs for list/create/evidence/approve/status, and preserves the no-direct-table-DML control. It supports evidence references, provider buy-rate/platform-fee reconciliation inputs, qualified tax-review reference, commercial approval reference, effective dates, and guarded activation/suspension/expiry.
- JavaScript syntax checks passed; all five RPCs were confirmed executable by the authenticated database role. This does not establish browser E2E: no signed-in AAL2 session was available for an actual UI workflow test.
- Domestic same-country lane creation remains explicitly blocked in the UI until the pending migration is applied and verified.


### Step 3 verification correction — 5 November 2026
The earlier note that a domestic-lane database migration was required was incorrect. Live function definitions were inspected directly: rate-card creation accepts same-country lanes, and both approval and activation already expect one market for domestic routes and two for cross-border routes. The stale, unapplied migration candidate was removed; the admin console's obsolete client-side domestic-route block was removed as well. No production database change was needed for domestic-lane support.

The private admin console is linked in the admin navigation, checks AAL2, and uses the existing server-side permission-checked pricing RPCs. Static script validation and RPC argument/signature inspection passed; signed-in browser E2E has not been claimed.

**Step 3 engineering deliverables are complete:** governed global rate-card lifecycle, private admin workflow, direct table-write lockdown, evidence/approval/activation checks, quote fail-closed behavior, and domestic/cross-border market-count handling. **Commercial publication remains disabled by design** because production currently has zero active verified partner capabilities and zero eligible markets, with no genuine provider cost evidence, KRIM margin decision or qualified tax review. The one existing pricing row is a zero-value non-commercial template; no invented commercial values were added. This gate must remain in force until actual business evidence is available.


## 11. Step 3 — Commercial Pricing & Rate Cards (5 November 2026)

**Governance and quote-integrity implementation: applied. Commercial activation: evidence-gated and not yet accepted.**

- Global rate-card table writes are restricted to permission-checked privileged RPCs. Anonymous and direct authenticated writes are revoked; RLS remains enabled.
- Rate activation requires documented provider cost, KRIM platform fee, currency-precision reconciliation, qualified tax-treatment review, explicit approval, verified registered-business provider capabilities in both route countries, and both markets passing the full activation gate.
- Same-country domestic lanes are supported alongside cross-border lanes. Conflicting concurrent rate-card activations are serialized.
- All quote paths require active, evidence-backed and approved rate cards, market activation, route/service-tier matching and currency-aware rounding.
- Issued tariff quotes persist a price-basis snapshot without exposing provider buy cost or KRIM margin to the customer.
- A private admin rate-governance console is linked from the private Control Centre. The partner rate-card register is organization-scoped and read-only. The legacy fictional rate-card examples have been removed.
- The zero-value INR placeholder remains a draft. Production currently has 0 active/positive rate cards, 0 partner rate cards, 0 partner quotes, 0 verified active partner capabilities, 0 active FX rates and 0 tax rules.
- No rates, carrier offers, margins, tax values or approvals have been fabricated. No quote, payment, shipment or market activation was attempted.

**Commercial acceptance remains pending:** at least one defined India-first lane requires a verified provider, dated carrier buy-rate evidence, approved KRIM fee/margin, qualified tax treatment, active market readiness and a verified persisted customer quote. Tax-exclusive pricing and international FX conversion are not enabled until their reviewed calculation paths and reference data exist.

Detailed evidence: `docs/audits/step-03-commercial-pricing-readiness-2026-11-05.md`.


### Privileged RPC MFA hardening — 5 November 2026
A further security review found that the five pricing RPCs relied on the admin permission check but did not independently enforce AAL2 in their database function bodies. The browser-side MFA check alone was insufficient because authenticated users can call RPC endpoints directly. This has now been corrected:
- Applied production migration `20261105102900_enforce_aal2_on_global_rate_card_admin_rpcs`.
- Added a server-side `auth.jwt()->>'aal' = 'aal2'` guard to the administrator list, create-draft, record-evidence, approve and status RPCs.
- Re-queried all five live function definitions: all five contain the AAL2 guard; authenticated EXECUTE is present; anon EXECUTE is false.
- Committed the exact applied SQL to `supabase/migrations/20261105102900_enforce_aal2_on_global_rate_card_admin_rpcs.sql`; migration history confirms it is applied.
- The pricing table remains RLS-enabled with authenticated direct INSERT/UPDATE/DELETE denied. The pricing console reads and writes only through the guarded administrator RPCs.


## Step 4 — Partner Acquisition & Verification (5 November 2026)
- Implemented a unified global partner-network admission page and retained the existing country-aware application flow and private evidence upload.
- Confirmed existing AAL2-protected administrator workflows for organisation verification and service-capability review; both are linked from Platform Admin navigation.
- Retired three misleading static growth dashboards that showed fabricated partner names, scores, response rates, applications, PIN coverage and activation claims. Legacy URLs redirect to the truthful partner-network page.
- Production snapshot: 1 open verification case, 1 pending capability, 1 open partner opportunity, 2 cancelled opportunities, 0 growth prospect records, and no verified active partner capability.
- No partner was fabricated, approved, contacted or commercially activated. Genuine verification decisions remain subject to evidence review and authorised administrator action.
- Detailed audit: `docs/audits/step-04-partner-acquisition-verification-2026-11-05.md`.
- **Step 4 foundation status:** acquisition and verification workflow foundations implemented; actual partner-network acquisition and verified coverage remain dependent on genuine applicant submissions and human evidence review. Step 5 is not started.


### Step 4 prospect discovery update — 5 November 2026
Created `docs/growth/partner-prospect-register-2026-11-05.md` with six source-backed priority leads (Kiran Group, Deepak Roadlines, CJ Darcl Logistics, Pranik Logistics, Patel Integrated Logistics and Delivery Partners) plus separately labelled lower-confidence local discovery leads. Public company contact channels and official source links are recorded. All leads remain discovered, uncontacted and unverified; no outreach, CRM write, form submission, partner approval or commercial activation was performed. See the Step 4 audit for details.


## 9. Sequential engineering checkpoint — 5 November 2026

### Step 4 — Partner acquisition & verification
- Digital admission, onboarding, organisation verification, capability review, private document access, MFA controls and legacy-route cleanup have been inspected and source-level checked.
- The public onboarding country helper now distinguishes catalogue availability from actual market activation.
- Legacy partner legal/registration pages that contained unsupported company, guarantee, SLA, certification and settlement claims now redirect to the current governed framework or onboarding flow.
- **Boundary:** no real partner outreach, approval, agreement execution or commercial activation is authorised until the user completes the ecosystem review and explicitly starts operations. Source-backed prospect research is parked; it is not an active outreach pipeline.

### Step 5 — Shipment matching & assignment
- Verified capability, route, mode, weight and reservable-capacity matching; authorized quote award; partner assignment response; idempotent capacity reservation; and audit paths have been inspected.
- Customer checkout now requires both partner acceptance and a matching confirmed capacity binding. The Razorpay order Edge Function independently checks the confirmed reservation against the same partner, shipment and leg before creating or reusing an order.
- Legacy static matching pages with fabricated live-engine or shipment claims have been retired to the current authenticated workflows.
- **Current evidence:** 18 shipments; 0 partner quotes; 0 assignments; 0 capacity resources; 0 capacity availability rows; 0 reservations; 0 capacity bindings. No positive commercial E2E was fabricated or run.
- **State:** engineering guardrails implemented and source/deployment checked; positive partner assignment and capacity E2E remains pending genuine partner and capacity evidence. No real operations have started.


- Customer partner-selection now restores an already-awarded quote after refresh and keeps checkout locked if the quote has expired, even when capacity is reserved.
Detailed audit: docs/audits/step-05-shipment-matching-assignment-2026-11-05.md.


### Step 6 — Operational fulfilment (initial audit; in progress)
- Initial production snapshot shows 0 driver profiles/assignments, 0 approved warehouse facilities/tasks/inventory, 0 dispatches, 0 POD records, 0 customs records and 0 operational exceptions. Only 1 tracking event and 2 shipment milestones exist; these do not establish active execution or live telemetry.
- Confirmed authenticated driver and warehouse workspaces, AAL2 admin review, driver assignment/milestone and warehouse task/evidence guardrails, and an opaque-token public tracking endpoint that returns recorded events only.
- Retired six legacy pages containing fabricated GPS, POD/settlement, warehouse KPI, fleet telemetry or exception/SLA claims. Routes now redirect to authenticated or canonical workflows.
- **State:** initial audit and legacy cleanup only. Complete the remaining driver, warehouse, dispatch, customs, exception and POD page/workflow audit before Step 6 can be accepted. No real operations have started.
- Detailed audit: docs/audits/step-06-operational-fulfilment-initial-audit-2026-11-05.md.


### Step 6 — Operational fulfilment (continued; still in progress)
- Implemented the driver POD evidence upload path in the authenticated Driver Workspace. Private file upload is followed by row registration; the database policy requires a matching object owned by the signed-in driver, an active driver membership and the driver's own non-closed assignment. Only SELECT/INSERT are granted; UPDATE/DELETE remain denied. Evidence submission does not itself mark delivery complete.
- Retired legacy static/demo routes across driver, warehouse, customs/trade, operations, visibility and partner POD workflows. They now redirect to authenticated/canonical pages. Unsupported GPS/AIS/air/rail/sensor and prediction claims are not presented as live data.
- **State:** substantial page cleanup and POD evidence foundation completed; warehouse-to-dispatch chain, partner/driver POD lifecycle alignment, customs authorization, exception handling and signed-in browser E2E remain open. Step 6 is not complete and no real operations have started.
- 
- Additional non-functional public operations placeholder routes now redirect to authenticated Operations Control modules. Project-wide RLS/SECURITY DEFINER advisor findings remain assigned to Step 8 rather than being changed outside the security workstream.

- POD lifecycle hardening: driver assignments now link to the exact partner assignment; driver POD submission requires owned private evidence; pending POD tracking no longer appears as delivered; and AAL2 admin review is required before final delivery authorization. A private admin verification page is linked from the control centre. Source and SQL checks passed; no live evidence or operational records were created. Signed-in E2E remains pending.

- Operational milestone RPC now binds driver users to their exact linked driver assignment, requires shipment update/dispatch permission for other partner users, fails closed on ambiguous multi-leg matches and rejects direct `delivered` events pending verified POD authorization. The Driver Milestones UI still needs atomic event/tracking integration and remains an open Step 6 item.

- Operations Control Tower Shipment Control and Dispatch & Handover now include RLS-scoped read-only shipment registers. No dispatch, assignment, milestone, customs, or shipment mutation is exposed from these pages. Customs remains read-only under SELECT-only grants; no authority decision is fabricated. Current operational tables contain zero dispatches, customs records, warehouse facilities/tasks/movements, driver assignments or POD evidence. A stale expired open opportunity is blocked by the quote RPC and documented for cleanup.

- Verified the retained warehouse task/evidence modules and server-side operator/facility authorization; admin facility review requires AAL2. Fixed a driver POD bypass: drivers can no longer mark assignments delivered directly through the trip-event RPC; delivery completion is now reserved for AAL2 POD review plus delivery authorization. Migration `require_verified_pod_before_driver_delivery_completion` is applied and verified (authenticated EXECUTE true; anon false). No operational records were created or changed.

- Added RLS-scoped read-only source registers across the seven Operations Control modules: shipments, dispatch, exceptions, recorded tracking events, route plans, warehouse facilities and customs declarations. All seven updated inline scripts pass syntax checks; no live operational writes or fabricated telemetry are enabled. Signed-in browser E2E and role-by-role visibility tests remain pending.

- Final GitHub Actions production smoke checks and static link audit passed after the global-shell and retired-route audit corrections (commit `d79d3fab500c0c582180742f8808622618efd026`). Pages deployment was still in progress at the time of this note.
Detailed audit: docs/audits/step-06-operational-fulfilment-initial-audit-2026-11-05.md.


### Step 6 — Operational fulfilment (POD security and customs/dispatch checkpoint)
- Driver POD upload form now writes only private file evidence for the signed-in driver's own in-transit assignment. Migration `20261105054211_secure_driver_delivery_evidence_registration` is applied; RLS verifies uploaded object ownership, exact user/assignment path, active driver membership and non-closed assignment. Evidence table UPDATE/DELETE remain denied; failed metadata registration triggers a best-effort private-object cleanup.
- Customs workspace is read-only, organization/permission-scoped and explicitly does not file declarations or guarantee authority clearance. No customs records exist.
- Dispatch and exception pages remain preparation-only; the underlying dispatch/transition functions are service-role-only. Do not expose them directly to browser users. A dedicated authorized server gateway and browser E2E are still required.
- **State:** Step 6 remains in progress. Warehouse end-to-end chain, authorized dispatch/exception workflows, customer-safe POD visibility, customs evidence authorization and signed-in E2E remain open. No live operational records or outreach were created.
- Detailed audit: `docs/audits/step-06-operational-fulfilment-initial-audit-2026-11-05.md`.


### Step 4 — Partner acquisition & verification (digital infrastructure only; acceptance testing pending)
- Verified the backend controls for partner onboarding, non-commercial development/test mode, verified capability requirements, opportunity RLS, quote submission, capacity registration, driver invitations, AAL2 admin verification/capability review, and private evidence storage. Current database snapshot: 1 open verification case, 1 pending capability, 3 opportunities (1 open/2 cancelled), zero partner quotes, assignments, capacity resources, availability rows or driver invitations; the only current partner organization is development/test with verification/compliance pending.
- Retired legacy partner demo pages that displayed fictitious loads, companies, fleet/telemetry, payouts, invoices, settlements or non-functional controls. They now route to the authenticated Partner Workspace; directory/profile legacy routes route to the factual partner-network information page.
- No real outreach, partner application, verification decision, commercial bid, shipment assignment or payment was performed. No fabricated partner/evidence data was inserted.
- **State:** backend guardrails and page consolidation substantially complete; full signed-in browser acceptance tests remain pending. Step 4 is not marked complete until those tests can be run safely with a designated test account and genuine test documents. See docs/audits/step-04-partner-acquisition-verification-2026-11-05.md.


### Step 7 — Payment & financial integrity (in progress; live checkout locked)
- Fresh read-only snapshot: 6 Razorpay INR orders (5 created, 1 paid); 1 matching canonical financial transaction for shipment 15; 10 webhook events (6 processed, 4 unmatched historical events); 0 partner payables. Legacy finance/payout/revenue rows still lack proven lineage to the canonical shipment chain.
- Razorpay webhook v15 validates raw-body HMAC, event ID, deduplication, amount/currency, unknown-order fail-closed and no paid-order downgrade. Global order creation v15 requires accepted quote, accepted partner assignment, confirmed capacity binding and reservation; live checkout remains blocked by unverified merchant eligibility, settlement, refunds and FX.
- Fixed a gap in `verify-razorpay-payment`: the deployed v13 function and GitHub source now revalidate the exact confirmed capacity binding and reservation before verifying an unpaid order. Commit `eb81cb5296b917dda36a274baa4a035626d4edff`.
- Cashfree and legacy payment endpoints are deployed only as HTTP 410 retirement stubs; Razorpay is the only enabled checkout path. No payment, webhook replay, payout, or financial data mutation was performed.
- **State:** not approved for live payments. Four unmatched webhook events, five stale created orders, historical ledger lineage, zero partner payables, live merchant/settlement/refund/FX evidence and controlled provider-signed acceptance tests remain open. See docs/audits/step-07-payment-financial-integrity-2026-10-26.md.

- Follow-up: inspected the four unprocessed webhook rows; they are two historical event pairs whose provider order IDs do not match any current canonical payment order. One includes a legacy shipment-14 note, but that shipment's current payment order has a different provider order ID. Left all four quarantined and unchanged pending provider-side evidence; did not replay, ignore, or delete them. Five September `created` orders also remain unchanged until their provider-side state is confirmed.
- Added read-only RLS-scoped payment-order and partner-payable registers to `app/finance/payment-processing.html` and `app/finance/partner-settlements.html`. No financial write path was added; JavaScript syntax validation passed. Step 7 remains not live-approved.


### Step 8 — Security & Compliance (in progress)
- Security Advisor: 23 RLS-enabled/no-policy tables (INFO); every affected table has zero anon/authenticated grants. 249 public SECURITY DEFINER functions, 79 authenticated-executable, 0 anon-executable; all 79 include `auth.uid()`, all 249 have explicit `search_path`. No blanket revocation is appropriate.
- Fixed the only authenticated `admin.platform` SECURITY DEFINER RPC missing server-side AAL2: `krim_admin_schedule_inquiry_followup`. Migration `enforce_aal2_on_admin_inquiry_followup` applied and verified; zero admin RPC AAL2 gaps remain.
- Retired empty legacy POD storage/table access paths referencing `shipment_requests`/`partners`; canonical private POD evidence remains intact. Five storage buckets are private; no anonymous Storage policies.
- Public Edge Functions reviewed: Razorpay webhook signature/deduplication, public tracking opaque UUID token (no IP throttle yet), public inquiry IP/email limits, Cashfree webhook 410 retirement stub. `config.js` contains only the public publishable key; secrets were not read.
- **Outstanding:** leaked-password protection is disabled and Supabase docs indicate Pro+; project-wide new-user MFA enrollment was not verifiable; public tracking throttling is recommended; per-function SECURITY DEFINER review remains ongoing. See `docs/audits/step-08-security-compliance-2026-11-05.md`.


### Step 6 — Warehouse fulfilment security checkpoint (5 November 2026)
- Applied `20261105120500_harden_warehouse_inventory_movement_chain`: direct authenticated/anon access to the internal inventory movement primitive revoked; receipt/pick only; pick rechecks released quality after row lock; organization-scoped unique idempotency key and payload conflict rejection added. Manual dispatch, transfer, return and adjustment remain disabled pending dedicated governed workflows.
- Inventory ledger rebuilt as read-only. Warehouse performance and attention queue pages now display live database-derived values with explicit record-window/notification limitations. Warehouse dispatch handover is labelled as a warehouse custody checkpoint only, not shipment dispatch or carrier assignment.
- Applied `20261105121500_harden_warehouse_evidence_ownership_and_cleanup`: evidence registration verifies actual storage object owner, path, MIME and size; private bucket retained; own unregistered-object cleanup only. Evidence count remains zero.
- Static JavaScript syntax passed for 15 key warehouse/admin pages. No signed-in browser E2E performed.
- **State:** Step 6 remains in progress. The warehouse operational chain is implemented but cannot be proven end-to-end until a genuinely verified warehouse organization/facility is available in an approved test context. Shipment-level dispatch integration, returns/transfers/adjustments, cycle-count and bin-capacity controls remain open.
- Detailed audit: `docs/audits/step-06-operational-fulfilment-initial-audit-2026-11-05.md`.
