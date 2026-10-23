# Phase 4 — Quotes, Pricing & Commercial Review Audit

**Date:** 2026-10-23  
**Phase status:** IMPLEMENTED — AUTOMATED CHECKS PENDING; LIVE ACCEPTANCE REQUIRED  
**Scope:** Quote request, approved tariff matching, partner-bid fallback, quote review/comparison, validity and acceptance gates.

## Canonical workflow pages

1. [Global Freight Quote Desk](../public/shipper/rate-calculator.html)
2. [Customer Quote Review & Bid Status](../public/shipper/spot-approvals.html)
3. [Global Quote Comparison](../public/shipper/quote-comparison.html)
4. [Quote Requests & Offers](../public/customer/quote-request.html)
5. [Customer Workspace](../app/customer/index.html)
6. [My Active Shipments](../public/shipper/active-shipments.html)

The rate calculator is the canonical request-pricing entry point. The quote review page shows customer quote and partner-bid state; quote comparison is the commercial decision page for real shipment-linked offers. The quote-request page remains a separate shipment/offer register until live usage proves it is duplicate and safe to consolidate. No pages were deleted in this phase.

## Read-only production evidence

A read-only Supabase inspection found:

- `krim_pricing_rate_cards`: **1 total; 0 active**.
- `krim_quotes`: **7 records**.
- `krim_partner_opportunities`: **2 records**.

Therefore, the system currently has **no active rate card** to produce a live tariff price. The quote desk must not invent a price or activate an unapproved commercial rate. The existing server-side function fails closed when no approved active rate card matches the saved shipment's origin/destination markets, transport mode and service tier. The UI can attempt the controlled partner-bid fallback, but that request is still subject to explicit active market controls. A location record alone is not operational coverage.

No production rate card, quote, shipment, partner opportunity, payment or assignment was created or changed by this audit.

## Implemented in this phase

- Applied the shared `core/krim-global-interface.css` stylesheet and `krim-global-shell` class to the canonical quote review and comparison pages, keeping their existing page-specific workflow logic.
- Removed a duplicate entry in the static smoke-check page list.
- Added Phase 4 static smoke assertions for shared styling, the tariff RPC, partner-bid fallback, server-side quote acceptance, quote validity and safe empty/demo states.
- Preserved server-authoritative quote creation and acceptance; no client-side price calculation was added.

## Required commercial and lifecycle controls

- A quote is not a confirmed booking, a payment, a carrier assignment, a pickup or a delivered shipment.
- Quote acceptance currently transitions the shipment lifecycle to `confirmed` in `krim_accept_global_quote`. This lifecycle coupling must be reviewed with Phase 5 checkout/payment so a quote acceptance cannot be misrepresented as a paid or fully booked transaction. Do not change that database contract in isolation before checkout's prerequisites and transitions are updated together.
- Quote acceptance must remain organization-scoped, permission-checked, unexpired, linked to the correct shipment and protected against accepting competing offers.
- Partner-bid fallback must remain blocked unless the origin and destination have explicit active KRIM markets; an open opportunity is not a partner commitment.
- International quoting requires an approved rate card/offer with currency, effective dates, service scope and applicable fees. INR-only checkout remains a known limitation and must not be described as universal multi-currency settlement.

## Live acceptance checklist

- [ ] Signed-out visitor is sent to sign-in; no quote or bid is created.
- [ ] Signed-in customer can load only shipments belonging to an authorized active organization.
- [ ] Invalid shipment ID and unauthorized organization produce understandable errors.
- [ ] A lane with no approved active tariff displays no fabricated amount.
- [ ] Partner-bid fallback either returns a real opportunity reference under active-market rules or reports the server's explicit block; it never claims that a partner is assigned.
- [ ] An active approved test tariff, when provisioned by an authorized pricing administrator, returns a server-generated quote with the correct currency, amount and validity.
- [ ] Quote review refreshes and displays persisted records and statuses.
- [ ] Expired, already accepted, invalid, or unauthorized quotes cannot be accepted.
- [ ] Quote comparison displays only real shipment-linked offers; preview examples remain clearly non-live.
- [ ] No accepted quote is presented as payment complete or delivered.
- [ ] Links work from Customer Workspace → Shipment → Quote Desk → Quote Review/Comparison → next authorized step on mobile and desktop.

## Exit decision

**Phase 4 is not formally closed.** Static source changes and database inspection do not substitute for live user acceptance. The current production dataset has zero active rate cards, so live tariff-price acceptance cannot pass until an authorized, commercially approved test rate card is configured for a supported lane. Do not use invented amounts or seed an unapproved rate card just to make a demo appear successful.
