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
