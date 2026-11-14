# KRIM Logistics — Global Operating Architecture and Market Activation

## Product claim

KRIM is designed as a global logistics operating-system platform. It is **global-ready by architecture**, not universally operational in every country. A country in the ISO catalogue, a configured country pack, or a corridor record does not establish legal permission, partner coverage, rates, bookability, or fulfilment capability.

KRIM must never claim worldwide operational coverage until each advertised country, route, service, and partner combination has passed the applicable activation gates.

## Global platform requirements

The platform architecture must support:

- ISO 3166 country and area identifiers, with jurisdiction and territory distinctions.
- Country, state/province, city, postal-code, and service-location hierarchies.
- Localized addresses, phone numbers, languages, time zones, and currency metadata.
- Country-specific legal, tax, privacy, licensing, customs, sanctions, safety, insurance, and consumer-protection assessments.
- Road, rail, air, ocean, multimodal, warehousing, customs, forwarding, and last-mile service scopes.
- Origin/destination corridors with leg-level partner, customs, documentation, and compliance eligibility.
- Local payment-provider eligibility, currency/FX, settlement, refunds, and invoicing controls.
- Localized customer and partner experiences, notifications, documents, and operational timestamps.
- Auditable evidence, review expiry, maker-checker approvals, and server-side activation gates.

## Market activation lifecycle

Each market is governed independently:

1. Catalogue — jurisdiction exists in the country/area registry.
2. Setup — verified jurisdiction metadata and localization are configured.
3. Regulatory assessment — authoritative sources and qualified local legal/tax/compliance reviews are recorded.
4. Partner acquisition — suitable providers are identified for each service and location.
5. Partner verification — identity, licences, insurance, capacity, and operational capability are checked.
6. Commercial readiness — rates, contracts, payment/funds-flow eligibility, support, and dispute handling are approved.
7. Operational testing — booking, handoff, milestones, tracking, documents, delivery, invoicing, and exception workflows pass end-to-end tests.
8. Activation — authorized independent approvers enable the market and eligible service/corridor combinations.
9. Continuous monitoring — evidence expiry, partner status, route restrictions, incidents, and regulatory changes can suspend eligibility.

No catalogue or frontend setting may bypass the server-side activation gate. Activation must be scoped to the specific market, service, location, and corridor that have passed review.

## Current verified baseline (2026-11-14)

- Country/area catalogue baseline: 249 ISO alpha-2 entries.
- Country operating-pack records: 249 catalogue/configuration records; their existence is not evidence that every jurisdiction's controls have been researched and approved.
- Market register: 6 records.
- Configured service locations: 32.
- Network corridor catalogue: 7 records.
- Existing country-catalogue audit records India as the only operationally activated market at the time of that audit; confirm current live database status before making any current-market availability claim.
- Country-catalogue audit reports that newly seeded records did not have inferred default currency, phone code, or time zone, and that alpha-3 codes were not populated for those newly seeded rows.

These figures are infrastructure/catalogue counts, not live coverage counts. They must not be presented as active partners, active routes, or worldwide service availability.

## Release and launch rule

KRIM may describe itself as a **global-ready logistics platform** when its shared architecture supports international markets and its controls remain market-specific. Public service availability must be limited to combinations that are currently activated and supported by verified partners.

A global launch claim such as "available in every country" or "universal logistics coverage" is prohibited unless independently evidenced for every relevant market and service. No software change can replace local legal advice, licences, commercial contracts, insurance, payment-provider approval, customs expertise, or real partner capacity.

## Immediate engineering work

1. Reconcile the country catalogue with authoritative ISO identifiers and verified metadata; do not infer multi-time-zone or multi-currency facts from a single default.
2. Build country/territory localization records with provenance and review dates.
3. Verify market, service, location, partner, rate-card, payment, and corridor activation gates are consistent across all booking and quote entry points.
4. Test role permissions, evidence expiry, two-person approvals, and fail-closed behavior.
5. Run end-to-end tests per activated corridor and service before enabling public availability.
6. Maintain a market-by-market readiness register and publish only verified service coverage.

## Operating principle

**Build global by architecture. Activate markets by evidence.** India is the initial operating focus. Other markets remain catalogue-only or in readiness until their own gates are satisfied.
