# KRIM Global Corridor Eligibility — Production Rule Matrix and Integration Blueprint — 2026-11-16

## 1. Purpose and release position
This document maps the live production corridor, country-market, partner, shipment-compliance and customs controls into a single proposed eligibility decision. It is a specification and integration plan, **not a production implementation**.

**Release status: NO-GO for operational/cross-border booking or dispatch.** Production migration history and repository SQL lineage remain materially divergent. Do not run DDL, alter grants, replace functions, replay/baseline migrations or activate markets until the sanitized production schema manifest and deployed definitions are reconciled.

## 2. Live production inventory (read-only snapshot)

| Domain | Live records | Current state / significance |
|---|---:|---|
| Markets | 6 | Activation controls: all 6 blocked |
| Market readiness requirements | 22 | Mandatory market criteria are defined |
| Market readiness assessments | 82 | Assessments exist; approval/evidence completeness still requires per-market evaluation |
| Regulatory sources | 0 | No live source records currently substantiate market requirements |
| Country operating packs | 249 | All 249 research_pending |
| Country pack controls | 4,482 | All 4,482 pending |
| Network corridors | 7 | All 7 draft |
| Corridor compliance dossiers | 0 | No approved corridor dossier exists |
| Corridor dossier legs | 0 | No corridor-country/mode leg records |
| Corridor controls | 0 | No route-specific control reviews |
| Customs jurisdiction requirements | 5 | All research_pending |
| Shipment customs cases | 0 | No shipment has a customs case |
| Customs broker licences | 0 | No verified broker licences |
| Customs broker assignments | 0 | No broker assignments |
| Customs document submissions | 0 | No reviewed customs documents |
| Shipment compliance checks | 0 | No checks recorded |
| Shipment compliance gate rows | 6 | Existing rows do not prove checks ran |

The absence of source records, dossiers, corridor controls, customs cases and compliance checks is a hard operational blocker. A country or location being catalogue-active is not an operational approval.

## 3. Rule matrix: authoritative source, decision and enforcement

| Gate | Required pass condition | Existing production source | Existing evaluator / control | Integration requirement |
|---|---|---|---|---|
| Market catalogue | Market and country active; correct market-country relationship | `krim_markets`, `krim_countries` | `krim_internal_market_activation_gate(market_id)` checks catalogue active | Resolve market for each origin/destination jurisdiction and direction; do not infer from global active flags |
| Market operational activation | `krim_market_activation_controls.operational_status='active'` with request/approval evidence | `krim_market_activation_controls`, `krim_market_activation_events` | `krim_admin_request_market_activation`, `krim_admin_approve_market_activation`; internal gate checks readiness | Require active activation state at booking and recheck at dispatch; suspension immediately blocks new dispatch |
| Market readiness | Every mandatory market requirement approved, current, evidence-backed, source-backed; legal domains require qualified legal/tax opinion | `krim_market_readiness_requirements`, `krim_market_readiness_assessments`, `krim_market_regulatory_sources` | `krim_internal_market_activation_gate` | Bind assessment and source IDs + hashes/versions into eligibility snapshot; reject expired or missing sources |
| Country operating pack | Pack approved; every mandatory control approved with applicability, evidence, reviewer note and valid source; independent reviewer | `krim_country_operating_packs`, `krim_country_pack_controls`, `krim_market_regulatory_sources`, `krim_country_pack_events` | `krim_admin_review_country_pack_control`, `krim_admin_set_country_pack_status`; market gate checks pack | Require pack for every jurisdiction in itinerary; enforce pack review date and control expiry at dispatch |
| Corridor definition | Corridor active/approved for exact direction, origin/destination and transport mode | `krim_network_corridors` | No corridor approval/evaluator RPC surfaced in public function inventory | Add explicit corridor lifecycle, directional mode matching and immutable approval events; current 7 corridors are draft |
| Corridor dossier | Approved dossier for exact corridor, mode and cargo scope; not expired / past next review | `krim_corridor_compliance_dossiers`, `krim_corridor_compliance_legs` | No corridor dossier evaluator/reviewer RPC surfaced | Implement reviewer workflow and require exact itinerary country sequence, border crossings, mode and cargo applicability |
| Corridor controls | Every mandatory/applicable control approved with source, evidence reference, reviewer note, independent reviewer and valid expiry | `krim_corridor_compliance_controls`, `krim_corridor_compliance_events`, `krim_market_regulatory_sources` | No corridor control review RPC surfaced | Add AAL2 platform legal/compliance review RPC, immutable events and qualified opinion rule for legal domains |
| Shipment/cargo compliance | Required shipment-specific checks complete; no failed, pending, expired or blocked check | `krim_compliance_checks`, `krim_shipment_compliance_gates` | `krim_internal_evaluate_shipment_compliance_gate(shipment_id)` | Current evaluator treats zero checks as clear. Replace with requirement-derived expected check count and fail closed when checks are missing |
| Partner identity/compliance | Active registered business, independently verified, latest current approved compliance review | `krim_organizations`, `krim_partner_compliance_reviews`, `krim_partner_compliance_evidence` | `private.krim_partner_compliance_is_current(org_id)` | Recheck for every assigned leg; expiry/suspension invalidates future dispatch |
| Partner capability | Verified active capability for exact mode and each required country, weight and effective dates | `krim_partner_capabilities`, `krim_locations`, `krim_countries` | `private.krim_partner_capability_covers_shipment_leg(org_id,leg_id)` | Preserve exact-leg match; supplement with verified service area and cargo-specific restrictions |
| Customs applicability | Determine whether import/export/transit/customs procedures apply to shipment, commodity, value and direction | `krim_customs_jurisdiction_requirements`, shipment cargo and route | Current requirements are all research_pending; no integrated route evaluator | Build applicability decision from approved current legal requirements; unknown = block/review, never assume not applicable |
| Customs broker | Required broker is licensed for exact jurisdiction and licence valid; assignment accepted | `krim_customs_broker_licenses`, `krim_customs_broker_assignments` | `krim_customs_broker_license_submit/review`, `krim_customs_broker_assign/respond/close` | When broker is mandatory, require verified current licence, accepted assignment and correct shipment/jurisdiction |
| Customs documents and release | Required documents accepted and customs case reaches explicit cleared/released state | `krim_shipment_customs`, `krim_customs_document_submissions`, events | `krim_customs_document_submit/review`, `krim_customs_transition_case` | Block dispatch until applicable documents accepted and authority release recorded; submitted is not accepted/cleared |
| Dispatch prerequisites | Exact-leg assignment, partner, confirmed physical capacity, driver/vehicle where road, handover and prior-leg custody | Assignment, capacity, driver, warehouse, custody and dispatch authorization tables | `krim_authorize_leg_dispatch`; `private.krim_leg_dispatch_authorization_is_current` | Compose all country/corridor/cargo/customs gates into the dispatch currentness predicate |

## 4. Important existing evaluator: market activation
Live `public.krim_internal_market_activation_gate(market_id)` already exists as a non-publicly executable SECURITY DEFINER helper. It checks:
- Active market catalogue status.
- At least one active service location in the country.
- At least one verified active partner capability in the country.
- All mandatory market readiness assessments approved with evidence/reviewer note and current expiry.
- Reviewed sources for mandatory requirements, including qualified legal/tax opinions for specified legal domains.
- A country operating pack exists, is approved, and all mandatory country-pack controls are approved with current evidence.

Market activation approval requires AAL2, platform-admin permission, a 30-character rationale, a different administrator from the requester and a fresh passing gate snapshot.

**Critical integration gap:** this market activation gate is not invoked by the live route-plan evaluator, route-plan activation or dispatch authorization/currentness helper inspected in the preceding operational RPC review. Thus the activation workflow exists, but the execution path does not compose it.

## 5. Important existing shipment compliance evaluator flaw
Live `public.krim_internal_evaluate_shipment_compliance_gate(shipment_id)` counts only existing rows in `krim_compliance_checks`:
- Failed/rejected/non-compliant/blocked rows => blocked.
- Pending/in-review/review-required rows => review required.
- Expired rows => expired.
- Otherwise => clear.

With **zero check rows**, it returns `clear`. It does not derive expected mandatory checks from country, corridor, mode, commodity, customs requirements or partner/vehicle context. Therefore zero checks is indistinguishable from all required checks passed.

**P0 correction required:** expected controls must be generated from an approved rule catalogue. Evaluation must compare expected versus completed controls and fail closed on missing, unknown, unreviewed, stale or expired checks. A clear result must include the complete expected-control set, evidence/source references, evaluator version and timestamp.

## 6. Proposed unified decision contract
Create a private, non-exposed evaluator (exact name/signature to be decided after schema reconciliation), returning structured evidence and blockers. Conceptual response:

```json
{
  "eligible": false,
  "decision": "blocked",
  "scope": {
    "shipment_id": 0,
    "route_plan_id": 0,
    "route_plan_version": 0,
    "leg_id": 0,
    "direction": "origin-to-destination",
    "transport_mode": "ROAD"
  },
  "gate_results": [
    {
      "gate": "market_activation",
      "status": "blocked",
      "jurisdiction": "IN",
      "source_ids": [],
      "evidence_refs": [],
      "valid_until": null,
      "blockers": ["Market activation is blocked"]
    }
  ],
  "missing_controls": [],
  "stale_controls": [],
  "evaluated_at": "database timestamp",
  "rule_version": "immutable evaluator/rule-set version"
}
```

Do not expose internal sensitive evidence paths to customers or partners. Return role-appropriate blocker codes and safe messages; preserve full references in restricted audit records.

### Decision semantics
- `eligible=true` only when every required gate is explicitly `passed`.
- `not_applicable` is valid only when a reviewed applicability rule and rationale prove it; unknown is not not-applicable.
- `pending`, `missing`, `expired`, `suspended`, `rejected`, `unknown` and evaluator errors all block.
- Each result is scoped to exact shipment, route-plan version, leg, partner, mode, direction, cargo classification and intended execution window.
- Re-evaluate on booking, assignment, capacity reservation, dispatch authorization and actual dispatch. A stale prior snapshot must not authorize a later event.
- Persist a versioned decision snapshot and append-only events. Do not let customer/partner clients write gate outcomes.

## 7. Integration sequence
1. **Migration/source reconciliation (P0):** reconcile production migration versions and checked-in migration files using the sanitized schema manifest; inspect deployed function bodies against repository source. No production DDL before this step.
2. **Rule catalogue completeness (P0):** obtain current authoritative sources and qualified legal/tax opinions for each required legal domain; convert research-pending pack/corridor/customs requirements into reviewed controls. No invented regulatory assertions.
3. **Market gate composition (P0):** route evaluator and dispatch currentness must invoke the market gate for every jurisdiction used by the itinerary; also enforce market operational status active, not just catalogue status.
4. **Corridor dossier workflow (P0):** create corridor legs and dossiers for exact route direction/modes/cargo scopes; reviewer controls with independent review and expiry.
5. **Shipment compliance expected-control engine (P0):** replace zero-checks-means-clear behavior with expected-vs-completed checks; bind cargo/commodity/customs requirements.
6. **Customs integration (P1):** determine customs applicability per route/commodity; require licensed broker, accepted assignment, accepted docs and official release where mandatory.
7. **Partner and physical execution composition (P1):** retain exact-leg partner compliance/capability, confirmed physical capacity, road driver/vehicle, warehouse handover and preceding-leg accepted custody.
8. **State machine and audit (P1):** distinct states for route_structurally_valid, corridor_compliance_pending, compliance_approved, capacity_confirmed, dispatch_authorized, dispatched, in_transit, delivered_verified. No shortcut from route validation to booking or dispatch.
9. **Staging tests (P1):** missing pack, suspended market, draft corridor, absent dossier, stale source, unknown control, expired control, wrong direction, wrong mode, restricted cargo, customs pending, expired broker licence, missing document, unaccepted release, partner capability expiry, capacity conflict, dispatch handover missing, custody rejected, idempotency replay and market suspension between authorization and departure.
10. **Supervised pilot (P2):** only after every prior gate passes, one verified low-risk domestic corridor and one partner, human operations control, customer/provider contract directly, no KRIM freight custody.

## 8. Release criteria
- Every active market has a current approved operating pack and mandatory market readiness assessment/source evidence.
- Every active corridor has approved directional dossier, exact country/mode legs and current mandatory control reviews.
- No zero-checks-means-clear path.
- Dispatch authorization and currentness call the same authoritative eligibility decision, with no bypass RPC.
- Customs applicability and clearance enforced where required.
- Gate records are not directly writable by ordinary authenticated users.
- Audit events and decision snapshots are immutable, scoped and reproducible.
- Staging integration and negative tests pass; production migration lineage is reconciled.
- Operations team can explain every blocker and evidence requirement to customer/partner without exposing sensitive records.

## 9. Verification boundary
Read-only production catalog, table-count and function-definition queries only. No writes, business RPC execution, DDL, grants, migrations, market activation or corridor approvals were performed. This document intentionally does not claim that a corridor is approved or legally cleared.
