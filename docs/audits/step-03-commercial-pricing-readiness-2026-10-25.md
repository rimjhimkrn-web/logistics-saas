# KRIM Logistics — Step 3 Commercial Pricing Readiness Audit
Date: 2026-10-25
Environment: Supabase production project `ebltviniygljwwseplph`

## Production findings
- `public.krim_pricing_rate_cards`: 1 record; 0 active; 0 active, effective, positive-price cards.
- The one existing card is ID 1, a draft ROAD flat-rate card with INR currency, base amount 0, minimum charge 0, and no service tier. It is not a customer-usable rate.
- `public.krim_rate_cards`: 0 records.
- No rate card should be activated or assigned a positive price without approved commercial inputs and a verifiable cost/margin basis.

## Decision
Step 3 is **blocked / in progress**. No pricing values were invented and no existing commercial records were modified. Until a valid card is approved, the customer journey must not imply a confirmed price or allow an unpriced quote to proceed as if it were commercially approved.

## Minimum inputs needed to safely configure an initial India lane
1. Approved lane definition: origin/destination service areas and supported mode.
2. Real carrier/partner buy rate and evidence/source/date.
3. KRIM platform fee or margin policy approved by the business.
4. Charge basis (per shipment, weight, distance, volume, or agreed tariff), minimum charge and applicable surcharges.
5. GST/tax handling reviewed for the actual service and transaction.
6. Currency INR, effective dates, expiry/review owner, and approval record.
7. Quote/checkout test confirming the displayed price matches the persisted quote and payment amount.

## Guardrails
- Do not use demo amounts as live rates.
- Do not treat a draft or zero-value rate card as usable.
- Do not charge customers until the quote is valid, approved, and linked to the shipment; payment provider order and webhook reconciliation must be independently verified.
- Do not activate rates for inactive markets or lanes without verified service capacity and partner compliance.

## Next action
Establish one real, approved India lane with the business/partner's documented cost and KRIM's approved margin, then create and test its rate card. Until those commercial inputs are supplied/verified, Step 3 cannot honestly be marked complete.


## Follow-up production verification (2026-10-25)
- The draft row's metadata explicitly says `commercially_approved=false`, `customer_quote_eligible=false`, and identifies it as a non-commercial setup template.
- `public.krim_partner_quotes`: 0 rows; no submitted/accepted positive partner quote exists.
- `public.krim_partner_opportunities`: 2 rows; neither is awarded to a partner in the current check.
- The inspected candidate organisations are not commercially verified: KRIM Test Transport Partner has verification/compliance not started; ABC Logistics is marked development-test-only with commercial access disabled and verification/compliance pending.
- The rate-card create function requires a positive amount and creates cards in draft. The status function validates amount/date window but the business still needs to provide and approve the underlying cost/margin evidence.
- A separate migration now requires explicit `market_activation` settings for both ends of a tariff quote, aligned with the booking guard: [migration](../../supabase/migrations/20261025193000_enforce_market_activation_for_tariff_quotes.sql).

## Current acceptance state
**No rate cards or partner records were modified in this follow-up.** Step 3 remains blocked by missing genuine commercial inputs, not by a need to invent a test price.


## Follow-up verification — 2026-10-25
- Re-queried production: still 1 rate-card row, and 0 active/effective/positive-price rate cards. The existing row remains unsuitable for customer pricing.
- Confirmed six countries are marked active in the country catalogue and six market rows are marked active, but only one market has an explicitly active `market_activation` setting. Tariff quote creation now checks that setting for both origin and destination.
- Confirmed 12 active India location records exist (including Ranchi, Jamshedpur, Kolkata, Ahmedabad, Chennai, Jaipur, Guwahati, Hyderabad, Pune, Bengaluru, Mumbai and Delhi). These are catalogue locations, not proof of partner coverage or a commercially serviced lane.
- Reviewed partner records: `KRIM Test Transport Partner` is not verified; `ABC Logistics` is marked verification/compliance pending and its metadata labels it development-test/sample-only with commercial access false; `KRIM Driver Account` is not a verified operating carrier. None can be treated as evidence of an approved commercial rate.
- Inspected `krim_admin_create_global_rate_card`: it validates positive price, active countries/currency, supported tier/mode and dates, and creates a draft with approval required. It does not itself establish carrier cost, margin approval, tax review or real service capacity. The status function's positive-price/date checks alone are not commercial approval evidence.
- No price, partner verification status, market activation, or financial record was fabricated or changed in this follow-up.

## Current acceptance decision
Step 3 remains **blocked by real-world commercial inputs**, not by absence of a pricing table. The system can create a draft rate card, but it must not be activated as a live customer rate until a verified partner supplies a documented cost for a defined lane and KRIM's fee/margin, charge basis, tax handling and approval are recorded.

## Fastest safe next step
Obtain these minimum values for one lane: (1) origin and destination service area, (2) mode and service tier, (3) partner/carrier buy price and dated evidence, (4) KRIM platform fee or margin, (5) charge basis and minimum charge, (6) tax/surcharge treatment, and (7) approver and effective dates. Then create the rate card in draft, verify the calculated quote, and activate only after approval.