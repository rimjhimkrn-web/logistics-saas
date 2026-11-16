# KRIM Global Market, Country Pack and Corridor Activation Readiness Audit
**Date:** 16 November 2026  
**Scope:** Read-only production catalogue and status review of markets, country operating packs, readiness requirements, activation controls, corridor candidates, compliance dossiers and controls. No market/corridor activation, evidence approval, shipment booking, partner action, or production data/schema change was performed.

## Executive decision
**NO-GO for operational shipment bookings on any market or corridor.** The database deliberately fails closed: all six configured markets have activation status `blocked`, all 249 country operating packs are `research_pending`, all seven corridor candidates remain `draft`, and no corridor compliance dossiers or controls were found. The six market rows marked `active` are catalogue records only; they do not mean the market is operationally enabled.

## 1. Market catalogue and activation
The six configured market catalogue entries are India (IN), UAE (AE), Germany (DE), United Kingdom (GB), Singapore (SG) and United States (US). All six have `krim_markets.status='active'` and `is_active=true`, but each matching `krim_market_activation_controls.operational_status` is `blocked`. Each carries the explicit decision note: "Fail-closed initial state; no operational activation evidence has been approved."

This distinction is essential: catalogue availability is not permission to offer, quote, book or execute logistics services in a jurisdiction.

## 2. Country operating packs and regulatory readiness
- Country operating packs: **249 total; 249 research_pending**.
- Market readiness assessments: **82 total; 82 pending**.
- Market readiness requirement definitions: **22; zero with source_review_status='approved'**.
- The operating-pack structure includes jurisdiction, version, status, legal owner and review date; control records include applicability, evidence reference, source, reviewer, review time and expiry.
- No operating pack is currently approved for operational use. No legal or regulatory conclusion can be inferred from seeded country metadata, localization, currency, timezone or country catalogue records.

## 3. Corridor candidates
Seven network corridors exist; all are `draft` and none has a compliance dossier:

| Corridor | Type | Current state |
|---|---|---|
| Ranchi–London | Cross-border candidate | Draft; no dossier |
| Ranchi–Kolkata | Domestic candidate | Draft; no dossier |
| Ranchi–Singapore | Cross-border candidate | Draft; no dossier |
| Ranchi–Dubai | Cross-border candidate | Draft; no dossier |
| Ranchi–New York | Cross-border candidate | Draft; no dossier |
| Ranchi–Frankfurt | Cross-border candidate | Draft; no dossier |
| Ranchi–Jamshedpur | Domestic pilot candidate | Draft; no dossier |

No corridor is operationally approved. The names are planning candidates, not confirmed carrier routes, service schedules, transport mode availability, customs lanes or partner coverage.

## 4. Critical readiness interpretation
1. A market marked active in the catalogue must not be surfaced as a live service market while activation control is blocked.
2. A country pack marked research_pending cannot satisfy legal-operating readiness.
3. A corridor route that is structurally valid is not necessarily legally or commercially serviceable.
4. Corridor dossier approval and current mandatory controls must be established for exact route, mode and cargo scope.
5. Customs authority clearance must be represented by authoritative evidence; KRIM internal document/broker review is not government release.
6. Partner capability and capacity must be independently verified for the exact geography, transport mode, service and operating dates.
7. Pricing/rate cards must be supported by an active approved partner/service and route.
8. Every change must be reviewed, evidenced, time-bounded and revocable; expired or withdrawn sources must close the gate.

## 5. India-first activation recommendation
Do not attempt simultaneous global activation. Use India as the first market activation candidate, but keep it blocked until the following evidence is complete:
- CA/legal review of KRIM's operating model, commercial role and GST applicability.
- Written service scope that accurately distinguishes KRIM referral/coordination from the partner's regulated transport/customs obligations.
- State and central requirements for the selected service/mode, with current official source references and reviewer notes.
- A narrowly scoped domestic pilot corridor with confirmed endpoints, mode, partner, service dates, insurance/liability, service terms and exception handling.
- Verified partner legal identity, licences/permits as applicable, insurance, capability, capacity and contract.
- Rate evidence and transparent customer/partner contracting.
- Operational readiness: dispatch, driver, tracking, warehouse (if used), POD, customer support and escalation.
- Separate authority for customs/export/import only if a later cross-border corridor is proposed.

A Ranchi–Kolkata or Ranchi–Jamshedpur candidate may be evaluated as a domestic pilot, but neither is approved by this audit. Choose only after partner evidence and service economics are established.

## 6. Cross-border expansion gates
For India→UAE or any other international corridor, require both origin and destination country operating packs, exact corridor dossier, current source-backed controls, export/import documentation and authority requirements, customs broker eligibility, mode-specific partner capability, insurance/liability, sanctions/restricted-party screening where applicable, data/privacy and tax review, and documented exception/return handling. No global market should be enabled merely because a country appears in the catalogue.

## 7. Required platform behaviour
- Show separate catalogue and operational activation states.
- Do not return live quote/booking eligibility for blocked markets or draft corridors.
- Route evaluation must include market activation, both jurisdiction packs, approved corridor dossier, applicable current controls, partner capability, capacity, customs/authority evidence and mode/cargo scope.
- Zero configured mandatory controls must fail closed as blocked/review_required, never clear.
- Any source/control expiry, suspension or revocation must invalidate cached readiness and prevent new commitments.
- Preserve a full approval event trail, reviewer independence, rationale, evidence hash/source and effective dates.
- Distinguish customer lead/enquiry from confirmed service availability.

## 8. Remediation and sequencing
1. Correct dashboard/API labels so active catalogue rows are not misrepresented as live markets.
2. Establish official-source research and legal ownership for the India operating pack.
3. Review the 22 requirement definitions and their source provenance; none currently has approved source status.
4. Build a complete India domestic pilot corridor dossier and mode/cargo-specific controls.
5. Obtain independent approvals through the established AAL2 maker-checker process.
6. Verify real partner capability, capacity, service contract and rate evidence for the exact corridor.
7. Run staging-only negative and positive activation tests, including expired evidence, revoked source, missing control, blocked market and suspended partner.
8. Only then seek explicit approval to activate a narrowly defined pilot.
9. Repeat country and corridor diligence before any cross-border launch.

## 9. Change control and release gate
This was a read-only audit. No operating packs, assessments, sources, corridor dossiers, controls, activation states or partner data were created or changed. Production migration reconciliation remains unresolved; no production schema/function fix should be applied until the migration crosswalk and sanitized schema manifest are reconciled. No real shipment, quote, partner commitment or customer promise was made.

**Release status: NO-GO for operational market/corridor bookings.** KRIM has a global market catalogue and governance framework, but no approved operating market or corridor is evidenced in the current production data.
