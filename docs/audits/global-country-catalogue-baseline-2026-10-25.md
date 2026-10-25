# KRIM Logistics — Global Country Catalogue Baseline
Date: 2026-10-25

## Change
Added 51 ISO 3166-1 country-code catalogue records to `public.krim_countries`, preserving the six existing country rows. Source standard: ISO 3166-1 alpha-2 and alpha-3 country codes; see https://www.iso.org/iso-3166-country-codes.html.

## Production verification
- Country records: 57 total.
- Existing active country records: 6.
- Newly added inactive catalogue-only records: 51.
- New records intentionally have no inferred default currency, phone code, or time zone.
- No additional market was activated. Market activation remains a separate operational readiness decision; the prior verified state was India only.

## Important limitation
This is a baseline expansion, not a complete 249-entry ISO catalogue and not proof of global operational readiness. The catalogue must be expanded to the full current ISO 3166-1 set using a maintained authoritative dataset. Country-level currencies, phone metadata, time zones, sanctions/trade controls, pricing, local service coverage, payment support, and customer/partner workflows must be independently validated before activation.

## Launch impact
No shipment, payment, partner, or historical operational records were modified by this seed. Newly added countries remain inactive to avoid representing unsupported lanes as bookable.
