# KRIM Global Logistics OS — Phase 0 Implementation Audit
Date: 2026-10-22
Repository: rimjhimkrn-web/logistics-saas
Branch: krim/global-operations-audit
Environment: GitHub source inspection + read-only Supabase production inspection

## Scope and safety
This is a source/schema audit, not an authenticated browser E2E pass. No production rows were created or modified during this audit. Do not activate live payment credentials or claim launch readiness from this document.

## Confirmed source paths
- Public homepage: `index.html`
- Access/workspace portal: `auth/access.html`
- Customer booking: `public/shipper/booking-request.html`
- Rate calculation/quotation workspace: `public/shipper/rate-calculator.html`
- Quote/checkout: `public/quote-result.html`
- General quote request entry: `public/quote.html`

The homepage links directly to the customer booking page and the general quote request page. The booking page's next-step redirect points to `/logistics-saas/public/shipper/rate-calculator.html`; the target file exists in the repository.

## Booking page source findings
- Loads Supabase JS v2 and uses the configured client.
- Checks the authenticated session and active organization membership.
- Filters for an active customer/shipper/client organization and refuses ambiguous multiple active customer organizations.
- Requires selected origin and destination place results, rejects identical coordinates, validates domestic/cross-border route type, goods description, and positive weight.
- Calls `krim_create_global_shipment_idempotent` with organization, origin/destination place JSON, goods, weight, transport mode, route type, and a booking request UUID.
- Handles an RPC error and refuses a blind retry if the RPC returns without a usable shipment identifier.
- On a returned identifier, redirects to the rate-calculator page with shipment ID and service/route query parameters.
- Source inspection alone does not prove the client RPC call succeeds with the live user's JWT, that the RPC authorization is correct, or that the created row and next-page load succeed in a real browser.

## Supabase schema/function findings
- Production project status returned as `ACTIVE_HEALTHY` (Postgres 17).
- The following public RPC overloads are present according to read-only catalog inspection:
  - `krim_create_global_shipment(p_customer_organization_id bigint, p_origin_location_id bigint, p_destination_location_id bigint, p_goods_description text, p_total_weight_kg numeric)`
  - `krim_create_global_shipment_from_places(...)` with multiple argument overloads
  - `krim_create_global_shipment_idempotent(p_customer_organization_id bigint, p_origin_place jsonb, p_destination_place jsonb, p_goods_description text, p_total_weight_kg numeric, p_transport_mode text, p_route_type text, p_booking_request_id uuid)`
- Both `shipment_requests` (legacy) and `krim_shipments` (canonical) exist and have foreign-key relationships between them. Preserve both until a compatibility and data-mapping audit proves a safe migration path.
- A previous read-only inventory showed existing shipment, quote, payment, status-history and legacy financial records. Their presence is not evidence of an end-to-end passing workflow.

## Step 1 decision
Status: IN PROGRESS — NOT APPROVED.
Reason: source and RPC existence are confirmed, but no authenticated fresh booking has yet been submitted and verified end-to-end.

## Required tests before Step 1 can pass
1. Real homepage → customer access → booking navigation.
2. Fresh authenticated customer account with exactly one active customer organization.
3. Origin/destination search returns selectable place records.
4. Missing fields, same place, domestic/cross-border mismatch, invalid weight and oversized goods are rejected without creating a shipment.
5. Valid booking submits once and the RPC returns the canonical shipment ID.
6. Verify the new `krim_shipments` row has the correct organization, route, cargo, mode, route type and request/idempotency key.
7. Confirm exactly one shipment is created for a repeated request with the same request UUID.
8. Confirm the next page loads that exact shipment ID and denies access to a shipment belonging to another organization.
9. Test timeout/error recovery without accidental duplicate creation.
10. Save reproducible evidence (test account role, timestamp, record reference, expected/actual results and relevant logs) before approval.

## Risks / questions to resolve in the next audit pass
- Inspect the exact RPC body, grants, SECURITY INVOKER/DEFINER behavior, organization membership authorization and idempotency constraint/index.
- Verify how selected geographic place JSON is validated and persisted server-side.
- Verify route-calculator reads use `shipment_id` as the authoritative identifier and enforce organization ownership.
- Trace the quote RPC, rate-card selection, quote versioning/expiry and partner-bid fallback.
- Trace checkout Edge Function, webhook verification, event idempotency and refund/reconciliation paths.
- Audit each workspace's canonical route and backend access separately.
- Check deployment/base-path behavior on GitHub Pages and any custom domain.
- Review Supabase security and performance advisors; the advisor request was not completed in this audit pass.

## Change policy
No production schema change, production data mutation, secret change, live payment or broad page rewrite is approved by this audit. Fixes should be isolated, reviewed, tested in a safe environment and backed by evidence.
