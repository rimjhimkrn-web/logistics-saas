# KRIM Logistics — Step 3 Commercial Pricing & Rate Cards
Date: 5 November 2026
Environment: Production Supabase project `ebltviniygljwwseplph`

## Decision

**Commercial pricing infrastructure implemented; commercial acceptance remains blocked by genuine external inputs.** No fabricated buy rates, customer prices, platform fees, taxes, FX rates, accessorial charges, carrier offers or approvals were added. The existing zero-value draft placeholder remains unchanged and cannot be activated.

## Production baseline (rechecked)

| Record | Current count |
|---|---:|
| Global pricing rate cards | 1 |
| Active global pricing rate cards | 0 |
| Positive-amount global pricing rate cards | 0 |
| Partner rate cards | 0 |
| Rate lines | 0 |
| Accessorial charges | 0 |
| FX rates | 0 |
| Tax rules | 0 |
| Partner quotes | 0 |
| Verified active partner capabilities | 0 |

The one existing global rate card remains a draft placeholder: INR, ROAD, flat basis, amount 0, minimum 0, no service tier. Its metadata explicitly marks it non-commercial and not customer-quote eligible. No pricing record was changed.

## Implemented and applied

1. **Pricing data write protection**
   - Direct `anon` and `authenticated` table access to `krim_pricing_rate_cards` was revoked.
   - The former organization-wide ALL policy was removed. RLS remains enabled with no direct table policy; the table is accessed through privileged, permission-checked governance RPCs and internal quote functions only.
   - Anonymous reads were revoked from partner rate cards, rate lines, accessorial charges, quote pricing components, shipment cost items and FX rates. Authenticated access to permitted records remains read-only under existing RLS policies.
   - No client-side service-role access was introduced.

2. **Evidence-led commercial governance**
   - Admin-only RPCs now create global draft cards, record provider cost evidence, record commercial approval, list cards and change status.
   - Provider evidence requires an active verified registered-business organization, cleared compliance, and verified active capability for the selected transport mode in both route countries.
   - Provider buy rate plus KRIM platform fee must reconcile to the customer rate-card amount at the configured currency precision.
   - Dated cost evidence, qualified tax-treatment review and explicit approval references are mandatory. NULL tax-treatment values are rejected.
   - Activation rechecks provider status and capability, evidence and approval, both market-readiness gates, validity dates, currency precision and conflicting active route/tier/priority cards.
   - Route activation uses a transaction-scoped advisory lock to prevent concurrent conflicting activations.
   - Same-country domestic lanes are supported; domestic India pricing is not incorrectly forced to use two different countries.

3. **Quote integrity**
   - Both quote paths now consume only active, evidence-backed, commercially approved rate cards and require the relevant market activation gates.
   - Service tier and transport mode are checked. Currency rounding uses KRIM's configured minor-unit exponent.
   - Quote records now have an immutable JSON pricing snapshot field. New tariff quotes persist the rate-card ID, rate basis, minimum charge, shipment weight, quoted amount, currency, validity window and tax treatment. Provider buy cost and KRIM margin are not exposed in the customer snapshot.
   - The internal quote-calculation path records whether tax is included in the rate or reviewed as not applicable; it does not invent a tax amount.
   - Existing quote records were not rewritten.

4. **Workspace and interface integrity**
   - A private, admin-guarded Global Rate Governance console was added and linked from the private Control Centre. It calls only the permission-checked RPCs; it does not write directly to pricing tables.
   - Partner commercial rate cards remain an authenticated, organization-scoped read-only register.
   - The legacy partner rate-card page, which previously displayed fictional carrier names and prices, now routes to the canonical authenticated register. All invented sample tariffs were removed.
   - Customer quote register/detail views now display persisted pricing basis and tax treatment when present, while preserving old records with empty snapshots.

## Verification performed

- All seven relevant production migrations are present in Supabase migration history:
  - `lockdown_commercial_pricing_table_writes`
  - `require_evidence_for_commercial_rate_activation`
  - `require_approved_rates_in_all_quote_paths`
  - `apply_domestic_rate_and_tax_evidence_guards`
  - `add_quote_pricing_snapshot_column`
  - `persist_tariff_quote_price_snapshot`
- Verified `pricing_snapshot` is non-null JSONB with an object-type constraint.
- Verified tariff quote function contains evidence, market-gate and pricing-snapshot writes.
- Verified the internal quote engine contains market, approval and tax-treatment guards.
- Verified anonymous execute is false for all commercial admin and quote functions. Authenticated execute is granted only where the function is intended to be called; each privileged admin function checks `admin.platform` inside the SECURITY DEFINER body. The internal pricing calculator is not executable by anon or authenticated clients.
- Verified pricing table RLS remains enabled and no direct `anon` or `authenticated` DML grants remain.
- JavaScript syntax checks passed for the new private admin console, Control Centre, partner commercial register and customer quote operations. The legacy static page contains no sample carrier names or prices.
- No authenticated browser-session E2E was performed. No live quote, partner bid, payment, shipment, rate activation or market activation was attempted.

## Remaining acceptance blockers — real commercial evidence

KRIM cannot honestly activate a customer rate card until all of the following exist for at least one defined India-first lane:

1. A genuinely verified registered-business provider with active verified capability for the lane and transport mode.
2. A dated carrier buy-rate document/evidence reference and currency.
3. KRIM's approved platform fee/margin and charge basis.
4. A qualified tax opinion establishing whether the rate is tax-inclusive or tax is not applicable. Tax-exclusive rates remain blocked until a reviewed tax calculation path exists.
5. A commercially approved lane and active market readiness gate for both ends.
6. A persisted quote calculation/snapshot check showing the exact customer amount, currency, validity and terms.

Current production has zero verified active partner capabilities, zero tax rules and zero FX rates. International cross-currency cost conversion is therefore not configured; no international tariff is enabled. Accessorial charges and fuel/handling surcharges also remain unpopulated.

## Control decision

- No price, carrier, margin, tax rule, FX rate or approval was invented.
- No rate card was activated.
- No customer quote was generated from the zero-value placeholder.
- No customer payment or shipment operation was initiated.

**Step 3's governance, protection and quote-integrity implementation is in place. Its commercial acceptance criteria are not met until real provider cost and qualified tax evidence are available.** Step 4 must not be treated as completed or silently substituted for Step 3; if partner acquisition is later authorized, its verified provider evidence is the dependency required to finish this step.
