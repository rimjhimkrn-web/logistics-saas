# KRIM Booking Lifecycle — Live Definition Revalidation
Date: 2026-11-11
Environment: Production Supabase catalog, read-only
Status: CONFIRMED RELEASE BLOCKER — NO REMEDIATION APPLIED

## Why this revalidation exists

The earlier booking lifecycle review and preflight plan were based on previously inspected function definitions. A fresh live `pg_get_functiondef` check was run against the production database before writing any migration. It found a material discrepancy: the current live definition of `krim_accept_global_quote(bigint)` does not contain the partner-assignment acceptance check that the earlier summary attributed to it.

Treat the fresh live definition as authoritative. The earlier statement that this function verifies an accepted partner assignment must be corrected.

## Live function behavior confirmed

### 1. Customer award currently confirms the shipment before partner commitment

Live `public.krim_award_partner_quote(bigint)`:
- Authenticates the customer and checks customer organisation access plus `quote.update` and `shipment.update`.
- Checks opportunity and quote eligibility, partner organisation verification/compliance and a currently verified capability.
- Locks quote, opportunity, shipment and checks route capability.
- Marks the selected partner quote accepted, rejects competing quotes and marks opportunity awarded.
- Creates a partner assignment with status `offered` and a 24-hour response deadline.
- Then transitions the shipment from `quoted` to `confirmed` immediately, even though the assignment is still only `offered`.

### 2. Checkout wrapper pre-accepts customer quote before partner accepts

Live `public.krim_award_partner_quote_for_checkout(bigint,timestamptz)`:
- Calls `krim_award_partner_quote`, inheriting the premature shipment confirmation and offered assignment.
- Inserts a customer `krim_quotes` row with status `accepted` immediately.
- Inserts a quote version with status `accepted` and an accepted event.
- Its pricing snapshot says payment terms are after partner assignment acceptance, but the quote row/version are already accepted before that acceptance.
- It allows a previously confirmed shipment to be awarded again if it finds a rejected assignment; the exact lifecycle and cleanup behavior must be covered by tests.

### 3. Customer quote acceptance does not check partner assignment

Fresh live definition of `public.krim_accept_global_quote(bigint)`:
- Locks the customer quote and shipment.
- Checks customer organisation access and `shipment.update`.
- Requires quote status `sent`, a valid expiry and shipment status `quoted`.
- Marks the quote accepted and transitions shipment `quoted -> confirmed`.
- The live function body contains no query or validation for an accepted/active partner assignment, partner quote, capacity commitment or partner acceptance.
- Function is executable by `authenticated`; anon execution is false.

This contradicts the previous audit summary. Do not rely on the prior summary's assertion about this function.

### 4. Readiness gate treats confirmed shipments as not requiring a partner

Live `public.krim_internal_evaluate_shipment_readiness(bigint)` assigns `partner_status = 'not_required'` for shipment states `draft`, `requested`, `quoted`, and `confirmed`. Thus a shipment can be confirmed without an accepted partner and the readiness evaluator does not mark the partner as missing at that stage.

### 5. Partner response RPCs have different access and lifecycle behavior

Current function execution grants:
- `krim_award_partner_quote(bigint)`: authenticated = true; anon = false.
- `krim_award_partner_quote_for_checkout(bigint,timestamptz)`: authenticated = true; anon = false.
- `krim_accept_global_quote(bigint)`: authenticated = true; anon = false.
- `krim_respond_to_partner_assignment(bigint,boolean,text)`: authenticated = true; anon = false.
- `krim_partner_respond_to_invitation(bigint,text,numeric,text,timestamptz,text)`: authenticated = false; service_role = true.
- `krim_internal_finalize_partner_assignment(bigint)`: authenticated = false; service_role = true.
- `krim_internal_evaluate_shipment_readiness(bigint)`: authenticated = false; service_role = true.

The two partner response functions are not interchangeable:
- `krim_respond_to_partner_assignment` is directly executable by authenticated users and updates assignment/leg/tracking/audit state.
- `krim_partner_respond_to_invitation` is service-role-only and creates a partner quote and capacity commitment before marking the assignment accepted. Trace all Edge Function/service-role callers before changing or removing it.

### 6. Shipment transition catalog

Live transition rows:
- `quoted -> confirmed`: allowed = true; requires `shipment.update`.
- `confirmed -> assigned`: allowed = true; requires `shipment.assign`.
- `assigned -> dispatched`: allowed = false; requires `shipment.dispatch`.

The dispatch transition being disabled in this table must be reconciled with the internal dispatch workflow and any direct status update path before the lifecycle design is finalized. Do not simply enable it without caller and trigger analysis.

## Required coordinated design correction

The implementation must make the following states unambiguous and consistent across shipment, customer quote, partner quote, assignment, capacity, opportunity, readiness and payment:

1. Partner quote selected / award invitation issued — assignment `offered`; shipment must not be customer-visible as confirmed/booking-ready.
2. Partner explicitly accepts the exact shipment and commercial terms — accepted assignment and matching partner quote; current capability/compliance/route/capacity revalidated and capacity commitment persisted.
3. Customer explicitly accepts the final customer quote — customer quote moves to accepted only after partner commitment is valid; quote amount/currency/terms must match the partner offer and approved pricing.
4. Operational finalization — assignment becomes active and shipment assigned only after the required customer and partner acceptances plus committed capacity.
5. Dispatch — allowed only after all operational, document, compliance, payment and dispatch gates are satisfied.

The product owner/business rule still needs to settle the order of steps 2 and 3. Whichever order is chosen, no accepted customer quote, confirmed booking, payment eligibility, customer-facing booking confirmation or paid checkout can be produced before partner commitment is explicit.

## Required migration scope — not yet written or applied

A safe coordinated migration must review and, where appropriate, replace together:
- `krim_award_partner_quote`
- `krim_award_partner_quote_for_checkout`
- `krim_partner_respond_to_invitation` and its service-role callers
- `krim_respond_to_partner_assignment`
- `krim_accept_global_quote`
- `krim_internal_finalize_partner_assignment`
- `krim_internal_evaluate_shipment_readiness`
- shipment status transition rows and dispatch path
- triggers for quote cancellation, assignment/quote integrity, capacity commitment and capacity release
- customer quote version/event creation
- payment order creation/webhook and eligibility checks
- all frontend, mobile, Edge Function, admin, enterprise and scheduler callers.

Do not patch only the award function. Do not simply change the status transition table. Do not reuse the freight payment pipeline as SaaS billing.

## Mandatory tests

- Award creates only an offered assignment and does not confirm shipment or mark customer quote accepted.
- Partner decline/expiry leaves shipment unconfirmed and customer quote unpaid/unaccepted.
- Partner acceptance verifies exact route, mode, cargo, weight, current capability, compliance, quote currency/amount and capacity.
- Customer acceptance is impossible before partner commitment.
- Customer acceptance with wrong org, wrong quote, mismatched price/currency, expired offer or rejected partner is denied.
- Rejection after partner commitment releases capacity and restores/reopens only the correct eligible opportunity/quotes.
- Duplicate and concurrent award/accept/decline/customer-accept requests are idempotent or safely rejected.
- Readiness gate marks missing partner as blocking for all states where a partner is required.
- No payment order/checkout eligibility before explicit partner commitment and customer acceptance.
- Dispatch remains blocked until assigned state and all dispatch requirements pass.
- Direct authenticated RPC calls cannot bypass frontend sequencing.
- All existing audit, trigger, multi-tenant and permission invariants remain intact.

## Safety and status

- Only read-only production SQL catalog/function-definition queries were run.
- No production or staging schema/data was changed.
- No migration file has been proposed as executable SQL yet.
- No payment, booking, partner assignment or customer quote was created or changed.
- Production booking and payment should remain disabled/fail-closed until the coordinated design and regression suite are completed.
