# KRIM Step 5 — Shipment Matching & Assignment Audit

**Review date:** 5 November 2026  
**Scope:** Verified-partner matching, quote award, partner assignment response, capacity reservation, customer checkout preconditions, legacy matching routes.

## Existing backend controls inspected

- Quote orchestration checks active registered-business partner organisations, verified/compliant lifecycle state, active verified capabilities for the requested transport mode and route countries, cargo weight limits, and verified vehicle/weight availability at the origin for the requested service window.
- Matching subtracts confirmed and unexpired held reservations from reservable capacity. It fails closed when no eligible partner or reservable capacity is found.
- Customer award RPCs require authenticated organization access and quote.update plus shipment.update; the partner quote must belong to the authorized opportunity/shipment, remain open and valid, and belong to a commercially eligible registered business with a verified capability. Development/test partners are excluded.
- Partner assignment response requires active partner organization access and shipment.update, locks the assignment, validates response deadline and current capability, updates the linked shipment leg, records tracking and audit events.
- Capacity reservation requires an accepted/active assignment, matching shipment leg, active verified/compliant partner, current verified capability, approved vehicle/weight availability, valid planned departure/arrival, idempotency key and sufficient unreserved capacity. Reservation, leg binding, shipment schedule and audit events are written together.
- Assignment and capacity tables have RLS enabled. Authenticated customer organizations can read matching capacity bindings through the shipment-ownership policy. Anonymous EXECUTE is revoked from the award/response/reservation RPCs reviewed.

## Defect found and corrected

Previously, the customer assignment page and quote-result checkout page treated assignment.status = accepted as sufficient to unlock checkout. However, the partner workflow performs capacity scheduling and reservation as a separate action after accepting the assignment. The Razorpay order Edge Function also checked assignment acceptance but did not verify the capacity binding/reservation. This could allow payment-order creation before capacity had actually been reserved.

Corrections:
1. public/partner-selection-assignment.html now requires a matching confirmed capacity binding before enabling checkout.
2. public/quote-result.html applies the same requirement and shows capacity-pending status when the partner has accepted but has not reserved capacity.
3. supabase/functions/create-global-razorpay-order/index.ts now independently verifies:
   - assignment is accepted;
   - assignment has a shipment leg and capacity binding;
   - binding is confirmed and matches shipment and leg;
   - linked reservation is confirmed and matches partner organisation, shipment and leg.
   The check runs before existing-order reuse or creation, so a stale or released reservation cannot pass merely because a payment order already exists.
4. Deployed Edge Function create-global-razorpay-order version 15, with JWT verification still enabled. The deployed source was re-fetched and confirmed to contain both capacity-binding and reservation fail-closed codes.
5. Retired misleading static routes:
   - public/growth/shipment-matching.html now redirects to the current operations assignment workbench.
   - public/shipments/carrier-assignment.html now redirects to the current customer partner-selection workflow.

## Verification performed

- JavaScript syntax checks passed for the customer partner-selection page, quote-result checkout page, operations assignment page and operations carrier-matching loader.
- Legacy matching routes were re-fetched and confirmed to contain path-safe redirects, not sample shipment data or fabricated active-engine claims.
- krim_capacity_leg_bindings has RLS enabled, an authenticated SELECT grant and a customer-organization access policy.
- Edge Function deployment verified as ACTIVE version 15 with verify_jwt=true and the new capacity-reservation guard present.
- Production counts at audit time: 18 shipments, 0 partner quotes, 0 partner assignments, 0 capacity resources, 0 capacity availability rows, 0 capacity reservations and 0 capacity bindings.
- No test partner, quote, assignment, capacity record or payment order was fabricated or created.

## Remaining acceptance boundary

The matching and assignment code paths are guarded, but a positive end-to-end assignment cannot be demonstrated without a real verified partner, approved capacity resource and available schedule. The user has explicitly deferred real partner/customer operations until the entire ecosystem has been completed and reviewed. Therefore no partner was contacted, no shipment was awarded, no capacity was reserved and no payment was attempted. Signed-in browser E2E and a real partner/capacity acceptance test remain launch gates, not claims of completion.


## Follow-up continuity correction — 5 November 2026
- The customer partner-selection page now restores the latest accepted customer quote and selected partner quote from the authenticated shipment record after a page refresh. This allows the customer to resume assignment/capacity checks after the partner completes the later reservation step.
- Checkout restoration also requires the accepted customer quote to have a future validity timestamp; a confirmed capacity reservation does not extend an expired quote.
- The updated inline JavaScript was syntax-checked. No shipment, quote, assignment or payment data was created or changed.
