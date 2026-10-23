# KRIM Customer Ecosystem — Phase 2 Location, Coverage & Service Discovery Audit

**Audit date:** 2026-10-23  
**Repository:** `rimjhimkrn-web/logistics-saas`  
**Blueprint:** `docs/KRIM_CUSTOMER_ECOSYSTEM_14_PHASE_LOCKED_BLUEPRINT.md`  
**Status:** **AUDIT IN PROGRESS — serviceability is not yet verified**

## User-reported phase transition

The user reports that Phase 1 pages and the customer entry journey have been tested and verified. Phase 2 is now the active workstream. This report records repository and read-only database observations; it does not claim independent browser acceptance testing.

## Phase 2 objective

A customer must be able to identify a practical origin and destination (including rural/remote localities), understand whether a route/service is actually supported, and request coverage review when it is not. A geocoded place is not proof of an activated market, partner coverage, capacity, approved tariff, customs eligibility, or a delivery promise.

## Evidence inspected

### Frontend route selection

Canonical shipment intake reviewed: `public/shipper/booking-request.html`.

- The page uses Photon geocoding (`photon.komoot.io`) for worldwide place search.
- Search results are selectable and the chosen place data is passed to `krim_create_global_shipment_idempotent`.
- The form distinguishes domestic from cross-border based on selected country codes and prevents submitting without a selected place.
- UI copy correctly says geocoding does not guarantee coverage, customs clearance, carrier availability, transit time or price.
- No confirmed serviceability check is performed in the inspected place-search flow before shipment-request creation.
- The current external geocoder is a third-party dependency and needs a documented fallback, failure state, and data-handling review. Its result list is not KRIM's authoritative location or service directory.
- The related quote page `public/shipper/rate-calculator.html` explicitly states approved tariff checks and does not promise every service profile in every country. That does not substitute for location/lane coverage validation.

### Read-only production database snapshot

Inspected the existing canonical structures; no database writes or migrations were made.

| Entity | Rows | Active rows | Interpretation |
|---|---:|---:|---|
| `krim_markets` | 6 | 6 | India, UAE, Germany, UK, Singapore and US are configured as active markets; active configuration alone is not proof of operational coverage. |
| `krim_locations` | 32 | 32 | All 32 rows are active; 30 have `location_type=city_hub`, and 2 have no location type. |
| `krim_partner_service_areas` | 0 | 0 | No partner coverage records currently substantiate service areas in this table. |
| `krim_route_options` | 0 | 0 | No persisted route options currently substantiate routable lanes in this table. |
| `krim_route_constraints` | 0 | 0 | No constraints are currently recorded in this table; zero rows must not be interpreted as zero restrictions. |
| `krim_customer_service_requests` | 0 | 0 | No existing coverage/service inquiry records were found. |

Existing database structures include market, location hierarchy, partner service areas, route constraints/options, country localization, and customer service requests. Relevant RPCs include `krim_create_global_shipment_idempotent` and `krim_submit_customer_service_request`. Their authorization, record ownership, inputs and side effects must be reviewed before wiring a new customer action; no RPC was invoked as part of this audit.

## Current assessment

**Phase 2 exit gate: NOT MET.**

1. Country/market records exist for six countries, but coverage of all countries, regions, cities and rural areas is not established.
2. The current place search is geographic discovery, not a KRIM-managed canonical hierarchy or serviceability check.
3. No partner service-area or persisted route-option rows are available to prove service coverage from the inspected tables.
4. There is an existing customer service-request pathway, but no records exist and its suitability for unsupported-location/coverage inquiries must be validated.
5. No customer-facing path has yet been independently tested for an unsupported rural locality, ambiguous place, international lane, empty result, geocoder outage, or a coverage inquiry reference.

## Required implementation sequence

1. Review RPC definitions and RLS/authorization for locations, route checks, partner service areas, and `krim_submit_customer_service_request`; confirm the correct customer identity/profile mapping and do not assume its foreign-key types.
2. Define one authoritative serviceability response with distinct outcomes such as **supported**, **coverage review required**, **unsupported/restricted**, and **temporarily unable to check**. A supported geographic result alone must never produce a supported-service outcome.
3. Preserve exact customer-entered locality/address when no canonical city/hub matches; never silently replace a village or remote area with a nearby city.
4. Connect a real coverage inquiry to an authorized server-side operation with a traceable reference and clear next steps. Avoid collecting unnecessary personal data and avoid claiming an inquiry is accepted until the backend confirms it.
5. Add source-level tests for configured, unsupported, ambiguous and international routes; empty results; third-party search outage; duplicate submissions; and invalid/unselected results.
6. Use only approved and evidenced coverage, tariffs, partner/service capability and applicable restrictions to present service choices. Unknown data must remain **unverified**, not be treated as availability.
7. Record deployed browser tests and backend evidence before closing Phase 2.

## Change safety

- Read-only database inspection only; no production records, policies, schemas or secrets were changed.
- No pages were deleted or duplicated as part of this audit.
- Keep the existing canonical shipment intake route. Do not introduce a second shipment or quote data model to implement coverage review.
- Apply the approved global interface standard to any Phase 2 UI changes.
- Do not label Phase 2 complete until deployed acceptance gates pass.

## Next action

Continue Phase 2 by reviewing the existing service-request RPC implementation and its identity/authorization contract, then implement a safe coverage-review path and serviceability messaging in the canonical shipment intake page. Keep the phase open until evidence is collected.
