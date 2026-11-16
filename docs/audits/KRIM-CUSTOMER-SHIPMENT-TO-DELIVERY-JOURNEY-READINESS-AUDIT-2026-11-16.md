# KRIM Customer Shipment-to-Delivery Journey Readiness Audit
**Date:** 16 November 2026  
**Scope:** Read-only trace of canonical customer shipment booking, tariff/partner quote request, partner bid submission, customer quote acceptance, assignment, dispatch authorisation, tracking and proof of delivery.

## Executive decision
**The customer shipment request path is implemented, but KRIM is not currently ready to fulfil a real shipment end-to-end.** The canonical booking page calls a server-side idempotent shipment RPC and checks active markets. The quote desk uses an evidence-backed tariff RPC and falls back to partner sourcing only when the tariff is unavailable. Partner bid submission, customer quote acceptance, exact-leg dispatch authorisation, tracking and verified POD controls exist.

However, production currently has no open partner opportunities, no submitted partner bids, no accepted partner assignments, no dispatch authorisations and no verified POD records. The only partner capability record is inactive and pending verification. The three existing partner organisations are not operationally eligible. The current data contains historical test-style shipment and quote records; those records do not establish live service capacity or a customer-ready commercial offer.

**Do not advertise a route as bookable or accept a real customer shipment for fulfilment until a real partner is verified, route capability and capacity are confirmed, and the full workflow is staging-tested.**

No shipment, quote, partner opportunity, bid, assignment, dispatch, tracking event or POD was created. No email or notification was sent. No production data, schema, RLS, grants or functions were changed.

## 1. Production snapshot

| Workflow record | Production rows |
|---|---:|
| Shipments | 18 |
| Shipment legs | 1 |
| Customer quotes | 7 |
| Partner quotes | 0 |
| Partner opportunities open and in deadline | 0 |
| Partner assignments | 0 |
| Capacity reservations | 0 |
| Dispatches (legacy table) | 0 |
| Leg dispatch authorisations | 0 |
| Tracking events | 1 |
| Verified POD records | 0 |
| Quote orchestration runs | 0 |
| Shipment event receipts | 0 |

Shipment statuses: 8 draft, 3 quoted, 6 confirmed, 1 closed.  
Customer quote statuses: 1 sent and 6 accepted. The sent quote is expired. The accepted quotes are historical and have no linked partner quote ID. They are not evidence of a valid live partner-backed booking.

All three partner/carrier organisations inspected are ineligible:
- One legacy partner and one carrier have no registered-business account mode and verification is not started.
- One development-test partner is pending verification and not active as a compliant operational provider.
- The only capability row belongs to the development-test organisation; it is inactive, verification pending, and scoped to a limited India coverage record.

## 2. Customer shipment creation

### Canonical page
`public/shipper/booking-request.html` is the canonical page. `public/customer/shipment-create.html` redirects to it. The page:
- Requires an authenticated session and exactly one active customer organisation membership.
- Collects globally searched origin and destination places and stores labels, place type and coordinates.
- Checks domestic versus cross-border route type.
- Requires both endpoints to map to active KRIM country/location/market records before submission.
- Validates cargo description and positive gross weight.
- Calls `krim_create_global_shipment_idempotent` with the customer organisation, selected places, goods, weight, mode, route type and a browser-persisted booking request UUID.
- Locks the form while submitting and does not claim success if the RPC returns no shipment identifier.

### Server-side controls
The SECURITY DEFINER RPC:
- Requires `auth.uid()`.
- Checks active organisation membership/access and `shipment.create` permission.
- Requires an active customer organisation.
- Uses an advisory transaction lock keyed by organisation and booking request UUID.
- Returns the existing shipment on a safe retry only when the complete request details match.
- Rejects reuse of the same request UUID with different route/cargo/weight/mode data.
- Calls the canonical place-based shipment creator and binds the idempotency UUID.

The function is executable by authenticated users and uses an empty search path. The lower-level place-based creator is also executable by authenticated users, so its own authorization and validation remain part of the security boundary and must be preserved.

**Positive finding:** shipment creation is materially safer than a client-side insert and includes idempotency, organization authorization and active-market preflight.

**P1-A — Frontend preflight is not authoritative.** The browser checks the two endpoints, but the server must continue to repeat market activation, corridor, cargo, route and compliance validation. The tariff and partner-opportunity functions do repeat market activation checks, which is good. Keep all serviceability decisions server-side.

**P1-B — Shipment creation is not a booking or provider commitment.** The UI correctly calls this a shipment request and moves to the quote desk. Preserve this language in all pages and notifications.

## 3. Tariff and partner quote request

### Customer rate desk
`public/shipper/rate-calculator.html` calls `krim_create_tariff_quote`. The RPC:
- Requires an authenticated user with access to the shipment and `quote.create`.
- Requires a draft/quoted shipment with positive weight and a supported service tier.
- Verifies both endpoints are in active countries and markets and pass the market activation gate.
- Requires an explicit transport mode.
- Looks for a current, active, global rate card with route, mode, service tier, commercial evidence and commercial approval.
- Calculates from flat or per-kg rate, applies minimum charge and currency minor-unit rounding.
- Saves a quote with a pricing snapshot including rate-card reference, calculation basis, weight, currency, validity and tax treatment.
- Does not invent a price when no approved rate card matches.

### Partner sourcing fallback
When the tariff RPC returns the specific no-approved-rate-card error, the browser calls `krim_create_partner_opportunity`. The server function:
- Requires authenticated access to the customer organisation and `quote.create`.
- Allows only draft or quoted shipments with an explicit transport mode.
- Requires active country, location and market records at both ends.
- Blocks shipment-wide sourcing for active multi-leg plans until leg-specific sourcing is supported.
- Creates or reuses an open opportunity and transitions draft shipments to quoted.
- Records an audit event and response deadline.

**Positive finding:** the customer quote desk does not calculate arbitrary browser-side prices. Tariff creation and partner opportunity creation are server-side and use different, explicit pathways.

**P0-A — No current partner market to fulfil the fallback.** The opportunity fallback is implemented, but there are zero open opportunities and no eligible registered-business partner with a current verified capability. The single capability record is inactive and pending. Do not interpret a successful opportunity creation as proof a partner has been found or can accept the work.

**P1-C — Multi-leg commercial sourcing is intentionally gated.** The opportunity and partner quote functions reject shipment-wide sourcing when an active multi-leg plan has more than one leg. A true multi-leg journey needs leg-specific opportunities, quote comparison, assignments, capacity reservation and custody handover for each leg. Do not bypass this gate to make the page appear complete.

## 4. Partner bidding

`public/partner/submit-quote.html`:
- Requires an active partner/carrier/forwarder organisation.
- Requires registered-business mode, verified organisation, active lifecycle, compliant status and a current verified capability.
- Loads only open opportunities and the partner's own bids.
- Calls `krim_submit_partner_quote` with opportunity, amount, currency, validity and notes.
- Displays no placeholder freight price.
- Checks the returned quote ID, opportunity, partner organisation and submitted status before showing success.

The SECURITY DEFINER submission function independently checks:
- Authenticated user and exactly one eligible partner organisation.
- `quote.create` permission and active configured currency.
- Open opportunity, future deadline and no award.
- No shipment-wide quote for active multi-leg plans.
- Current partner capability covers mode, both route countries/regions and weight.
- Partner is not bidding on its own customer shipment.
- Bid validity is future-dated and capped by the opportunity deadline.
- Existing active bid is updated rather than duplicated.
- Audit event is written.

**Positive finding:** server-side partner eligibility and bid validation are stronger than UI-only gating.

**P0-B — No real partner can bid now.** Production has zero eligible opportunities and zero active partner bids; the partner capability and organisation statuses prevent operational bidding. Partner acquisition and verification are the immediate real-world dependency.

## 5. Customer quote acceptance and assignment

The canonical quote acceptance page uses `public/customer-os/assets/quote-operations.js` and calls `krim_accept_global_quote`.

The SECURITY DEFINER acceptance function:
- Locks quote and shipment rows.
- Requires customer organisation access and `shipment.update`.
- Rejects expired or non-sent quotes.
- Requires the customer quote to reference a partner quote.
- Requires the partner quote to be accepted and match the shipment, amount, currency and partner assignment.
- Requires active/verified partner organisation and a current verified capability covering the shipment.
- Transitions the shipment to confirmed and finalizes the accepted partner assignment.
- For an already accepted quote, it only treats the operation as idempotently finalizable if a matching accepted/active assignment exists; otherwise it raises an error.

The RPC is executable by authenticated users and checks organisation/permission internally.

**P0-C — Historical accepted quotes are not proof of a valid provider-backed booking.** Six accepted customer quotes currently have `partner_quote_id = NULL`. They cannot satisfy the current partner-backed acceptance invariant. Treat them as historical/test records pending reconciliation, not as evidence that KRIM has completed six real bookings.

**P1-D — Customer-facing quote list should clearly distinguish quote origin and provider linkage.** The canonical quote detail code reads `partner_quote_id` and matching assignment, but the generic list primarily displays amount/status. Ensure a customer never mistakes a tariff-only quote, historical quote or partner bid request for a confirmed provider booking. A quote being accepted is not proof of delivery, payment or KRIM revenue.

## 6. Dispatch, tracking and POD

The previously completed dispatch/POD audit remains applicable:
- Exact-leg `krim_authorize_leg_dispatch` requires an accepted assignment, shipment dispatch permission, exact leg, capacity reservation and required driver/vehicle verification for road; later legs require custody transfer.
- Dispatch authorisation is distinct from actual departure.
- Dispatch readiness `ready_for_authorized_review` is not a dispatch.
- Driver POD submission is bound to assigned driver, in-transit assignment and private driver evidence.
- Admin POD review requires MFA AAL2, platform-admin authority and reviewer independence from the driver.
- Customer POD access is restricted to independently verified evidence and authorized organisation access.
- GPS tracking is limited to active consented sessions, verified driver, in-transit status and active assignment; terminal shipments suppress GPS.

Current production counts confirm there are no accepted assignments, dispatch authorisations or verified PODs. The single tracking event is not evidence of a live shipment-tracking journey.

## 7. Tenant access and record integrity

RLS policies inspected for:
- `krim_shipments`
- `krim_shipment_legs`
- `krim_quotes`
- `krim_partner_quotes`
- `krim_shipment_partner_assignments`
- `krim_partner_capabilities`
- `krim_capacity_reservations`
- `shipment_dispatches`
- `krim_tracking_events`
- `krim_pod_records`

Positive controls:
- Shipment reads are scoped to customer organisation, active assigned partner, authorized operations role or a narrow open-opportunity eligible partner predicate.
- Customer quote reads require access to the quote's customer organisation.
- Partner quote reads are scoped to the partner organisation or the relevant customer organisation for its opportunity.
- Assignment reads are scoped to the shipment customer or assigned partner.
- POD customer reads require verified status and verified timestamp; partner access is scoped to the partner organisation.
- Tracking reads are scoped to customer organisation, active assignment, operations permission or exact driver assignment.

The `shipment_dispatches` table is a legacy surface with partner-profile-based own-dispatch policies. Keep the newer exact-leg authorisation path canonical; do not revive the legacy shipment-wide dispatch path.

**Security verification limitation:** RLS policy definitions were inspected, but no two-tenant direct API penetration test was executed. The SQL read-only review does not prove every nested RPC, view or storage object is tenant-safe.

## 8. Staging acceptance tests

1. Customer A can create a shipment only for an active organisation where they have `shipment.create`.
2. Customer B cannot create a shipment under Customer A's organisation by altering the RPC parameter.
3. Idempotent retry returns the same shipment for identical payload and rejects a changed payload with the same request UUID.
4. Missing/unconfirmed market endpoints fail closed at the database function, even if browser preflight is bypassed.
5. Unsupported transport mode, route type, invalid place coordinates, empty cargo, zero/negative weight and cross-border mismatch are rejected.
6. No customer-facing amount is displayed before an approved rate card or real partner bid exists.
7. Tariff selection uses only current, approved, evidence-backed rate cards; expiry, wrong route, wrong mode, wrong tier and tax-treatment mismatch fail closed.
8. Tariff calculation tests flat, per-kg, minimum charge, currency minor units, overflow, expiry and concurrent duplicate requests.
9. If tariff is unavailable, a single idempotent opportunity is created with the correct shipment and customer organisation.
10. Opportunity creation rejects inactive markets, missing transport mode, expired deadlines and unsupported multi-leg shipment-wide sourcing.
11. Partner A cannot see or bid on Customer B's private shipment unless an eligible opportunity explicitly exposes the limited sourcing view.
12. Unverified, expired-compliance, inactive, development-test or capability-mismatched partners cannot bid, even by direct RPC.
13. Partner cannot bid on own customer shipment or on a closed/awarded/expired opportunity.
14. Duplicate partner bid submission updates the existing active bid; concurrent submissions do not create duplicate active bids.
15. Customer cannot accept a quote from another organisation or an expired/non-sent quote.
16. Customer acceptance requires accepted partner quote and matching accepted assignment, same shipment, partner, amount and currency.
17. Customer acceptance is idempotent only when the matching assignment is already accepted/active; otherwise fail closed.
18. Multi-leg quote/assignment/capacity and custody are tested per leg, including partial failures and retry.
19. Dispatch cannot be authorised without accepted assignment, exact leg, capacity, driver/vehicle verification and custody where required.
20. Dispatch authorisation is not reported as physical departure until a separate departure event is recorded.
21. Tracking events are tenant-scoped, ordered, deduplicated and source-attributed; GPS is hidden when consent/session/assignment/driver status is invalid or stale.
22. POD submission requires the correct assigned driver and private evidence object ownership.
23. POD approval requires independent reviewer, AAL2 and platform-admin authority; rejected POD cannot close delivery.
24. Customer sees only verified POD evidence for an authorized shipment.
25. Shipment closure requires required leg completion, delivery evidence and all configured exception/compliance gates.
26. Customer direct freight payment to partner is not inferred from quote acceptance, assignment, shipment status or a KRIM payment record.
27. KRIM referral revenue is recognized only under the separate signed fee agreement, delivered-service evidence, KRIM service invoice and receipt/reconciliation controls; freight GMV is not KRIM revenue.
28. All workflow events and outbox notifications are idempotent, recoverable, tenant-safe and observable; retries and dead-letter paths are tested.
29. Cross-tenant tests cover direct table reads, every exposed RPC, signed storage URLs, customer quote lists, shipment details, tracking and POD.
30. Browser failure after a successful RPC does not create duplicate shipment, opportunity, bid, acceptance, dispatch or POD on retry.

## 9. Release blockers and sequence

### P0 — before a real shipment
1. Verify and contract at least one real partner for a specific route/mode/cargo profile, with current evidence and operational capacity.
2. Activate only the specific market corridor and partner capability supported by evidence.
3. Reconcile historical/test shipments and quote records; exclude them from customer-facing live pipeline metrics.
4. Ensure tariff quotes and partner bids remain visibly distinct and quote acceptance cannot bypass provider assignment.
5. Complete staging tests for idempotency, partner bidding, acceptance, assignment, dispatch, tracking and verified POD.
6. Confirm customer support, exceptions, cancellation and failed-delivery procedures before taking a real order.

### P1 — before broad launch
1. Build leg-specific sourcing and assignment for multimodal and multi-leg routes.
2. Provide due-date/expiry, stale-quote and no-partner-available states with honest customer messaging.
3. Add full lifecycle observability from shipment request through quote, opportunity, bid, assignment, capacity, dispatch, tracking and POD.
4. Reconcile event receipts and notification outbox delivery; a completed cron run is not proof the customer or partner received an alert.
5. Add customer-facing audit history and explicit distinctions between request, offer, confirmed provider assignment, dispatch, delivery and verified POD.
6. Add a tenant-isolation test suite for tables, RPCs and private storage.

### Safety / migration constraint
The repository-to-production migration-history mismatch remains unresolved. Do not apply/replay/baseline migrations or make production schema, function, policy, grant or financial changes until exact production schema source and migration crosswalk are recovered and reconciled. This audit is read-only.

## 10. Scope and limitations
Inspected current GitHub pages and JavaScript for canonical booking, rate desk, partner quote submission, customer quote list/acceptance and shipment details. Read-only production queries inspected selected table counts, statuses, shipment/quote records, partner capability and organisation status, RPC definitions/grants and RLS policies. Reused the detailed prior dispatch/tracking/POD audit for downstream controls.

No real signup, quote request, partner bid, quote acceptance, dispatch, tracking session, POD upload/review or customer payment was executed. No two-tenant penetration test, live carrier confirmation, external provider API delivery, route simulation or staging E2E was performed.

**Decision:** the software contains important controls for the intended journey, but real-world fulfilment is blocked by partner readiness and zero current assignments/capacity/dispatch/POD evidence. KRIM is not yet a live freight operator for any unverified route.
