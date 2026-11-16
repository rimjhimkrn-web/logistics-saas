# KRIM Operational RPC Deep Review — Route Plans, Capacity, Dispatch and Custody — 2026-11-16

## Scope
Read-only review of live production definitions for route-plan evaluation/activation, partner capacity reservation, dispatch authorization/currentness, warehouse dispatch handover and multi-partner custody transfer. Reviewed helper definitions, execution grants and the existing production/migration-history reconciliation blocker. No RPC was executed; no data, grants, policies, functions or migration history were changed.

## Executive result
The operational functions contain meaningful safeguards: exact-leg assignment linkage, verified capability checks, future time windows, capacity reservation records, driver/vehicle checks for road transport, idempotency, private evidence ownership, two-party custody acceptance and a dispatch-handover proof requirement.

However, a critical global-activation gap remains: the live route-plan evaluator checks route geometry, active locations/modes, time windows, shipment endpoints, existing-leg conflicts and shipment-wide quote conflicts, but it does not evaluate market operational activation, corridor dossier approval, corridor controls, country operating-pack approval or shipment-specific customs/regulatory clearance. The dispatch authorization/currentness helper likewise does not include a corridor activation/dossier/control predicate. Active country/location metadata and partner capabilities are not equivalent to legal corridor activation.

This is a **P0 release blocker for cross-border and regulated/corridor-dependent operations** and a P1 control gap for any route where market/corridor activation is required.

## Function-by-function findings

### 1. Route-plan evaluator and activation
Live `public.krim_evaluate_shipment_leg_plan(bigint)`:
- Requires authenticated user and owning-customer `shipment.update` permission.
- Requires draft/ready plan and pre-execution shipment state.
- Checks 1–20 legs, contiguous sequence, active origin/destination locations, active transport mode, connected adjacent legs, positive capacity requirement/unit pairing, valid time ordering, shipment origin/destination match, no other active plan, no conflicting existing initial leg and no unresolved shipment-wide quote flow for multi-leg plans.
- Does **not** check the operational activation state for either market, an approved corridor dossier, corridor control evidence, current country operating packs, route-specific customs requirements or independent compliance clearance.

Live `public.krim_activate_shipment_leg_plan(bigint,text)`:
- Locks shipment and plan, requires customer update permission, idempotency, successful evaluation and a single activation record.
- Creates/matches the planned leg rows and activation/event snapshots transactionally.
- Because activation trusts the evaluator's `ready` result, it is a route-structure activation, not proof of regulatory or commercial execution readiness. UI/API must not label it “approved for operation” or “bookable”.

### 2. Partner capability and compliance helper
Live `private.krim_partner_capability_covers_shipment_leg(bigint,bigint)`:
- Checks active endpoint locations, active endpoint countries, active mode, positive shipment weight, verified partner capabilities for both endpoint countries, capability validity and max weight.
- Does not itself check active market operational activation, approved corridor dossier, mandatory corridor controls, operating-pack approval or shipment-specific customs clearance.
- It is a capability/coverage predicate, not a country/corridor operating approval.

Live `private.krim_partner_compliance_is_current(bigint)`:
- Requires active registered-business partner, verified identity, compliant organization lifecycle/status, and a latest approved compliance review with a future valid-until date.
- This is a useful partner-level control, but partner compliance is not a substitute for route/cargo/country compliance.

### 3. Capacity reservation
Live `public.krim_partner_reserve_shipment_leg_capacity(bigint,timestamptz,timestamptz,text)`:
- Requires authenticated active partner membership and shipment.update permission, accepted/active exact-leg assignment, current partner compliance, exact partner/leg/mode binding, pre-dispatch leg state, and verified capability coverage.
- Requires future departure and later arrival.
- Searches verified active lane availability and verified vehicle resources, locks candidate resource/availability rows with `FOR UPDATE SKIP LOCKED`, calculates overlapping active reservations, checks both availability-level and physical-resource capacity, and creates reservation/binding/event/audit records.
- Uses an idempotency key and records the planned window.
- This is a positive locking pattern. Still requires concurrency and interval-boundary tests in an isolated non-production environment; the live empty capacity inventory means no real reservation path has been demonstrated.
- Before release, confirm unique constraints on organization/idempotency key and binding per exact leg, and ensure all competing reservation writers use the same lock discipline.

### 4. Dispatch authorization
Live `public.krim_authorize_leg_dispatch(bigint,text)`:
- Requires authentication, accepted/active exact-leg partner assignment and `shipment.dispatch` permission.
- Locks assignment, exact leg, shipment, binding and reservation.
- Requires leg status assigned, partner-owned confirmed physical capacity binding/reservation, and for ROAD an accepted verified driver, current licence, active verified vehicle binding and mandatory current vehicle documents.
- For later legs, requires accepted custody transfer from the immediately preceding leg.
- Creates an authorization and audit-like partner execution event. It explicitly does not record physical departure.
- Does not directly check corridor operational activation, approved corridor dossier/control evidence, shipment compliance-gate validity, or customs release. The currentness helper also omits these predicates.
- The helper `private.krim_leg_dispatch_authorization_is_current` checks active multi-leg plan/plan-item match, assignment, partner verification/compliance, exact confirmed capacity, current capability, dispatch handover and prior custody acceptance. It does not check the corridor dossier/operational activation chain.
- Dispatch authorization must therefore remain blocked for corridors whose legal/operational activation is absent, even if partner capability and capacity pass.

### 5. Warehouse handover
Live `private.krim_dispatch_handover_is_current` requires a completed dispatch_handover task for the same partner/shipment/leg, picked shipment allocation, no remaining reserved allocation and a private uploader-owned dispatch-proof object in the warehouse evidence bucket with allowed MIME/size.
- This is a meaningful evidence gate.
- It does not itself prove carrier physical departure or downstream carrier acceptance; dispatch authorization remains distinct from dispatch execution.
- Warehouse facilities/tasks/allocations/evidence are currently empty, so this gate has not been exercised with real records.

### 6. Custody transfer
Live `public.krim_create_leg_custody_transfer(...)`:
- Requires adjacent legs in same shipment and same active route plan, different assigned partner organizations, completed releasing leg with actual arrival, releasing-partner assignment and permission, receiving-partner accepted assignment and confirmed capacity reservation.
- Requires cargo manifest to account for every shipment cargo line with exact quantity/unit.
- Requires private evidence object owned by releasing user, scoped under releasing organization/user path, allowed MIME and <=10 MB.
- Uses advisory transaction lock and idempotency; emits offered event.
- Receiving response function requires receiving organization `partner.manage`, locks transfer, checks receiving leg/partner binding has not changed and rechecks accepted assignment and confirmed reservation before acceptance; rejection requires a reason.
- Positive two-party control. The creation function records cargo condition, seal and discrepancy, but does not itself require a non-empty seal number or a separate independent condition inspection/review. For high-risk cargo, require condition/seal review and discrepancy resolution before next-leg dispatch.
- The releasing user must have `partner.manage`; receiving acceptance is a separate organization-authorized action. Do not treat offer creation as transfer completion.

## Priority gaps

| Priority | Finding | Required control |
|---|---|---|
| P0 | No corridor/market activation and approved dossier/control checks in route-plan evaluator or dispatch currentness | Central server-side corridor eligibility predicate, backed by approved current dossier, country operating packs and required controls; fail closed |
| P0 | Shipment readiness/compliance gates have previously observed direct authenticated write/delete grants and organization-wide ALL policy | Remove direct client writes after migration reconciliation; only trusted evaluators/reviewers may update, with immutable evidence and independent review |
| P1 | Route-plan activation may be misrepresented as operational approval | Separate statuses: route_structurally_valid, corridor_compliance_pending/approved, capacity_confirmed, dispatch_authorized, dispatched |
| P1 | Capacity interval concurrency and idempotency are not proven by live data | Test overlapping windows, simultaneous requests, expired holds, same idempotency key replay and resource-level capacity in staging |
| P1 | Dispatch authorization is not physical dispatch | Require separate departure event from authorized carrier/driver, verified source and timestamp; keep authorization distinct |
| P1 | Custody condition/seal/discrepancy may be recorded without independent inspection | Add configurable cargo-risk rules and independent inspection/acceptance for damaged, short, overage, unknown or sealed/high-value cargo |
| P1 | No end-to-end operational data | Controlled non-production end-to-end test before a single supervised pilot |

## Required safe architecture
A single server-side eligibility decision should compose, not replace, these separate facts:
1. Market activated for the specific service/mode.
2. Origin/destination country operating packs current and approved.
3. Corridor dossier approved and valid for direction, mode and shipment type.
4. Mandatory corridor controls have current sources/evidence and reviewer notes.
5. Customs/broker/permit/commodity controls satisfied where applicable.
6. Partner identity, compliance, exact-leg capability and service-area evidence current.
7. Exact-leg assignment and physical capacity reservation confirmed.
8. Warehouse inventory and handover evidence reconciled where required.
9. Driver/vehicle and dispatch authorization valid where applicable.
10. Dispatch departure, tracking, custody handovers and independently verified POD recorded as separate events.

The decision should return explicit blockers and evidence references, not a generic `ready=true`. Any missing, expired, unknown or unreviewed requirement must fail closed. A platform-wide admin toggle or country `is_active` flag is not sufficient.

## Release decision
**NO-GO for global/cross-border dispatch or any corridor-dependent booking based on the current production predicates.** The live functions show robust pieces, but the missing corridor activation/dossier/control predicate means the operating-country/corridor approval chain is not composed into route activation and dispatch authorization.

Do not patch production directly. Production migration history and repository SQL lineage remain materially divergent; no migration, baseline, replay, DDL or grant change is safe until the sanitized production schema manifest has been reconciled with checked-in source and deployed function definitions.

## Verification boundary
Only catalog/function-definition reads and prior live row/grant snapshots were used. No business RPC, write query, migration, test booking or dispatch was run. Next verification belongs in isolated staging after migration recovery and the corridor eligibility gate is implemented.
