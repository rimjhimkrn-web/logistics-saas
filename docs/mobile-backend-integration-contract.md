# KRIM Mobile Backend Integration Contract

Status: verified discovery baseline; not production acceptance.
Branch: mobile/krim-partner-app
Supabase project: Logistics SaaS (project ref ebltviniygljwwseplph)

## Non-negotiable rules

- Mobile clients use only the Supabase publishable/anon key. Never embed service-role keys, Razorpay secrets, webhook secrets, or private credentials.
- Authentication is not authorization. Every operational read/write must be scoped by active organization membership, role, resource ownership, lifecycle status, and permission checks enforced by Postgres RLS or a server-side RPC/Edge Function.
- Do not expose guessed rates, partner coverage, shipment status, tracking, assignments, driver identity, balances, payouts, invoices, or payment outcomes.
- Do not directly insert/update operational tables from mobile. Use reviewed RPCs or Edge Functions.
- Keep hazardous goods, customs-sensitive, regulated, temperature-controlled, and cross-border capabilities blocked unless verified partner capability, service area, documentation, and jurisdiction rules are satisfied.
- Global architecture must carry country, market, currency, timezone, locale, units, and country-specific compliance metadata. Do not assume India rules apply globally.

## Verified schema contracts (read-only discovery)

### Identity and organization

- `public.krim_organization_members`: `id bigint`, `organization_id bigint`, `user_id uuid`, `role text`, `status text`, `created_at timestamptz`.
- `public.krim_organizations`: includes organization type, legal/display name, country/market, default currency, timezone, lifecycle status, and partner verification/compliance/onboarding state.
- Membership must be active. Partner access additionally requires an eligible verified organization and relevant permission. A user may have multiple memberships; clients must not arbitrarily select an organization without an authorized server-side membership check.

### Customer shipment and quote

- `public.krim_shipments`: includes shipment number, customer organization, origin/destination location IDs and place labels, cargo description, weight, status, public tracking token, requested mode/route, and timestamps.
- `public.krim_quotes`: includes shipment, customer organization, amount, currency, validity, status, partner quote link and pricing snapshot.
- Customer read policy on shipments is organization-scoped; quote read policy requires customer organization access.
- Existing RPC candidates:
  - `krim_create_global_shipment_from_places(p_customer_organization_id bigint, p_origin_place jsonb, p_destination_place jsonb, p_goods_description text, p_total_weight_kg numeric, p_transport_mode text, p_route_type text)`
  - `krim_create_global_shipment_idempotent(..., p_booking_request_id uuid)`
  - `krim_accept_global_quote(p_quote_id bigint)`
  - `krim_get_shipment_tracking(p_shipment_number text)`
- These functions require a separate code/grant/authorization review before enabling in a client. Quote acceptance is a commercial commitment and must not be enabled until payment/order flow and business terms are proven.

### Partner operations

- `public.krim_partner_opportunities`: includes shipment/customer organization, opportunity number, status, requested/deadline timestamps, awarded partner organization and metadata.
- `public.krim_partner_capabilities`: includes organization, transport mode, service type, country/region coverage, weight limit, refrigerated/hazardous flags, active state, verification status and effective dates.
- `public.krim_shipments` has a scoped read policy that allows an open opportunity only for active, registered-business, verified/approved partner organizations with compliant lifecycle and a currently verified capability that covers the shipment.
- This is the baseline for partner opportunity visibility; do not create a broader client-side query or relax RLS.

### Driver execution

- `public.krim_driver_assignments`: includes driver user, organization, shipment/dispatch/partner assignment/leg references, assignment number, status, pickup/delivery labels, schedule, accepted metadata and vehicle.
- RLS policy allows a driver to read only their own assignment when they have active driver membership in that organization.
- `public.krim_driver_profiles`: includes identity/contact, company, licence number, verification status and onboarding mode.
- `public.krim_driver_trip_events`: records assignment, user, event type, notes and timestamp.
- Existing server-side RPC candidates:
  - `krim_driver_accept_assignment(p_assignment_id uuid)`
  - `krim_driver_record_trip_event(p_assignment_id uuid, p_event_type text, p_notes text)`
  - `krim_driver_submit_delivery_pod(p_driver_assignment_id uuid, p_received_by_name text, p_received_by_role text, p_signature_reference text)`
- Trip event RPC explicitly limits events to pickup, in_transit and exception; it enforces event order, driver identity, active membership, commercial partner assignment and shipment/leg state. POD requires registered private evidence files and in-transit state. Do not bypass this workflow.
- Driver evidence bucket: `krim-driver-evidence`; confirm bucket policy, MIME/size limits, signed upload and retention before enabling uploads.

## Current mobile integration blockers

1. The three app screens are still preview-oriented; no live organization-context resolver or data repositories are integrated.
2. The current customer shipment request form does not submit or persist. Keep this clear until the complete create-request flow is tested.
3. Partner opportunity and shipment views are not connected; partner RLS policy and RPCs must be reviewed together.
4. Driver task reads and execution RPCs need real-account tests, including rejected/expired assignment, wrong driver, inactive membership, stale partner assignment, vehicle mismatch, weight mismatch, invalid event order and terminal shipment cases.
5. Payment screens are not integrated. Razorpay must be server-order-created, signature/webhook verified, idempotently reconciled and posted to the ledger before any app displays paid/failed/refunded/settled states.
6. No real device, live authentication, EAS signing, APK/AAB, Play Console or App Store acceptance is implied by CI export.

## Required integration and acceptance sequence

1. Review function definitions, execute grants, RLS policies, storage policies and Edge Function auth for every intended operation.
2. Add read-only organization context repositories; handle multiple organizations and no-membership states safely.
3. Connect customer shipment list and tracking via verified customer-scoped access.
4. Connect partner opportunities and assignments using the existing eligibility policy; do not allow quote submission until partner permissions and quote creation checks are proven.
5. Connect driver own-assignment reads and the three reviewed RPCs; keep POD blocked until evidence upload policy and second-party verification are confirmed.
6. Integrate payments only after end-to-end Razorpay order/webhook/ledger/refund tests pass.
7. Add automated negative authorization tests across two organizations and all three personas.
8. Perform real Android device tests, offline/retry tests, accessibility checks, and release signing/build verification.
9. Release only after market-specific legal, partner, operational and support readiness is confirmed.

## CI note

The GitHub Actions workflow validates all three app folders on pull requests and branch pushes. Android Expo export is a bundle/export check, not an installable APK/AAB or a live-backend test.
