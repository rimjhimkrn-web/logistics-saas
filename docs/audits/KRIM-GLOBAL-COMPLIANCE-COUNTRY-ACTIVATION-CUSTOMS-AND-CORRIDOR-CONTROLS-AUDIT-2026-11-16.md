# KRIM Global Compliance, Country Activation, Customs and Corridor Controls Audit — 2026-11-16

## Scope
Read-only inspection of live production country/market, corridor, shipment compliance, partner compliance and customs schemas; RLS, table privileges, policy predicates, selected database function definitions, trigger attachments and record counts. No production writes, compliance evaluations, customs submissions or market activation actions were performed.

## Executive summary
KRIM has meaningful global-compliance architecture, including country operating packs, market activation gates, corridor dossiers, regulatory source records, partner compliance and customs workflows. The architecture is deliberately fail-closed in several critical paths. However, the live data is not ready to support a claim of operational market coverage.

Two high-priority findings:
1. All six markets have descriptive status `active`, but their separate operational activation controls are all `blocked`. Shipment creation checks the operational activation control, so an active market label does not mean it is operationally enabled.
2. Authenticated members of a shipment's customer organisation have direct INSERT/UPDATE privileges on `krim_shipment_compliance_gates`, with an `ALL` policy based on organisation membership only. This allows an organisation member to write gate state, including a potentially misleading `clear` state, outside the intended internal evaluator. This is a material compliance-integrity risk requiring staged correction.

## 1. Market and country activation status
- Market records: 6 (India, UAE, Germany, UK, Singapore, US). All have `status='active'` and `is_active=true`.
- Operational activation controls: 6; every one is `blocked`, with no activation request or approval timestamp and a fail-closed initial-state note.
- The private `krim_market_country_operational` predicate requires both active market metadata and an operational control with `operational_status='active'`, plus a successful internal activation eligibility gate.
- The shipment-write trigger calls this operational predicate for both origin and destination countries and blocks shipment writes when either market is not operationally activated.

**Conclusion:** These six records are market catalogue entries, not six live operational markets. India is not operationally activated in this snapshot. Do not advertise bookable country coverage from the catalogue status.

## 2. Country operating packs and corridor readiness
- Country operating packs: 249.
- All 249 are `research_pending`.
- Market readiness assessments: 82.
- Corridor compliance dossiers: 0.
- Corridor compliance controls: 0.
- Corridor compliance legs: no approved corridor dossier evidence was found in the inspected live records.
- Market regulatory sources and control/event tables exist, but the corridor trigger requires an active exact-location corridor, approved-for-activation dossier, mode match, approved mandatory controls with evidence/reviewer notes and a current reviewed regulatory source. It also checks country operating packs for every transit jurisdiction and blocks if a pack is not approved or mandatory controls are incomplete/expired.

**Conclusion:** No inspected corridor has the required approved dossier/control evidence. The trigger is fail-closed and blocks shipment writes when exact corridor requirements are absent. A corridor catalogue or seeded country pack is not evidence of an executable route.

## 3. Shipment compliance gate integrity — high priority
The live `krim_shipment_compliance_gates` table has RLS enabled, but:
- Authenticated role has direct SELECT, INSERT and UPDATE privileges.
- Its single `ALL` policy checks only whether the user has organisation access to the customer organisation owning the shipment.
- The policy does not visibly require compliance-management permission, an independent reviewer or a trusted worker identity.
- The table contains 6 records, each with `status='clear'`, `risk_level='low'`, and `checked_by=NULL`.

The internal evaluator `krim_internal_evaluate_shipment_compliance_gate(shipment_id)` computes status from `krim_compliance_checks` and writes the gate row. However, the inspected trigger inventory for `krim_shipments` showed market-activation and corridor-compliance enforcement triggers, not a compliance-gate integrity trigger. The evaluator's intended state can therefore be undermined if a customer-organisation member can directly update the gate table.

Additional context:
- Compliance checks: 0.
- Compliance rules: 0.
- Compliance findings/holds: 0.
- The six existing `clear` gate rows have no checked-by actor.
- The evaluator returns `clear` when there are no failed, expired or review-required checks; with no rule/check records, a clear state does not prove a substantive screening process took place.

### Required correction design (not applied)
- Revoke direct authenticated INSERT/UPDATE/DELETE on `krim_shipment_compliance_gates`.
- Replace the broad `ALL` policy with a narrowly scoped read policy, if customer visibility is required.
- Allow gate writes only through the trusted internal evaluator or a separately authorised compliance workflow.
- Record evaluator version, rule-set version, source evidence, actor/worker identity, evaluated timestamp and a deterministic input fingerprint.
- Ensure every booking/dispatch decision re-evaluates current compliance and rejects stale or manually altered gate records.
- Add staging tests proving ordinary customer members cannot write or clear gates; missing checks do not silently imply substantive compliance clearance; expired sources and changed shipment/cargo data invalidate old evaluations.

Do not patch production until migration-history reconciliation is complete.

## 4. Customs broker and document workflow
The live schema includes:
- customs cases;
- broker licences and licence review events;
- broker assignments and assignment events;
- customs document submissions and document events;
- jurisdiction requirements.

Inspected RLS policies are SELECT-only for authenticated users and scope access to the shipment customer organisation, accepted assigned broker organisation, compliance permission, or AAL2 platform administrator. Direct authenticated INSERT/UPDATE was not granted on the inspected customs tables.

Functions exist for customs case creation/transitions, broker licence submission/review, broker assignment/response/closure and document submission/review. The inspected public wrappers are SECURITY INVOKER and authenticated-callable; private internal counterparts exist for selected actions.

Live records:
- Customs cases: 0.
- Broker licences: 0.
- Broker assignments: 0.
- Customs document submissions: 0.

No real customs workflow has been exercised with live records. The schema alone does not establish country-specific customs correctness, broker authorisation or government-system connectivity.

## 5. Partner compliance
Partner compliance evidence/review tables are RLS-enabled and forced, but have no policies and no direct authenticated read/write privileges in the inspected snapshot (fail-closed). An independent-review trigger exists on partner compliance reviews. A partner compliance evidence submission function is authenticated-callable and SECURITY DEFINER; this requires a separate full function-body review of caller-bound organisation checks, file ownership/path validation, reviewer separation and expiry/currentness logic before relying on it. No partner compliance evidence/review records were present in the inspected counts.

## 6. Public claims and operating boundaries
Until country/corridor/customs activation is independently approved:
- Do not claim KRIM is operational in all six catalogue markets.
- Do not claim customs brokerage or customs clearance is provided by KRIM.
- Do not quote route availability, transit time, tariff, customs duty or compliance status without verified route/provider/source data.
- Treat country packs as research records until reviewed against current official primary sources, assigned a legal owner and approved with evidence.
- Keep shipment acceptance gated on active origin/destination markets, exact approved corridor and every relevant transit-jurisdiction pack.

## 7. Prioritised next actions
1. Fix the shipment compliance gate direct-write path as a security priority after migration reconciliation.
2. Complete India/Jharkhand/Ranchi first-market legal and operating evidence; obtain qualified legal/customs review where required.
3. Select one pilot corridor and build its exact route dossier, transit jurisdictions, transport-mode scope, regulatory source citations, mandatory controls and expiry/review schedule.
4. Activate no market until the independent evidence and approval workflow passes.
5. Verify customs broker licences against the relevant official authority and test document submission/review in staging.
6. Test all negative paths: expired licence/source, unapproved pack, missing corridor control, unsupported cargo, prohibited/restricted goods, destination/transit mismatch, revoked broker, stale compliance result and attempted customer gate tampering.

## Conclusion
The global compliance architecture has useful fail-closed controls, but the live production snapshot is a catalogue and research foundation rather than a globally operational network. All six markets are operationally blocked, all 249 country packs are research-pending, and no corridor dossier or customs activity is present. The shipment compliance gate's organisation-wide direct-write policy is a material integrity issue. No production changes were made.
