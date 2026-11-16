# KRIM Partner Quote Submission and Award Security Review
**Captured:** 16 November 2026  
**Project:** Production Supabase `ebltviniygljwwseplph`  
**Method:** Read-only inspection of live function definitions. No RPCs invoked and no production writes performed.

## Executive result
The partner quote submission and leg-award functions show meaningful server-side safeguards. They restrict quote submission to authenticated users linked to a single eligible registered-business partner, require current verified capability and permissions, and enforce opportunity and shipment state. Exact-leg sourcing validates the route-plan item and refuses unreviewed special cargo requirements. Awarding checks the customer-side permissions and revalidates provider eligibility and exact-leg coverage before creating an offered assignment.

This is positive code-level evidence, not proof that the end-to-end workflow has passed adversarial testing.

## Shipment-wide partner quote submission
`public.krim_submit_partner_quote(...)`:
- Requires authenticated user and validates opportunity ID, positive amount, currency format and note length.
- Resolves the partner organization from the caller's active memberships; requires exactly one eligible organization.
- Requires registered-business mode, active organization, verified/approved status, active/verified lifecycle, acceptable compliance status and at least one current verified capability.
- Requires `quote.create` permission.
- Requires an open opportunity within its response deadline and no prior award.
- Rejects shipment-wide quoting when an active multi-leg route plan exists.
- Checks that verified partner capability covers transport mode, both route countries, region and shipment weight.
- Rejects a partner bidding on its own customer's shipment.
- Constrains quote validity to the opportunity deadline and records an audit event.

## Exact-leg partner quote submission
`public.krim_submit_leg_partner_quote(...)`:
- Applies the same authenticated partner resolution, registered-business, verification, lifecycle, compliance and `quote.create` checks.
- Requires current partner compliance.
- Requires an open, unawarded leg opportunity within deadline.
- Confirms shipment/customer linkage and pre-execution shipment state.
- Requires the opportunity, shipment leg and active route-plan item to match exactly, including sequence, origin, destination and transport mode.
- Rejects non-empty free-form cargo requirements until a reviewed canonical evaluator exists.
- Requires verified capability to cover the exact leg's mode, route countries and weight.
- Validates finite positive quote amount, active currency and quote validity.
- Writes a quote and an audit event.

Capacity is not reserved at quote submission. That is appropriate only if the downstream award/assignment and dispatch path continue to require explicit capacity commitment/reservation. Current dispatch authorization separately requires confirmed physical capacity binding and a matching partner-owned reservation.

## Customer award of exact-leg partner quote
`public.krim_award_leg_partner_quote(bigint)`:
- Requires authentication, customer organization access, `quote.update` and `shipment.update`.
- Locks and verifies the opportunity, quote, shipment, exact leg and active route plan.
- Requires quote/opportunity/shipment/leg identifiers to match and the opportunity/quote to remain eligible.
- Rejects development/test partners and requires active registered-business partner, verified status, current compliance and current exact-leg capability.
- Requires the target leg to match its route-plan item and have no unresolved special requirements.
- Prevents multiple active assignments for the same leg.
- Accepts the selected quote, rejects competing open quotes, awards the opportunity and creates an offered assignment, with an audit event.

## Remaining concerns / test requirements
1. Add negative tests for a caller with membership in multiple eligible partner organizations, no `quote.create` permission, expired verification, stale compliance, expired capability, wrong route country, excessive weight, own-shipment bidding, and a development/test partner.
2. Add race-condition tests for two customer award requests on the same leg and concurrent quote updates.
3. Verify every assignment acceptance path creates/validates the exact capacity commitment before assignment activation.
4. Verify no UI describes a submitted quote as an accepted booking, awarded quote as accepted assignment, or offered assignment as dispatch authorization.
5. Test replay and idempotency semantics for quote resubmission and award retries.
6. Preserve the explicit gate that special cargo requirements cannot be priced until their capability evaluator is reviewed.
7. Do not relax these checks or make production changes before migration reconciliation and staging tests.

## Limits
Function source inspection only. No live calls, staging tests, race tests, or cross-tenant penetration tests were run. No production data or schema changed.
