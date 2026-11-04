# KRIM Global Logistics OS — Master Blueprint & Operational Readiness Register

Last reviewed: 4 November 2026  
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
