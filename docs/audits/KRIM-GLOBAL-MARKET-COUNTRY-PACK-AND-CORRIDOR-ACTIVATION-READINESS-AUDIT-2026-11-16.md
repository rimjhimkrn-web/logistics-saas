# KRIM Global Market, Country Pack and Corridor Activation Readiness Audit
Date: 2026-11-16

## Executive result

**NO-GO for accepting live bookings across countries or claiming global operational coverage.** The platform has a structured country/market/corridor governance model and several meaningful approval gates, but the live production evidence shows no activated market, no approved country operating pack, no regulatory source records and no approved corridor dossier.

### Production readiness snapshot

- Markets in catalogue: 6
- Market activation controls blocked: 6
- Country operating packs: 249, all `research_pending`
- Country pack controls: 4,482, all mandatory and `pending` / `unknown`
- Market readiness assessments: 82
- Regulatory sources: 0
- Network corridors: 7, all `draft`
- Corridor compliance dossiers: 0
- Corridor compliance controls: 0
- Compliance rules: 0
- Shipment compliance checks: 0
- Compliance obligations: 0
- Compliance holds: 0

These are live database counts at audit time. They demonstrate that the global governance framework is not yet populated with reviewed jurisdiction evidence or activated corridors.

## Confirmed controls and gaps

### 1. Country operating packs — useful approval controls, but no country is approved

The live country pack approval function requires:
- At least one mandatory control and every mandatory control approved.
- Evidence reference, rationale, reviewer and future/absent expiry.
- Jurisdiction-matched regulatory source with current source-review status and effective dates.
- Source registration and review by different users, neither equal to the pack approver.
- A pack approver different from the reviewer of its mandatory controls.

This is a meaningful separation-of-duties design. However, all 4,482 mandatory controls remain pending/unknown, all 249 packs remain research_pending, and there are zero regulatory source records. No country pack can currently be approved.

### 2. Corridor dossier — source freshness/independence not revalidated at final approval (P1)

The corridor control review function validates source jurisdiction, review status and effective dates when a control is marked source_checked/approved. It requires source/evidence/rationale and prevents the dossier owner from approving their own controls.

However, the final corridor dossier approval function counts mandatory controls using:
- review_status = approved,
- applicability in yes/no/conditional,
- source_id present,
- evidence reference and reviewer note present,
- control expiry absent or future.

It does **not** rejoin the regulatory source registry to revalidate that the source remains current, jurisdiction-matched, independently registered/reviewed, and within its effective dates at the moment the dossier is approved. A source can be changed, expire or lose reviewed status after control review while the stored control still satisfies the dossier's final count. The final approval function also checks country packs, but this separate source revalidation gap remains for corridor controls.

Required: final approval must revalidate each mandatory control's source record, jurisdiction, review status, source effective dates, source creator/reviewer separation and evidence expiry in the same transaction. Add staging tests for source expiry/revocation/change between control review and dossier approval.

### 3. Market activation gate — source effective dates are not rechecked (P1)

The market activation gate requires:
- Active market catalogue entry.
- At least one active location and verified active partner capability.
- All mandatory market assessments approved, evidenced, reasoned and unexpired.
- A reviewed source for every mandatory requirement, including qualified legal/tax opinions for specified regulated categories.
- An approved country pack and every mandatory country control approved/evidenced.

However, the source-existence count checks source review status but does not test `effective_from` or `effective_until`. Thus an otherwise reviewed source whose legal effective period has expired can still contribute to the source count and may not block activation if the other gates pass. The country-pack approval routine checks source dates when approving the pack, but the activation gate should independently revalidate source dates at activation time rather than relying solely on an earlier approval snapshot.

Required: activation gate must check current source effective dates, source creator/reviewer independence, evidence expiry and current pack/control state atomically at both request and second approval.

### 4. Shipment compliance evaluator — zero checks can still produce clear (P0; previously identified)

The live `krim_internal_evaluate_shipment_compliance_gate(bigint)` counts failed, pending and expired checks. If all three counts are zero, it writes `clear`, including when there are **zero compliance checks at all**. It does not require a minimum applicable check set or verify that all required obligations have been evaluated.

This repeats the earlier customs/compliance P0 finding: absence of checks is treated as a clean result. It must be fail-closed until the applicable rule set, shipment-specific checks, jurisdiction, transport mode, cargo restrictions and evidence are present and current. No compliance evaluator was invoked during this audit.

### 5. Market activation has meaningful two-person approval

The request and approval RPCs require AAL2 and platform-admin permission. The requester cannot approve their own activation, and the second approval re-runs the activation gate before setting the market active. This is a positive control; it does not compensate for incomplete evidence or the source-freshness gap.

## Required remediation — not applied

1. Populate each target-country pack from reviewed official sources and qualified local legal/tax opinions as required; no blanket assumption that one country's controls apply worldwide.
2. Resolve every mandatory control with applicability, evidence, source, rationale, reviewer and expiry.
3. Revalidate source status, jurisdiction and effective dates at final country, corridor and market approval time.
4. Add a fail-closed shipment compliance baseline: determine mandatory checks from shipment origin/destination/transit jurisdictions, transport mode, cargo, service and applicable rules; zero checks must be blocked/review_required, never clear.
5. Add corridor dossier approval checks for source independence and source/evidence freshness.
6. Add market activation negative tests for expired sources, future-effective sources, revoked sources, same-user source author/reviewer, expired evidence, inactive partner capability, missing locations and country pack downgrade.
7. Add end-to-end staging tests for market request, second-person approval, suspension and reactivation after evidence expiry.
8. Keep market activation and corridor status separate from country catalogue presence. A country or city existing in reference data is not proof of legal or operational service availability.
9. Reconcile production migration history with repository migrations before applying any production schema or function changes.

## Release impact

**NO-GO for global live booking and operational claims.** KRIM can continue building a global-ready architecture, but country, corridor, mode, cargo and partner coverage must be activated only after jurisdiction-specific evidence, partner capability and operational controls are independently reviewed.

For a controlled first India pilot, the same gates must be completed for the exact domestic corridor, mode and cargo scope. India-first does not mean all-India coverage is automatically authorized.

## Evidence boundaries

Read-only inspection of live table inventories, aggregate counts, country/corridor/market approval functions and shipment compliance evaluator definition. No approval RPC was executed, no market/country/corridor status changed, no source or evidence was created, and no production schema or data was modified.
