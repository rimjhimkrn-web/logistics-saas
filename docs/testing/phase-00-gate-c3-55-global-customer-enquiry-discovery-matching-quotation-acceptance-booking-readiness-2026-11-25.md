# C3.55 — Global customer enquiry, discovery, matching, quotation, acceptance and booking readiness

**Programme:** KRIM GLOBAL PLATFORM — AI QUALITY ASSURANCE, SIMULATION & RELIABILITY PROGRAMME  
**Phase:** 00 — Infrastructure Audit  
**Gate:** C3.55  
**Baseline:** `72d75a18f985ceb09e468839435ee95700e11e46` (immutable source baseline)  
**Audit date:** 2026-11-25  
**Method:** Read-only frontend, SQL migration and dated audit-artifact review. No RPCs, database writes or customer journeys executed.

## Verdict

**FAIL / BLOCKED — NO-GO for live self-service booking, customer quote acceptance or representing a shipment as commercially booked until the booking, matching, partner acceptance, customer acceptance and assignment lifecycle passes reproducible isolated-Staging tests.**

The baseline has a more mature canonical booking page and quote workflow than legacy pages, including an idempotency-key submission and guarded partner/customer acceptance. Those controls are meaningful source-level progress, but there are material unresolved gaps and no current runtime evidence.

## Scope reviewed

- `public/shipments/shipment-create.html`
- `public/customer/shipment-create.html` legacy redirect
- `public/customer/quote-request.html`
- `public/customer-os/customer-services/booking-request.html`
- `public/customer-os/customer-services/quote-request.html`
- `public/customer-os/assets/shipment-operations.js`
- `public/customer-os/assets/quote-operations.js`
- `public/customer-os/quotes-pricing/quote-comparison.html`
- `public/partner/submit-quote.html`, `load-marketplace.html`
- Booking, partner quote permission, quote orchestration, quote acceptance, partner assignment, customer quote lifecycle and multi-leg migrations.
- Dated 16 Nov audits for booking/quote/cancellation, customer-to-partner journey, quote/assignment/capacity integrity and multi-leg quote acceptance.

## Positive source controls — PARTIAL PASS

1. **Canonical customer booking uses an idempotency key.** The current Customer OS booking page calls `krim_create_global_shipment_idempotent` with customer organization, normalized origin/destination, cargo, weight, selected transport mode, route type and a booking request UUID. It locks the submit button and avoids blind retry if no shipment identifier is returned.
2. **Customer organization and permission checks are part of the intended secured booking contract.** The dated booking audit describes server-side active membership and `shipment.create` checks in the idempotent booking RPC. Current runtime function body and effective grants were not re-read in this gate.
3. **Partner bid submission requires scoped permission.** Migration `20261105153000_enforce_partner_quote_create_permission.sql` adds `quote.create` enforcement to the partner quote submission RPC.
4. **Quote orchestration uses current eligibility and capacity inputs.** The reviewed orchestration function filters active registered-business partners with verified identity, compliant state, active mode/capability and effective dates, then checks network capacity or verified vehicle/weight availability for the requested date, route and weight.
5. **Customer offer listing is organization-scoped.** The quote comparison UI loads the requested shipment only when it belongs to an active customer/shipper/enterprise organization available to the signed-in user, then loads partner offers through a dedicated RPC.
6. **Modern customer quote preparation binds partner quote, shipment and assignment.** The UI calls `krim_customer_prepare_partner_quote`; reviewed migrations implement a guarded award/preparation flow that validates the selected offer and creates customer quote plus assignment offer as a single commercial preparation step.
7. **Partner assignment acceptance precedes customer acceptance.** The reviewed `krim_accept_global_quote` migration locks quote/shipment, checks customer organization access and permission, quote state/expiry, shipment state, matching partner quote amount/currency and accepted assignment before confirming the shipment. Later migration additionally rechecks partner active state, verification, compliance, capability and shipment coverage.
8. **Multi-leg shipment-wide award is explicitly blocked rather than silently mispriced.** Migrations block shipment-wide customer quote preparation/award for active multi-leg plans where the leg-specific customer acceptance model is not complete. Exact-leg partner opportunity/quote/award paths exist.
9. **Legacy customer URLs are redirected.** `public/customer/shipment-create.html` forwards to the canonical customer booking workflow; old partner marketplace URL forwards to live-data-only freight exchange and states sample loads are fictional.

## P0 — release blockers

1. **No current end-to-end execution evidence.** No Staging journey has demonstrated enquiry/booking → opportunity/matching → eligible partner offer → partner assignment acceptance → customer quote acceptance → shipment confirmation → capacity reservation with database and audit evidence. No actual UI/RPC/browser test was run in this gate.
2. **Booking function-chain conflict remains unresolved in the available dated evidence.** The 16 Nov audit found the then-live idempotent RPC's overload chain inserted the shipment before setting `requested_transport_mode`, while a BEFORE INSERT corridor trigger required the mode. The current frontend sends the mode to the idempotent RPC, but this static review did not establish that the deployed or baseline SQL implementation now persists it before the guarded insert. Treat the prior P0 as OPEN until exact current function bodies, trigger order and isolated Staging test prove otherwise.
3. **Operational market/corridor readiness blocks booking independently.** The dated 16 Nov activation audit found active catalogue locations were not equivalent to approved operational markets/corridors; all sampled market controls were blocked and country operating packs/corridor dossiers were not approved. Historical values are not asserted as current, but no later evidence in this gate proves that the route activation prerequisites have been satisfied.
4. **Multi-leg customer commercial acceptance is structurally incomplete in the dated audit.** Leg-specific partner opportunities, quote submission and award can create an offered assignment, but the reviewed design had no leg-aware customer quote preparation/acceptance path. Shipment-wide customer quote preparation deliberately rejects multi-leg plans; partner assignment response defers finalization until customer acceptance; finalization requires shipment confirmed. No later migration in the reviewed baseline tree establishes a complete consolidated or per-leg customer acceptance contract. Keep multi-leg customer booking BLOCKED.
5. **Alternate legacy acceptance RPC remains a bypass risk in dated evidence.** The 16 Nov audit found authenticated `krim_customer_accept_quote(bigint)` could mark a customer quote accepted without the modern permission, partner-quote binding, accepted assignment and shipment transition checks. The current UI uses `krim_accept_global_quote`, but this audit did not establish that the legacy function was revoked or hardened in the baseline. Verify effective EXECUTE grants and close the alternate path before release.
6. **No verified supply or commercial coverage.** Partner discovery and matching source code is not proof of verified active partners, route-specific service, available capacity, rate, equipment or a provider commitment. Earlier gates C3.53/C3.54 remain blocked.

## P1 — important workflow and customer-experience gaps

1. **No complete customer enquiry-to-qualified-lead handoff proven.** Public contact/enquiry, customer organization provisioning, qualification, anti-spam, CRM handoff and conversion into a shipment request have not been traced as one durable, idempotent workflow.
2. **Booking and opportunity creation may be split across separate actions in legacy surfaces.** The older `public/shipments/shipment-create.html` form and dated audit describe a two-RPC sequence that could save a draft shipment and then fail to create the partner opportunity. The canonical Customer OS booking page uses a different idempotent RPC; legacy entry points and redirects must be reconciled so users cannot enter a broken path.
3. **Customer cancellation/withdrawal is not established.** The 16 Nov audit did not identify a complete customer-facing cancellation or withdrawal RPC. Safe cancellation must distinguish pre-award draft withdrawal, quote rejection, post-partner-acceptance/pre-dispatch cancellation, and post-dispatch exception/return handling; include capacity release, fees/refunds, partner response and audit history.
4. **Quote expiry and retries require execution proof.** Source has quote validity checks, expiry handling and idempotent booking key, but no concurrent duplicate-submit, replay, quote expiry boundary, network timeout/retry or stale-page test was run.
5. **Multi-shipment quote aggregation and comparison need full contract coverage.** A customer quote list supports multiple shipments, but no full proof exists for partial offers, multi-provider comparison, revisions, rejection, withdrawal, currency/tax snapshots, quote version immutability or customer-visible disclosure.
6. **Customer-safe partner identity and data exposure need tenant-negative testing.** Offer visibility is intended to expose limited provider information; no two-customer/two-partner cross-tenant test or buy-rate confidentiality test was run.
7. **No confirmed booking wording until all gates pass.** UI text and success banners must distinguish shipment request created, partner quote received, assignment offer sent, partner accepted, customer quote accepted, capacity reserved and operationally confirmed. A created draft/request must never be described as a confirmed booking.
8. **Shipment mode and service-tier semantics require canonical validation.** Booking page sends both transport mode and route type; older form has separate service tier and mode concepts. Validate that only physical transport modes are persisted as mode values and service tiers remain a separate commercial attribute.
9. **No complete quote/booking cancellation, refund or payment integration evidence.** The commercial and payment gates remain blocked; customer acceptance must not imply KRIM has collected freight or that a provider has received funds.

## Required isolated Staging acceptance tests

- Submit valid and invalid customer enquiries; verify spam controls, consent, lead ownership, CRM sync/retry and no duplicate lead on retry.
- Create bookings for every supported mode/route type; assert selected physical mode is persisted before corridor trigger validation and the booking request UUID returns the same shipment on replay.
- Exercise inactive locations, country, market, corridor, mode, expired route dossier and unsupported route; expected fail-closed errors with no orphan shipment.
- Inject network timeout after commit and retry same key; verify one shipment and one opportunity, or a recoverable explicit partial state with safe resume.
- Verify organization ownership, shipment.create/quote.create/quote.update/shipment.update permissions, wrong-tenant and revoked-membership denial.
- Discover eligible and ineligible partners across modes, exact origin/destination, effective dates, weight, capacity, vehicle and compliance expiry; prove no ineligible offer appears or can be submitted.
- Submit partner quote with invalid/zero/negative amount, unsupported currency, expired validity, wrong opportunity, wrong partner, duplicate/replay and concurrent requests.
- Prepare customer quote; verify exact partner quote, customer, shipment, route/leg, amount, currency and assignment linkage.
- Partner accept/reject; customer accept/reject; verify status graph, exact assignment, shipment transition, audit events and capacity commitments.
- Test legacy acceptance RPC with anonymous, authenticated non-owner, owner without required permission and valid owner; require one canonical guarded outcome.
- Test multi-leg partial/full offers, one leg unavailable, mixed currencies, partial acceptance, failure/retry and consolidated pricing; remain blocked until a defined customer contract passes.
- Test cancellation at each lifecycle stage, reservation release, partner notification mock, refund/fee accounting and post-dispatch exception route.
- Capture browser trace, request/response, DB before/after snapshots, audit events and repeatable negative-test output.

## Status

| Area | Status | Basis |
|---|---|---|
| Canonical booking frontend contract | PARTIAL PASS | Idempotency key and mode/route fields sent; runtime not executed |
| Booking database/trigger compatibility | BLOCKED | Dated P0 conflict not independently closed |
| Enquiry qualification and CRM handoff | NOT TESTED | Full journey not traced |
| Partner matching and eligibility | PARTIAL PASS | Source filters capability/compliance/capacity; no live verified supply |
| Partner quote submission | PARTIAL PASS | Scoped permission migration; runtime not tested |
| Customer quote preparation/acceptance | PARTIAL PASS | Guarded source path; no E2E execution |
| Legacy quote acceptance alternate path | BLOCKED | Dated weaker RPC grant/body requires current revalidation |
| Multi-leg customer quote/acceptance | BLOCKED | No complete leg-aware customer acceptance contract established |
| Cancellation/withdrawal | NOT TESTED | Complete customer workflow not found in dated audit |
| Commercial booking and fulfilment readiness | BLOCKED | No complete Staging journey, current route readiness or verified supply proof |

## Safety boundary

No Production or Staging RPC, SQL, customer enquiry, booking, opportunity, quote, assignment, capacity reservation, payment, notification, provider call or deployment was performed. No secrets or personal customer records were read. No synthetic identities were created. Dated 16 Nov live audits are historical evidence, not current live-state assertions.

## Exit criteria

Do not enable customer self-service booking or claim confirmed commercial booking until booking-mode/trigger order is verified, route activation and partner supply are current, every quote acceptance route is canonical and permission-bound, multi-leg acceptance is either fully implemented or explicitly disabled, cancellation semantics are defined, and the complete customer-to-partner journey passes isolated Staging with independent evidence.
