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
