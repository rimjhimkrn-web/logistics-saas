# KRIM Customer Ecosystem — Global Readiness Retrofit
Date: 2026-11-21
Status: Implemented on staging branch for Customer Ecosystem pages 1–12; review and runtime QA pending.

## Scope delivered in this batch

The following 12 customer-facing pages now load the shared read-only global customer context runtime:

1. Customer OS Home
2. Customer Portal Overview
3. Customer Onboarding
4. Customer Verification
5. Company Profile
6. Customer Workspace
7. Team Members
8. Workflow Hub
9. Address Book
10. Locations
11. Cargo Profiles
12. Shipping Preferences

Shared runtime: `public/customer-os/assets/customer-os-globalization.js`

The runtime is linked on all 12 pages with the public Supabase client configuration and reads saved regional preferences for an authenticated user. It exposes locale-aware helpers for currency, numbers, dates, date-times, weights and lengths. The Customer OS homepage language selector reads and persists the account language preference when the user is signed in, while retaining a device-local fallback. The runtime itself is read-only; it does not activate markets or translate page content by itself.

The Customer OS homepage remains the single customer-facing language selector. Its selector catalogue has been expanded to 100+ language choices, with right-to-left document direction support for RTL languages. Machine translation availability and quality remain dependent on the translation provider and must not be described as professionally localized content.

## Page-specific changes

- **Cargo Profiles:** weight can be entered in kilograms, metric tonnes, pounds, US short tons or UK long tons. Values are normalized and stored as canonical kilograms. Additional transport/service preference categories are available. Staging review bypasses authentication, exposes no personal cargo records and disables all form controls and writes. Production still requires a valid authenticated session.
- **Shipping Preferences:** broad country/region, browser-supported currency, language and IANA time-zone options; metric/SI, US customary and UK imperial systems; additional regional date/number formats; expanded logistics preferences and notification channels. These are personal display/preferences, not a statement of market availability, payment capability or service coverage.
- **Address Book, Locations, Onboarding and Company Profile:** copy now explicitly accounts for country-specific address conventions, administrative areas, postal-code applicability, international contact formats and jurisdiction-specific business/tax identifiers.
- **Customer Workspace:** removed the rupee-specific finance icon in favour of a neutral global currency symbol.

## Global acceptance rules for all future customer pages

1. Store event timestamps in UTC; display using an IANA time zone selected by the user or organization.
2. Store monetary values with explicit ISO 4217 currency codes and correct currency precision. A display currency preference never changes the transaction currency, exchange rate, tax, settlement or payment rail.
3. Store canonical measurement values (kg, metres and other agreed base units); convert for display only. Always label units.
4. Use country-aware address forms. Do not assume every country has a state/province, postal code, or identical address order.
5. Normalize phone numbers internationally (E.164 where supported); never assume an Indian +91 number.
6. Show local business registration/tax identifiers only when relevant to the selected legal jurisdiction. GSTIN/PAN are India-specific examples, not global defaults.
7. Use the user's locale for date, number and currency presentation. Respect right-to-left direction where the interface is genuinely RTL-ready.
8. Distinguish language options from verified translations. Do not claim every screen is translated until translation and QA are complete.
9. Distinguish reference catalogues from activated markets. A country, currency, language, time zone or transport mode appearing in a selector does not prove service availability.
10. Operational eligibility must be checked independently: approved country pack, active market/corridor, verified partner capability, confirmed capacity, approved rate, legal/compliance checks, payment-provider eligibility and tested fulfilment.
11. Customer staging previews must be publicly reviewable without authentication, use illustrative/empty states only, expose no personal account data and disable all writes. Production authentication and authorization must remain intact.
12. Reuse the shared runtime on every Customer Ecosystem page. New pages must pass responsive, accessibility, navigation, locale, data-integrity and security checks before approval.

## Important limitations and remaining work

- This batch integrates the shared runtime into pages 1–12; it does not automatically localize every static sentence or retroactively redesign every field on every future route.
- The shared formatting helpers are available to dynamic data components. Each page must explicitly use the appropriate helper for any displayed currency, number, date, time, weight or dimension.
- The 249-entry country reference catalogue and broad browser option lists are not market activation. Operational market, corridor, partner, rate, customs, tax and payment availability remain separately gated and must be verified.
- Browser-supported currency and time-zone lists vary by device/runtime version. Production forms that initiate commercial or operational actions must use KRIM's authoritative backend catalogues and eligibility checks, not browser lists.
- Professional translations, locale-specific address validation, E.164 phone validation, full RTL visual QA, country-specific tax/customs requirements, FX services and local payment rails require separate implementation and verification.
- Automated source checks do not replace manual testing on real Android/iOS devices, desktop browsers, authenticated accounts and supported screen readers.

This is a staging implementation record, not a global launch-readiness certificate.
