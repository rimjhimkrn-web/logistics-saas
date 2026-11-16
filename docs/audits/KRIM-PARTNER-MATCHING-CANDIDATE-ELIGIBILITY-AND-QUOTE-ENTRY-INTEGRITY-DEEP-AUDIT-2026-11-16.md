# KRIM Partner Matching, Candidate Eligibility and Quote-Entry Integrity Deep Audit — 2026-11-16

## Executive decision

**NO-GO for live automated partner matching, availability claims, partner bidding and shipment execution.**

This is a read-only deep review of the live matching orchestration function, location-coverage scoring helper, shipment/leg capability helpers, legacy and leg-specific partner quote submission functions, customer quote-list RPC, relevant table schemas, ACLs and production record counts.

No matching run was created, no opportunity or quote was submitted, no partner was notified, no capacity was reserved, and no production data, schema, policy, grant, function or partner status was changed.

## Live production snapshot

| Object | Rows |
|---|---:|
| Shipments | 18 (8 draft, 3 quoted, 6 confirmed, 1 closed) |
| Partner capabilities | 1 |
| Partner service areas | 0 |
| Partner match runs | 0 |
| Partner match results | 0 |
| Partner opportunities | 3 |
| Currently open opportunities with a future/no deadline | 0 |
| Partner-submitted quotes | 0 |
| Partner capacity availability | 0 |
| Partner capacity commitments | 0 |
| Capacity reservations | 0 |

The existing capability is pending/inactive. No partner currently qualifies for live commercial service. The matching engine has no production outcome history to validate candidate quality, precision, recall, fairness or reliability.

## Positive controls confirmed

### Matching function exposure

- `krim_internal_create_partner_matching_run(bigint,bigint)` is SECURITY DEFINER and executable by `service_role`, not anon or authenticated.
- It validates the orchestration run and source request, requires customer organization, positive cargo weight, active origin/destination locations and an active transport mode, and checks that the shipment belongs to the customer organization.
- It creates a match-run snapshot and stores candidate results separately.
- Candidate selection requires a verified active transport capability, matching mode/service, effective dates, maximum weight, active partner lifecycle, verified partner identity and persisted compliant status.
- It requires either both endpoint coverage scores or a matching active corridor/lane service-area record.
- The location score helper checks active service-area scope, mode/service and effective dates, and separately allows verified capability country/region coverage.
- The leg quote submission function checks current compliance with `private.krim_partner_compliance_is_current`, validates the opportunity/shipment/leg/active route-plan relationship, blocks non-empty free-form special cargo requirements pending canonical evaluation, and checks exact-leg capability.
- The customer quote-list RPC re-evaluates partner identity, current compliance and shipment capability at read time; it returns separate eligibility booleans and requires access to every requested shipment.
- Customer quote listing is SECURITY DEFINER but executable by authenticated users only; the internal matcher and score helper are service-role-only.

## Findings

### P0 — Matching uses persisted compliance status, not current evidence validity

The internal matcher filters on `o.partner_compliance_status = 'compliant'`, but does not call `private.krim_partner_compliance_is_current(organization_id)`.

That means the matcher can write a candidate result for an organization whose stored compliance label remains compliant even though the latest compliance review/evidence has expired or is no longer current. Other downstream paths may later reject the partner, but the match result itself is stale and can mislead internal operations or future consumers.

**Required remediation:** call the authoritative current-compliance helper inside the candidate predicate and fail closed for suspended/restricted/non-current organizations. Test expired evidence, rejected/revoked review, lifecycle suspension and compliance-status drift.

### P0 — Candidate generation does not verify live capacity or availability

The matcher does not query `krim_partner_capacity_availability`, `krim_partner_capacity_commitments`, `krim_capacity_reservations` or an equivalent date/equipment-specific capacity source.

It only checks the capability's maximum weight. It therefore produces capability/coverage candidates, not partners proven to have a vehicle, vessel, slot, warehouse resource, equipment or available quantity at the requested operating time.

**Required remediation:** retain a clearly named *potential capability match* stage, then perform a separate atomic, date/equipment/quantity-specific capacity check and reservation before representing capacity as held or confirmed. Candidate scores must never be described as available capacity.

### P1 — Matching does not enforce market activation or corridor approval

The matcher validates active location and transport-mode catalogue rows. The endpoint coverage score does not consult country operating-pack approval or market activation controls. The corridor/lane shortcut checks an active partner service-area row and matching metadata endpoints/countries, but does not join to an approved corridor dossier and its current mandatory controls.

A structurally active catalogue location or a partner's service-area row is not legal/operational permission to serve that route. This is material because the current country packs remain research_pending and corridor candidates remain draft.

**Required remediation:** before any customer-visible candidate or quote, enforce approved origin and destination country operating packs, active market controls, exact approved corridor dossier and current applicable controls. Cross-border matching must additionally require origin and destination regulatory/customs readiness. No generic country-level fallback should bypass a blocked corridor.

### P1 — Shipment-wide legacy quote submission omits current compliance check

The live `krim_submit_partner_quote` function checks persisted partner verification, lifecycle and compliance status labels, plus a verified active capability and shipment coverage. Unlike the leg-specific quote submission function, its body does not call `private.krim_partner_compliance_is_current`.

The customer quote-list RPC subsequently suppresses quotes that fail current compliance, but this is not a substitute for rejecting an ineligible quote at submission time. The legacy route must fail closed even when called directly.

**Required remediation:** add the current-compliance helper and any required current service-area/market/corridor gates to the legacy quote submission path, or retire that path in favour of the stricter leg-specific path after all callers and migration dependencies are reconciled.

### P1 — Shipment-wide quote submission has no service-area row check

The shipment-wide capability helper verifies active origin/destination countries, active mode and capability country/region coverage. It does not require an approved, currently effective `krim_partner_service_areas` row. The leg-specific path likewise relies on the capability helper rather than requiring a service-area approval record.

The matching engine's location score can also be satisfied by capability-only country coverage. This creates two potential sources of geographic authority: approved service-area workflow and capability country/region fields.

**Required remediation:** define one authoritative coverage contract. If approved service areas are mandatory, enforce them consistently in matching, both quote-submission paths, quote eligibility and award/dispatch. If capability country/region is intentionally sufficient, document that decision and ensure its evidence, independent approval, expiry and revocation are equivalent to the service-area workflow. Do not mix both models implicitly.

### P1 — Match result status “eligible” overstates what has been established

The matcher inserts `match_status='eligible'` and uses eligibility reason labels such as `verified_partner` and `verified_weight_capacity`. The actual predicates do not establish current compliance evidence, legal corridor activation, equipment compatibility, cargo restrictions, insurance limits, operating schedule or available capacity.

**Required remediation:** rename or map this state to `potential_candidate` / `capability_match` until all mandatory controls are evaluated. Persist each passed/failed/unknown gate with evidence version and evaluation timestamp. A separate state should represent partner-confirmed capacity; another should represent a confirmed assignment.

### P1 — Opportunity is created even when zero partner candidates are found

The matcher creates or reuses an open partner opportunity before candidate generation and records a completed match run even when zero candidates are inserted. This can leave an opportunity open for four hours with no eligible partner recipients. It is not necessarily a security bypass, but it creates a misleading operational state and can cause staff/customer expectations that sourcing is underway with a viable network.

**Required remediation:** distinguish `no_eligible_candidates` from `sourcing_open`; do not publish an opportunity to partners or customers without an eligible recipient set. Provide an explicit no-coverage outcome and controlled manual review path. Ensure retries do not extend deadlines or duplicate opportunities unexpectedly.

### P2 — Capability matching does not fully evaluate cargo/equipment constraints

The shipment-wide matcher uses weight and service/mode but does not evaluate dimensions, volume, vehicle body/equipment, temperature, hazardous/restricted goods, insurance coverage or detailed handling requirements. The leg-specific quote path blocks any non-empty free-form requirements until a canonical evaluator exists; this is safer than silently accepting unknown requirements.

**Required remediation:** adopt structured, versioned cargo requirements and capability attributes. Unknown or unsupported requirements must return review_required/no_match, not pass by omission. Keep the leg-specific fail-closed behavior until that evaluator is independently tested.

### P2 — Ranking score is not an operational reliability rating

The location helper scores location, market, region and country matches, and also capability coverage. This is a geographic/capability heuristic, not evidence of on-time delivery, service quality, safety or partner reliability. There are no completed shipment outcomes in the matching result history.

**Required remediation:** label the score as geographic/capability fit only. Do not publish partner ranking or reliability claims until there are sufficient independently verified completed-shipment observations, transparent denominators, dispute correction and bias/fairness review.

### P2 — Security-definer search path needs hardening review

The internal matcher and public location-score helper use `SET search_path TO 'public','pg_temp'`. Their exposed execution ACLs are restricted, which reduces attack surface, but privileged code should prefer an empty search path with schema-qualified object references. Confirm schema CREATE privileges and object qualification before any change. This audit did not attempt shadow-object testing or modify function settings.

## Required canonical matching contract

A candidate may be shown internally as a *potential partner* only after the system verifies:
1. Active registered-business partner, independently verified, not suspended/restricted.
2. Current compliance evidence and all applicable licences/insurance for the service and jurisdiction.
3. Approved capability for exact transport mode, service, cargo class, equipment, weight and dimensions.
4. Current approved geographic coverage at both endpoints or an explicitly approved exact corridor.
5. Approved origin/destination market and country operating packs, and approved corridor dossier/current controls.
6. Signed active partner agreement and current commercial terms.
7. No unresolved eligibility hold or conflicting assignment.
8. Clear, explainable gate results with evaluation timestamp and evidence versions.

Before the word **available** is used, the platform must additionally confirm time-specific equipment and quantity, subtract active reservations/commitments, account for capacity holds and expiry, and obtain partner confirmation. Before **booked/assigned**, require customer acceptance, partner acceptance and atomic capacity reservation/assignment activation. Dispatch is a separate control gate.

## Remediation sequencing and change control

1. Reconcile production migration history and the sanitized schema manifest before backend changes.
2. Consolidate the coverage authority decision (capability vs approved service-area row) and enforce it consistently.
3. Add current compliance, market/corridor and structured cargo checks to candidate generation and legacy quote submission.
4. Separate capability match, operational availability, partner confirmation, quote acceptance, assignment and dispatch states.
5. Add atomic capacity evaluation/reservation with date, equipment, dimensions/volume, quantity and competing holds.
6. Add staging-only positive and negative tests for expired compliance, revoked service area, blocked country, draft corridor, missing capability, unsupported cargo, no capacity, concurrent reservation, partner rejection, quote expiry and duplicate retries.
7. Validate match precision/recall and ranking only after real partner evidence and permissioned pilot data exist.

## Verification

- Live production catalog, function definitions, function ACLs, schemas and record counts inspected read-only.
- No matching function, quote function, award function or customer RPC invoked.
- No shipment, opportunity, quote, capacity, assignment, dispatch, partner status or customer record changed.
- No production DDL, grant, policy or migration applied.
- Existing CI results for the preceding geographic coverage audit commit `ff08515cd3b5af1591a92b1fe45c5dcb3d540ff8`: production smoke, static link audit and Pages deployment all completed successfully. These repository checks do not certify live matching behavior.

## Release gate

**NO-GO for live partner matching, availability claims, partner bidding, shipment execution and financial collection.** The current production dataset contains no approved service areas, no active verified capability, no capacity, no match results and no partner quotes. Backend remediation is blocked on migration/schema reconciliation; staging tests remain mandatory.
