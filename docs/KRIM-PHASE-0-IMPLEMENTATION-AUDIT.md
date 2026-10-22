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


## Security and performance advisor snapshot (2026-10-22)
- Supabase security advisor returned a warning category `authenticated_security_definer_function_executable` with 27 findings. The findings include shipment creation RPCs, quote acceptance, partner quote award, driver assignment and admin rate-card / verification functions.
- This warning is not by itself proof of an exploitable vulnerability: some SECURITY DEFINER RPCs are intentional. However, every listed function must be inspected for explicit `auth.uid()` checks, organization/resource authorization, safe `search_path`, and appropriate execute grants before production launch.
- Do not bulk-revoke EXECUTE or switch all functions to SECURITY INVOKER; that could break intended workflows. Review and remediate one function family at a time with role tests.
- Performance advisor returned 9 unindexed foreign-key findings, including driver assignment/evidence relationships and private payment-transaction relationships. These should be reviewed for query plans and added indexes where justified.
- Performance advisor also returned 641 unused-index findings. Do not delete indexes based solely on this snapshot: the project may have recently created indexes or low-volume features. Review workload, query plans, write overhead and production usage before removing any index.
- These advisor results are a release-readiness concern and should be tracked. They are not authorization to make broad production DDL changes without review and verification.

## Audit pass continuation
- Confirmed the canonical rate calculator file exists at `public/shipper/rate-calculator.html`; the booking redirect target is not a missing-file defect.
- Confirmed the booking page calls the idempotent shipment RPC overload that exists in the production function catalog.
- Still not confirmed: RPC body-level authorization, grants, idempotency uniqueness guarantees, real browser session behavior, new-row correctness, and rate-calculator cross-organization access control.


## Step 1 follow-up: booking-to-rate-calculator source trace (2026-10-22)
- Re-inspected the booking submit handler: it creates/retains a UUID in sessionStorage, disables the submit button while sending, calls `krim_create_global_shipment_idempotent`, requires a returned identifier, and redirects with that identifier as `shipment_id`. This is a useful client-side duplicate-retry safeguard, but server-side uniqueness and authorization are still unverified.
- Re-inspected the rate calculator: it reads the numeric `shipment_id` query parameter and fetches the corresponding `krim_shipments` row using the Supabase client. This confirms the intended record handoff in source code, but does not prove that RLS prevents a different organization from reading the shipment. Cross-organization denial must be tested.
- The rate calculator's source has a shipment-fetch error path, but a successful read, rate-card selection and quote creation have not yet been demonstrated in an authenticated browser.
- No live shipment was submitted and no production data was changed in this follow-up.
- Step 1 remains IN PROGRESS / NOT APPROVED until an authorized fresh booking and next-page access test are completed with database evidence.


## Step 1 security review — RPC body and grants (2026-10-22)
### Confirmed positives
- `krim_create_global_shipment_idempotent` is SECURITY DEFINER and explicitly checks `auth.uid()`, active organization access, `shipment.create` permission, and active organization status before creating or returning a shipment.
- It takes a transaction-scoped advisory lock keyed by organization + booking request UUID, then checks for an existing shipment with that key. When the same key is reused with different shipment details, it raises an error instead of silently returning a mismatched shipment.
- The function pins `search_path` to `public, private, pg_temp`.
- EXECUTE is granted to `authenticated`, `postgres`, and `service_role`; the user-facing function's own identity/organization/permission checks are therefore especially important and are present in the inspected definition.
- The delegated `krim_create_global_shipment_from_places` validates authenticated identity, organization access and shipment.create permission through its delegated creation path, validates required cargo and weight, validates country code/name and coordinate ranges, and rejects identical coordinates.

### Findings requiring resolution or proof
- The idempotency function's lookup is keyed by organization + request UUID and uses an advisory lock. The audit has not yet confirmed a matching unique database constraint/index; inspect indexes and prove concurrent duplicate behavior before calling it fully verified.
- The place-creation function inserts countries and, on a country-code conflict, sets `is_active=true`. This can reactivate a previously inactive country when a customer books a place there. Treat this as a potential market-governance defect: verify intended semantics and fix in a reviewed migration if inactive-country controls are meant to block unsupported markets.
- The place-creation function may create a `krim_locations` row when no matching active city/region exists. Verify that this is an intentional customer-requested location workflow, that concurrent creation cannot cause inconsistent duplicate locations, and that creating a location does not implicitly activate a market that has not passed KRIM's launch controls.
- Function catalog inspection found authenticated EXECUTE for the SECURITY DEFINER function. This is not automatically unsafe given its checks, but all reachable helper functions and the underlying create RPC must be reviewed as a chain, including search_path and grants.
- Rate calculator reads `krim_shipments` by numeric ID through the Supabase client. Source shows it relies on database access policies for isolation; actual cross-organization denial has not yet been tested with two authenticated organizations.

### Current decision
Step 1 remains IN PROGRESS / NOT APPROVED. The function-body review is partially positive, but browser E2E, selected-place persistence, RLS isolation, idempotency/concurrency, and inactive-market behavior remain unverified. No production data was changed in this audit.


## Step 1 follow-up: idempotency, access policies and quotation RPC trace (2026-10-22)
- Confirmed the canonical shipment table has a partial unique index on `(customer_organization_id, booking_request_id)` when `booking_request_id IS NOT NULL`. This supports database-level protection against duplicate requests for the same organization/request UUID. The function also uses a transaction-scoped advisory lock. A true concurrent authenticated duplicate-submission test is still required.
- Confirmed `krim_shipments` has an authenticated SELECT policy using `private.krim_has_organization_access(auth.uid(), customer_organization_id)`, plus a separate policy allowing verified partners to view shipments linked to open partner opportunities. The policy definitions look scoped, but a two-organization browser test is still required to prove actual denial and intended partner visibility.
- Confirmed the rate calculator calls the server RPC `krim_create_tariff_quote`; if the server returns the specific “no approved active global rate card matches” / “tariff quote unavailable” error, it calls `krim_create_partner_opportunity`. The page does not calculate or invent a customer price in the browser. Catalog checks show both functions are SECURITY DEFINER, pin a `search_path`, and reference `auth.uid()` and organization-access checks. Full body/role testing remains required before approving the quote step.
- Potential market-governance defect remains: one `krim_create_global_shipment_from_places` overload explicitly reactivates a country on country-code conflict (`is_active=true`). This must be resolved deliberately in a reviewed database migration if inactive countries represent markets that KRIM has not approved for launch. No production DDL was executed.
- Found that the rate calculator's internal links and login/redirect targets were hard-coded to `/logistics-saas/`. Updated the page in the audit branch to calculate the GitHub Pages base path and use root paths on a custom domain, including the manifest and internal navigation. This change is committed to the branch, but it is **not confirmed deployed to the public GitHub Pages site**; merge/deployment and browser verification remain separate gates.
- No production shipment or quote was created. Step 1 remains IN PROGRESS / NOT APPROVED pending authenticated browser evidence, server-side market-governance decision, and actual record/route verification.


## Global-market integrity and public route portability (2026-10-22)
- KRIM's global architecture must distinguish global geographic coverage from commercial/service availability. A customer choosing a country or city must not activate that country's operational market switch. Market launch/availability must remain an explicit KRIM-controlled decision, with serviceability checked separately from geography.
- Drafted a review-only SQL function replacement at `docs/review/KRIM-country-market-status-preservation.sql`. It changes the country upsert so a new country master record is inserted inactive and a conflict does not change the existing `is_active` value. It preserves the current function signature, SECURITY DEFINER mode, pinned search_path and existing authorization checks. **This is a branch draft only; it has not been applied to production and needs isolated staging tests and a proper reviewed migration before deployment.**
- The draft alone does not establish route serviceability. The quotation and partner-bid functions must independently verify active service lanes, approved rate cards, compliance requirements and eligible partners before promising a service or dispatching a bid request.
- Updated `public/shipper/booking-request.html` to derive internal login/quotation links and manifest paths from the current base path, supporting both GitHub Pages at `/logistics-saas/` and root-hosted custom-domain paths. Commit: `922d74ece05cb844c6bec4e5d9ff612a87f2c575`.
- Updated `public/shipper/rate-calculator.html` with the same base-path behavior. Commit: `0c212a770078eadbad7b91252717ec6fcab3d81e`.
- These source changes are committed on `krim/global-operations-audit`; deployment to the default branch and live-site browser verification are not confirmed.
- Step 1 remains IN PROGRESS / NOT APPROVED. No production SQL was executed and no production shipment or quote was created.
