# Gate C3.19 — Global operations, multimodal execution, route planning, handoffs, control tower and cross-border readiness

**Programme:** KRIM GLOBAL PLATFORM — AI QUALITY ASSURANCE, SIMULATION & RELIABILITY PROGRAMME  
**Gate:** Phase 00 / C3.19  
**Source baseline:** `72d75a18f985ceb09e468839435ee95700e11e46`  
**QA branch:** `qa/phase-00-baseline-2026-11-25`  
**Review date:** 2026-11-25  
**Disposition:** **PARTIAL PASS / BLOCKED — NO-GO for global multimodal dispatch, autonomous routing, cross-border clearance or universal control-tower operations claims.**

## 1. Scope and method

Read-only source audit of verified partner capability and capacity matching, partner capacity reservation and release, exact route-lane reservation, shipment leg-plan creation/evaluation/activation, exact-leg dispatch authorization/revocation, dispatch readiness, vehicle compatibility, warehouse picked-allocation and handover gates, customs broker assignment/licence jurisdiction checks, operations route-planning UI, control-tower routes, global trade-lane register, and operations runtime.

Baseline pinned to `72d75a18f985ceb09e468839435ee95700e11e46`. Review uses migration and frontend source only. No live DB queries, RPCs, route-plan creation, capacity reservation, dispatch, customs declaration, partner matching, warehouse handover, provider request or operational record was executed. No Production or Staging data was read or changed.

## 2. Positive source controls

1. **Network capability matching fails closed.** The internal network-capability check requires an active transport mode, verified active partner capability, and available capacity evidence; missing mode/capability/capacity returns unavailable rather than pretending network coverage exists. Internal function execution is restricted to service role.
2. **Capacity matching subtracts existing reservations.** The later quote-matching definition calculates reserved capacity against each availability record and uses only the remaining resource/availability minimum. It checks resource type, transport mode, time window, capacity unit and weight/vehicle sufficiency.
3. **Partner capacity reservation is exact-leg scoped.** The reservation RPC checks authenticated partner context, accepted/active assignment, linked shipment leg, matching partner organization and transport mode, pre-dispatch leg state, approved availability/resource, scheduled window and remaining capacity. It records reservation, leg binding and audit events and reuses an existing binding only when the underlying reservation remains active.
4. **Capacity release is linked to terminal lifecycle.** Assignment terminal transitions and shipment terminal transitions release held/confirmed capacity reservations and leg bindings with event records.
5. **Route plans have secure draft creation and validation RPCs.** Draft creation validates shipment/route leg inputs, active modes, endpoints, continuity and positive paired capacity/unit values, with an idempotency key. Evaluation is documented as non-mutating and returns validation results.
6. **Plan activation is atomic at the plan/leg-record layer.** The activation RPC locks the plan, re-evaluates it, uses an idempotency key and creates/links shipment legs and activation audit events. The migration explicitly states activation does not assign partners, reserve capacity, dispatch or advance shipment status.
7. **Multi-leg dispatch is exact-leg, not shipment-wide.** A unique active authorization per leg binds shipment, leg, partner assignment, organization, confirmed capacity binding and reservation. It checks partner dispatch permission, accepted assignment, route-plan item linkage and capability. Legacy shipment-wide dispatch is blocked for active multi-leg plans.
8. **Dispatch authorization can be revoked and is revalidated at execution.** Revocation requires a reason and dispatch permission, is blocked after pickup/transit, and is audited. Driver event execution revalidates current exact-leg authorization, partner assignment, capacity and custody conditions.
9. **Road driver/vehicle readiness has meaningful controls.** The dispatch readiness register checks partner dispatch permission, exact leg, warehouse handover and eligible driver count. Road dispatch checks a verified driver, current licence, active verified vehicle binding and current mandatory vehicle documents.
10. **Non-road multi-leg execution is deliberately blocked.** The route-plan dispatch guard rejects non-ROAD authorization until mode-specific verified resource and execution controls exist. This is an important fail-closed control, not a completed multimodal capability.
11. **Warehouse handover is a real dispatch prerequisite in source.** A dispatch handover must be linked to exact shipment leg, picked inventory allocations must exist, unpicked reservations block handover, and dispatch authorization requires completed exact-leg handover, picked stock and current private dispatch proof.
12. **Customs broker assignment is jurisdiction- and licence-aware.** Broker response requires active broker organization membership and compliance permission, a known customs country/jurisdiction and an approved licence for that country. Customs workspace frontend additionally requires authenticated session, AAL2, active customs organization membership and compliance.view permission.
13. **Operations UI is cautious about unverified functionality.** The route-planning page requires active operations-organization membership, shows route plans/legs from KRIM tables, supports draft creation and evaluation, and leaves activation disabled pending market/corridor/customs/compliance verification. It says no operational record is changed by preparation-only controls.
14. **Control tower runtime does not fabricate telemetry.** AIS, predictive ETA and automated rerouting are explicitly disabled when no verified provider/data is connected. The runtime generates no sample vessel positions or simulated events.

## 3. Findings and release risks

### P1 — Multimodal execution is not implemented end-to-end
The exact-leg dispatch guard explicitly blocks every non-ROAD mode pending mode-specific verified resource and execution controls. The audited driver event path also restricts the inspected multi-leg trip execution to ROAD. Active transport-mode catalog entries and route-plan draft support do not constitute rail, air, ocean or multimodal dispatch readiness.

**Impact:** Do not accept or dispatch non-road legs as operationally executable until the appropriate partner/resource, schedule, custody, evidence, handoff and mode-specific lifecycle gates are implemented and tested. Keep each unready mode unavailable at quote/assignment/dispatch.

### P1 — Global trade-lane register is not the canonical route/corridor activation system
The Global Trade Lane Management UI describes a local review checklist and generic records. Its shared runtime writes rows to `krim_global_ops_records` under a module key, rather than linking a lane record to canonical shipment routes, approved route-plan items, partner capability, reservations, customs jurisdictions and market activation evidence. The page itself says its records are not yet linked to underlying shipment, finance, compliance or partner source-of-truth systems. The route-planning UI separately says activation is blocked pending approved market activation, corridor dossiers/controls and customs/compliance prerequisites.

**Impact:** A saved trade-lane record is not a verified operating corridor. No lane or country should be represented as bookable/active from the generic register.

### P1 — Cross-border clearance is only a partial broker foundation
The audited broker response checks jurisdiction and an approved broker licence, and customs workspace access is tightly gated. This review did not establish an end-to-end country-pair rule engine covering import/export/transit, HS classification, restricted/sanctioned goods, permits, origin rules, customs valuation, duties/taxes, document completeness, customs declaration submission, customs authority responses, release/hold, broker capacity or border handoff. Country-specific legal requirements and live government single-window integrations were not runtime verified.

**Impact:** Do not promise customs clearance or cross-border service availability from broker licensing alone. Require shipment- and jurisdiction-specific documentary and regulatory readiness.

### P1 — Route-plan evaluator does not prove market activation and corridor compliance
The route-plan draft and evaluator validate structural route continuity, endpoint, location and mode consistency and legacy-leg compatibility. The operations page explicitly keeps activation disabled because full market activation, corridor dossier/control and customs/compliance prerequisites are not established. The backend plan activation RPC creates plan/leg records but its migration states it does not assign partners, reserve capacity, dispatch or advance shipment status.

**Impact:** A structurally valid route plan is not commercially, legally or operationally executable. Keep activation/execution gated until all prerequisites are enforced in backend and UI.

### P1 — Operations UI does not establish fine-grained operational authorization for every write
The route-planning page verifies an active operations-organization membership but its own status says fine-grained operations permissions and write workflows still require verification. The draft RPC has its own server-side checks, but the complete permission matrix for route creation, evaluation, activation, partner assignment, reservation, dispatch, reroute approval and exception closure was not exhaustively reconciled in this gate.

### P2 — Capacity reservation and release require concurrency/failure runtime proof
Source uses row locks, remaining-capacity calculations, idempotency and lifecycle release triggers. No Staging tests were run for two partners/users racing for the last unit, overlapping time windows, unit conversion, concurrent cancellation vs dispatch, duplicate retries, deadlocks, partial failures or capacity restoration after assignment/shipment terminal transitions. The source-level design is promising but not proof of no overbooking.

### P2 — Route planning is not a route optimization or schedule engine
The inspected operations page loads saved route records and route-plan references; its text explicitly says it does not calculate or publish a route. No verified traffic, rail timetable, flight schedule, vessel schedule, port cut-off, sailing/connection, border wait, transit-time source, cost model or service-level optimization integration was established. Automated rerouting is disabled.

### P2 — Control-tower global operational coverage is not established
The operations runtime reports AIS provider not connected, AIS disabled, predictive ETA disabled and automated rerouting disabled. No verified end-to-end event ingestion from carriers, airlines, rail operators, ports, terminals, warehouses, customs or telematics was established. The control tower is an authenticated workspace shell and set of records/workflows, not proof of 24/7 global monitoring or staffed incident response.

### P2 — Generic global operations records can be mistaken for authoritative operational state
The global operations script stores generic user-authored module records in `krim_global_ops_records`. These are useful reference/workflow records, but they are not automatically authoritative lane, route, carrier contract, customs, market, shipment or finance entities. UI labels and downstream consumers must preserve this distinction.

### P2 — Country, currency, time-zone and regulatory completeness is unverified
No comprehensive active-country × origin/destination × mode × service × partner × capability × customs-jurisdiction × currency × timezone × holiday/cut-off matrix was validated. The route-plan code accepts active transport-mode IDs, but that does not establish globally normalized units, FX, calendar, local cut-offs, Incoterms, tax treatment, sanctions screening or regulatory applicability.

### P2 — Multi-leg custody transfer remains a separate critical dependency
Earlier C3.13 found positive adjacency, accepted receiving assignment, capacity and evidence controls, but also identified replay/idempotency omissions and missing receiving-side co-acknowledgement. This gate confirms dispatch authorization requires a prior-leg custody transfer for subsequent legs; it does not establish the complete physical handoff/reconciliation workflow through runtime testing.

### P2 — No operational service continuity evidence
No real or synthetic tests were run for partner failure, mode cancellation, missed connection, port congestion, border hold, route closure, customs document rejection, warehouse capacity shortage, vehicle breakdown, dispatch revocation, custody discrepancy, reroute approval, partial delivery or recovery. Operations control tower ownership, 24/7 on-call and escalation SLAs are not certified.

## 4. Required remediation before release

1. Publish an explicit mode-by-mode readiness matrix. Keep ROAD-only execution as the only candidate until rail, air, ocean and each multimodal handoff have their own verified partner/resource/schedule/evidence/lifecycle gates.
2. Create a canonical approved trade-lane/corridor entity linked to origin/destination countries and locations, route-plan items, transport modes, active partner capabilities, capacity, service schedules, customs jurisdictions, market activation, currency, timezone, cut-offs, restrictions, effective dates, owners and approval evidence.
3. Move corridor activation prerequisites into backend-enforced policy/RPC/trigger gates; UI-only disablement is not sufficient. Require independent compliance approval and immutable audit.
4. Complete a cross-border regulatory matrix by country pair, direction, mode, cargo/HS category, permits, sanctions, origin, valuation, tax/duty, document set, customs broker licence, declaration state and authority response. Block unknown or expired requirements.
5. Implement mode-specific dispatch execution and exception recovery: confirmed schedules/resources, loading/manifest, custody/seal, departure/arrival, handoff acknowledgement, missed connection, damage/loss, proof and cancellation/recovery.
6. Reconcile permissions for all consequential operations RPCs and tables. Test unauthenticated, wrong organization, wrong role, stale membership, expired licence, revoked assignment, cross-tenant ID and service-role/internal-only paths.
7. Run isolated Staging capacity race tests with concurrent reservation, duplicate idempotency, overlapping windows, unit conversions, cancellation/dispatch races and terminal release; verify no overbooking and complete audit.
8. Add route/schedule data provenance and freshness: carrier/airline/rail/ocean/port/border feeds, timestamps, timezone, source contract, confidence and outage behavior. Keep optimization/rerouting unavailable until these sources are verified.
9. Label generic `krim_global_ops_records` entries as non-authoritative reference/workflow records. Do not use them to assert live coverage, partner availability, customs readiness or corridor activation.
10. Verify the global market matrix including country, currency/FX, IANA timezone, locale, units, calendars/holidays, cut-offs, Incoterms and mode/cargo restrictions.
11. Complete and test physical custody transfer co-acknowledgement, seal/discrepancy matching, evidence integrity, idempotency and receiving-party acceptance.
12. Establish operational ownership, staffed hours, on-call escalation, customer/partner notices and business continuity for disruption and cross-border holds.

## 5. Verification matrix

| Check | Result | Evidence / limitation |
|---|---|---|
| Verified mode and partner capability matching | SOURCE PASS | Internal check requires active mode and verified active capability; no live network query. |
| Capacity-aware matching | SOURCE PASS | Remaining capacity subtracts reservations and checks resource/time/unit. |
| Exact-leg partner capacity reservation | SOURCE PASS / PARTIAL | Authenticated accepted assignment, leg, partner, resource and reservation; concurrency runtime not tested. |
| Capacity release on terminal lifecycle | SOURCE PASS / NOT TESTED | Assignment/shipment triggers release reservations/bindings; runtime not tested. |
| Secure route-plan draft creation | SOURCE PASS | Validates route input, mode, endpoints, capacity fields and idempotency; no RPC executed. |
| Route-plan evaluation | SOURCE PASS / PARTIAL | Structural checks; does not establish all market/corridor/customs prerequisites. |
| Atomic plan activation | SOURCE PASS for plan/leg layer | Activation creates leg records; does not assign, reserve or dispatch. No activation run. |
| Exact-leg dispatch authorization/revocation | SOURCE PASS / PARTIAL | Exact partner/leg/capacity binding, reasoned revocation, audit and revalidation; no runtime test. |
| Multi-leg ROAD execution readiness | SOURCE PASS / NOT TESTED | Driver/vehicle/capacity/custody/warehouse gates exist in source; no live execution. |
| Rail/Air/Ocean dispatch | FAIL / BLOCKED | Explicit non-ROAD dispatch guard; mode-specific execution not implemented. |
| Warehouse picked allocation and dispatch proof | SOURCE PASS / NOT TESTED | Exact-leg picked inventory and private proof gates; no handover execution. |
| Customs broker jurisdiction/licence acceptance | SOURCE PASS / PARTIAL | Country and approved broker licence required; broader clearance engine not established. |
| Cross-border country-pair regulatory readiness | BLOCKED | No complete country-pair rule matrix/declaration authority integration established. |
| Global trade-lane activation | FAIL / BLOCKED | Generic records not linked to canonical route/corridor/compliance/partner source of truth. |
| Route optimization / schedules / rerouting | FAIL / BLOCKED | Route page does not calculate/publish; automated rerouting disabled. |
| Control-tower live external telemetry | FAIL / BLOCKED | AIS, predictive ETA and automated rerouting disabled; no provider configured. |
| Fine-grained operations permission matrix | NOT TESTED | UI itself says fine-grained permissions/workflows require verification. |
| Global currency/timezone/regulatory matrix | NOT TESTED | No exhaustive country × mode × service validation. |
| End-to-end disruption/handoff recovery | NOT TESTED | Requires isolated Staging simulation and owner-approved test data. |

## 6. Change and safety record

- No Production or Staging SQL, RPC, Edge Function, route plan, shipment leg, capacity reservation, dispatch authorization, warehouse task, customs record, partner assignment, shipment, provider or deployment was changed or invoked.
- No real partner/carrier/customs authority was contacted.
- No shipment was routed, booked, reserved, dispatched or moved.
- Documentation-only change on the QA branch.

**Gate C3.19 result: PARTIAL PASS / BLOCKED.** KRIM has meaningful foundations for verified partner capability, capacity reservation, route-plan drafts, exact-leg dispatch authorization, road dispatch readiness, warehouse handover and jurisdiction-licensed customs brokers. The architecture deliberately fails closed for non-road execution, and control-tower automation remains disabled without verified providers. The global trade-lane registry, cross-border rules, corridor activation, mode-specific execution, route optimization, live external telemetry and full operations permission/recovery testing are not yet established. Continue India-first only on specifically verified partner, route, mode and service combinations; do not publish broad global coverage claims.
