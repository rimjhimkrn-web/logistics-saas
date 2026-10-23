# Phase 6 — Customer Shipment Dashboard Audit

**Date:** 2026-10-23  
**Status:** SOURCE IMPLEMENTATION UPDATED — AUTOMATED CHECKS / DEPLOYMENT PENDING — LIVE ACCEPTANCE NOT VERIFIED  
**Canonical page:** `public/customer-os/customer-services/shipment-list.html`

## Goal

Provide one dependable, mobile-friendly place for an authenticated customer to review shipment records associated with their active customer organization, understand real status, and continue to authorized detail, tracking and quote workflows.

## Changes made

- Kept `public/customer-os/customer-services/shipment-list.html` as the canonical customer shipment register because the Customer OS already links to it.
- Added sort controls (newest first, oldest first, shipment reference A–Z, status A–Z) and client-side pagination of 20 records per page, while retaining search and status filters.
- Preserved live data loading from `krim_shipments`; records are filtered to active customer/shipper/enterprise organizations discovered through the signed-in user's active memberships. No sample shipment records are generated.
- Corrected shipment creation actions in the register to use the canonical `public/shipper/booking-request.html` route.
- Consolidated `public/shipper/active-shipments.html` into a backward-compatible redirect to the canonical register. The redirect preserves query parameters and the URL fragment, so two independently maintained shipment registers are no longer presented as separate products.
- Updated shared Customer OS navigation so “Book shipment” points to the canonical shipment-request workflow.
- Applied `core/krim-global-interface.css` and `krim-global-shell` to the shipment details, timeline and tracking-map pages, maintaining one shared design language throughout the dashboard journey.
- Added Phase 6 regression checks for organization-scoped data access, dashboard interactions, canonical route usage, the compatibility redirect and global-interface conformance.

## Canonical customer journey

1. [Customer Workspace](../../app/customer/index.html)
2. [Customer Operations Hub](../../public/customer-os/index.html)
3. [Shipment Register / Dashboard](../../public/customer-os/customer-services/shipment-list.html)
4. [Shipment Details](../../public/customer-os/customer-services/shipment-details.html?shipment_id=)
5. [Shipment Timeline](../../public/customer-os/customer-services/shipment-timeline.html?shipment_id=)
6. [Shipment Tracking & Visibility](../../public/customer-os/customer-services/tracking-map.html?shipment_id=)
7. [Quote Register](../../public/customer-os/quotes-pricing/quote-list.html)
8. [Canonical Shipment Request](../../public/shipper/booking-request.html)
9. [Legacy My Shipments URL — redirects to the canonical register](../../public/shipper/active-shipments.html)

Shipment detail, timeline and tracking links require a real `shipment_id` from a record the signed-in user is authorized to view.

## Data and trust rules

- A shipment request is not proof of a confirmed operational booking, payment, carrier assignment, pickup or delivery.
- Counts and shipment cards are based on rows returned by the connected database; errors do not fall back to fabricated data.
- Organization filtering in the interface is not a substitute for Supabase RLS and server-side authorization.
- The register currently loads the newest **up to 100** authorized shipment records and paginates those records 20 at a time. This is a documented scaling limitation: before very large customer portfolios are certified, implement and verify server-side pagination and cross-page search/filter/sort so older records cannot be hidden by the 100-record retrieval cap.
- Customer OS links outside the dashboard were not broadly deleted. Existing routes are preserved unless a dependency-safe canonical redirect was added.

## Verification status

- Source updated and committed to the repository.
- Automated GitHub Actions checks: **pending final result** at the time this report was created.
- GitHub Pages deployment: **pending final result** at the time this report was created.
- Live authenticated browser testing, multi-organization isolation testing, and real record detail/timeline acceptance: **not independently verified in this audit**.

## Acceptance checklist

- [ ] Signed-out users are routed to sign-in and cannot see customer shipment records.
- [ ] Active customer organization membership is required; non-customer-only accounts do not receive customer shipment records.
- [ ] Two organizations' shipments remain isolated in live tests.
- [ ] Search, status filters, sort options and 20-record pagination behave consistently.
- [ ] Detail, timeline, tracking and quote links open the expected record and preserve its identifier.
- [ ] Empty, failed and no-membership states give a useful next step without sample data.
- [ ] Legacy `active-shipments.html` redirects to the canonical dashboard without losing query/hash.
- [ ] Mobile/desktop visual checks pass using the shared global interface.
- [ ] Server-side pagination is implemented and verified before the dashboard is certified for portfolios larger than the current 100-record retrieval cap.

**Exit decision:** Phase 6 has received source-level improvements, but it is not formally verified until the automated results and deployed authenticated acceptance checks are reviewed.
