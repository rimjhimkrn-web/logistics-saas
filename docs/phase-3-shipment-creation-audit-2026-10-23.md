# KRIM Customer Ecosystem — Phase 3 Shipment Creation Audit

**Audit date:** 2026-10-23  
**Repository:** `rimjhimkrn-web/logistics-saas`  
**Canonical blueprint:** `docs/KRIM_CUSTOMER_ECOSYSTEM_14_PHASE_LOCKED_BLUEPRINT.md`  
**Status:** IMPLEMENTED — AUTOMATED CHECKS PENDING; LIVE ACCEPTANCE TESTS REQUIRED

## Objective

A signed-in customer creates one accurate shipment request for one active organization. Backend authorization and validation are authoritative; repeat submissions must not create duplicate shipments; successful requests must return a real shipment reference and continue to the existing rate/quote workflow without implying confirmed service, a quote, payment, booking, or carrier assignment.

## Existing implementation audited

- Canonical customer shipment form: `public/shipper/booking-request.html`.
- Existing shipment data model: `public.krim_shipments`; no parallel shipment table was created.
- Existing backend RPC: `krim_create_global_shipment_idempotent(bigint,jsonb,jsonb,text,numeric,text,text,uuid)`.
- Existing unique index: `krim_shipments_customer_booking_request_uidx` on `(customer_organization_id, booking_request_id)` when the request ID is not null.
- `krim_shipments` has row-level security enabled.
- Read-only function-definition inspection confirmed the RPC checks `auth.uid()`, organization access, the `shipment.create` permission, active organization status, and required booking request ID; it uses an advisory transaction lock and returns the already-created shipment only when the same request ID and details are reused. Different details under the same request ID are rejected.
- The form has a stable booking-request identifier, client-side required-field and route checks, a duplicate-submit lock, a recoverable error state, and navigates to the existing rate calculator using the returned shipment ID.
- No test shipment or other production database record was created during this audit.

## Changes made

1. Customer Workspace booking buttons now link to the canonical global shipment request page.
2. The former `public/customer/shipment-create.html` route is retained as a lightweight backward-compatible redirect to `public/shipper/booking-request.html`; it no longer runs a second shipment-creation implementation. The route is not deleted, so existing inbound links are less likely to break.
3. The legacy redirect uses the approved shared `core/krim-global-interface.css` design layer.
4. Production smoke checks now guard the canonical page's idempotent RPC, request identifier, duplicate-submit protection, rate-workflow continuation, legacy redirect, customer-workspace links, and shared global design layer on Phase 3 customer pages.
5. Existing Phase 2 customer pages and the canonical shipment form continue to use the shared global interface standard.

## Customer-facing test links

1. [Customer Workspace](https://rimjhimkrn-web.github.io/logistics-saas/app/customer/index.html)
2. [Canonical Global Shipment Request](https://rimjhimkrn-web.github.io/logistics-saas/public/shipper/booking-request.html)
3. [Legacy shipment URL — should forward to the canonical form](https://rimjhimkrn-web.github.io/logistics-saas/public/customer/shipment-create.html)
4. [Rate & Service Workflow](https://rimjhimkrn-web.github.io/logistics-saas/public/shipper/rate-calculator.html)
5. [My Active Shipments](https://rimjhimkrn-web.github.io/logistics-saas/public/shipper/active-shipments.html)
6. [Customer Shipment List](https://rimjhimkrn-web.github.io/logistics-saas/public/customer-os/customer-services/shipment-list.html)
7. [Global Coverage Review](https://rimjhimkrn-web.github.io/logistics-saas/public/shipper/coverage-review.html)

## Live acceptance checklist

Use a test customer account and non-sensitive test cargo details.

- [ ] Customer Workspace opens and the Book Shipment buttons lead to the canonical form.
- [ ] Signed-out users are directed to customer sign-in; no shipment is created.
- [ ] Signed-in customer with one active customer organization can complete required fields.
- [ ] Missing goods, invalid weight, missing place, identical endpoints, or mismatched domestic/cross-border selection is rejected with understandable feedback.
- [ ] A successful submit produces one real shipment number/reference and one corresponding `krim_shipments` record.
- [ ] Rapid double click/retry with the same booking request does not create a duplicate record.
- [ ] An uncertain network outcome does not falsely display success; the user is told to check My Shipments before retrying.
- [ ] Returned shipment ID reaches the existing rate/service workflow.
- [ ] Rate/service UI does not invent a price, partner offer, serviceability, delivery date, or booking confirmation.
- [ ] Shipment appears in the customer's authorized shipment list and remains after refresh.
- [ ] Another organization cannot view or create shipments under the first organization's ID.
- [ ] Legacy shipment URL forwards to the canonical form and does not render a second booking form.
- [ ] All Phase 3 pages load on mobile and retain the shared KRIM interface standard.

## Known limits / risks not certified by static checks

- The live browser journey, email/auth state, organization-specific data visibility, real RPC submission, duplicate-submit behavior, and post-submit list persistence have not been run as a full end-to-end test by this audit.
- The place-to-shipment backend function currently contains logic to upsert a country as active and create a `customer_requested` location for a new selected place. That behaviour must not be interpreted as operational route coverage. Keep serviceability, partner capacity, and rate claims gated on separate verified evidence; review the market-activation side effect in the coverage/serviceability hardening work.
- `SECURITY DEFINER` functions require continued review. This audit inspected the shipment-creation function's authorization path but is not a complete audit of every privileged database function.

## Exit decision

**Phase 3 is not formally closed yet.** Source-level implementation and automated checks are not substitutes for the live acceptance checklist above. Close the phase only after successful submission, no-duplicate retry, organization-isolation, error-path, and post-submit visibility tests pass in the deployed site.
