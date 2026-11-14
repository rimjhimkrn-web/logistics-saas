# KRIM Logistics — Global Country Catalogue Baseline
Date: 2026-10-25

## Change
Seeded the complete 249-entry ISO 3166-1 alpha-2 country/area catalogue into `public.krim_countries`, preserving existing country records. The full list was sourced from the maintained datasets country-list project, whose source is ISO 3166-1 / Debian iso-codes: https://github.com/datasets/country-list/blob/main/data.csv. Official ISO overview: https://www.iso.org/iso-3166-country-codes.html.

## Production verification
- Country records: 249.
- Unique country codes: 249.
- Existing active catalogue rows: 6.
- Inactive catalogue-only rows: 243.
- Inactive rows with an inferred default currency, phone code, or time zone: 0.
- No additional market was activated.
- India is the only operationally activated market. The five other previously configured markets remain inactive for bookings.

## Scope and limitations
This completes the ISO alpha-2 country/area catalogue baseline, not global operational readiness. Newly seeded rows intentionally remain inactive and have no inferred default currency, phone code, time zone, or locale. Alpha-3 codes are not populated for newly seeded rows by this migration. The country catalogue must not be treated as service coverage.

Before activating any additional market, validate its currency and time-zone metadata, localization, applicable sanctions/trade restrictions, tax and customs requirements, payment provider/merchant eligibility, actual partner capacity, approved rates, and end-to-end booking/fulfilment/payment workflow.

## Launch impact
This catalogue seed did not modify shipment, payment, partner, or historical operational records. New catalogue entries remain inactive to avoid implying unsupported service.

## 2026-11-14 production addendum

The country reference foundation was subsequently expanded using the DataHub `core/country-codes` dataset (2026-10-15) and IANA Time Zone Database 2026f:

- 249/249 records have ISO alpha-2, alpha-3, and numeric identifiers.
- 248/249 have a calling code; the one absent source value remains null.
- 248/249 have UN M.49 region metadata.
- 253 country-currency mappings across 246 jurisdictions; 155 currency codes are in the KRIM currency catalogue. Multiple currency references are retained; no single default is inferred when multiple are listed.
- 423 country/time-zone links across 247 jurisdictions, representing 312 IANA zone names. Multi-zone jurisdictions retain all listed zones.
- Single-zone defaults were filled only where a jurisdiction had exactly one IANA zone and no existing default; all other defaults were preserved.
- The new reference tables are RLS-enabled and read-only for Data API clients; writes remain restricted to service-role/database administration.
- No market, corridor, partner capability, service area, rate card, or booking was activated.

Current operating readiness remains separate: all 6 market activation controls are blocked, all 249 country operating packs are research-pending, 0/4,482 mandatory country-pack controls are fully approved, 0 corridors are active, and 0 active verified partner capabilities are present.

Source references:
- DataHub country reference dataset: https://datahub.io/core/country-codes
- ISO 3166 overview: https://www.iso.org/iso-3166-country-codes.html
- IANA tzdb 2026f: https://www.iana.org/time-zones/releases/2026f

