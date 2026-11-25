# C3.54 — Global partner commercial readiness: pricing, rate cards, contracts, commission and settlement

**Programme:** KRIM GLOBAL PLATFORM — AI QUALITY ASSURANCE, SIMULATION & RELIABILITY PROGRAMME  
**Phase:** 00 — Infrastructure Audit  
**Gate:** C3.54  
**Baseline:** `72d75a18f985ceb09e468839435ee95700e11e46` (immutable source baseline)  
**Audit date:** 2026-11-25  
**Method:** Read-only source, migration and dated audit-artifact review. No live database queries or commercial transactions.

## Verdict

**FAIL / BLOCKED — NO-GO for automated customer pricing, paid partner referrals, freight collection, partner payout promises or claims of complete commercial contracting until the relevant legal, pricing, tax, provider, contract and settlement controls are implemented and independently verified.**

This is not a statement that all commercial code is absent. The source contains meaningful rate-card governance and guarded payment/settlement primitives. It is a statement that code paths and schemas are not evidence of a complete executable commercial arrangement or tested financial outcome.

## Scope reviewed

- Global tariff quote RPC and fail-closed rate-card migration.
- Global rate-card administration and AAL2 migration.
- Rate-card read visibility and direct-write lockdown.
- Evidence-backed approval and activation migration.
- Current partner compliance enforcement migration.
- Quote pricing snapshot migration.
- Partner quote RPC contract review.
- Payment/partner settlement RPC review.
- Pricing/tax/FX audit dated 2026-11-16.
- Customer–partner contract and commercial-terms audit dated 2026-11-16.
- Partner contract, insurance, liability and SLA audit dated 2026-11-16.
- Partner, finance and platform-admin commercial pages.

## Positive source controls — PARTIAL PASS

1. **No hard-coded fallback price:** the tariff quote implementation selects an effective active global rate card for the exact origin country, destination country and mapped mode; if no matching card exists, it fails closed. A separate historical migration explicitly disabled quote generation without an approved active card.
2. **Customer organization and shipment checks:** tariff quote creation requires authentication, shipment organization access, `quote.create` permission, valid shipment state, positive weight and active mapped origin/destination locations.
3. **Duplicate quote mitigation:** an existing unexpired sent platform tariff quote is reused under shipment/quote row locking. Concurrency and exactly-once behavior still require runtime proof.
4. **Rate-card governance:** create/evidence/approval/status routines are privileged; a later migration adds AAL2 checks to the listed global rate-card admin RPCs. Direct authenticated writes to the global pricing rate-card table are revoked.
5. **Provider and route eligibility:** commercial evidence recording checks provider active/registered-business/verified/compliance states, verified active mode capability in both countries, active currency and route-market prerequisites.
6. **Cost-plus reconciliation:** provider buy rate plus platform fee must reconcile to the customer rate at the currency's minor-unit precision. Evidence requires dated cost reference and tax-review reference.
7. **Approval and activation are distinct:** approval requires evidence and both active route markets to pass the internal market-activation gate; activation rechecks evidence, approval, date window, amount reconciliation and tax-treatment label. Activation uses row locking and checks active-priority conflicts.
8. **Current compliance enforcement:** migration `20261105200000_require_current_partner_compliance_for_commercial_actions.sql` introduces a helper requiring a latest approved, time-limited compliance review and patches selected capacity, assignment and capability paths. It also requires a validity deadline for an approved compliance decision, correcting the earlier nullable-validity behavior identified in the preceding source migration.
9. **Payment/settlement primitives are restricted:** the dated 7 Nov RPC review records selected internal payment and partner payout routines as non-executable by anon/authenticated clients, with service-role checks on Razorpay reconciliation. This is a dated review, not current ACL confirmation.

## P0 — release blockers

1. **No execution-ready legal contracting basis.** The 16 Nov contract audit says the canonical public terms remain preliminary and the partner agreement is a framework, not a signed agreement. It found no complete live workflow for generating, presenting, accepting, preserving and binding a customer-specific provider contract/work order. A framework, quote or partner registration is not evidence of a binding contract.
2. **No proven paid KRIM–partner commercial agreement.** The 16 Nov audit found no executed agreement establishing KRIM's exact referral/coordination/SaaS role, fee trigger, calculation, territory, tax/invoice treatment, currency, due date, liability allocation, dispute/clawback and termination. Do not charge or promise partner referral revenue on the basis of a draft framework.
3. **No independently verified end-to-end commercial execution.** No reproducible Staging evidence demonstrates a real rate card progressing from provider evidence → independent approval → activation → matching quote → customer acceptance → exact provider/leg assignment → contract/work order → invoice/payment or separately governed fee → ledger → reconciliation → eligible partner payout. No real funds or provider payout tests were performed.
4. **No current proof of live rate/tax/FX readiness.** The 16 Nov pricing audit snapshot reported one draft INR/ROAD/flat rate card, zero active global cards, zero FX rates, zero tax rules, zero pricing runs/components/quote versions/partner quotes. These are dated historical figures, not current counts. They nevertheless show that, at that snapshot, no production-calculated commercial quote was evidenced.
5. **No complete legal and liability/insurance assurance.** The 16 Nov partner contract/insurance/SLA audit reported no executed contracts, SLA schedules, shipment SLA targets, breaches/remedies, insurance evidence/reviews, claims or SLA evaluation runs. A generic compliance approval is not proof of insurance cover for a particular mode, cargo, territory, limit or period.

## P1 — material pricing and finance gaps

1. **Narrow pricing model.** The dated pricing audit describes the calculator as flat/per-kg only, with no demonstrated volumetric/chargeable weight, pallet/container/vehicle units, distance/zone bands, multiple legs, fuel, tolls, waiting, loading/unloading, handling, storage, customs, insurance, peak/remote-area or other accessorial calculations. The tariff RPC maps only surface_express/heavy_haul to ROAD and air_priority to AIR. Rail, ocean and warehouse pricing are not established by that path.
2. **Tax calculation is not a global tax engine.** The dated audit found generated tax_total=0 and empty additional-tax breakdown, with no jurisdictional lookup against tax rules. The allowed labels `included_in_rate` and `not_applicable` plus a reference string do not by themselves establish correct tax treatment, invoice liability or compliance.
3. **FX conversion and quote locking are not established.** The dated audit found empty FX snapshots and no evidenced source/effective-time/spread/rounding/validity conversion policy. Do not display an indicative converted amount as an executable settlement amount without an immutable FX snapshot.
4. **Maker-checker gap in rate approval.** The reviewed evidence RPC stores `recorded_by`; the approval RPC stores `approved_by`, but the inspected approval path does not reject the same user approving the evidence they recorded. Activation checks presence of approval metadata, not an independent approver identity. Require enforced separation of duties for material commercial rates.
5. **Rate card ≠ provider offer or capacity.** The global tariff quote is not a multi-provider live quote comparison and does not itself prove provider availability, shipment-date capacity, equipment, cargo fit, route commitment or service SLA. Customer price must not imply a confirmed carrier booking.
6. **Commercial contract lifecycle incomplete.** Dated audit review found contract/acceptance/terms/SLA/claim/dispute/refund record populations empty at that snapshot; no versioned bilateral signature/acceptance and shipment binding was established. Recheck current state in Staging; do not treat historical counts as current.
7. **Commission, platform fee and settlement semantics need one canonical ledger contract.** The rate card records a platform fee as cost-plus pricing evidence, but that is not the same as a separately accepted partner commission/referral fee or a legally approved KRIM service fee. Fee basis, trigger, tax invoice, currency, refund/clawback and settlement schedule must be explicit and versioned.
8. **Payout controls are not payout proof.** Restricted internal payout RPCs and a settlement UI do not establish reconciled payable balances, bank-account ownership, maker-checker, payout provider success, idempotent retries, failed/returned payout recovery or beneficiary confirmation. The 7 Nov RPC review is historical.
9. **Payment/freight custody boundary remains critical.** Earlier payment/webhook audits identified a captured-payment webhook path that could bypass the freight-collection control even when order creation is gated. This gate does not revalidate live behavior; it remains an open cross-gate P0 until the payment and finance remediation is independently tested.
10. **No live commercial data or evidence was inspected in this gate.** The 16 Nov counts and reviews are explicitly dated historical context and must not be presented as today's database state.

## Required isolated Staging acceptance tests

- AAL1, non-admin, wrong organization and anonymous attempts against every rate-card create/evidence/approve/activate/suspend/list RPC; verify direct table DML denial and correct audit actor.
- Record evidence, then attempt approval by the same user; expected denial after maker-checker remediation. Verify independent reviewer and immutable timestamps.
- Missing, stale, future-dated, malformed and contradictory provider cost/tax evidence; currency minor-unit boundaries; negative/zero/oversized values; duplicate active priority cards; overlapping effective windows; concurrent activation.
- Inactive country/market/mode/currency, unverified or expired provider, withdrawn capability, expired compliance and exact-route mismatch; expected fail-closed result.
- Flat/per-kg pricing boundary values, weight rounding, minimum charge, currency exponent (including zero- and three-decimal currencies), quote expiry, duplicate submission and concurrent quote requests.
- Unsupported rate type, rail/ocean/warehouse, accessorials, tax jurisdictions and cross-currency cases; verify explicit BLOCKED/unsupported outcome rather than invented totals.
- Customer quote visibility, partner private buy-rate confidentiality, tenant separation, quote version immutability and exact partner/customer acceptance.
- Contract generation, version/hash, authorized signatory, both-party acceptance, shipment binding, cancellation/amendment and dispute/claim access.
- Commission calculation and fee trigger, invoice/tax treatment, refunds/clawbacks, payable ledger, maker-checker payout approval, idempotency, provider failure and bank reconciliation using mocked payment/payout providers only.
- End-to-end evidence: browser trace, RPC inputs/outputs, database before/after state, audit events, exact quote/contract/ledger references and repeatable negative tests.

## Status

| Area | Status | Basis |
|---|---|---|
| Rate-card governance source | PARTIAL PASS | AAL2/admin, evidence, approval and activation controls found |
| Rate-card live data and quote execution | NOT TESTED | Historical 16 Nov snapshot only; no current query or runtime execution |
| Partner-specific quotes and capacity | BLOCKED | Global tariff rate is not proof of provider offer/capacity |
| Tax and FX calculation | BLOCKED | Dated audit identifies missing jurisdictional tax and FX calculation |
| Bilateral customer/partner contracts | BLOCKED | Framework and schema are not executed contracts |
| KRIM–partner fee/commission agreement | BLOCKED | No executed fee agreement established |
| Insurance and SLA assurance | NOT TESTED | Dated audit found no evidence population or evaluator; current state not rechecked |
| Partner payout/settlement | NOT TESTED | Restricted RPC review exists; no payout or reconciliation execution |
| Commercial end-to-end workflow | NOT TESTED | No isolated Staging journey executed |

## Safety boundary

No Production or Staging SQL/RPC, payment, payout, invoice, quote, rate-card, contract, partner, bank, tax, FX, notification, provider or deployment action was performed. No secrets were read. No real funds moved. No partner/customer was contacted. No synthetic user was created.

## Exit criteria

Do not authorize paid partner acquisition, automated customer price promises, freight collection or payout commitments until execution-ready legal terms are approved, rate/tax/FX scope is accurately represented, maker-checker and current partner eligibility are enforced, the fee/settlement model is documented, and the complete commercial journey passes isolated Staging with independent evidence.
