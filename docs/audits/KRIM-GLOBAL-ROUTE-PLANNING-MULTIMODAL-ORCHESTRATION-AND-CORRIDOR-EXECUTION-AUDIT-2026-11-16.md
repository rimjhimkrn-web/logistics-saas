# KRIM Global Route Planning, Multimodal Orchestration and Corridor Execution Audit
**Date:** 16 November 2026  
**Scope:** Read-only production catalog/data review of transport modes, locations, route options/segments/constraints, shipment routes/legs, multi-leg planning, plan evaluation/activation, corridor dossiers/controls and dispatch/custody gates; source review of the operations route planner. No route plan was created, evaluated or activated. No shipment, leg, quote, assignment, capacity, corridor, partner or operational record was changed. No dispatch or provider action was performed.

## Executive decision
**NO-GO for real route recommendations, multimodal booking, corridor activation or shipment execution.** KRIM has a meaningful foundation: six active mode catalogue entries, location references, a shipment-linked route/leg model, an idempotent plan-creation RPC, continuity/time-window validation, a separate plan evaluation step, an atomic activation function, and downstream exact-leg dispatch/custody checks. However, live route evidence is nearly empty: zero route options, zero route constraints, no route plans/items/activations, no corridor dossiers/controls, and only one route/one route segment/one shipment leg in the production snapshot. All seven corridor candidates remain draft. The route planner UI blocks activation, but the authenticated database activation RPC remains executable and its function body relies on the evaluator without visibly enforcing market/corridor dossier/control readiness. A browser-only disablement is not a server-side safety boundary.

## 1. Production data baseline
Read-only counts at audit time:

| Component | Rows |
|---|---:|
| Locations | 32 |
| Transport mode catalogue | 6 |
| Route options | 0 |
| Route segments | 1 |
| Route constraints | 0 |
| Shipment routes | 1 |
| Shipment legs | 1 |
| Shipment leg plans | 0 |
| Shipment leg plan items | 0 |
| Plan activations / activation events | 0 / 0 |
| Corridor candidates | 7 |
| Corridor dossiers | 0 |
| Corridor controls / corridor legs / events | 0 / 0 / 0 |
| Custody transfers | 0 |
| Leg dispatch authorizations | 0 |

Active catalogue modes are ROAD, RAIL, OCEAN, AIR, WAREHOUSE and MULTIMODAL. WAREHOUSE is a facility/service stage, not a physical transport mode. MULTIMODAL is an orchestration classification, not a carrier mode by itself. The six catalogue entries do not prove actual service availability, operator connectivity, schedules, rates, handling capacity or regulatory permissions.

Prior global market readiness audit found all 249 country operating packs research_pending, readiness requirements unapproved and all seven corridor candidates draft. No corridor dossier or controls have been populated. The current production route tables therefore do not demonstrate an operational route network.

## 2. Route planning data model and controls
### Positive controls
- Shipment route/segment records are linked to a canonical KRIM shipment; route segment validation checks route existence, location existence and transport mode existence.
- Route segments have unique sequence per route, positive sequence, different endpoints, non-negative distance and planned/actual time checks.
- Shipment legs have unique sequence per shipment, valid endpoint/mode foreign keys, canonical statuses and optional linkage to route-plan items.
- The leg-plan creation RPC requires authentication and `shipment.update` permission for the owning customer organization, locks the shipment, limits plans to 1–20 legs, requires an idempotency key and fingerprints the request so the same key cannot be replayed with different inputs.
- Plan creation checks shipment pre-execution status, active location and mode references, origin/destination continuity, leg timing, and other structural constraints before persisting a draft.
- The evaluation RPC checks customer organization permission, plan/shipment state, declared versus actual leg count, contiguous leg numbering, valid non-identical endpoints, active locations, leg continuity and planned time ordering; it also checks compatibility with existing shipment legs.
- Activation is a separate atomic RPC. It re-evaluates the plan, locks shipment/plan, uses an idempotency key, writes activation and plan events, maps plan items to shipment legs and aborts transactionally on leg-count or status mismatch.
- Plan/leg/route read policies are customer-organization scoped. The corridor catalogue and route constraints are exposed to authenticated users only when status is active.

These controls establish a credible structural planning workflow, not proof that a proposed route is commercially, physically or legally executable.

## 3. Critical finding ROUTE-01 — P0: frontend activation block is not a backend authorization gate
The operations route planner:
- lets an authorized user create a route-plan draft through `krim_create_shipment_leg_plan`;
- calls `krim_evaluate_shipment_leg_plan` for validation;
- permanently disables the visible activation button and explains that corridor, market, customs and compliance controls are not yet established.

However, the production function `public.krim_activate_shipment_leg_plan(bigint,text)` is executable by authenticated users. Its inspected body:
1. checks authentication and `shipment.update` permission for the shipment's customer organization;
2. locks the shipment and plan;
3. calls `krim_evaluate_shipment_leg_plan`;
4. if the evaluator returns ready, inserts activation records and creates/links shipment legs, then marks the plan active.

The inspected activation/evaluator definitions do not visibly call the corridor compliance evaluator, verify an approved corridor dossier and its mandatory controls, or require approved country operating packs/market activation as a precondition to activation. The UI click handler's disabled state does not prevent a direct authenticated RPC invocation.

This is a high-severity server/client parity gap: a caller with shipment.update may attempt to activate a structurally valid plan directly even though the UI tells the user activation is blocked. The audit did not invoke this function and did not test an exploit. **Treat direct activation as a P0 release blocker until the server-side gate is proven.** Reconcile function dependencies and migration history first; then enforce the complete route/market/corridor/compliance gate inside the authoritative backend transaction and test direct RPC calls in staging. Do not rely on JavaScript button state.

## 4. Finding ROUTE-02 — P1: route plan structural readiness is not route feasibility
The plan evaluator validates database structure and continuity. It does not establish:
- a verified road carrier/vehicle/driver or rail/air/ocean operator for each leg;
- a published and confirmed timetable, slot, sailing, flight, rail path or terminal cutoff;
- real transit time, dwell time, connection buffer or terminal handling window;
- capacity available for the actual cargo dimensions, weight, temperature, hazardous classification or handling needs;
- transfer terminal/port/airport/railhead/warehouse access and custody acceptance;
- route restrictions, weather/seasonal conditions, road permits, axle/height limits, port disruption or carrier embargo;
- current tariffs, fuel/surcharges, taxes, insurance or quote validity;
- customs/border controls and government release where applicable.

A continuous chain of active location IDs and active mode IDs is only a structurally valid itinerary. Do not label it optimized, feasible, available, bookable, fastest, cheapest or guaranteed without independent route evidence.

## 5. Finding ROUTE-03 — P1: route options and constraints are unused in live production
`krim_route_options` and `krim_route_constraints` have zero rows. No candidate/alternative/contingency routes or active restrictions have been recorded. The existence of tables and a route-optimizer page does not prove an optimization engine, data source, distance calculation, cost model, risk model, scoring weights or refresh process is running. The platform currently has no evidence-backed comparison between road-only, rail, air, ocean or multimodal options.

Recommendation: make route-option provenance explicit (provider/source, retrieved_at, validity window, assumptions, data quality, version, currency, units and confidence). Distinguish static/manual planning from live provider-confirmed schedules and rates. Expire stale options automatically and require human approval for exceptions.

## 6. Finding ROUTE-04 — P1: corridor compliance is not populated or proven
The corridor compliance schema separates dossier, corridor leg, mandatory control, evidence reference, review status, reviewer and expiry. That is the right type of governance model. But production has seven draft corridor candidates and zero dossiers, controls, corridor legs or compliance events. There is no approved corridor evidence for domestic or cross-border execution.

A domestic route still needs relevant road/rail permissions, operator eligibility, state/region restrictions, local handling and insurance controls. An international route additionally needs origin/destination market approval, export/import requirements, transit-country rules, customs/broker responsibilities, sanctions/restricted-goods checks, border crossing evidence, permits and government clearance. A corridor candidate or active market catalogue flag is not authorization.

## 7. Finding ROUTE-05 — P1: multimodal transfer and custody are not operationally evidenced
The platform has later-leg custody transfer and acceptance gates, warehouse handover checks and exact-leg dispatch authorization. These are positive control patterns. But there are zero custody transfers, zero transfer events, zero warehouse allocations and no activated route plans. No actual handover between road, rail, air, ocean, warehouse or customs actors has been demonstrated.

For each transfer point, the system needs:
- sending and receiving legal entities and authorized personnel;
- timestamped handover, location and condition;
- cargo/package/pallet/handling-unit reconciliation;
- seal and document references where applicable;
- discrepancy/damage/shortage workflow;
- acceptance/rejection and independent review where risk warrants;
- clear custody responsibility during dwell and transfer windows.

Do not infer custody acceptance from arrival milestones or a route-plan segment transition.

## 8. Finding ROUTE-06 — P1: dispatch authorization is not departure or live carrier confirmation
The existing exact-leg dispatch authorization checks accepted partner assignment, confirmed capacity, road driver/vehicle evidence, active route-plan item and warehouse picked-stock/private proof. Later legs require accepted custody. This is layered and useful.

But the previous shipment execution audit found a single-leg dispatch trigger condition that expects a route plan with more than one leg, conflicting with the exact-leg dispatch interface. The current production dataset has only one shipment leg and zero plan activations, so dispatch behavior is not operationally demonstrated. GPS is disabled; manual coordinates are not verified GPS. Dispatch authorization is not actual departure, carrier check-in, vehicle movement or live location.

This requires an isolated staging regression for both one-leg and multi-leg plans before any execution release.

## 9. Finding ROUTE-07 — P1: mode catalogue risks overstatement
Six active catalogue records include WAREHOUSE and MULTIMODAL alongside ROAD, RAIL, OCEAN and AIR. Clarify the taxonomy:
- physical carriage modes: road, rail, air, ocean (and any additional verified modes);
- service/facility stages: warehouse, customs, transload, terminal handling;
- orchestration types: multimodal/intermodal.

Do not let a warehouse facility entry appear as a carrier transport mode or a MULTIMODAL record imply a single provider can execute every leg. Every physical leg should carry its own actual mode, operator, scope, evidence and custody responsibility.

## 10. Route planner frontend review
The operations route planner loads only shipments visible to the current user and in draft/quoted/confirmed state; it loads active locations and active transport modes; it creates draft plans through the authorized RPC; it displays plan/item rows under RLS; and it makes the activation blocker explicit. This is safer than silently activating or presenting a false “ready” result.

Remaining frontend risks/limitations:
- it is not a live route recommendation engine and does not fetch carrier schedules or rates;
- the evaluator's structural readiness text may be interpreted as operational readiness unless UI labels explicitly say “structural validation only”;
- activation is blocked only in the browser, while the backend RPC remains callable;
- the route-plan list reads a limited recent window (50 plans) and is not a paginated global register;
- location labels are user-friendly city/region/code but not full geocoded routing evidence;
- no authenticated browser tests were run.

## 11. Required staging-only acceptance tests
1. A direct authenticated call to `krim_activate_shipment_leg_plan` for a structurally valid plan on a corridor with no approved dossier must fail closed and create zero legs/activation rows.
2. A route plan for a market with research_pending or inactive operating pack must not activate.
3. Missing, expired, rejected or unreviewed mandatory corridor controls must block activation; an empty control set must not mean clear.
4. Every leg must have an active physical mode, valid origin/destination, contiguous sequence and consistent connection time.
5. Test one-leg and multi-leg plans separately, including the known single-leg dispatch trigger regression.
6. Test direct RPC activation against the disabled UI; UI and backend must produce the same decision.
7. Test cross-tenant shipment IDs, missing shipment.update, revoked membership and AAL1/AAL2 requirements as applicable.
8. Test idempotent plan creation and activation under concurrent retries and conflicting payloads.
9. Test stale plan version, concurrent plan edit, superseded plan and shipment state transition during activation.
10. Test provider-confirmed schedules, capacity and service-area evidence per exact leg; expired evidence must block.
11. Test each transfer point with sending/receiving party, warehouse/terminal evidence, condition and custody acceptance.
12. Test ROAD, RAIL, AIR and OCEAN leg eligibility independently; WAREHOUSE must be treated as a service stage, not a physical carrier mode.
13. Test special cargo, prohibited/restricted goods, dangerous goods and customs requirements fail closed unless the exact controls are reviewed.
14. Test ETA, cost, distance, currency, units and route risk provenance; stale/illustrative estimates must be clearly labelled.
15. Test route deviation, missed connection, terminal delay, carrier cancellation and reroute approval without bypassing corridor/market gates.
16. Verify no route optimizer returns a “best” or “available” result without source freshness, confidence and explicit assumptions.

None of these staging tests was executed.

## 12. Remediation order
1. Treat the callable activation RPC without a proven server-side corridor/market gate as P0. After migration reconciliation, make activation enforce all hard gates inside its transaction; revoke or narrow direct execution if an approved server-side workflow cannot yet be guaranteed.
2. Ensure the evaluator reports separate outcomes: structurally_valid, market_approved, corridor_approved, regulatory_clear, partner_covered, capacity_confirmed, transfer_ready and operationally_activatable. Never collapse these into one ambiguous `ready` boolean.
3. Reconcile single-leg versus multi-leg dispatch trigger semantics in staging.
4. Populate and independently review the first domestic pilot corridor before any international route claims; all route/country evidence must be current and source-backed.
5. Add per-leg partner, mode, timetable, capacity, cost and transfer evidence.
6. Build a genuine route option engine only after data provider/source integrations and data freshness/quality controls exist.
7. Run full staging-only end-to-end route, booking, custody, dispatch, exception and delivery tests.
8. Keep financial collection deferred until the separate final financial readiness phase.

## 13. Change control and release decision
Read-only audit only. No route-plan creation/evaluation/activation RPC was called; no shipment legs, assignments, reservations, dispatches, custody transfers, route options or corridor controls were created. No production schema/function/policy was changed.

The production migration-history mismatch and sanitized schema-manifest gate remain unresolved. Do not replay, baseline, squash or apply corrective DDL until full reconciliation is complete.

**Release status: NO-GO for live route recommendations, multimodal booking, corridor activation and unrestricted shipment execution.** The plan data model and staged controls are promising, but real route/corridor/provider evidence is absent and the callable activation RPC must be reconciled with the UI's hard block before any operational use.
