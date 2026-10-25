# KRIM Logistics — Step 2: Global Foundation Audit

Audit date: 2026-10-25  
Environment: Supabase production project `ebltviniygljwwseplph`  
Status: **In progress — master-data gaps and market-activation conflicts remain.**

## Verified production inventory

- Countries: 6 (India, United Arab Emirates, Germany, United Kingdom, Singapore, United States); all six rows have ISO2/ISO3 codes, default currency, default time zone, and `is_active=true`.
- Markets: 6 rows, each with country, currency, and time zone populated.
- Currencies: 6 active currencies.
- Locations: 32, with no missing country, city, or time-zone values in the aggregate check. Coverage is limited to the six configured countries and is not comprehensive geographic coverage.
- Transport modes: 6 active catalog modes (road, rail, ocean, air, warehouse, multimodal).
- Languages: initially empty. Seeded English (`en`) and Hindi (`hi`) as active because these are the two interface languages currently supported. The migration is committed and applied.
- Country localization: 0 rows; locale-specific address/phone/measurement configuration is not yet populated.
- The country, market, currency, language, location, localization, and transport-mode tables have RLS enabled. Authenticated read policies exist; no public anonymous-read policy was found in the policy inventory.

## Change made and verified

Migration `20261025142414_seed_supported_global_languages.sql` is committed to GitHub and the Supabase migration history records version `20261025142414` as applied. A follow-up query confirmed the two active language rows:
- English — `en`
- Hindi — `hi`

Other languages were not marked active because full application translations have not been verified.

## Critical activation inconsistency — preserved for safe resolution

The market table reports `status='active'` for all six markets, but `krim_market_settings.market_activation` says:
- India: active
- United Arab Emirates: inactive
- Germany: inactive
- United Kingdom: inactive
- Singapore: inactive
- United States: inactive

I have not silently changed these flags. Before resolving the conflict, dependent functions and frontend gating must be checked so a status correction does not unintentionally enable or disable real booking flows. This is not evidence that service is operational in all six countries.

## Step 2 exit criteria still open

1. Expand the country master catalogue beyond six countries using a verified country/ISO source and correctly map currencies/time zones; do not mark all countries operational merely because they exist in the catalogue.
2. Resolve market `status` versus `market_activation` setting inconsistency after checking every dependent function and UI gate.
3. Populate country localization with validated address, phone, language, currency-display, and measurement settings.
4. Define and test timezone/locale behavior, currency precision, FX handling, tax/compliance configuration, and market-specific service availability.
5. Verify that the UI and booking backend use the same market activation rules and reject unsupported/inactive markets.

## Honest scope boundary

This was a live schema/data audit plus a small language-catalogue seed. It did not create global carrier coverage, local tax/compliance configurations, FX rates, service pricing, or live payment availability. No market has been represented as fully launch-ready based on catalogue presence alone.


## Follow-up verification (2026-10-25)

- Confirmed all six market currency codes and time zones match their country master defaults.
- Confirmed `market_activation` is active only for India; UAE, Germany, the UK, Singapore, and the US remain inactive. No activation changes were made.
- The market rows' `status='active'` / `is_active=true` values appear to represent catalogue availability, while `market_activation` is the separate operational gate. The dependent frontend/backend code still needs tracing before any activation-related change.
- Confirmed `krim_locales` and `krim_country_localization` have zero rows. Country-specific formatting cannot yet be considered configured.
- The locations catalogue contains 32 active locations across six countries; this is selective coverage, not complete national coverage.
- Next gate: inspect frontend and backend market-activation checks, then add verified locale/unit-system master data and country localization without enabling non-operational markets.


## Market activation enforcement change (2026-10-25)

Migration `20261025143500_enforce_active_markets_for_shipment_booking.sql` adds a fail-closed check to `krim_create_global_shipment_from_places` with the explicit route type. Both origin and destination must match a configured country/market whose country and market catalogue rows are active and whose `market_activation` setting is active. This prevents catalogue-only countries from being treated as operational booking markets.

- Migration committed to GitHub (commit `5304bf94ee546135c0cd16f0543ed796ad0eaf51`) and applied to production via Supabase migration tooling.
- Read-only post-change verification confirmed the function contains activation checks and the expected origin/destination rejection messages.
- The same verification confirmed India is the only operational booking market; UAE, Germany, UK, Singapore, and US remain disabled.
- This is database-level definition/configuration verification, not an authenticated browser end-to-end test. A real customer booking test remains in the end-to-end test phase.
