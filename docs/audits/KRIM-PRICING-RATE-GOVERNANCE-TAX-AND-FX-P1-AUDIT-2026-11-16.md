# KRIM Pricing, Rate Governance, Tax and FX Reliability Audit
Date: 2026-11-16

## Executive result

**NO-GO for publishing automated customer prices or relying on KRIM-generated totals as commercially complete.** The live pricing engine has a guarded, evidence-led global rate-card design, but production contains only one draft INR/ROAD/flat card and no active approved card, tax rules, FX rates, calculation runs, pricing components, quote versions or partner quotes. The current calculator is a narrow base-rate calculator, not a full logistics landed-cost engine.

## Live production inventory

- Global pricing rate cards: 1 (draft; ROAD; flat; INR)
- Active global pricing rate cards: 0
- Legacy rate cards / rate lines: 0 / 0
- FX rates: 0
- Tax rules: 0
- Pricing calculation runs: 0
- Quote pricing components: 0
- Quote versions: 0
- Partner quotes: 0

There is no production evidence of a calculated quote using the current pricing engine.

## Confirmed controls

### 1. Rate card commercial governance is meaningfully guarded

Rate card create/evidence/approval/activation routines require AAL2 and platform-admin permission. The evidence routine checks:
- active, verified registered-business provider and partner compliance status;
- verified active transport capability in both countries;
- active currency and transport mode;
- dated provider buy-rate evidence and tax-review reference;
- provider buy rate plus KRIM platform fee reconciles to the customer rate-card amount at currency minor-unit precision.

Approval requires cost evidence, tax treatment and a documented approval reference. Activation rechecks provider status/capability, route-market activation gates, effective dates and duplicate active priority combinations. This is a useful governance foundation.

## P0/P1 findings

### 1. P1 — Pricing calculator only supports flat and per-kg base rates

`krim_internal_calculate_quote_pricing` calculates:
- `per_kg`: base amount × cargo weight, subject to minimum charge;
- `flat`: base amount, subject to minimum charge.

Other rate types return an invalid calculation. It does not calculate volumetric/chargeable weight, pallet/container/vehicle/load units, distance or zone bands, minimum trip distance, fuel indexation, tolls, waiting, loading/unloading, handling, storage, customs brokerage, insurance, peak/remote-area fees or other accessorials.

For logistics use across road, rail, air, ocean and warehousing, this is not sufficient to present a complete comparable customer price. The current service tier/mode validation is also narrow: surface_express and heavy_haul map to ROAD; air_priority maps to AIR. No equivalent rail/ocean/warehouse tariff path is represented by this global rate-card create function.

### 2. P1 — Tax is hard-coded to zero in generated calculations

The calculator accepts only rate-card tax treatment `included_in_rate` or `not_applicable`, writes `tax_total=0`, and records an empty additional-tax breakdown. It does not look up the live `krim_tax_rules` table or calculate jurisdiction-specific tax.

This is not inherently wrong for a specific rate that is demonstrably tax-inclusive or legally not applicable, but it is unsafe as a general global pricing engine. A tax review reference string and tax-treatment label do not substitute for a jurisdiction-specific tax determination, invoice treatment or tax calculation. Current tax rules table is empty.

### 3. P1 — FX conversion is not implemented in the calculator

The calculator writes an empty `fx_snapshot` and calculates in the rate-card currency. The live FX table is empty. No exchange-rate source, effective-time selection, spread, rounding policy or quote-locked conversion is applied. Cross-currency display or billing must not imply a converted executable amount without an explicit FX snapshot and validity policy.

### 4. P1 — Commercial evidence/approval separation of duties is not enforced

The evidence routine stores `recorded_by`; the approval routine stores `approved_by`. The approval routine validates the evidence fields and approval reference but does not reject the same user approving the rate card they supplied commercial evidence for. The activation routine validates presence and timestamp of the approval record, but does not independently verify that the approver differs from the evidence recorder.

Require independent commercial approval for the rate evidence, with immutable identity and timestamp checks.

### 5. P1 — Rate card selection does not establish complete customer price coverage

The calculator chooses a single global rate card for exact origin/destination countries, transport mode and service tier. It supports exact country-pair selection and a preferred exact tier/fallback general tier, but no partner-specific tariff aggregation, multiple-leg sum, lane-distance pricing, local origin/destination accessorials, or quote comparison across multiple providers.

The rate-card approval routine binds one provider and reconciles buy rate plus platform fee to base rate, which is a good cost-plus foundation. But it does not create a live provider quote or establish available capacity, date, vehicle/equipment, cargo fit or service commitments. Those remain separate gates.

### 6. P1 — No rate evidence or pricing execution exists in production

Only one draft rate card exists. There are no active cards, FX/tax data, calculation runs or quote versions. The current rate card cannot be used by the calculator because it is draft and lacks commercial evidence/approval. There is no evidence that the engine has produced even one valid customer price.

## Required remediation — not applied

1. Define a canonical logistics pricing schema: route/zone/distance, mode, service, equipment, chargeable unit, weight/volume, minimums, accessorials, surcharges, discounts, tax and currency.
2. Add mode-specific chargeable-weight rules and dimensional-weight divisor/version for air and applicable parcel services; add road FTL/LTL, rail, ocean FCL/LCL and warehouse/storage pricing models separately.
3. Model partner buy-rate and KRIM fee transparently. Under the planned partner-direct model, distinguish the partner's freight price from KRIM's separately contracted referral/coordination/platform fee. Do not treat partner freight GMV as KRIM revenue.
4. Add a jurisdiction-aware tax engine with effective-dated rules, source evidence, tax-inclusive/exclusive treatment, exemption reason, place-of-supply/jurisdiction and qualified review. Do not invent tax rates or presume a tax is not applicable.
5. Add FX source, timestamp, base/quote currency, rate, spread/fees, rounding and validity; snapshot the exact rate used into immutable quote versions.
6. Enforce evidence recorder != commercial approver and independent tax reviewer where required. Record immutable evidence hashes/source references and expiry/revalidation.
7. Snapshot every pricing input, selected rate card/version, provider buy rate, KRIM fee, each surcharge, tax rule, FX rate, calculation formula version, rounding and quote validity. Customer-visible total must be reproducible.
8. Add price-change controls for fuel, tolls, waiting, demurrage, storage, customs, remote-area, reweigh/re-measurement and service changes; require customer acceptance for material changes.
9. Add staging tests for effective-date boundaries, expired/revoked sources, zero/negative/very large weight, currency minor units, tax inclusive/exclusive, missing tax evidence, FX stale/missing, concurrent overlapping rate cards, provider capability expiry, same-user approval, duplicate quote generation and exact retry payload.
10. Reconcile production migrations before schema/function changes; never enable a rate card merely to make the UI display a price.

## Release impact

**NO-GO for automated global price publication, tax-inclusive totals, FX conversion or a reliable multi-mode logistics price comparison.** The platform can continue to collect partner-submitted commercial quotes in a controlled future workflow, but no quote should be represented as a guaranteed or complete landed price unless all shipment-specific charges, tax treatment, currency and validity are explicit.

For the first domestic pilot, use a verified partner's dated, written INR quote for the exact route, cargo, vehicle/service and date, disclose inclusions/exclusions and any separately agreed KRIM fee, and have the relevant tax treatment reviewed before presenting an executable offer.

## Evidence boundaries

Read-only inspection of live pricing functions, rate-card governance routines, table definitions, ACLs and aggregate counts. No rate card, tax rule, FX rate, quote, pricing calculation or commercial approval was created or changed. No pricing calculation or approval RPC was executed. No production schema or settings were modified.
