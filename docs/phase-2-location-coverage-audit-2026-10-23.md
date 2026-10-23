# KRIM Customer Ecosystem — Phase 2 Location, Coverage & Service Discovery

**Audit date:** 2026-10-23  
**Repository:** `rimjhimkrn-web/logistics-saas`  
**Blueprint:** `docs/KRIM_CUSTOMER_ECOSYSTEM_14_PHASE_LOCKED_BLUEPRINT.md`  
**Status:** **IMPLEMENTED — LIVE CUSTOMER ACCEPTANCE TESTS PENDING**

## Phase objective

Customers must be able to find a practical origin and destination, including rural/remote localities, understand that geographic search does not prove operational coverage, and request a coverage review without silently replacing the location or receiving invented service promises.

## Findings that drove the implementation

- The canonical shipment intake is `public/shipper/booking-request.html`; it uses Photon for worldwide geographic search.
- Place search is discovery only; it does not confirm an activated market, a partner service area, a feasible freight lane, cargo eligibility, approved tariff, capacity, customs eligibility or delivery promise.
- The read-only production snapshot showed 6 active market records and 32 active location records, but **0 partner service-area records, 0 persisted route-option records, 0 route-constraint records and 0 customer service-request records** in the inspected tables. These counts are not proof that all routes are unsupported; they mean coverage cannot be established from those records.
- The existing `krim_submit_customer_service_request` RPC was not executable by `authenticated` users. Its previous implementation also logged every request type as `quote_requested`, including general inquiries. This was corrected before wiring the customer workflow.

## Implemented in this phase

1. **Canonical shipment intake updated** — `public/shipper/booking-request.html` now offers a direct path to coverage review and passes selected origin, destination, route type, preferred mode and weight as prefill values.
2. **Coverage-review page added** — `public/shipper/coverage-review.html` allows a signed-in customer to enter exact origin/destination text, including a locality missing from geographic search; choose a route arrangement and transport preference; optionally enter weight/date; and explain the review request.
3. **Backend authorization corrected** — migration `supabase/migrations/20261023110000_enable_authenticated_customer_coverage_requests.sql` updates the existing service-request RPC to:
   - require an authenticated user;
   - require a verified customer identity and active customer workspace;
   - validate optional location IDs, positive weight and non-past requested date;
   - limit notes to 2,000 characters;
   - write the request and audit event through the existing workflow;
   - record acquisition metrics only for the matching quote/shipment request type, not for general coverage inquiries;
   - revoke execution from `PUBLIC` and `anon`, and grant it to `authenticated`.
4. **Database ACL verified** — read-only privilege check after the production SQL change returned `anon=false`, `authenticated=true`, `service_role=true` for the RPC. The function remains `SECURITY DEFINER` and includes explicit authentication, identity and workspace checks.
5. **Automated source guards added** — `scripts/krim-production-smoke.mjs` now checks the coverage page, shared stylesheet, canonical intake link, RPC usage, honest serviceability wording and migration ACL patterns.

## Customer-facing pages to test

1. [Customer workspace](https://rimjhimkrn-web.github.io/logistics-saas/app/customer/index.html)
2. [Canonical global shipment request](https://rimjhimkrn-web.github.io/logistics-saas/public/shipper/booking-request.html)
3. [Global coverage review](https://rimjhimkrn-web.github.io/logistics-saas/public/shipper/coverage-review.html)
4. [Customer shipment list](https://rimjhimkrn-web.github.io/logistics-saas/public/shipper/active-shipments.html)
5. [Rate and service workflow](https://rimjhimkrn-web.github.io/logistics-saas/public/shipper/rate-calculator.html)

The canonical route for a place that is not found is the coverage-review page; no second shipment model or duplicate quote workflow was created.

## Production database and security notes

- The SQL migration was applied to the connected production Supabase project and the RPC execute grants were re-queried afterward.
- No shipment, quote, payment, customer profile, location, partner coverage, route option or constraint rows were created or deleted during this work.
- No real customer data was used for acceptance testing.
- The coverage request writes through the existing customer-service workflow; a successful reference means the request was received, **not** that coverage was approved.
- Partner service areas and routable lanes remain unpopulated in the inspected structures. KRIM must not claim confirmed global serviceability until authoritative coverage records and operational checks exist.

## Acceptance test checklist

Run while signed into a verified, active customer account:

- [ ] Booking page opens; global search returns places; selecting both places updates the route preview.
- [ ] Coverage-review link carries the selected route values into the form.
- [ ] A locality not returned by place search can be entered manually without substituting another city.
- [ ] An empty origin, empty destination, identical endpoints, invalid weight or past requested date is rejected client-side.
- [ ] Submitting a valid coverage inquiry returns a backend reference and a clear message that coverage remains unverified.
- [ ] The request appears in the authorized customer-service workflow with the exact locality text in notes.
- [ ] A signed-out user is redirected to customer sign-in.
- [ ] An authenticated user without a verified active customer identity/workspace cannot submit.
- [ ] A failed request shows an error and does not claim success.
- [ ] Mobile layout, keyboard focus, links, empty search, geocoder outage and refresh/back navigation work on the deployed site.
- [ ] Existing shipment creation and rate/quote workflow remain intact.

## Current exit-gate decision

**Phase 2 is implemented at source/database-permission level but is not formally closed.** The SQL privilege result and repository source guards are evidence of implementation, not proof that the signed-in browser journey works end to end. Live browser acceptance, a successful controlled coverage request, and CI results must be recorded before Phase 2 can be marked **VERIFIED** or Phase 3 begins.

## Change safety

- Existing canonical shipment and quote pages were retained.
- No duplicate shipment or quote model was added.
- No existing pages were deleted.
- Unknown coverage remains unverified; geocoding does not become a serviceability promise.
