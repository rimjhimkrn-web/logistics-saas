# KRIM Customer Global Operations — Implementation Audit

Date: 2026-10-22  
Repository: `rimjhimkrn-web/logistics-saas`  
Branch: `krim/global-operations-audit`  
Environment: source inspection on the development branch + read-only Supabase production catalog inspection

## Scope and safety

This is an implementation audit, not an authenticated browser end-to-end test. No production records, schema, payment credentials, or deployed functions were changed during this pass. The branch is not confirmed merged or deployed to the public site.

## Customer operations status

| Module | Current status | Evidence / next acceptance requirement |
|---|---|---|
| Customer signup and workspace entry | OUT OF SCOPE for this phase; previously completed by project owner | Do not rebuild the journey unless a regression is found. |
| Shipment request UI | IMPLEMENTED IN SOURCE; NOT E2E VERIFIED | `public/shipper/booking-request.html` checks session, active customer organization, selected place results, route type, goods and positive weight, then calls the idempotent RPC. Need authenticated browser test and database evidence. |
| Shipment creation authorization/idempotency | PARTIALLY VERIFIED BY SOURCE/CATALOG | `krim_create_global_shipment_idempotent` checks auth identity, organization access and `shipment.create`; uses advisory locking. A partial unique index on organization + booking request UUID was previously confirmed. Concurrent authenticated replay still needs testing. |
| Global market governance | BLOCKER — REVIEW REQUIRED | The delegated place-based creation function can set a country `is_active=true` on country-code conflict. Geography selected by a customer must not activate a commercial market. The review SQL draft is not applied. |
| Shipment-to-quote handoff | IMPLEMENTED IN SOURCE; NOT E2E VERIFIED | `public/shipper/rate-calculator.html` loads the canonical `krim_shipments` record by numeric ID under client/RLS, then calls server quote RPCs. Must prove successful read and cross-organization denial with two test organizations. |
| Approved tariff quote | SERVER RPC EXISTS; WORKFLOW CONTRACT MISMATCH FOUND | `krim_create_tariff_quote` is an authenticated SECURITY DEFINER RPC with auth/org/permission checks. Its source inserts a tariff quote without a `partner_quote_id`; checkout requires a quote with a partner quote ID and an accepted assignment. Therefore the tariff-quote path appears unable to pass the current checkout gate unless another explicit award/linking step binds a partner quote. Trace and resolve before enabling payments. |
| Partner-bid fallback | IMPLEMENTED IN SOURCE; NOT E2E VERIFIED | If the tariff RPC returns the recognized “no approved active global rate card” response, the page calls `krim_create_partner_opportunity`. Must verify only eligible, verified, serviceable partners can respond and that the winning offer becomes the exact customer quote/assignment. |
| Quote acceptance and shipment state | BLOCKER — WORKFLOW STATE NEEDS RECONCILIATION | `krim_accept_global_quote` marks a quote accepted and calls `krim_transition_shipment(..., 'confirmed', ...)`. Checkout separately requires an accepted partner assignment. Confirmed state is therefore reached before the checkout page's partner-assignment precondition is satisfied, unless a separate award/assignment workflow guarantees the assignment exists first. The quote acceptance / award / partner acceptance / shipment confirmation sequence needs a single consistent state machine and regression tests. |
| Checkout preflight | IMPLEMENTED IN SOURCE; FLOW NOT PROVEN | `public/quote-result.html` checks accepted quote, linked shipment/organization, INR-positive amount, accepted partner assignment and confirmed shipment before enabling payment. |
| Payment order creation | SOURCE REVIEWED; NOT LIVE-TESTED | `create-global-razorpay-order` independently authenticates the user, checks organization access, confirmed shipment, accepted quote, partner quote and accepted assignment; checks expiry/amount/currency; reuses an eligible existing order or creates a Razorpay order and local `payment_orders` record. Needs test-mode integration and failure/retry tests. |
| Payment verification | SOURCE REVIEWED; NOT LIVE-TESTED | `verify-razorpay-payment` checks authenticated ownership, organization access, exact quote/assignment linkage, signature, provider payment/order, amount, currency and captured status. Need verify webhook idempotency, concurrency, local-record update and recovery together; source inspection alone is not proof. |
| Global currency support | PARTIAL / BLOCKER FOR GLOBAL COMMERCIAL CLAIMS | The current Razorpay checkout path explicitly supports INR only. Do not advertise global multi-currency checkout until currency eligibility, provider availability, conversion/accounting and settlement rules are implemented and tested. |
| Tracking, documents, proof of delivery, claims, invoice history | NOT YET AUDITED IN THIS PASS | Inventory existing customer pages, tables, RLS and backend workflows before implementing or replacing anything. |

## Highest-priority issues to resolve

### P0 — Establish one coherent quote-to-booking state machine

Current source contracts do not align cleanly:
1. Tariff-generated quotes appear to have no `partner_quote_id`.
2. Both checkout UI and the order-creation Edge Function require a partner quote and an accepted partner assignment.
3. Quote acceptance calls a shipment transition to `confirmed`, while checkout separately requires the partner assignment to be accepted.

Before changing production, trace the partner quote award function(s), assignment creation/acceptance functions, quote row linkage, and transition rules. Then define and test the exact lifecycle, for example:
- shipment request created (not confirmed);
- serviceability and compliance eligibility checked;
- either approved tariff with a valid fulfilment/partner model, or a partner opportunity with an awarded offer;
- customer quote accepted;
- partner award/assignment created and partner acceptance recorded when the service requires it;
- payment order created from the exact accepted quote;
- payment verified by provider and recorded idempotently;
- booking/dispatch readiness set only when all applicable prerequisites pass.

Do not hard-code the illustrative sequence if KRIM's intended commercial model differs. The invariant is that the quote, shipment, partner offer, assignment, amount, currency and payment must refer to the same authorized transaction.

### P0 — Preserve market activation controls

A customer booking request must not flip a country's commercial market activation flag. Prepare a reviewed database migration after tracing all overloads and testing new-country and existing-inactive-country cases in a safe environment. The existing review-only SQL file is not a production migration and has not been applied.

### P1 — Prove authorization and duplicate protection

Run authenticated tests for:
- correct customer organization;
- a second unrelated organization trying to load or quote the shipment;
- unauthorized user calling RPCs directly;
- repeated request UUID with identical payload;
- repeated request UUID with a different payload;
- concurrent duplicate submits;
- timeout after server success but before browser receives the response.

### P1 — Prove the complete payment lifecycle in test mode

Test order creation, existing-order reuse, provider failure, signature mismatch, amount/currency mismatch, uncaptured payment, repeated verification, webhook replay, delayed webhook, and recovery after a provider succeeds but the local write fails. Keep live credentials and live charges gated until these tests pass.

## Test evidence policy

For every test record:
- test case ID and timestamp;
- account role and organization (no passwords or secrets);
- shipment/quote/assignment/payment reference IDs;
- expected and actual result;
- relevant application, Edge Function and database logs;
- whether the result was observed in a real authenticated browser or only inspected in source/catalog.

Do not mark a module VERIFIED based only on the existence of a page, table, RPC or Edge Function.

## Current decision

**Customer Global Operations: IN PROGRESS — NOT APPROVED.**  
The source contains meaningful building blocks, but the customer workflow cannot be accepted as end-to-end complete until the quote/partner/assignment/confirmation contract is reconciled, market activation is protected, and authenticated tests prove isolation, idempotency and payment recovery.

## Next action

Trace the full partner quote → award → customer quote → assignment → partner acceptance functions and the shipment transition rules. Resolve the P0 lifecycle mismatch in a reviewable branch/migration plan first; do not make production DDL or live payment changes during this audit step.
