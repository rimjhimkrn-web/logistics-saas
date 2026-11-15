# KRIM Logistics OS — Shipment Lifecycle Map

**Last reconciled:** 16 November 2026  
**Authority:** Production database routines and current canonical workspace flows take precedence over older mock pages and historical status labels.

## 1. Operating principles

- A shipment request is not a quote, provider commitment, assignment, dispatch, delivery or payment.
- A quote is not a booking until the current provider-acceptance and customer-acceptance gates have completed.
- A provider-accepted assignment is not dispatch authorization. Physical capacity, driver/vehicle readiness, leg/custody and compliance gates still apply.
- A delivery submission is not a verified delivery. POD review and delivery authorization are separate.
- KRIM's current freight collection model is **partner-direct**: the customer contracts with and pays the logistics provider directly. `partner_direct` is not a paid, settled or KRIM-collected state.
- GPS collection remains disabled pending consent, legal and device validation. Do not describe GPS telemetry as active.
- Customs clearance is only recorded when the applicable legal, broker and authority evidence supports it. A generic shipment milestone is not a customs approval.
- A state shown in legacy data may predate the current lifecycle contract. Always verify linked records before treating it as operational truth.

## 2. Intended single-leg customer-to-partner lifecycle

1. **Shipment request — `draft` / request state**  
   Canonical customer form: `public/shipper/booking-request.html`. It uses `krim_create_global_shipment_idempotent`, active organization membership and server-side `shipment.create` authorization. Booking request IDs protect retries. Creating a shipment does not imply market coverage or provider availability.

2. **Pricing / partner sourcing — `quoted` workflow**  
   Canonical quote desk: `public/shipper/rate-calculator.html`. It calls `krim_create_tariff_quote` for approved tariff pricing and `krim_create_partner_opportunity` for partner sourcing. Tariff quotes require a currently approved rate card; partner sourcing requires active origin/destination markets. A location catalogue entry alone is not service coverage.

3. **Partner offer submission**  
   Canonical partner page: `public/partner/submit-quote.html`. It calls `krim_submit_partner_quote` against an open opportunity. The backend validates partner organization status, current verification/compliance, capability, route, cargo and opportunity validity. A submitted partner quote is not yet a customer quote or assignment.

4. **Customer prepares provider offer**  
   Canonical customer comparison: `public/shipper/quote-comparison.html`. It reads eligible partner offers and calls `krim_customer_prepare_partner_quote`. The backend creates a customer quote linked to the selected partner quote and an `offered` partner assignment. It does not yet confirm the shipment.

5. **Provider accepts assignment**  
   Partner response is recorded through `krim_respond_to_partner_assignment`. The accepted assignment must match the partner quote, shipment, partner organization and exact leg where applicable. An acceptance trigger creates a legacy shipment-weight capacity commitment. This commitment is not by itself proof of a physical vehicle/resource reservation.

6. **Customer accepts exact quote**  
   The customer accepts via `krim_accept_global_quote`. The server requires a linked accepted partner quote, matching accepted partner assignment, active/verified/compliant partner, current capability covering the shipment and matching price/currency. It then transitions the shipment to `confirmed` and finalizes the partner assignment to `assigned`. This is a provider commitment, not dispatch, delivery or payment.

7. **Physical capacity reservation and dispatch readiness**  
   The partner must reserve actual capacity for the exact shipment leg using `krim_partner_reserve_shipment_leg_capacity`. This creates a reservation and leg binding against an approved capacity resource and availability window. The leg dispatch authorization routine `krim_authorize_leg_dispatch` independently requires an accepted exact-leg assignment, confirmed binding and reservation. For ROAD, it additionally requires an accepted, verified driver, current licence, verified active vehicle binding and required vehicle documents. A later leg requires an accepted custody transfer from the preceding leg.

8. **Driver execution / trip milestones**  
   Driver modules verify authenticated driver membership and assignments. Pickup and transit milestones must be persisted against the correct assignment/leg. GPS remains off until the separate legal consent and physical device gates are approved; milestone events must not be fabricated from browser geolocation.

9. **Delivery evidence submission**  
   Driver POD module: `app/driver/module-10-proof-of-delivery.html`. It uploads private evidence to `krim-driver-evidence`, records metadata in `krim_driver_delivery_evidence`, then calls `krim_driver_submit_delivery_pod`. The server checks the signed-in driver owns the assignment, active driver membership, in-transit state, matching partner assignment, exact shipment/leg and an existing private evidence object owned by that driver.

10. **Independent POD verification and delivery authorization**  
    Platform-admin review uses `krim_admin_review_delivery_pod`, requires AAL2 and platform-admin permission, blocks the submitting driver from reviewing their own POD, and checks private evidence ownership. Verification is followed by a separate delivery authorization before the driver assignment/shipment can be treated as delivered. Customer ePOD access must remain restricted to authorized organizations and verified evidence.

11. **Commercial closure and finance**  
    Delivery and settlement are separate. Under the partner-direct launch model, KRIM does not collect or verify freight payment. Any KRIM referral/coordination fee is separate from provider freight charges and must be contractually, tax and accounting reviewed. Do not create a paid/settled state from a partner-direct record.

## 3. Multi-leg lifecycle

For shipments requiring multiple transport legs, the intended path is:

1. Create a versioned plan with contiguous sequence numbers, connected endpoints, mode, service window and cargo constraints.
2. Evaluate the plan; activate it atomically with an idempotency key; verify expected and created leg counts.
3. Source, quote and assign each leg independently to a currently eligible partner.
4. Reserve physical capacity for each exact leg.
5. Dispatch only after leg-specific partner assignment, capacity, driver/vehicle and required compliance checks.
6. Record arrival and custody handover between adjacent legs. The receiving partner must accept the transfer before onward dispatch.
7. Submit POD for the exact leg and assignment. A leg's completion must not mark the whole shipment delivered until all required legs are complete and final delivery is independently verified.

Relevant records include `krim_shipment_leg_plans`, `krim_shipment_leg_plan_items`, `krim_shipment_leg_activations`, `krim_shipment_legs`, `krim_shipment_partner_assignments`, `krim_capacity_reservations`, `krim_capacity_leg_bindings`, `krim_shipment_leg_dispatch_authorizations` and `krim_shipment_leg_custody_transfers`.

The legacy shipment-wide `krim_dispatch_shipment` path and newer exact-leg `krim_authorize_leg_dispatch` path must not be treated as interchangeable. Their contracts and capacity records require continued consolidation/traceability review.

## 4. Status meanings and non-equivalences

| Record / state | What it establishes | What it does not establish |
|---|---|---|
| Shipment `draft` / `quoted` | Customer request and/or quote workflow state | Provider acceptance, assignment or dispatch |
| Customer quote `sent` | A quote is presented for customer review | Provider has accepted or shipment is booked |
| Partner assignment `offered` | Provider has an assignment offer to respond to | Provider acceptance |
| Partner assignment `accepted` | Provider accepted the linked assignment | Physical capacity binding or dispatch authorization |
| Shipment `confirmed` | Current intended flow: customer accepted after provider acceptance | Dispatch, freight payment or delivery |
| Shipment / leg `assigned` | Provider responsibility recorded | Physical dispatch has occurred |
| Capacity commitment | Shipment weight commitment attached to assignment | Verified vehicle/resource availability for a time window |
| Capacity reservation + confirmed leg binding | Physical capacity reservation is recorded for the exact leg | Dispatch has been authorized or cargo collected |
| Dispatch authorization | Server readiness checks passed for the exact leg | Driver has physically collected the cargo |
| POD `submitted` | Driver submitted evidence for review | Delivery independently verified |
| POD `verified` | Authorized reviewer verified submitted evidence | Shipment closure or provider/customer payment settlement unless separate rules pass |
| `partner_direct` payment status | KRIM is not collecting the freight payment | Payment received, paid, reconciled or settled |

## 5. Current production snapshot — 16 November 2026

This snapshot was obtained through read-only production SQL. It is not a test run and no production records were created or changed.

| Object | Count / state |
|---|---:|
| Active KRIM markets / active countries | 6 / 6 (of 249 country catalogue records) |
| Active partner-type organizations / verified eligible organizations | 2 / 0 |
| Shipments | 18: 8 draft, 3 quoted, 6 confirmed, 1 closed |
| Customer quotes | 7: 6 accepted and 1 sent; all 7 have no linked partner quote |
| Partner opportunities | 3: 2 cancelled, 1 expired; 0 open |
| Partner quotes | 0 |
| Partner capabilities | 1 pending and inactive; 0 verified active |
| Approved active rate cards | 0 (1 rate card record exists, inactive) |
| Partner assignments | 0 |
| Capacity resources | 0 |
| Capacity reservations / leg bindings | 0 / 0 |
| Shipment legs | 1, status assigned |
| Active multi-leg plans / activations | 0 / 0 |
| Driver assignments | 0 |
| Dispatch authorizations | 0 |
| Custody transfers | 0 |
| Driver delivery evidence / POD records | 0 / 0 |
| Shipment milestones | 2 |

**Release-blocking data discrepancies:** six shipments are `confirmed` but have no accepted/active partner assignment; the six accepted quote records have no partner quote link; the one assigned shipment leg has no matching accepted/active partner assignment. Six readiness-gate records are currently marked `ready` with `partner_status='not_required'`. The current readiness evaluator treats `confirmed` as not requiring a partner, which conflicts with the current quote-acceptance contract. These legacy records must not be presented as real booked/assigned shipments until individually reconciled.

No historical rows were rewritten as part of this audit. Do not bulk-update statuses or invent partner links to make counts look healthy.

## 6. Launch guardrails

- Keep customer booking and partner sourcing unavailable for markets/corridors that are not explicitly active.
- Do not publish tariff prices without an approved active rate card.
- Do not call a shipment booked/assigned without a matching verified partner assignment.
- Do not call an assignment dispatch-ready without a confirmed physical capacity reservation and all applicable leg/driver/vehicle/custody checks.
- Keep freight checkout and KRIM freight-fund collection disabled under the current partner-direct model.
- Keep GPS disabled until the legal consent notice, retention policy and physical Android tests are approved.
- Keep customs filing/clearance disabled until authoritative jurisdiction requirements and verified broker capability are approved.
- Do not mark delivered without private driver evidence, independent POD verification and delivery authorization.
- Treat all production rows predating the current contract as legacy until reconciled.

## 7. Audit references

- `docs/audits/KRIM-CUSTOMER-TO-PARTNER-OPERATIONS-TRACEABILITY-2026-11-16.md` — current page/backend/data traceability and blockers.
- `docs/phase-3-shipment-creation-audit-2026-10-23.md` — shipment request and idempotency.
- `docs/phase-4-quotes-pricing-audit-2026-10-23.md` — tariff and partner quote gates.
- `docs/audits/step-05-shipment-matching-assignment-2026-11-05.md` — matching, assignment and capacity controls.
- `docs/phase-8-pickup-custody-handover-audit-2026-10-23.md` — pickup and custody limitations.
- `docs/phase-10-delivery-proof-of-delivery-audit-2026-10-23.md` — historical POD audit; this must be read alongside the current driver POD source, which now includes an evidence submission form.
- `docs/phase-11-customer-finance-shipment-closure-audit-2026-10-23.md` — finance and closure.
- `docs/shipments/MULTI-LEG-EXECUTION-RELEASE-SPEC.md` — multi-leg release criteria.

