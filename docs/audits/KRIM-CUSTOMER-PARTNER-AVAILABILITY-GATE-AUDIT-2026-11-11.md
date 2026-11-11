# KRIM Customer Booking — Partner Availability Gate Audit
Date: 11 November 2026
Status: internal release-blocking finding; no production data or schema changed.

## Verified baseline
A read-only production query of `public.krim_partner_capabilities` returned:
- 1 capability record with `verification_status = pending` and `active = false`;
- 0 active partner capabilities in the returned grouped result.

This means KRIM currently has no verified active partner capability recorded in this table. It does not prove that no logistics businesses exist outside KRIM; it means the production system has no active approved capability available to rely on for marketplace fulfilment.

## Customer booking-page review
The current `public/shipper/booking-request.html` preflight checks whether the origin and destination map to active KRIM countries, locations and markets. If both endpoints pass, the page calls `krim_create_global_shipment_idempotent` and creates a shipment request.

The inspected browser flow does not perform a matching active, verified partner-capability check for the exact route, transport mode, service and cargo constraints before creating the shipment request. The page does link to a coverage-review page for location/route review, and it correctly warns that location search does not itself prove serviceability. However, active-market status is not equivalent to partner availability.

## Release consequence
Until a secure server-side partner-match / availability gate is implemented and tested:
- Do not run broad paid customer acquisition or advertise confirmed service availability.
- Do not charge a customer for marketplace access, an uncovered request, a quote that does not exist or a booking that has not been accepted.
- Treat existing shipment-request creation as an enquiry/request only, never as a confirmed booking or provider commitment.
- Keep partner onboarding and verification as the first operational priority.
- Continue only controlled internal testing and free, clearly labelled coverage-review intake.

## Required implementation
1. Reconcile production migration history with the repository before any DDL. Do not replay migrations by filename or deploy speculative schema changes.
2. Define the authoritative server-side match rules using approved partner capabilities, active partner organisation status, origin/destination coverage, transport mode, service type, cargo restrictions, weight/equipment constraints and current validity.
3. Expose a least-privilege, authenticated server-side preflight that returns only a safe result such as `matched`, `no_verified_provider` or `review_required`; never expose private partner documents or sensitive partner data to customers.
4. Make shipment-request creation fail closed if the required capability match cannot be verified. A match is not a confirmed booking: obtain partner acceptance and specific-job capacity confirmation before showing booking confirmed.
5. When no match exists, offer a free coverage-review request and state plainly that it is not a booking and does not guarantee service.
6. Test positive, negative, expired-evidence, wrong-mode, unsupported-cargo, insufficient-capacity, unauthenticated, cross-organisation and retry/idempotency cases.
7. Verify the actual customer UI and backend response in production only after reviewed migrations and controlled deployment.

## Acceptance criteria
- No shipment request is represented as bookable merely because its endpoints belong to active markets.
- No unverified, inactive or expired capability can satisfy the match.
- No partner identity, documents or private capacity details leak to another organisation or customer.
- No provider match means no charge and a clear free coverage-review path.
- A booking is confirmed only after a specific partner explicitly accepts the job and capacity/price/terms are confirmed.
