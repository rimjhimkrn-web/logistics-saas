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

## Production re-audit — 5 November 2026

### Current production evidence
- `public.krim_pricing_rate_cards`: 1 row, 0 active. The only row is ID 1, a non-commercial India ROAD flat-rate template with INR, base amount 0, minimum charge 0, no service tier, and metadata explicitly marking it non-commercial and not customer-quote eligible.
- `public.krim_rate_cards` and `public.krim_rate_lines`: 0 rows each.
- `public.krim_partner_quotes`: 0 rows. No submitted carrier bid exists to substantiate a customer rate.
- `public.krim_quotes`: 7 historical rows; 0 currently valid sent quotes.
- `public.krim_pricing_calculation_runs`, `krim_quote_items`, and `krim_quote_pricing_components`: 0 rows each.
- `public.krim_fx_rates`, `krim_tax_rules`, and `krim_accessorial_charges`: 0 rows each. No approved FX conversion table, tax-rule catalogue, or accessorial schedule is available for commercial calculations.
- RLS is enabled on the global pricing table. Authenticated direct INSERT, UPDATE and DELETE privileges are all false; rate governance is routed through privileged database functions.
- Quote creation and orchestration fail closed unless a matching active, effective, commercially evidenced and approved rate exists and both route markets pass operational activation gates. The configured markets remain gated under Step 2.

### Pricing governance already present
- Draft rate creation validates country, active currency, supported mode/tier, positive base amount, non-negative minimum charge, effective dates and priority.
- Commercial evidence recording checks an active verified registered-business provider, active verified capability for both lane countries and the selected mode, a dated cost evidence reference, tax review evidence, and exact reconciliation of provider buy rate plus KRIM platform fee to the customer-facing rate.
- Approval and activation check the market readiness gates, evidence and approval references, provider status/capability, effective dates, and duplicate active route/tier/priority conflicts.
- No real commercial evidence was supplied or inserted during this audit. No rates were priced, approved or activated.

### Defect found: domestic same-country lanes
The rate-card creation RPC currently rejects origin and destination being in the same country, and the approval/activation RPCs expect two active markets. This prevents a domestic lane such as Ranchi–Kolkata from using the global rate-card governance path, even though India is the initial operating market. A correction has been prepared in `supabase/migrations/20261105190000_support_domestic_same_country_rate_cards.sql`: domestic lanes will require one distinct country/market gate; cross-border lanes will continue to require two. **The migration file is committed but was not applied because the Supabase migration action was blocked by the safety checks.** Do not treat domestic rate-card support as live until this migration is approved, applied and verified.

### Partner rate-card interface correction
The old `public/partner/rate-cards.html` page contained hard-coded sample carrier names, routes, amounts, fuel-surcharge percentages and an unsupported claim of four active cards. Those sample claims have been removed. The compatibility page now forwards to `public/partner/commercial-rates.html`, which reads permitted records from the authenticated partner workspace and does not create sample prices. The partner page remains read-only for global rate governance.

### Current acceptance decision
**Step 3 remains incomplete / blocked.** Technical governance is substantially present, but the domestic-lane correction is pending and there is no genuine, verified partner buy-rate, KRIM fee/margin approval, qualified tax review, surcharge evidence, or approved lane. No customer-facing rate may be published and no payment/checkout may be enabled on the basis of the zero-value template. The next valid completion point is after the pending migration is applied and a real lane's documented commercial inputs are supplied and approved.


## Production re-audit — 5 November 2026

- `krim_pricing_rate_cards`: 1 row, 0 active. The only row is ID 1, a zero-value, non-commercial India ROAD flat-rate template in INR, with no service tier. Its metadata explicitly marks it not commercially approved and not customer-quote eligible.
- `krim_rate_cards` and `krim_rate_lines`: 0 rows. `krim_partner_quotes`: 0 rows. `krim_quotes`: 7 historical rows, 0 currently valid sent quotes.
- Pricing calculation runs, quote items, quote pricing components, FX rates, tax rules and accessorial charges: 0 rows each.
- RLS is enabled on the global pricing table. Authenticated direct INSERT, UPDATE and DELETE privileges are all false. Commercial rate governance is routed through privileged database functions.
- Governance functions require a verified registered-business provider, active verified lane/mode capability, dated buy-rate evidence, tax review reference, exact reconciliation of provider buy rate plus KRIM platform fee to customer price, approval evidence, eligible market gates, effective dates and duplicate active-card checks.
- Customer quote paths fail closed without a matching active, effective, evidence-backed approved rate and eligible markets. No rates or commercial evidence were invented or activated.

### Defect: domestic same-country lanes
Rate-card creation rejects origin and destination being in the same country; approval/activation expect two active markets. This blocks domestic India lanes. A correction is committed at `supabase/migrations/20261105190000_support_domestic_same_country_rate_cards.sql`, changing the expected market count to the number of distinct countries (one domestic, two cross-border). **It is not applied** because the Supabase migration action was blocked by safety checks. Do not bypass that block or treat domestic pricing as live until the migration is approved, applied and verified.

### Partner interface correction
The old `public/partner/rate-cards.html` hard-coded sample carrier names, routes, prices, fuel surcharge percentages and a false “four active cards” claim. These were removed; the compatibility page now forwards to the authenticated, RLS-controlled `public/partner/commercial-rates.html` register.

### Acceptance decision
**Step 3 remains incomplete.** No verified partner buy-rate, approved KRIM fee/margin, qualified tax review, surcharge evidence or approved commercial lane exists. No customer-facing rate may be published and no payment/checkout may rely on the zero-value template. Step 4 must not begin until the domestic-lane migration is applied and a real commercial lane is evidenced and approved.


### Admin pricing governance interface — implemented 5 November 2026
- Added `app/platform-admin/commercial-pricing.html` and linked it from the private platform-admin navigation.
- The page requires a valid Supabase session and AAL2 MFA. The administrator-only list RPC and each mutation RPC independently enforce the `admin.platform` permission server-side.
- The interface uses the existing privileged RPCs for draft creation, commercial evidence recording, approval and status changes. It does not grant direct table writes and does not expose provider cost/evidence metadata in the register.
- It provides active country/currency selectors, supported ROAD/AIR service-tier validation, date/priority inputs, cost and tax evidence references, approval reference, and activation/suspension/expiry controls.
- JavaScript syntax validation passed. RPC execute grants for all five functions were verified for the authenticated role. Actual signed-in AAL2 browser interaction was not performed in this audit, so no claim of device/browser E2E is made.
- The UI explicitly blocks same-country draft creation while the domestic-lane correction is pending. The pending migration remains unapplied.


## Correction after function-definition reinspection — 5 November 2026
The earlier domestic-lane defect finding was incorrect and is superseded by this verification:
- The live `krim_admin_create_global_rate_card` definition does not reject equal origin/destination country IDs.
- The live `krim_admin_approve_global_rate_card` and `krim_admin_set_global_rate_card_status` definitions already require one active market for a same-country route and two for a cross-border route, using `CASE WHEN origin_country_id=destination_country_id THEN 1 ELSE 2 END`.
- Therefore no domestic-lane database migration is required. The previously committed migration candidate used a stale text-match assumption and was removed from the repository without being applied.
- Removed the obsolete client-side same-country rejection from the private commercial-pricing console. Domestic lanes now pass to the existing server-side governance checks.
- Verified the console is linked from the private platform-admin navigation. Its AAL2 session check, admin-only list RPC and mutation RPC names/argument shapes were inspected against live definitions. This remains static/backend verification, not signed-in browser E2E.

## Current production gate — 5 November 2026
The pricing engine and governed administration workflow are implemented, but no genuine commercial lane can be activated yet:
- Global pricing cards: 1 existing non-commercial zero-value template; 0 active.
- Partner quotes: 0; FX rates: 0; tax rules: 0; accessorial charges: 0.
- Active verified partner capabilities: 0; eligible markets: 0.
- No live rate, provider cost, platform margin, tax treatment, FX rate, surcharge or coverage was fabricated.

**Engineering acceptance:** the rate-card lifecycle, permissioned admin workflow, direct-DML lockdown, quote fail-closed controls and domestic/cross-border market-count logic are implemented. **Commercial activation remains deliberately gated** until real verified partner cost evidence, KRIM fee approval, qualified tax review and market eligibility exist. This is a dependency on genuine business evidence and partner verification, not an outstanding domestic-lane code defect.


### Privileged RPC MFA hardening — 5 November 2026
A further security review found that the five pricing RPCs relied on the admin permission check but did not independently enforce AAL2 in their database function bodies. The browser-side MFA check alone was insufficient because authenticated users can call RPC endpoints directly. This has now been corrected:
- Applied production migration `20261105102900_enforce_aal2_on_global_rate_card_admin_rpcs`.
- Added a server-side `auth.jwt()->>'aal' = 'aal2'` guard to the administrator list, create-draft, record-evidence, approve and status RPCs.
- Re-queried all five live function definitions: all five contain the AAL2 guard; authenticated EXECUTE is present; anon EXECUTE is false.
- Committed the exact applied SQL to `supabase/migrations/20261105102900_enforce_aal2_on_global_rate_card_admin_rpcs.sql`; migration history confirms it is applied.
- The pricing table remains RLS-enabled with authenticated direct INSERT/UPDATE/DELETE denied. The pricing console reads and writes only through the guarded administrator RPCs.
