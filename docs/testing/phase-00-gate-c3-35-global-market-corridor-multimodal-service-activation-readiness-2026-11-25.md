# C3.35 — Global Market, Corridor & Multimodal Service Activation Readiness Audit

**Date:** 25 November 2026  
**Immutable source baseline:** `72d75a18f985ceb09e468839435ee95700e11e46`  
**QA branch:** `qa/phase-00-baseline-2026-11-25`  
**Method:** Read-only source and historical production-evidence review of market activation architecture, country operating packs, regulatory-source governance, corridor compliance, partner geographic coverage, route planning, multimodal orchestration, shipment creation and execution. No live RPCs, bookings, route-plan activation, dispatch, corridor approvals, provider calls or data mutations were performed.

## Executive verdict

**FAIL / BLOCKED — NO-GO for operational market activation, customer booking, commercial route recommendations, multimodal execution or cross-border service claims.**

KRIM has a well-developed global-ready architecture: ISO country catalogue, market registers, country operating packs, regulatory source governance, corridor dossiers, mode-specific partner capabilities, route/leg planning, capacity reservation and custody hand-off concepts. The system correctly distinguishes catalogue presence from operational availability and has several fail-closed shipment-write controls.

However, the historical evidence shows no approved country pack, operationally active market, approved corridor dossier, verified active partner capability, approved service area, capacity commitment or operational route plan. There are also material source-level control gaps: route-plan activation appears to lack the full server-side market/corridor gate; canonical shipment creation omits the transport mode required by the corridor trigger; and the legacy partner-opportunity path does not consistently enforce the authoritative activation gate. These prevent a safe claim that the entire booking-to-execution chain is protected.

## 1. Evidence reviewed

- `docs/KRIM_GLOBAL_CORRIDOR_COMPLIANCE_ENGINE.md`
- `docs/architecture/global-market-activation.md`
- `docs/audits/KRIM-GLOBAL-MARKET-COUNTRY-OPERATING-PACK-AND-CORRIDOR-ACTIVATION-READINESS-AUDIT-2026-11-16.md`
- `docs/audits/KRIM-GLOBAL-MARKET-COUNTRY-PACK-AND-CORRIDOR-ACTIVATION-READINESS-AUDIT-2026-11-16.md`
- `docs/audits/KRIM-GLOBAL-ROUTE-PLANNING-MULTIMODAL-ORCHESTRATION-AND-CORRIDOR-EXECUTION-AUDIT-2026-11-16.md`
- `docs/audits/KRIM-GLOBAL-CORRIDOR-ELIGIBILITY-RULE-MATRIX-AND-INTEGRATION-BLUEPRINT-2026-11-16.md`
- `docs/audits/KRIM-CANONICAL-SHIPMENT-CREATION-AND-LIVE-CORRIDOR-GATE-P0-AUDIT-2026-11-16.md`
- `docs/audits/KRIM-GLOBAL-TRADE-DOCUMENTATION-REGULATORY-SOURCE-AND-COUNTRY-PACK-READINESS-AUDIT-2026-11-16.md`
- `docs/audits/KRIM-GLOBAL-SHIPMENT-EXECUTION-ROUTE-CAPACITY-WAREHOUSE-AND-DELIVERY-JOURNEY-AUDIT-2026-11-16.md`
- `docs/audits/KRIM-PARTNER-GEOGRAPHIC-COVERAGE-SERVICE-AREA-APPROVAL-AND-RECOVERY-AUDIT-2026-11-16.md`
- Relevant market/corridor/capability/route migrations and C3.19, C3.20, C3.23, C3.24, C3.29, C3.31 and C3.33 findings.

## 2. Global market and country-pack status

The 16 November read-only production snapshot recorded:
- 6 market catalogue entries: India, UAE, Germany, United Kingdom, Singapore and United States; all catalogue rows marked active, but all 6 operational activation controls were `blocked`.
- 249 country operating packs, all `research_pending`.
- 4,482 mandatory country-pack controls, all pending.
- 22 market readiness requirements and 82 assessments; no approved requirements/assessment evidence sufficient for activation.
- 0 regulatory source records/source versions.
- 7 corridor catalogue records, all `draft`.

The architecture explicitly says catalogue and localization data do not establish permission, partner coverage, rates, bookability or fulfilment capability. A market must pass regulatory assessment, partner verification, commercial readiness, operational testing and independent activation. The market gate must be rechecked at booking and dispatch.

**Decision:** India remains the first activation candidate, not an activated logistics service market. UAE and other countries remain catalogue entries only. Do not claim India-wide or global service coverage.

## 3. Corridor compliance architecture and status

Positive design:
- Corridor candidates are expanded into origin, transit and destination jurisdiction legs.
- Twelve mandatory review domains are specified, including entity eligibility, permits, customs/trade, cargo admissibility, sanctions/export controls, tax/payments/FX, insurance/liability, privacy/data transfers, workforce/safety, environment, border/transit and local operations.
- Control decisions require jurisdiction-matched sources, evidence references, rationale, applicability, review status and expiry.
- Final dossier approval is intended to require mandatory corridor controls and country-pack controls for every jurisdiction.
- The shipment-write trigger rejects a shipment write unless an exact active origin/destination corridor, approved dossier, matching mode and current mandatory controls/country packs exist.

Historical state: seven candidate pairs—Ranchi–Kolkata, Ranchi–Jamshedpur, Ranchi–Dubai, Ranchi–Frankfurt, Ranchi–London, Ranchi–Singapore and Ranchi–New York—all draft; zero dossiers, corridor legs, controls or approval events. Candidate names do not establish route geometry, transit states, mode, serviceability or provider availability.

### P1 source-governance gaps
The reviewed trade-documentation audit found that final corridor dossier approval did not fully revalidate source records for continued existence, non-retired/non-rejected status, approved review state, jurisdiction match and both effective dates. Corridor source-reviewer independence and final approver separation were also weaker/inconsistent compared with country-pack approval. These must be reconciled before any corridor approval is relied upon.

## 4. Partner service-area, capability and capacity gates

Historical partner coverage evidence:
- 0 service-area records (approved, active or pending).
- 1 capability record, pending/inactive.
- 0 active verified capabilities.
- 0 capacity resources, reservations or leg bindings.
- 0 executed partner contracts/SLA rows (see C3.20/C3.33).

Positive design: partner service-area submission uses private evidence, active partner membership, registered-business mode, compliance, geography, mode, effective dates and evidence ownership; independent AAL2 admin review checks approved country pack and matching verified capability.

Critical interpretation:
- Country/city coverage is not corridor authorization.
- An approved capability is not capacity for a specific shipment/date.
- A capacity record is not an accepted shipment assignment.
- Partner coverage must be exact for origin, destination, service, mode, cargo, equipment and dates.
- Current legal authority, insurance, contract and operating readiness remain separate requirements.

## 5. Multimodal route planning and execution

Historical route/execution snapshot:
- 6 active mode catalogue entries: ROAD, RAIL, OCEAN, AIR, WAREHOUSE and MULTIMODAL.
- WAREHOUSE is a facility/service stage, not a transport mode; MULTIMODAL is an orchestration classification, not a carrier mode by itself.
- 0 route options, 0 route constraints, 1 route segment, 1 route, 1 shipment leg, 0 leg plans/items, 0 plan activations/events.
- 0 capacity resources/reservations/bindings, 0 dispatches, 0 custody transfers, 0 warehouse facilities/inventory/allocations/tasks.
- One historical route/segment/leg was an old core test record with no meaningful schedule, distance or assignment; it is not an operational route.

Positive structural controls: idempotent draft plan creation, sequential leg continuity, endpoint/mode validation, time ordering, separate evaluation and activation concepts, and exact-leg assignment/capacity/custody checks. These prove code structures exist, not real-world route feasibility or operator connectivity.

### P0.1 — Route-plan activation server-side gate gap
The route planner UI disables activation and warns that corridor/market/customs/compliance controls are not established. The reviewed activation/evaluator definitions did not visibly enforce the complete approved market, country-pack, exact corridor dossier and current-control requirements within the authoritative backend activation transaction. A disabled browser button is not an authorization boundary; direct authenticated RPC access must be blocked server-side. No exploit was attempted.

### P0.2 — Canonical shipment creation conflicts with corridor trigger
The audited five-argument `krim_create_global_shipment` insert omitted `requested_transport_mode`, while the active shipment-write trigger rejects null/blank mode and requires exact corridor approval. The historical audit concluded canonical creation is expected to fail closed. This is a function/trigger contract incompatibility, not a reason to weaken the corridor gate. No booking RPC was invoked.

### P0.3 — Legacy partner-opportunity path has weaker activation checks
The global market architecture audit found the legacy `krim_create_partner_opportunity` path checks active country/location/market catalogue fields but does not itself call the operational market activation gate or verify an approved corridor dossier. An existing legacy shipment could be passed to that opportunity path without changing route fields. No bypass was exercised. Reconcile this path before using it for live sourcing.

### P1 route feasibility and multimodal gaps
- Route options and constraints are empty; no evidence-backed route optimization, distance/cost/risk model, refresh or contingency source is demonstrated.
- Structural route continuity does not prove timetable, sailing/flight/rail path, terminal slot, border status, weather, restrictions, cargo admissibility or physical capacity.
- No provider connectivity or schedule feeds are evidenced.
- Multi-leg commercial sourcing/quote/award aggregation is incomplete; shipment-wide quotes cannot substitute for leg-specific provider awards.
- No actual road-to-rail/air/ocean/warehouse handover or accepted custody journey has been demonstrated.
- Warehouse reservation-aware inventory transfer/picking remains a critical blocker from C3.23.
- Customs clearance is blocked by C3.24; customs broker licences/assignments and official release evidence were absent in historical evidence.
- Road dispatch, driver/vehicle checks and exact-leg authorization have separate unresolved P0/P1 findings in C3.26/C3.22.

## 6. Service activation decision matrix

| Scope | Current decision | Why |
|---|---|---|
| India domestic road | BLOCKED | No approved market control, country pack, corridor dossier, verified active capability, service area, capacity or contract |
| India rail | BLOCKED | Same market/corridor blockers; no rail operator/capability/timetable evidence |
| India air | BLOCKED | No airport/operator, cargo acceptance, schedule, security or regulatory evidence |
| India ocean | BLOCKED | No port/shipping-line, customs, sailing, container or maritime evidence |
| Warehouse stage | BLOCKED | No verified facility; inventory reservation/transfer defect |
| Multimodal | BLOCKED | No approved legs, operators, handovers, custody transfers or integrated execution |
| India→UAE / other cross-border | BLOCKED | Both country packs, corridor dossier, customs, sanctions/export controls, tax/FX, insurance, partner and operational gates absent |
| Global route recommendation | NOT TESTED / NOT APPROVED | Route options/constraints and authoritative feasibility integrations not established |

No row should be displayed as available/bookable based solely on active catalogue flags.

## 7. Required remediation sequence

1. Reconcile Production migration history and deployed function definitions against the repository before any DDL/function replacement; preserve existing fail-closed controls.
2. Repair canonical shipment creation with an explicit required mode argument validated against the authoritative mode catalogue and stored atomically; retire obsolete overloads only after caller inventory and staging verification.
3. Enforce operational market activation, country-pack approval, exact corridor dossier and current source/control checks inside every server-side route-plan activation, partner-opportunity, quote, booking, shipment-write and dispatch path.
4. Fix corridor final approval source integrity, future effective-date checks, reviewer independence and distinct final approver.
5. Complete one India domestic pilot dossier only after qualified legal/CA opinions, official sources, selected partner authority, insurance, exact capability/service area, capacity, contract and rates are independently evidenced.
6. Fix and test reservation-aware warehouse inventory transfer/picking and customs zero-check fail-closed evaluator before including those stages.
7. Build mode-specific readiness gates: ROAD; RAIL operator/timetable/terminal; AIR carrier/security/airport/cargo acceptance; OCEAN carrier/port/container/customs; WAREHOUSE facility/stock/QC; MULTIMODAL per-leg operators, schedules, transfers and custody.
8. Implement leg-specific sourcing, quotes, assignment, capacity reservations, handover acknowledgements and commercial aggregation; bind every decision to current route/corridor/market evidence.
9. Add staging-only negative and positive tests: blocked market, draft corridor, wrong direction/mode, missing or expired source, suspended partner, no capacity, unsupported cargo, missing customs control, direct activation RPC, legacy opportunity path, canonical booking with missing/valid mode, one-leg and multi-leg route, failed handover and warehouse stock reservation races.
10. Run one fully synthetic end-to-end corridor journey in isolated Staging only after proving project isolation; do not activate Production or contact real providers as part of this gate.

## Gate decision

**C3.35 FAIL / BLOCKED.** The global-ready architecture is substantial, but there is no evidence-backed operational market, corridor or multimodal service. Do not accept bookings, publish rates, promise transit times, show live coverage, recommend executable routes or claim customs/warehouse/multimodal fulfilment. Continue internal development and non-binding partner discovery only.

**Safety record:** No Production/Staging changes, RPC invocations, shipment bookings, corridor/market approvals, route-plan activations, dispatches, provider calls, customer communications or payments were performed. Historical snapshots are dated and not refreshed live; no browser journey was executed.
