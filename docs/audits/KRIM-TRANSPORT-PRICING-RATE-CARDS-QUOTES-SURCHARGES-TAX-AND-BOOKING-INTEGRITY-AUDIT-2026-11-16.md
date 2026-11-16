# KRIM Global Transport Pricing, Rate Cards, Quotations, Surcharges, Tax and Quote-to-Booking Integrity Audit — 2026-11-16

## Executive decision
**NO-GO for live customer pricing, freight-rate publication, tax/duty estimation, FX conversion, quote acceptance as a commercial commitment, or freight collection.** The database has a guarded draft-rate-card and quote architecture, but there are no approved rate cards, partner bids, pricing runs, tax rules, accessorial charges, FX rates, quote acceptance records or commercial commitments. Existing seven customer quote rows are historical, expired records and are not backed by partner offers.

The initial KRIM model remains non-custodial: the shipper contracts with and pays the actual provider directly; KRIM separately earns only its own agreed referral/coordination/platform fee where lawful and tax-compliant. Do not route partner freight funds through KRIM.

This audit is read-only. No pricing, quote, tax, FX, payment, shipment or financial RPC was invoked; no quote was created or accepted; no rate card was approved; no production data/schema changed.

## 1. Production evidence snapshot

| Object | Rows | Interpretation |
|---|---:|---|
| Global pricing rate cards | 1 | One draft placeholder, zero active |
| Legacy rate cards | 0 | No legacy live rate supply |
| Accessorial/surcharge definitions | 0 | No governed surcharge catalogue |
| Tax rules | 0 | No tax engine rules |
| FX rates | 0 | No exchange-rate observations |
| Country currency references | 253 | Currency reference mapping, not FX prices |
| Supported currencies | 156 | Currency catalogue only |
| Pricing calculation runs | 0 | No calculation evidence |
| Pricing overrides | 0 | No override history |
| Customer quotes | 7 | Six accepted, one sent; all expired |
| Quote versions/items/pricing components | 0 / 0 / 0 | No versioned itemised quote evidence |
| Partner quotes | 0 | No provider bids |
| Quote acceptances/events | 0 / 0 | No current acceptance evidence |
| Quote orchestration runs | 0 | No matching/orchestration evidence |
| Booking requests / commercial commitments | 0 / 0 | No quote-to-contract commitments |

The one rate card is ID 1, India-to-India ROAD, flat INR 0, minimum INR 0, status `draft`, with metadata explicitly describing it as a non-commercial placeholder and `customer_quote_eligible=false`. It has no commercial evidence or approval. It must not be activated or displayed as a usable price.

The seven quote rows were created in September 2026 and have validity dates in October 2026, all before this audit date. Six carry a historical `accepted` status and one `sent`; none is linked to a partner quote, and the quote acceptance table is empty. These rows are not proof of a current partner-backed offer, customer contract or live freight price. Do not count them as commercial transactions or revenue.

## 2. Positive architecture and controls
- Global rate-card administration requires AAL2 and platform-admin permission.
- Rate-card creation is draft-only; supported tiers are limited to ROAD/AIR mappings and flat/per-kg calculation.
- Commercial evidence requires a verified registered-business provider, current verified capabilities in origin and destination countries, a dated cost reference, provider buy rate, KRIM platform fee, and qualified tax-review reference.
- Provider buy rate plus KRIM platform fee must reconcile to the customer rate at the currency's minor-unit precision.
- Rate-card approval and activation recheck market activation gates, provider status/capability, effective dates and commercial evidence; active duplicate route/tier/priority cards are blocked under an advisory lock.
- The tariff quote RPC derives the price from an active evidence-backed approved card rather than accepting an arbitrary amount; it checks customer organisation access, `quote.create`, positive shipment weight, explicit transport mode, active origin/destination markets and market readiness.
- Customer quote acceptance now requires a matching accepted partner quote and accepted assignment for the same shipment, verified partner status/compliance/capability and amount/currency equality. This is a good separation of partner bid, customer quote, partner acceptance and assignment.
- Direct authenticated table writes are denied on the reviewed commercial pricing tables; RLS is enabled and anonymous SELECT/INSERT is denied on the reviewed tables.
- The older `krim_create_global_quote(bigint,numeric,text,timestamptz)` function is not executable by anon, authenticated or PUBLIC, reducing the risk from its arbitrary-amount legacy implementation. Do not re-grant it.

These controls are static code/catalog evidence only. No authenticated staging workflow was executed.

## 3. P1 — Tax rules and quote tax calculation are absent
There are zero rows in `krim_tax_rules`. The active tariff quote function selects an approved rate card and snapshots its `tax_treatment` as either `included_in_rate` or `not_applicable`; it does not calculate GST, VAT, customs duty, withholding, place-of-supply treatment, reverse charge or other jurisdiction-specific tax. The quote record is created with the freight amount and currency; there is no evidence of a tax-rule-driven tax breakdown.

A tax review reference string on a rate card is not a tax calculation or legal opinion by itself. Freight service tax and import duties/taxes are different liabilities and must not be conflated. Customs duty is not automatically part of a freight quote.

**Required remediation:**
1. Keep tax amount/status explicitly “not calculated / requires qualified review” until jurisdiction, contracting party, service role, place of supply, registration status, customer type and service classification are resolved.
2. Create jurisdiction- and transaction-specific tax rules only from current official sources and qualified CA/legal review.
3. Store tax base, rate, exemption/reverse-charge basis, rounding, effective dates, source version, reviewer and calculation snapshot.
4. Distinguish provider freight taxes, KRIM's own service-fee taxes and import/export duties/levies.
5. Block a final tax-inclusive quote if the applicable treatment is unknown, stale or unapproved. Do not infer that KRIM is GST-exempt.

## 4. P1 — Accessorial charges and surcharge catalogue is empty
There are zero accessorial charge rows. No governed fuel adjustment, toll, waiting/detention, loading/unloading, handling, security, peak-season, port/terminal, remote-area, storage, re-delivery, documentation, customs brokerage or dangerous-goods surcharge is configured.

The public `public/quotes/surcharges.html` page contains hard-coded example values (including a USD 650 BAF figure) and presents them in a management-style table, but the live accessorial table is empty. The static example is not a current provider tariff, index feed or customer quote.

**Required remediation:** replace hard-coded commercial examples with clearly labelled synthetic demos or live, source-backed, effective-dated charge records. Each charge must identify payer, calculation basis, unit, currency, route/mode applicability, taxable status, evidence/source, effective window, caps/floors, exclusions and disclosure timing. Require customer acceptance before applying any variable or conditional charge.

## 5. P1 — FX conversion is not operational
There are 156 currency catalogue rows and 253 country-currency reference rows, but `krim_fx_rates` has zero records. A currency catalogue says which codes exist; it does not provide an exchange rate, source, timestamp, spread, validity or conversion basis.

No current FX quote or conversion evidence is available. Do not convert or compare partner offers across currencies using a hard-coded or stale rate. A future FX process needs source/provider, base/quote pair, rate type, observed time, validity, precision, spread/markup, source reference, fallback policy and immutable quote-time snapshot. Any FX fee/spread must be disclosed separately.

## 6. P1 — Commercial rate-card evidence is reference-based, not a verified document chain
The admin console asks for carrier cost evidence and qualified tax review references. The database approval path checks that these references are non-empty and that the amounts reconcile, but the visible schema/function does not prove that the references resolve to immutable, access-controlled evidence documents, that the document was issued by the named provider, or that the tax review was completed by a qualified independent reviewer.

The evidence metadata does not by itself establish a provider's binding offer, service-area coverage, insurance scope, capacity or willingness to honour the rate for the quote's validity window. The provider capability checks are useful, but the earlier live network audit found no approved active capability, no service area and no partner quotes.

**Required remediation:** bind cost evidence and tax review to versioned private documents or trusted source records with hashes, issuer/author identity, reviewer qualification, approval timestamp and supersession/expiry. Recheck provider identity, service-area/corridor approval, insurance, capacity and rate validity when generating the customer quote and again before award/assignment.

## 7. P1 — Pricing model scope is narrower than KRIM's multimodal promise
The current global rate-card creation RPC supports service tiers `surface_express`, `air_priority`, and `heavy_haul`, with a strict ROAD/AIR mapping and flat or per-kg calculation. The tariff quote path derives an amount from shipment total weight. It does not provide a demonstrated production model for RAIL, OCEAN, MULTIMODAL, warehouse handling, customs services, volumetric/dimensional weight, chargeable weight rules, container/TEU, pallet/ULD, distance/zone, minimum transit legs, temperature control, hazardous cargo, high-value cargo, insurance, route-specific terminal fees or multi-leg cost aggregation.

Do not advertise full multimodal instant pricing. Expand pricing only as actual service providers, approved corridors and verified rate evidence become available. For other modes, use a transparent “request a verified partner quote” workflow rather than inventing an indicative price.

## 8. P1 — Public tax/duty page uses unsupported live-looking sample calculations
`public/quotes/tax-estimation.html` includes a Netherlands 21% VAT display and a sample USD 14,247.50 VAT amount, alongside customs tariff values. The page is static sample content and the production tax-rule table is empty. It does not establish a current jurisdiction-specific tax calculation or legal conclusion.

The page description promises automated customs duty and VAT calculation, which is not supported by the production evidence reviewed. This is a trust/misrepresentation risk.

**Required remediation:** clearly mark the page as a non-operational illustrative demo with synthetic values and a prominent “not a tax or customs assessment” warning, or replace it with a controlled tax information workflow that cannot present a final figure until verified rules and required inputs exist. No static percentage should appear as a universal rate.

## 9. P1 — Quote-to-booking and acceptance records are not a live commercial journey
Seven legacy quote rows exist, but there are zero partner quotes, quote acceptances, quote events, quote versions, orchestration runs, booking requests or commercial commitments. The historical accepted quote rows have no `partner_quote_id`, are past validity and do not have corresponding quote-acceptance rows. The current global acceptance RPC correctly rejects a fresh quote acceptance unless the partner quote and accepted partner assignment match the shipment, partner, amount and currency. The old historical rows therefore should not be treated as proof that the current end-to-end workflow has succeeded.

The separate commercial-commitment function family also needs staging verification: exact quote version binding, customer identity/permission, acceptance evidence, terms version, idempotency conflict behavior and atomic commitment/event creation must all be tested before use.

## 10. Quote disclosure and versioning requirements
Before a customer accepts, a quote should visibly preserve:
- provider identity and whether KRIM is acting as an intermediary;
- exact service scope, route/legs, mode, cargo details, assumptions and exclusions;
- price components, quantity/unit, currency, tax treatment and whether taxes are included/excluded/unknown;
- all known surcharges and the formula/trigger for conditional charges;
- validity, capacity condition, estimated transit window and its source/confidence;
- insurance evidence scope and exclusions without implying KRIM provides insurance;
- cancellation, waiting/detention, accessorial, claims and dispute terms;
- named freight contracting party and payment recipient;
- immutable quote version, acceptance timestamp and exact accepted terms.

A change in price, provider, route, service, tax, surcharge, validity or material assumption must create a new version and require fresh customer acceptance. No silent repricing after acceptance.

## 11. Staging acceptance tests — not run
1. Draft/placeholder/expired/unapproved rate cards never appear as customer quote options.
2. Only an approved rate with current provider, service-area, capability, insurance, capacity, market and corridor evidence is selectable.
3. Provider cost plus platform fee reconciles exactly under currency minor-unit rules.
4. Evidence references resolve to immutable, private, versioned documents and independent tax review.
5. Missing/unknown/stale tax treatment cannot be labelled tax-inclusive or not-applicable.
6. Tax calculation uses jurisdiction, role, place of supply, service and customer facts and a versioned rule source.
7. Customs duties are not represented as freight taxes or included without explicit supported scope.
8. Surcharges require effective-dated rules, units, triggers, caps, disclosure and acceptance.
9. FX conversion rejects missing/stale source rates and records the quote-time snapshot and spread.
10. Multi-currency partner offers compare only after an approved FX conversion and disclosure.
11. Flat/per-kg calculation handles zero, null, negative, extreme, precision and minimum-charge boundaries.
12. Dimensional/chargeable weight and mode-specific units are used only when the relevant approved tariff defines them.
13. Quote snapshot is immutable and every material revision creates a new version.
14. Expired quote cannot be accepted; conflicting retry is idempotent and audited.
15. Customer acceptance requires matching accepted provider quote, assignment, provider verification and exact amount/currency/version.
16. Provider withdrawal, capacity loss, insurance expiry or route/corridor block invalidates eligibility before acceptance/dispatch.
17. Cross-tenant quote, rate-card, evidence and acceptance access is rejected.
18. No freight amount is charged, collected, split or settled through KRIM in the initial non-custodial model.
19. Static demo tax/surcharge pages cannot be mistaken for live pricing or legal tax output.
20. Commercial commitment and event creation are atomic and bind exact customer, quote version, terms and acceptance evidence.

All tests remain unexecuted. No quote, price calculation, FX conversion, tax calculation or payment operation was run.

## 12. Release decision and remediation order
**NO-GO** for live customer freight pricing, tax/duty calculations, FX conversion, multimodal instant quotes, commercial booking or freight collection.

Priority:
- **P0/P1:** clearly relabel/remove unsupported static tax and surcharge examples and disable claims of automated tax/duty calculation until a verified engine exists.
- **P1:** establish an India-first legal/CA-reviewed tax treatment for KRIM's exact intermediary/service-fee model; keep partner freight and KRIM service fees separate.
- **P1:** onboard real verified partners, obtain actual route/service-area rate evidence, insurance and capacity before activating any commercial rate.
- **P1:** implement tax, surcharge and FX source/version governance and customer-facing breakdowns.
- **P1:** complete quote version, partner offer, acceptance, assignment and commitment staging tests.
- **Later:** extend mode-specific and multimodal pricing when corridor and provider evidence exists.
- **Final financial phase:** only after user authorisation, bank/accounting/tax readiness and signed commercial agreements, implement collection of KRIM's own fee only. Keep partner freight funds outside KRIM.

## Change boundary
Read-only production catalog/data/function/grant/RLS inspection and repository page review. No SQL DDL/DML, migrations, RPC invocations, pricing calculations, quotes, booking, payments, provider calls or customer communications. The production/repository migration-history mismatch remains unresolved; do not apply, replay, baseline or squash migrations or corrective production DDL until full schema-manifest reconciliation and separate authorisation.
