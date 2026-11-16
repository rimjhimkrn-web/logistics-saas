# KRIM Customer-to-Partner Commercial Journey, Booking Integrity and False-Confirmation Audit — 2026-11-16

## Executive decision
**NO-GO for live shipment request distribution, partner marketplace bidding, customer quote acceptance as a commercially bookable service, and operational booking.** The architecture contains meaningful backend gates and customer-facing language correctly separates shipment request, partner quote, assignment, operational readiness, dispatch and partner-direct freight payment. However, the current shipment form has a material integration defect: it collects a selected transport tier but does not persist the transport mode required by the partner-opportunity RPC. The RPC then rejects the opportunity. Separately, production market controls currently block operational booking, and there is no approved partner supply base. The frontend's active location catalogue is not an operational coverage signal.

This audit is read-only. No inquiry, shipment, opportunity, quote, assignment or partner bid was created; no RPC or Edge Function was invoked; no customer/partner contacted; no production data or schema changed.

## 1. Production evidence snapshot

| Object | Current rows / state |
|---|---:|
| Public contact inquiries | 0 |
| Customer service requests | 0 |
| Shipments | 18 |
| Shipment statuses | 8 draft, 3 quoted, 6 confirmed, 1 closed |
| Shipments with requested transport mode NULL | 17 of 18 |
| Shipments with requested transport mode multimodal | 1 |
| Partner opportunities | 3: 2 cancelled, 1 expired |
| Partner-submitted quotes | 0 |
| Customer quote records | 7: 6 accepted, 1 sent |
| Customer quote records linked to partner quote | 0 of 7 |
| Customer quote records expired at audit time | 7 of 7 |
| Shipment partner assignments | 0 |

These are row counts and stored statuses, not proof of completed customer transactions. In particular, the six legacy `accepted` customer quote rows have no `partner_quote_id`, are all expired, and have no matching partner-submitted quote or assignment. They must not be presented as current provider offers or confirmed bookings.

Prior market/corridor audit evidence remains applicable: six market catalogue rows are active metadata only but operationally blocked; all 249 country operating packs are research_pending; no corridor dossier/control is approved. Partner network audit found zero approved active capabilities, zero service areas, zero partner quotes and zero assignments. These conditions block real commercial coverage.

## 2. P0 — Shipment form omits the requested transport mode required by partner opportunity creation

### Frontend evidence
`public/shipments/shipment-create.html` presents a required “Preferred transport mode” selector with values:
- `surface_express`
- `air_priority`
- `heavy_haul`

On submit, it reads the selected value into `tier`, calls `krim_create_global_shipment` with customer organization, origin, destination, cargo description and weight, then calls `krim_create_partner_opportunity` with the selected `p_service_tier`.

**The first RPC payload does not include the selected transport mode or service tier.** The shipment creation function inserts the shipment without setting `requested_transport_mode`. The selected `tier` is only passed to the subsequent opportunity RPC.

### Live backend evidence
The live `krim_create_partner_opportunity(bigint,timestamptz,text)` function explicitly raises:
> Partner bid request blocked: shipment has no recorded transport mode.

The function requires a non-null `krim_shipments.requested_transport_mode` before creating an opportunity.

Production data is consistent with this defect: 17 of 18 shipment rows currently have `requested_transport_mode IS NULL`. This count alone cannot prove every row came from this form, but it corroborates the missing-field path.

### User impact
A customer can fill the form, select a mode and press “Create shipment & request partner bids”. The first RPC may create a draft shipment, while the second RPC fails. The page does display a partial-failure warning and says not to resubmit; this is safer than a false success, but the advertised one-step workflow does not complete.

### Required remediation
- Define one canonical mapping between the user-facing service tier and actual transport mode. Do not store `surface_express` / `air_priority` / `heavy_haul` as physical mode values if the database expects ROAD/AIR/RAIL/OCEAN etc.
- Extend the authoritative shipment creation contract to validate and persist the selected mode/tier (or use an explicitly approved existing RPC argument/column).
- Prefer one atomic server-side “create shipment request + create partner opportunity” transaction, or an idempotent orchestration RPC with a durable state and safe retry. The current two-call frontend sequence can leave a draft shipment without its opportunity.
- Add an idempotency key to the customer submission and make a retry return the existing shipment/opportunity rather than create duplicates.
- Add a visible recovery action for a shipment saved without an opportunity; it must retry only opportunity distribution for that exact shipment, not create a second shipment.
- Do not modify production function/migration until schema reconciliation and explicit authorisation.

## 3. P0/P1 — Active catalogue selection overstates operational bookability

The form loads `krim_countries.is_active=true` and `krim_locations.is_active=true`, and labels these as active locations/hubs. But the live `krim_create_global_shipment` backend additionally calls `private.krim_market_country_operational` for both endpoint countries and rejects the shipment if either market is not operationally activated.

Prior global market audit shows every current country operating pack is research_pending and all six market catalogue rows remain operationally blocked. Thus an active country/location catalogue entry does not mean the route can be booked or partner bids distributed.

**Required remediation:** filter or annotate route choices using the same server-owned market-operational decision that the shipment RPC enforces. Show “location listed — operations not yet activated” separately from “operationally bookable”. Return a structured gate code and user-safe reason from the backend rather than exposing raw SQL errors. Never enable a route based only on `is_active`.

## 4. P1 — Shipment creation and opportunity distribution are separate commits

The frontend creates the shipment first, then creates the partner opportunity in a second RPC. If the second RPC fails:
- the shipment remains persisted;
- the user is redirected to booking confirmation with `distribution=needs-attention`;
- the confirmation page correctly says the shipment record is not a confirmed carrier booking;
- the user is instructed not to submit the shipment again.

This is transparent partial failure, but the workflow has no visible one-click recovery path for creating/retrying the missing opportunity. A network timeout after the second RPC commits can also leave the browser uncertain whether the opportunity exists. The opportunity RPC is partially idempotent because it returns an existing open opportunity, but the full two-step request is not an atomic, end-to-end idempotent operation.

**Required remediation:** single transactional RPC or durable request state machine with idempotency, plus a recovery action that checks the authoritative opportunity register before retry. Do not automatically retry a shipment-create call after an ambiguous timeout.

## 5. P1 — Customer quote request page can count non-partner quote rows as offers

`public/customer/quote-request.html` loads rows from `krim_quotes` and its `activeQuotes()` helper treats statuses `draft`, `sent`, `accepted`, `pending` and `approved` as “eligible quote offers” if `valid_until` is absent or in the future. It does not require a non-null `partner_quote_id`, an eligible current partner, a matching accepted partner quote or an accepted assignment.

The customer quote detail/acceptance page has stronger controls: it loads the linked partner assignment and disables acceptance until the matching assignment is accepted/active; the backend `krim_accept_global_quote` requires a partner quote in accepted state, exact shipment/amount/currency binding, matching accepted assignment, active verified partner and current capability coverage.

That backend guard is good, but the list/metric can overstate offers and invite users to compare or act on quote rows that are not real partner offers.

Current production data makes the issue concrete: all seven `krim_quotes` have `partner_quote_id IS NULL`; all seven are expired; six carry legacy `accepted` status and one `sent`. The page's current expiry filter should exclude them today, but any future-dated unlinked row with one of those statuses could be counted as an offer.

**Required remediation:** source customer-facing offers from the canonical partner quote/eligibility view or require the full linkage chain (partner_quote_id, exact shipment, current partner eligibility/compliance/capability, unexpired quote, accepted assignment where required). Label customer quote records and provider bids as different object types. Do not infer provider supply from a generic customer quote status.

## 6. P1 — Partner bid submission UI and backend contain meaningful checks, but no partner supply exists

The partner submission page:
- requires authenticated active organization membership;
- limits bidding to one eligible partner organisation;
- checks registered-business mode, active status, verification, lifecycle, compliance and at least one active verified capability;
- loads open, unexpired opportunities and excludes the customer's own organisation;
- requires positive amount, active currency, future quote validity no later than opportunity deadline, notes length and confirmation checkbox;
- submits through `krim_submit_partner_quote`;
- checks that the returned quote references the exact opportunity and partner and has `submitted` status;
- warns customer review and later award/assignment are separate.

The backend independently repeats authentication, partner eligibility, `quote.create` permission, currency, opportunity status/deadline, multi-leg restriction, shipment capability coverage and self-bid checks. This is positive defense-in-depth.

However, live production has 0 eligible active approved capabilities, 0 service areas, 0 partner quotes and 0 assignments. The opportunity table contains only 3 closed opportunities. Therefore there is no live partner marketplace supply or bid evidence. A page existing and a guarded bid RPC do not establish marketplace readiness.

**Additional control to verify:** the legacy `krim_submit_partner_quote` function should be reviewed against the current partner compliance helper chain. Prior partner-network audit identified that it does not visibly recheck `private.krim_partner_compliance_is_current` in the same way as the leg-specific quote path. Customer offer visibility must never be used as a substitute for rejecting an ineligible partner bid at submission time.

## 7. P1 — Public inquiry acknowledgement and service-request linkage are not one atomic customer journey

The public inquiry Edge Function:
1. validates request shape, privacy notice acknowledgement, name, email, organisation and message;
2. applies IP/email rate limits where available;
3. calls `krim_submit_public_contact_inquiry`, which transactionally creates the inquiry, acquisition profile, qualification case, founder event and notification outbox row;
4. then separately calls `krim_internal_link_public_inquiry_to_service_request`;
5. logs but does not fail the customer response if that service-request linkage call fails.

The function explicitly says a general enquiry is not a quote or booking, which is correct. If linkage fails, it still returns HTTP 200 with “Your inquiry has been received.” This means the public inquiry may exist while the qualification/service-request workflow is incomplete. The prior CRM audit already recorded this as a P1 issue.

**Required remediation:** make inquiry creation and service-request linkage atomic inside one server-side transaction, or expose separate honest statuses such as “enquiry received — qualification pending repair”. Alert operators on linkage failure and provide idempotent repair. Do not tell the customer that a shipment request, quote or booking has been created.

The production count snapshot found 0 public inquiries and 0 service requests, so there is no live customer journey evidence.

## 8. P1 — Booking confirmation is a multi-gate evidence page, not a booking action

`public/shipment-confirmation.html` is read-only and requires shipment_id and quote_id. It checks:
- authenticated session;
- optional legacy KRIM payment order via the server-side payment status function;
- shipment and customer quote records;
- matching customer organization;
- quote status and partner_quote_id;
- matching accepted/active partner assignment with accepted_at;
- latest shipment readiness gate;
- latest shipment execution readiness;
- shipment booking state.

Without a legacy payment order, it explicitly treats freight payment as partner-direct and not collected/verified by KRIM. It only displays “Shipment booking confirmed” when accepted quote, matching partner assignment, readiness and booking status all pass. Otherwise it says not confirmed or readiness pending.

The page does not mutate shipment status. This is good. But static source review cannot certify the readiness queries, RLS or live UI states. In particular, if either readiness query errors and the other returns an empty result, the page fails closed by evaluating readiness as false. Good fail-closed behaviour.

The simpler `booking-confirmation.html` correctly says a saved shipment request is not a confirmed carrier booking and that partner responses, accepted quote, assignment, payment, milestones and POD are separate. It verifies shipment ownership through RLS-scoped reads and redirects to a status page. Good language.

**Remaining concern:** a confirmed quote/assignment is still not proof that a real service contract was executed or that a carrier has physically accepted custody. The prior contract/insurance audit and execution audit remain release blockers. A booking confirmation must not imply dispatch, pickup, transit or delivery.

## 9. P1 — Quote acceptance depends on an assignment that is absent in production

The customer quote acceptance frontend checks a matching assignment in `krim_shipment_partner_assignments` and blocks acceptance unless its status is accepted/active. It then calls `krim_accept_global_quote`. The backend validates the exact accepted partner quote, amount/currency, shipment, customer, active partner status, current capability and assignment, then transitions shipment to confirmed and finalizes the partner assignment.

This is a strong intended sequence, but live data has zero partner-submitted quotes and zero assignments. The six legacy accepted quote rows have no partner quote link. The current UI must display them as legacy/unverified, not as evidence of a provider booking. The quote acceptance page already contains a warning for accepted records with no matching accepted assignment.

## 10. P2 — Additional UX and integrity gaps
- The shipment form uses user-facing “preferred transport mode” wording while the values are service tiers; this semantic mismatch contributed to the missing persisted mode.
- The form's “active hubs / countries” count should never be used as an availability or route coverage claim.
- The customer quote list limits shipments to 100 and quotes to 300 without pagination; older customer records can disappear from the page without an explicit “showing latest N” explanation.
- Partner marketplace reads up to 100 opportunities and 100 partner bids; add cursor pagination before larger scale.
- A customer quote status of `accepted` is not a provider assignment unless the exact linked partner quote and accepted assignment are also verified.
- A partner offer submission success is not an award, contract, confirmed capacity, booking or dispatch. The UI currently states this distinction correctly.
- The customer journey has no complete live example to validate notification, status progression, quote comparison, acceptance, readiness or service recovery.

## 11. Required staging acceptance tests — not run
1. Customer creates shipment with each supported transport service tier; canonical requested transport mode is persisted and correctly mapped.
2. Unsupported or unmapped service tier is rejected before any shipment insert.
3. Both endpoint markets operationally approved; only then can the shipment request proceed.
4. Active catalogue location in a research_pending/blocked market is clearly shown as not operationally bookable and is rejected server-side.
5. Shipment + partner opportunity creation is atomic or idempotently recoverable after failure/timeout.
6. Repeated submit with the same idempotency key returns the same shipment and opportunity.
7. Opportunity creation failure leaves an explicit repair state and recovery action; no duplicate shipment.
8. Partner bid submission denied for unverified, expired, suspended, non-compliant, wrong-mode, out-of-region, overweight or wrong-tenant partner.
9. Duplicate partner bid retries update/return the same active bid or reject conflicting payload; no duplicate active offer.
10. Customer offer list excludes expired, unlinked, ineligible or wrong-shipment partner quotes.
11. Customer acceptance requires exact partner quote, exact shipment, exact amount/currency, active verified partner, current capability and accepted assignment.
12. Quote expiry between page load and click is rejected by server and shown as expired.
13. Partner award, partner acceptance, customer quote acceptance and shipment confirmed state remain distinct and auditable.
14. Confirmation page fails closed if shipment, quote, assignment, readiness or execution-readiness data is missing, inaccessible or inconsistent.
15. Customer cannot view or act on another organisation's shipment, quote, assignment or readiness.
16. Public inquiry linkage failure is visible to operators and repairable without duplicate enquiry/service request.
17. Customer-facing status copy distinguishes enquiry received, shipment request saved, partner opportunity open, partner quote received, quote accepted, assignment accepted, operational readiness, dispatch, pickup and delivery.
18. All retries, conflicts, cancellation, expiry and error states are recoverable and leave immutable audit evidence.

None of these tests has been executed.

## 12. Release decision and remediation order
**NO-GO** for live marketplace bidding, route booking, customer quote acceptance as a fulfilled commercial service, or shipment execution.

Priority order:
- **P0:** fix shipment form transport-mode mapping and make shipment/opportunity creation atomic or idempotently recoverable.
- **P0:** make operational market readiness visible in the route selector and retain server-side hard block.
- **P1:** make customer quote offer listing depend on canonical partner quote eligibility, not generic quote status.
- **P1:** make public enquiry-to-service-request qualification atomic or explicitly repairable.
- **P1:** establish real approved partner supply, service areas, contracts, insurance and capacity before inviting customer bookings.
- **P1:** complete staging journey tests for all transitions and false-confirmation cases.
- **P2:** add pagination and complete mobile/role-based UX verification.

## Change boundary
Static source review of customer shipment creation, customer quote list/detail/acceptance, partner quote submission, shipment confirmation, booking confirmation, public inquiry Edge Function and live read-only production counts/function definitions. No DDL/DML, RPC invocation, Edge Function invocation, provider call, customer/partner communication, migration or production change. Production/repository migration-history mismatch remains unresolved; no corrective production DDL or function deployment is authorised.
