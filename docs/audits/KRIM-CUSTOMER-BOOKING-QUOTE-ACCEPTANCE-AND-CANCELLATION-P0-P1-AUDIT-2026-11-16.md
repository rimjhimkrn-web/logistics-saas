# KRIM Customer Booking-to-Quote Journey and Cancellation Integrity Audit
Date: 2026-11-16

## Executive result

**NO-GO for customer self-service booking and quote acceptance in production.** The customer UI is wired to a modern idempotent booking RPC and a partner-direct quote award flow, but the live database's shipment-write trigger conflicts with the booking RPC call chain. The current live market/corridor governance state independently blocks all shipment writes. A legacy quote-acceptance RPC also remains callable by authenticated users without the same partner-binding safeguards used by the current UI.

## 1. P0 — Booking creation path conflicts with mandatory transport-mode trigger

The current booking page `public/shipper/booking-request.html` calls:

`krim_create_global_shipment_idempotent(bigint,jsonb,jsonb,text,numeric,text,text,uuid)`

The live function:
1. Validates authenticated user, active customer organization, organization membership and `shipment.create`.
2. Uses an advisory transaction lock and organization-scoped booking request UUID.
3. Checks an existing booking key against the normalized route/place, cargo, weight, mode and route-type fields.
4. For a new booking, calls the 7-argument `krim_create_global_shipment_from_places`.

The live overload chain is:
- 7-argument overload validates route type, then calls the 6-argument overload.
- 6-argument overload calls the 5-argument overload to create the shipment, and only afterwards updates `requested_transport_mode` and selected-place metadata.
- 5-argument overload calls `krim_create_global_shipment`, which inserts a shipment without `requested_transport_mode`.

A live BEFORE INSERT trigger `krim_enforce_corridor_compliance_before_shipment_write` requires a nonblank `requested_transport_mode` and an exact active corridor with an approved mode-matched dossier. It therefore rejects the insert before the later UPDATE can set the mode.

**Result:** the current customer booking RPC call chain cannot complete a new shipment insert as written. This is the previously reported P0 booking/RPC defect, confirmed again against current live definitions and the active trigger.

## 2. P0 — Market and corridor controls currently block all booking attempts

The active shipment write path also enforces:
- origin and destination market activation,
- exact origin/destination corridor match,
- approved corridor dossier and mandatory controls,
- approved country operating packs for every corridor jurisdiction.

The preceding live global activation audit recorded 6/6 market controls blocked, 249 country packs research_pending, 4,482 mandatory country controls pending/unknown, zero regulatory sources, 7 draft corridors and zero approved corridor dossiers. Thus correcting the function call order alone would not enable bookings today. This is an intentional fail-closed protection, not a reason to bypass the trigger.

## 3. P1 — Legacy authenticated quote acceptance lacks the current partner-binding safeguards

The current `public/shipper/quote-comparison.html` journey uses the stronger path:
- customer selects a live partner offer;
- `krim_customer_prepare_partner_quote` delegates to `krim_award_partner_quote_for_checkout`;
- that routine checks customer organization access and `quote.update` + `shipment.update`, prevents multi-leg shipment-wide awards, validates positive partner quote amount and validity, binds the opportunity/quote/shipment/customer, creates a partner assignment offer and customer quote together;
- after the provider accepts, the UI calls `krim_accept_global_quote`;
- that routine checks organization access and `shipment.update`, quote validity, shipment state, accepted partner quote and matching accepted assignment, partner organization verification/lifecycle/compliance status, active verified capability and shipment capability coverage before confirming and finalizing assignment.

However, the separate authenticated `krim_customer_accept_quote(bigint)` remains executable by authenticated users. Its live definition:
- checks authentication and customer organization access;
- checks only that quote status is `sent`;
- updates the customer quote to `accepted` and writes a quote event;
- does not require `quote.update` or `shipment.update`;
- does not bind acceptance to an accepted partner quote or accepted partner assignment;
- does not transition the shipment or finalize the partner assignment.

The current inspected quote-comparison UI does not call this legacy RPC; it calls `krim_accept_global_quote`. Nevertheless, the weaker authenticated RPC remains a reachable alternate acceptance path and can produce an accepted quote record without the partner acceptance and assignment conditions enforced by the modern path. It should be revoked from authenticated users or changed to delegate to the single canonical guarded acceptance routine after compatibility analysis.

## 4. P1 — Customer cancellation/withdrawal workflow not found

The live public shipment/quote function inventory contains quote rejection and a trigger that cancels a customer quote after partner rejection, but no customer-facing shipment cancellation, booking withdrawal, or quote-withdrawal RPC was identified. The main quote-comparison page offers award/acceptance and refresh actions; it does not expose a defined cancellation or withdrawal workflow.

A safe cancellation flow must distinguish:
- draft booking withdrawal before partner award;
- quote rejection before assignment;
- cancellation after partner acceptance but before dispatch;
- cancellation after dispatch (exception/return process, not ordinary cancellation);
- capacity reservation release, partner notification/acknowledgement, cancellation reason, potential partner costs, audit history and refund/fee handling.

Do not expose a generic status update or treat post-dispatch cancellation as a normal booking cancel.

## 5. Production data — no end-to-end proof

Live counts at audit time:
- Shipments: 18 (8 draft, 3 quoted, 6 confirmed, 1 closed)
- Customer quotes: 7 (6 accepted, 1 sent)
- Partner quotes: 0
- Partner assignments: 0
- Partner opportunities: 3
- Quote versions: 0

The zero partner quote/assignment/quote-version records mean the current modern partner-direct award and acceptance journey has no production execution evidence. Existing shipment/quote rows are not proof of a successful current customer journey.

## 6. Positive controls

- Booking UI uses a stable per-browser booking request UUID and the server uses an organization-scoped advisory lock and canonical payload comparison on retries.
- Booking function checks active customer organization, membership and `shipment.create`.
- Current quote comparison UI checks partner-offer validity and displays partner acceptance as a separate prerequisite.
- Modern award routine creates the partner assignment offer and customer quote in one database transaction.
- Modern customer acceptance checks exact quote/partner quote/assignment linkage and current partner status/capability before shipment confirmation.
- Shipment readiness triggers guard transitions into confirmed, assigned and dispatched states.
- Market and corridor write-time gates are fail-closed.

## Required remediation — not applied

1. Replace the nested shipment-creation overload chain with one atomic canonical insert that writes validated `requested_transport_mode`, route type and selected-place metadata in the INSERT before any BEFORE INSERT corridor/market trigger runs. Preserve all current authorization and corridor gates.
2. Keep booking idempotency atomic: unique organization + booking-request key, canonical normalized request payload comparison, and one transaction covering shipment, route/place metadata, initial leg and booking key.
3. Revoke the authenticated execute grant on the legacy `krim_customer_accept_quote` path or make it delegate to the canonical guarded acceptance function; first verify all callers and compatibility.
4. Define and implement the customer cancellation/withdrawal state machine, including pre-award and post-award cases, partner consent/notice, capacity release, fee exposure and audit trail. Dispatch/post-dispatch cases must use an exception/return workflow.
5. Align UI copy and error handling so market/corridor blocks are explained as unavailable coverage, not generic booking failures.
6. Add staging-only E2E tests for new booking, exact idempotent retry, same key/different payload rejection, route/mode mismatch, inactive market, missing corridor dossier, expired source, quote award, partner acceptance, customer acceptance, legacy RPC denial, quote expiry, rejection and cancellation at each allowed stage.
7. Reconcile the 558-version production migration history with repository migrations before any production DDL/function/ACL changes. Do not bypass country/corridor gates to make the booking page appear to work.

## Release impact

**NO-GO for real customer booking, quote acceptance or cancellation operations.** The current modern quote acceptance design has strong checks, but the first booking call path is blocked by the active BEFORE INSERT trigger and no market/corridor is activated. The legacy quote acceptance RPC is a second path that must be closed before commercial use.

## Evidence boundaries

Read-only inspection of live function definitions, ACLs, shipment triggers, table counts and customer booking/quote UI call sites. No booking, quote, partner assignment, shipment transition or cancellation RPC was executed. No production record, schema, ACL, policy or configuration was changed.
