# KRIM Customer-to-Partner Operational Traceability Audit — 16 November 2026

**Repository:** `rimjhimkrn-web/logistics-saas`  
**Production Supabase project:** `ebltviniygljwwseplph`  
**Scope:** customer request → quote → partner offer → assignment → capacity → dispatch → driver → custody → POD → readiness/closure.  
**Method:** canonical source inspection plus read-only production SQL and current database routine inspection. No production data or schema was changed by this audit.

## 1. Executive result

The core customer-to-partner workflow has substantial backend controls and canonical pages, but **the production network is not currently able to fulfil a new shipment**:

- No active open partner opportunities.
- No partner quotes.
- Six KRIM markets and six countries are active, but no verified active partner capability exists in the production dataset.
- Two partner-type organizations are active, but zero meet the verified/approved + active lifecycle + compliant eligibility test.
- No active rate card.
- No partner assignments or capacity resources.
- No driver assignments, dispatch authorizations, custody transfers or POD records.

There are also legacy-state inconsistencies that must be reconciled before the platform may safely present existing records as booked or operationally ready.

**Release state: blocked for live marketplace fulfilment; foundations implemented, real-world journey unverified.**

## 2. Canonical page → action → backend map

| Journey stage | Canonical source | Backend / persisted record | Source-level result |
|---|---|---|---|
| Customer creates shipment | `public/shipper/booking-request.html` | `krim_create_global_shipment_idempotent`; `krim_shipments`; `krim_organization_members`; `krim_organizations`; active country/location/market checks | Idempotent request creation and organization authorization present |
| Customer requests tariff / partner sourcing | `public/shipper/rate-calculator.html` | `krim_create_tariff_quote`; `krim_create_partner_opportunity` | Server RPCs used; tariff requires active approved rate; partner opportunity requires active market controls |
| Partner sees loads and submits offer | `public/partner/submit-quote.html` | `krim_partner_opportunities`; `krim_shipments`; `krim_partner_quotes`; `krim_submit_partner_quote` | Organization eligibility and server-backed quote submission present |
| Customer compares partner offers | `public/shipper/quote-comparison.html` | `krim_customer_list_partner_quotes`; `krim_quotes`; `krim_shipment_partner_assignments` | Organization-scoped offer list and shipment-bound assignment state; no fake offer fallback |
| Customer prepares chosen provider offer | `public/shipper/quote-comparison.html` | `krim_customer_prepare_partner_quote` → `krim_award_partner_quote_for_checkout` → `krim_award_partner_quote` | Creates customer quote linked to partner quote and an `offered` partner assignment; shipment remains quoted |
| Provider accepts/rejects | Partner assignment response RPC | `krim_respond_to_partner_assignment`; assignment trigger `krim_ensure_assignment_capacity_commitment` | Provider must accept exact linked assignment; capacity-weight commitment created; no evidence of live partner test |
| Customer accepts exact quote | `public/shipper/quote-comparison.html`; legacy review `public/shipper/spot-approvals.html` | `krim_accept_global_quote`; `krim_internal_finalize_partner_assignment` | Current RPC rejects tariff-only/unlinked quotes and requires accepted partner quote + matching accepted assignment + active verified capability |
| Partner reserves physical capacity | Partner capacity workflow | `krim_partner_reserve_shipment_leg_capacity`; `krim_capacity_resources`; `krim_capacity_reservations`; `krim_capacity_leg_bindings` | Exact-leg physical capacity reservation exists in backend; no live resource/reservation records |
| Dispatch authorization | Exact-leg operations/partner workflow | `krim_authorize_leg_dispatch`; `krim_shipment_leg_dispatch_authorizations` | Requires accepted exact-leg assignment, confirmed physical capacity binding/reservation; ROAD additionally requires verified driver, current licence, active verified vehicle and mandatory documents; later legs require accepted prior custody |
| Driver accepts assignment | `app/driver/module-03-assignment-acceptance.html` | `krim_driver_assignments`; `krim_driver_accept_assignment` | Driver membership and assignment acceptance checks present |
| Driver submits POD | `app/driver/module-10-proof-of-delivery.html` | Private bucket `krim-driver-evidence`; `krim_driver_delivery_evidence`; `krim_driver_submit_delivery_pod`; `krim_pod_records` | Current source includes evidence upload and submission form; backend validates assigned driver, active driver membership, in-transit assignment, linked partner assignment and driver-owned private evidence |
| Independent POD review | `app/platform-admin/delivery-pod-verification.html` | `krim_admin_list_delivery_pods`; `krim_admin_review_delivery_pod`; internal verify/authorize routines | MFA AAL2 and platform-admin permission; submitting driver cannot review own POD; private evidence object ownership checked |
| Customer delivery evidence | `public/customer/epod-vault.html` and customer shipment pages | Verified POD records and authorized evidence access | Access pattern exists; zero live POD records; real authorized customer access not E2E-tested |

**Important legacy distinction:** `public/shipper/spot-approvals.html` is the older tariff/global-quote review register. The newer customer partner-offer workflow is `public/shipper/quote-comparison.html`. A tariff quote with no partner quote link cannot be treated as a provider booking.

## 3. Read-only production evidence — 16 November 2026

### Core counts

| Production object | Current count |
|---|---:|
| `krim_shipments` | 18 |
| `krim_quotes` | 7 |
| `krim_partner_opportunities` | 3 |
| `krim_partner_quotes` | 0 |
| `krim_partner_capabilities` | 1 |
| `krim_shipment_partner_assignments` | 0 |
| `krim_capacity_resources` | 0 |
| `krim_capacity_reservations` | 0 |
| `krim_capacity_leg_bindings` | 0 |
| `krim_shipment_legs` | 1 |
| `krim_shipment_leg_plans` / activations | 0 / 0 |
| `krim_driver_assignments` | 0 |
| `krim_shipment_leg_dispatch_authorizations` | 0 |
| `krim_shipment_leg_custody_transfers` | 0 |
| `krim_driver_delivery_evidence` / `krim_pod_records` | 0 / 0 |
| `krim_shipment_milestones` | 2 |

### Status breakdown

- Shipments: 8 draft, 3 quoted, 6 confirmed, 1 closed.
- Customer quotes: 6 accepted, 1 sent. **All seven have `partner_quote_id IS NULL`.**
- Partner opportunities: 2 cancelled, 1 expired; 0 open.
- Partner quotes: 0.
- Partner capabilities: 1 pending and inactive; 0 verified active.
- Pricing rate cards: 1 record, 0 active.

### Cross-record integrity checks

1. **Six confirmed shipments have no accepted/active partner assignment.**
2. All six `accepted` quote records are unlinked tariff/legacy quotes, not accepted partner offers.
3. One shipment leg is marked `assigned` and has a partner organization ID, but has no matching accepted/active row in `krim_shipment_partner_assignments`.
4. Six shipment readiness-gate records are marked `ready`, with `partner_status='not_required'` and `payment_status='partner_direct'`.

These findings are not proof of fraud or data loss. They indicate legacy records created under an earlier lifecycle contract and require case-by-case reconciliation. Do not mass-change shipment, quote or leg statuses and do not invent partner links.

## 4. Critical readiness defect — P0

The current production routine `public.krim_internal_evaluate_shipment_readiness` sets partner status to `not_required` whenever shipment status is one of:

`draft`, `requested`, `quoted`, **`confirmed`**.

That rule conflicts with the current quote acceptance contract:

- `krim_accept_global_quote` now requires a linked partner quote.
- It requires a matching accepted partner assignment.
- It validates active partner organization, verification/compliance, price/currency match and current capability coverage.
- It then confirms the shipment and finalizes the assignment.

The six legacy confirmed shipments have no accepted partner assignment, yet their readiness rows are currently `ready` / `not_required`. This is a false-positive readiness state for those records.

**Required correction (not applied in this audit):**
1. Reconcile the readiness evaluator with the current lifecycle contract: at `confirmed` and later operational states, verify a matching accepted/active partner assignment instead of marking the partner gate `not_required`.
2. Ensure the check is shipment/leg/partner-bound and current; do not accept any unrelated assignment.
3. Re-evaluate the six legacy readiness records after code and migration-history review.
4. Keep the affected legacy shipments blocked from dispatch/operational-ready claims until manually reconciled.
5. Add regression tests for confirmed-without-assignment, assignment for wrong shipment, rejected/expired assignment, verified matching assignment, and partner capability expiry.

**No production DDL was executed.** The production migration history is known to be ahead of the repository at points; reconcile schema/migration history and current function dependencies before preparing or applying a correction migration.

## 5. Capacity model distinction

Two concepts must not be conflated:

- `krim_partner_shipment_capacity_commitments`: an assignment-acceptance trigger creates a shipment-weight commitment for the accepted partner assignment. This supports assignment finalization but does not prove a physical resource is reserved.
- `krim_capacity_resources` + `krim_capacity_reservations` + `krim_capacity_leg_bindings`: actual resource/availability reservation for an exact shipment leg.

The current exact-leg dispatch authorization checks the second set and additional readiness gates. The legacy shipment-wide `krim_dispatch_shipment` routine checks the older commitment and compliance/capability controls. These two dispatch paths need ongoing reconciliation and a single authoritative release contract. No current production capacity resource or reservation exists.

## 6. Partner-direct commercial boundary

The production readiness function records `partner_direct` as the payment collection model. It is explicitly not payment received or settled.

- Customer contracts with and pays the logistics provider directly under the current launch model.
- KRIM does not collect freight charges or settle provider freight funds.
- Provider freight invoice/payment, KRIM referral/coordination fee, SaaS subscription and integration service revenue are separate records and accounting/tax treatments.
- The presence of a confirmed shipment or partner-direct readiness value must never be displayed as paid, settled or revenue.
- Keep payment checkout and refund provider execution disabled unless a separate approved commercial/legal/payment design authorizes them.

## 7. Code correction completed in this audit

Commit: `18f2835c956fcbe545465c6da5a9deca58894a00`

File: `public/shipper/spot-approvals.html`

- The summary label now says “Accepted quote records” rather than simply “Accepted”.
- An accepted quote without a partner quote link is labelled “accepted · no partner offer”.
- Its detail panel now explicitly states that the legacy record is not evidence of a confirmed logistics provider, booked service, delivery or payment, and instructs operations reconciliation rather than payment.

No database rows, schema, RPCs, RLS policies, secrets or payment settings were changed.

## 8. Verification and acceptance status

**Source checks completed in this audit:**
- Canonical customer shipment form calls the idempotent shipment RPC.
- Tariff desk calls tariff and partner-opportunity RPCs.
- Partner quote page calls partner quote submission RPC.
- Customer comparison calls customer offer listing, offer preparation and quote acceptance RPCs.
- Driver POD page contains a private evidence upload and submission workflow.
- Admin POD review routines enforce AAL2 and independent review.
- Current database functions were inspected read-only for the core quote, assignment, capacity, dispatch and POD gates.

**Not completed:**
- No authorized live customer → partner → driver shipment E2E.
- No partner account with verified active capability.
- No active rate card or open partner opportunity.
- No capacity resource or physical capacity reservation.
- No real driver/vehicle assignment or dispatch.
- No custody transfer, delivery evidence or POD record.
- No cross-organization browser/RLS negative test for this entire journey.
- No production correction of readiness false positives.

Static source inspection and SQL metadata inspection do not certify browser runtime, physical logistics performance or a real shipment.

## 9. Remediation sequence

1. **P0 — Readiness false-positive correction:** reconcile production migration history, update the readiness evaluator in a controlled migration, add regression tests, then re-evaluate legacy readiness records.
2. **P0 — Legacy record triage:** inspect the six confirmed shipments and one orphan assigned leg through authorized operational review; determine whether they are test/legacy records, valid historical commitments or records requiring correction. Do not rewrite automatically.
3. **P0 — First real partner supply cell:** obtain one registered business partner, verify organization and documents, approve one exact transport capability/service area, register a real capacity resource and availability.
4. **P0 — First controlled customer journey:** one authorized test shipment through open opportunity → real partner quote → customer preparation → provider acceptance → physical capacity reservation → customer quote acceptance → dispatch authorization → driver acceptance → milestones → POD → independent verification.
5. **P1 — Multi-leg proof:** create and evaluate a real route plan, activate atomically, test per-leg partner/capacity/custody and final delivery. Keep multi-leg shipment-wide sourcing blocked until leg-specific sourcing is proven.
6. **P1 — Finance closure:** preserve partner-direct payment separation and prove invoice/fee/reconciliation records without collecting freight funds.
7. **P1 — Update phase audit docs:** keep the Phase 10 audit aligned with the current driver POD source and ensure the 14-phase acceptance blueprint remains the authority.

## 10. Evidence boundaries

- Live SQL queries were read-only.
- No production data was inserted, updated or deleted.
- No production migration or Edge Function was deployed.
- The frontend wording correction is committed but requires its own CI/deployment verification.
- Counts are a point-in-time snapshot and must be refreshed before launch decisions.
