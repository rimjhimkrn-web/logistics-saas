# KRIM Customer-to-Shipment Commercial Journey Audit — 2026-11-16

## Scope and method
Read-only review of the canonical customer booking form, customer quote register, quote acceptance, partner quote comparison, and live production RPC definitions and record counts. No shipment, quote, award, cancellation, payment, or assignment action was executed. No production data was changed.

Inspected repository surfaces:
- `public/shipper/booking-request.html`
- `public/customer/quote-request.html`
- `public/shipper/quote-comparison.html`
- `public/customer-os/quotes-pricing/quote-acceptance.html`
- `public/customer-os/assets/quote-operations.js`
- `public/customer/booking-confirmation.html` and legacy route wrappers

## Live production snapshot

### Core records
| Object | Count |
|---|---:|
| Shipments | 18 |
| Customer quotes | 7 |
| Partner quotes | 0 |
| Partner opportunities | 3 |
| Partner assignments | 0 |
| Route options | 0 |
| Partner service areas | 0 |
| Verified active partner capabilities | 0 |
| Active global rate cards | 0 |
| Operationally active market activation controls | 0 |

Shipment statuses: 8 draft, 3 quoted, 6 confirmed, 1 closed.
Customer quote statuses: 6 accepted, 1 sent.
Partner opportunity statuses: 2 cancelled, 1 expired.

### Critical data-integrity qualification
All six customer quotes marked `accepted` have `partner_quote_id IS NULL`. None is backed by a partner quote. The one sent quote also has no partner quote, and it is expired while still carrying status `sent`.

These historical rows must not be represented as provider-backed accepted offers, confirmed carrier bookings, payable freight commitments or operationally assigned shipments. The canonical acceptance RPC now rejects acceptance unless the customer quote is bound to an accepted partner quote and a matching accepted assignment from an active verified/compliant partner with current capability. Its idempotent accepted-state branch also checks for a matching accepted/active assignment.

The customer quote interface contains a potential presentation mismatch: when a row already has status `accepted`, it displays an “already accepted” explanation even if it has no partner quote; the acceptance action itself is disabled unless the matching partner assignment is found. For legacy rows, the status label/message can therefore be mistaken for a valid provider-backed acceptance. This is a UI interpretation issue; the current RPC gate is stronger than the historical data.

## Workflow and security controls verified

### 1. Customer shipment request
The canonical booking page:
- Requires an authenticated session and active customer organisation membership.
- Requires a selected origin and destination, goods description, positive shipment weight, transport preference and route type.
- Uses an idempotent booking-request UUID.
- Calls `krim_create_global_shipment_idempotent`.
- Shows a request reference and directs the user to quote workflow.
- Explains that a place appearing in search is not proof of serviceability, price, carrier, transit time or customs availability.
- Explains that the customer pays the contracting logistics provider directly.

The idempotent creation RPC binds to `auth.uid()`, active organisation access, `shipment.create` permission and active customer organisation. It takes an advisory lock on organisation + booking request ID and rejects reuse of the same request ID with changed shipment details.

The underlying place-based creation function validates named places, country codes, coordinates, supported transport and route types, then delegates to shipment creation. Shipment creation enforces the separate market operational activation and corridor-compliance gates.

### 2. Customer partner-offer visibility
`krim_customer_list_partner_quotes` is SECURITY DEFINER with empty search_path and authenticated execute. It validates a non-empty bounded unique shipment ID list and verifies access to every requested shipment. Returned partner offers are scoped to the customer's own shipment and opportunity and include explicit partner verification, compliance, capability and current eligibility indicators. Non-accepted offers are filtered to open opportunities and currently eligible partners.

### 3. Partner quote selection and award
The customer comparison UI loads partner quotes, customer quotes and assignment records. It disables customer acceptance until the provider assignment has accepted and shipment/quote state, expiry and current partner eligibility checks pass.

The UI calls `krim_customer_prepare_partner_quote`, an authenticated SECURITY INVOKER wrapper, which delegates to `krim_award_partner_quote_for_checkout`. The award function:
- Requires customer organisation access plus both `quote.update` and `shipment.update`.
- Locks partner quote, opportunity and shipment.
- Rejects expired/closed opportunities and invalid/expired partner offers.
- Requires an eligible shipment state and blocks shipment-wide award where an active multi-leg plan exists.
- Prevents duplicate award of the same offer and conflicts with another active customer quote.
- Creates the provider assignment, customer quote, quote version and quote event in one transaction.
- Records the partner quote, assignment, opportunity, amount, currency, and direct-provider payment terms in the pricing snapshot.
- Explicitly records that a production tax invoice is not ready and that finance reconciliation is required.

### 4. Customer quote acceptance
`krim_accept_global_quote` is SECURITY DEFINER with empty search_path and authenticated execute. It locks quote and shipment, checks customer organisation access and `shipment.update`, validates quote status/expiry and requires:
- a linked partner quote for the same shipment;
- an accepted partner quote;
- a matching accepted partner assignment;
- active verified partner organisation and current compliance;
- current verified capability covering the shipment.

It then marks the customer quote accepted, transitions the shipment to confirmed and finalizes the exact partner assignment. The RPC does not collect or settle freight payment. The UI correctly explains that payment is arranged directly with the contracting provider and dispatch remains separate.

### 5. Tariff quote path
`krim_create_tariff_quote` is SECURITY DEFINER and authenticated-callable. It checks customer organisation and `quote.create`, shipment state and weight, active market metadata, operational market activation, transport mode, and a global active rate card with commercial evidence/approval and reviewed tax-treatment metadata. It rejects if no matching rate card is available.

Current live counts show zero active global rate cards and zero operationally active market activation controls. Thus this tariff path should fail closed today; it must not display generated estimates or promise a price.

## P1 findings and release gates

### P1 — Historical accepted quote rows are not partner-backed
Six of six accepted customer quote rows have no linked partner quote, and there are zero partner assignments. These are not valid evidence of provider acceptance or booking. Preserve the audit trail; do not silently rewrite or delete history. Create an explicit legacy/unverified status interpretation or customer-facing warning through a reconciled migration after a data-owner decision. Test all reports, invoice/payment pages, notifications and shipment status screens for any false “booked/confirmed” implication.

### P1 — Customer quote status UI can overstate legacy acceptance
The acceptance UI displays an accepted-state message based on customer quote status, while partner assignment presence only disables the action. For accepted rows lacking `partner_quote_id`, show a clear “legacy/unverified — no confirmed provider assignment” state instead of “already accepted.” The backend acceptance gate must remain authoritative. Make this source change only after checking every page that interprets accepted quotes and add static tests; no production RPC execution.

### P1 — No live commercial supply
Zero partner quotes, assignments, service areas, verified capabilities, active global rate cards and operationally active market controls mean there is currently no evidenced route/service/provider offer to fulfil a customer request. The system correctly has market and corridor gates; do not weaken them to make demo bookings succeed.

### P1 — Cancellation consistency
The earlier cancellation audit found generic transitions allow cancellation from dispatched state and did not prove coordinated release/revocation of all linked partner assignments, capacity reservations, warehouse allocations, custody transfers, driver assignments and notifications. A customer-facing cancellation must not promise a complete cancellation until the canonical orchestrator and all resource-release paths are proven. Post-dispatch/in-transit changes should use a controlled disruption/return workflow, not a generic status update.

### P2 — Tax and commercial disclosure
Partner quote award stores tax breakdown as not separately calculated, production tax invoice readiness false, and finance reconciliation required. This is an appropriate guard. Do not present partner freight quotes as KRIM revenue or KRIM tax invoices. KRIM's separate referral/coordination fee requires its own written commercial agreement, evidence of service, accounting and CA-approved tax treatment before invoicing.

## Staging acceptance matrix
1. Customer A cannot create/read/quote/accept shipments belonging to Customer B.
2. Idempotent retry with identical payload returns the same shipment; changed payload under same request UUID is rejected.
3. Unactivated origin/destination market and unapproved corridor block creation/quote.
4. Expired, rejected, withdrawn, under-review or ineligible partner quote cannot be awarded.
5. Unverified, compliance-stale, capability-stale, out-of-area or inactive partner cannot be shown as eligible or awarded.
6. Duplicate and concurrent awards for one shipment cannot create multiple active assignments/customer quotes.
7. Customer cannot accept before provider accepts exact assignment.
8. Quote expiry between UI load and server acceptance is rejected.
9. Multi-leg shipment cannot use shipment-wide award path; exact-leg sourcing is required.
10. Customer quote accepted-state replay succeeds only if matching accepted/active partner assignment still exists.
11. Provider rejection/revocation after award invalidates the customer action and triggers safe compensation.
12. Cancellation before dispatch releases each reservation/assignment exactly once; after dispatch routes through disruption/return workflow.
13. Freight payment, KRIM referral fee and provider payable remain separate ledgers and contractual relationships.
14. Legacy accepted quote rows render as unverified and never trigger invoice, dispatch or customer payment claims.

## Release decision
The commercial workflow architecture contains meaningful authorization, idempotency, eligibility, offer/assignment binding and market gates. However, live production data shows no partner quote, no partner assignment, no verified capability, no active rate card and no operationally activated market. The six legacy accepted customer quote records are unlinked to any provider offer.

KRIM can be described as having a built customer shipment-request and quote workflow, but not as having a live bookable carrier marketplace or completed freight-booking service. Keep public commercial booking and any price/availability commitments gated until at least one market/corridor is formally activated, one provider is verified with current exact service coverage/capability, and a complete staging-tested pilot proves the end-to-end journey.

No production changes were made.
