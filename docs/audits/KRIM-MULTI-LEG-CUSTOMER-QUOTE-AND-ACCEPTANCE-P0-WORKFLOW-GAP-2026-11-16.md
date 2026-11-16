# KRIM Multi-Leg Quote-to-Customer-Acceptance — P0 Workflow Gap
Date: 2026-11-16

## Executive finding
**P0 — multi-leg partner sourcing has no complete customer quote and acceptance path.** Production has leg-scoped opportunity creation, partner quote submission and customer award/assignment functions. However, the customer-facing quote preparation function delegates to a shipment-wide award function that explicitly rejects any active multi-leg plan. The customer acceptance function accepts only a shipment-level `krim_quotes` record and requires an accepted partner quote plus matching accepted assignment. The leg-award function creates an assignment offer but does not create a customer quote. No dedicated leg/customer quote preparation or acceptance RPC was found in the production public function catalogue.

Consequently, a partner can be sourced and an assignment offer can be created for an individual leg, but the workflow cannot produce the customer quote/acceptance event required to move the shipment to `confirmed`. Partner assignment acceptance is deliberately deferred while shipment remains `quoted`; assignment finalization requires shipment `confirmed`. This creates a circular dependency for multi-leg shipments.

## Production evidence (read-only)
### Existing leg-specific path
- `krim_create_leg_partner_opportunity(shipment_id, shipment_leg_id, response_deadline)` creates an open opportunity bound to a plan-linked leg and verifies customer organization access, `quote.create` and `shipment.update`, active plan and exact leg-plan item bindings.
- `krim_submit_leg_partner_quote(opportunity_id, amount, currency, valid_until, notes)` verifies current partner compliance, registered-business verification, active capability, exact active route-plan/leg bindings and rejects non-empty unreviewed special requirements.
- `krim_award_leg_partner_quote(partner_quote_id)` awards the leg quote, rejects other active quotes for that opportunity, and creates an `offered` partner assignment for the exact leg. It does not create a customer `krim_quotes` row or customer quote version.

### Customer quote path is shipment-wide only
- `krim_customer_prepare_partner_quote(partner_quote_id, valid_until)` delegates to `krim_award_partner_quote_for_checkout`.
- `krim_award_partner_quote_for_checkout` explicitly raises an error when an active multi-leg plan has `total_legs > 1`, stating shipment-wide customer quote preparation is disabled until leg-specific sourcing is available.
- The function's successful path creates one shipment-level `krim_quotes` row, quote version and quote event. No leg-specific customer quote is created.
- `krim_accept_global_quote(quote_id)` accepts only a shipment-level `krim_quotes` row in `sent` status and requires a matching accepted partner quote and accepted partner assignment before transitioning the shipment to `confirmed`.

### Assignment finalization dependency
- `krim_respond_to_partner_assignment(assignment_id, accept, reason)` explicitly leaves an accepted partner assignment deferred when the shipment is still `quoted`, returning `next_step = customer_quote_acceptance`.
- `krim_internal_finalize_partner_assignment(assignment_id)` requires shipment status `confirmed` and an accepted assignment with a committed capacity commitment.
- For multi-leg plans, it activates the exact leg assignment and marks the overall shipment `assigned` only after every required leg is assigned and committed.

### Schema/function catalogue evidence
- `krim_partner_opportunities` and `krim_partner_quotes` have nullable `shipment_leg_id` fields.
- `krim_shipment_partner_assignments.shipment_leg_id` is non-null.
- `krim_quotes` has `shipment_id` and `partner_quote_id`, but no `shipment_leg_id` column.
- `krim_quote_versions` has no leg binding field in the inspected quote schema.
- A catalogue search for public functions matching leg/customer quote preparation or acceptance returned no dedicated function.

## Failure sequence
1. Customer has a multi-leg shipment in `quoted` state.
2. Customer creates leg opportunity; partner submits a leg quote.
3. Customer awards the leg quote; the system creates an `offered` assignment.
4. Partner accepts the assignment; the response function defers finalization because shipment is not yet `confirmed`.
5. Customer quote preparation delegates to shipment-wide checkout award, which rejects the active multi-leg plan.
6. Shipment-level customer acceptance cannot occur because no customer quote was created.
7. Assignment finalization cannot occur because the shipment is not confirmed.

This is a structural workflow gap, not a missing UI button.

## Required remediation design — not applied
1. Define the commercial contract for multi-leg pricing before coding: customer acceptance may be one consolidated quote covering every leg, or separately accepted leg quotes with an explicit overall shipment confirmation rule. Do not silently treat one leg price as the entire shipment price.
2. Add a leg-aware customer quote model (or a rigorously normalized quote-to-leg association) that binds each partner quote to exact shipment, leg, partner, currency, price basis, taxes/charges disclosure, validity and assignment.
3. Provide a customer quote preparation RPC that verifies all selected leg awards, current partner compliance/capability, no duplicate active quote, complete leg coverage or explicitly partial scope, and currency/pricing aggregation rules.
4. Provide an acceptance RPC with customer organization access, `quote.update`/required permissions, expiry checks, exact partner/leg/assignment binding and immutable quote-version evidence.
5. Define whether the shipment becomes `confirmed` only after all required legs have accepted commercial coverage; do not allow dispatch on a partially priced route unless an explicit partial-service contract supports it.
6. Preserve partner assignment acceptance as provisional until customer acceptance and capacity commitment checks pass. Ensure no leg becomes dispatchable solely because a partner accepted an offer.
7. Add staging tests for one-leg and multi-leg routes, incomplete leg coverage, duplicate/expired/conflicting quotes, mixed currencies, stale compliance, wrong-tenant acceptance, rejected partner offers, partial assignment, retry idempotency and all-legs-confirmed transition.
8. Reconcile production migration history and live definitions before preparing a migration. Do not apply production DDL or call business RPCs for testing.

## Release impact
- Multi-leg commercial quoting, customer acceptance and assignment finalization remain **NO-GO**.
- Do not bypass the shipment-wide multi-leg guard or mark a shipment confirmed manually.
- Single-leg flow must be separately tested; this report does not certify it as operational.

## Evidence boundaries
Only production catalogue/function definitions and schema metadata were inspected read-only. No opportunity, quote, assignment, shipment or capacity record was created or changed. No RPC was invoked. Findings are based on the complete available production function definitions and table metadata; they are not an end-to-end test.
