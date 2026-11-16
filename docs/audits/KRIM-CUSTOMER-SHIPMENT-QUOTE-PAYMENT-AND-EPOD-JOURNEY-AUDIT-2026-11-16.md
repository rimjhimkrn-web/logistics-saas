# KRIM Customer Shipment Creation, Quote Acceptance, Partner-Direct Payment and ePOD Review — 2026-11-16

## Scope
Reviewed:
- `public/shipper/booking-request.html`
- `public/shipper/quote-comparison.html`
- `public/customer-os/quotes-pricing/quote-acceptance.html`
- `public/customer-os/assets/quote-operations.js`
- `public/shipper/payment-checkout.html`
- `public/shipper/epod-vault.html`
- `public/shipper/shipment-details.html`

No production shipment, quote, partner assignment, payment, POD or document record was created or modified. No payment provider was called.

## Shipment request
- Requires authenticated session and exactly one active customer organization membership.
- Rejects partner, driver, warehouse, customs, finance and operations roles for this booking path.
- Requires origin and destination to be selected from global place search; validates distinct coordinates and route type/country consistency.
- Creates a shipment request through `krim_create_global_shipment_idempotent` with a stable booking request ID.
- If the RPC returns no shipment identifier, the UI locks to prevent blind duplicate retry; timeout guidance tells the customer to check shipment records before retrying.
- It routes to the quote workflow after a confirmed shipment reference. A shipment request is not an assignment, dispatch or confirmed delivery.

## Quote comparison and acceptance
- Quote comparison reads partner offers through `krim_customer_list_partner_quotes` and customer quotes/assignments through organization-scoped records.
- The customer cannot accept a partner offer directly. The first action prepares a customer quote and sends a provider assignment offer through `krim_customer_prepare_partner_quote`.
- Customer acceptance is enabled only after the matching provider assignment is accepted/active and the customer quote is valid and positive.
- The final acceptance uses `krim_accept_global_quote`; UI checks the exact returned quote ID and accepted status.
- The page explains that assignment, dispatch, route/customs compliance and capacity are separate steps.
- Server-side RPC checks remain authoritative. Client-side state is not a security boundary.

## Payment
- `payment-checkout.html` is informational partner-direct payment guidance.
- It has no payment SDK, payment-order RPC or payment table access.
- It does not mark shipments paid, verify provider bank accounts, collect freight, split settlement, escrow funds, pay partners or automatically refund.
- Customer and contracting provider arrange freight payment directly. KRIM's separate referral/coordination fee must not be confused with freight GMV or partner collections.

## ePOD and document vault
- Requires authenticated session and active organization membership.
- Loads shipments, documents, POD records, versions and verification history using organization-scoped queries, with RLS as the enforcement layer.
- Private POD files are shown only for verified POD records and opened through short-lived signed storage links.
- Empty POD/document results are explicitly not represented as delivery or customs clearance.
- **Scope gap found:** the vault initially included only organizations whose type was exactly `customer`, unlike other canonical customer workflows that also allow active `shipper` and `enterprise` organizations.
- **Correction:** commit `80f0e8bb280f15ad53eaaa36051230a976fcc22e` now includes only active organizations of type customer, shipper or enterprise in the vault's scope. Inactive organizations are excluded.

## Shipment details and tracking
- Reads shipment details within the user's active customer organization scope.
- Displays recorded shipment status and public tracking reference when present; it does not generate GPS or carrier telemetry.
- Milestone display is based on shipment status labels and must not be interpreted as independently verified physical events unless the underlying event record is present.

## Verification
- The ePOD organization-scope correction is committed. Static-link audit, production smoke checks and Pages deployment must be polled for this commit.
- No end-to-end production transaction was executed.
- No proof is claimed for live partner quote availability, accepted assignments, payment, dispatch, tracking telemetry or delivery.

## Remaining dependencies
1. The live market/corridor/customs/compliance/capacity/dispatch gates remain separate and currently block general real-world shipment execution.
2. Keep partner freight payments direct and outside KRIM custody.
3. Verify private storage bucket object-path authorization and cross-organization isolation in staging, including signed URL requests for another customer's POD path.
4. Verify quote/assignment races, expired offers, duplicate requests and timeout recovery in staging using non-production fixtures.
5. Keep customer quote acceptance separate from dispatch authorization and verified POD.
