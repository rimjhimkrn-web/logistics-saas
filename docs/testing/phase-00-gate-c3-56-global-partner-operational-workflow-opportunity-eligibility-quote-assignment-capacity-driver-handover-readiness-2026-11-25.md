# C3.56 — Global partner operational workflow readiness

**Programme:** KRIM GLOBAL PLATFORM — AI QUALITY ASSURANCE, SIMULATION & RELIABILITY PROGRAMME  
**Phase:** 00 — Infrastructure Audit  
**Gate:** C3.56  
**Immutable source baseline:** `72d75a18f985ceb09e468839435ee95700e11e46`  
**Audit date:** 2026-11-25  
**Method:** Read-only review of frontend pages, SQL migration definitions and dated 16 Nov audit notes. No runtime execution.

## Verdict

**FAIL / BLOCKED — NO-GO for automated partner availability claims, live bidding/award, capacity commitments, driver handover or dispatch until the complete exact-leg workflow is independently verified in isolated Staging.**

The source contains meaningful security and workflow controls: partner eligibility gates, scoped quote submission, leg-specific opportunities/quotes/awards, independent resource review, atomic capacity reservation logic, and driver acceptance bound to partner assignment and shipment leg. These controls do not yet establish end-to-end operational readiness or actual available supply.

## Scope reviewed

- Partner marketplace: `public/partner/available-loads.html`, `submit-quote.html`, `accepted-loads.html`.
- Partner resources: `public/partner/capacity-resources.html`; legacy capacity-calendar/fleet-assignment routes redirect to the partner workspace.
- Driver routes: legacy assignment inbox/details redirect to `app/driver/staging/` workflow pages.
- Migrations covering partner resource registration/review, capacity reservation, matching eligibility, marketplace visibility, partner assignment/expiry, driver assignment/acceptance and exact-leg award/acceptance.
- Dated 16 Nov partner matching, availability/capacity, assignment coordination and driver/vehicle/dispatch authorization audits.

## Positive source controls — PARTIAL PASS

1. **Partner opportunity visibility is permission- and eligibility-gated in the intended server-side flow.** The matching source requires active registered-business partner status, verified identity, capability, coverage and effective dates. Later marketplace migrations scope reads to verified capability and current compliance.
2. **Partner quote submission has server-side authorization.** The leg quote RPC requires an authenticated user, one unambiguous active registered-business partner organization, `quote.create`, current compliance, active currency, open unexpired opportunity and exact shipment/leg/active-plan linkage. Amount must be finite and positive; quote notes are bounded.
3. **Leg-specific sourcing avoids cross-leg award.** The leg opportunity/quote/award RPCs bind opportunity, shipment, route-plan item, leg, partner and customer permissions. The award path validates current partner eligibility/compliance and exact-leg capability. A partial unique index prevents multiple active partner assignments for the same leg.
4. **Partner acceptance revalidates commercial eligibility and assignment linkage.** The latest reviewed migration checks quote, assignment, opportunity, shipment and exact leg consistency; for multi-leg routes it requires the exact active plan item and an unassigned planned leg. It also rechecks active registered-business status and current compliance.
5. **Resource declaration is separated from independent approval.** Resource review requires platform-admin AAL2 and `admin.platform`; approval requires active verified/compliant partner status and separately verified mode capability. A later migration binds evidence to the original uploader and blocks a submitter from approving their own resource.
6. **Capacity reservation is a dedicated post-acceptance operation.** `krim_partner_reserve_shipment_leg_capacity` requires active partner membership and `shipment.update`, accepted/active assignment, exact shipment-leg-partner binding, current partner eligibility and capability coverage, future departure/arrival, and an idempotency key. It locks assignment/shipment/leg and eligible availability rows, checks verified vehicle/weight resources at the exact origin/mode/time window, subtracts existing held/confirmed reservations, then writes reservation, leg binding, schedule and audit events.
7. **Driver assignment acceptance has identity and chain-of-custody checks.** Driver acceptance binds the driver user, active driver membership, verified driver profile/licence, accepted partner assignment, shipment in assigned state and exact assigned leg. Later migration additionally requires independently accepted front/back licence and identity evidence.
8. **Driver trip events are constrained.** The reviewed driver RPC allows pickup, in-transit and exception events; delivery completion is not accepted through this event RPC and is reserved for authorized POD verification.

## P0 — release blockers

1. **Candidate matching is not a confirmed availability promise.** The immutable baseline matching function uses persisted `partner_compliance_status='compliant'` rather than the authoritative current-compliance helper. The dated 16 Nov deep audit identified that expired/revoked evidence could still yield a match candidate. The later quote/award path rechecks current compliance, but a stale candidate can still mislead internal or customer-facing discovery if surfaced without a clear “potential match only” status.
2. **Candidate generation and reservation are separate states.** Matching results are not capacity reservations. A candidate may have capability/coverage but no resource at the requested date/time. Even where candidate generation includes availability rows, it is not a committed reservation and must not be labeled “available”, “bookable” or “confirmed” until the atomic reservation succeeds. The dated 16 Nov live snapshot reported zero capacity availability and zero reservations; historical only, not current.
3. **Global market/corridor operational approval is not proven in the matching contract.** The dated 16 Nov audit found matching based on active locations/modes and partner service-area/country coverage without complete country operating-pack, active market and approved corridor dossier enforcement. Active catalogue records or partner-declared service areas do not confer legal/operational route authority. No newer evidence in this gate establishes the missing country/corridor approval chain.
4. **No real partner operational supply or successful lifecycle evidence.** The dated live snapshot contained one pending/inactive capability, zero service areas, zero match runs/results, zero current open opportunities, zero partner quotes, zero capacity availability/commitments and zero reservations. These figures are dated 16 Nov and not represented as current. No later verified evidence establishes active real partners, route/mode capacity or successful fulfillment.
5. **No complete runtime proof from award through capacity reservation and driver handover.** Source migrations describe these stages but no isolated Staging run proves that partner acceptance, shipment/leg transition, capacity reservation, driver assignment, driver acceptance and custody handover commit consistently, exactly once and in the right order.
6. **Driver handover/dispatch safety is not established by assignment acceptance alone.** Driver acceptance proves a driver accepted a specific assigned leg; it does not prove vehicle/driver licence validity at dispatch time, vehicle-to-leg compatibility, driver hours/availability, insurance, dangerous-goods/temperature credentials, route jurisdiction, pickup custody or actual dispatch. These require a separate eligibility and dispatch authorization chain and runtime evidence.
7. **No evidence that every alternate write path is closed.** The reviewed migrations secure selected RPC paths, but no exhaustive inventory proves direct table DML, legacy RPCs, service-role jobs, admin tools, Edge Functions and background automation cannot bypass opportunity, quote, award, assignment, reservation or driver handover invariants. The broader C3.42/C3.44/C3.51 findings remain open.

## P1 — workflow, data quality and operational gaps

1. **Partner-declared resources are not automatically verified supply.** Capacity UI describes declarations, evidence and review. The Page 103 audit explicitly states that registration does not book/assign shipments; only approved vehicle/weight capacity supports automated leg reservations. Warehouse, handling, equipment, container, volume and slot types remain review-only in the described booking logic.
2. **Capacity units and resource semantics need full validation.** Reservation code supports vehicle count or recognized weight units and compares availability/resource units; other units fail closed. Tests must cover kg/tonne conversions, rounding, mixed units, duplicate availability windows, partial consumption, release and rebooking.
3. **Capacity lifecycle/release needs independent verification.** Expiry logic releases accepted assignments when customer quote expires and attempts to release associated capacity commitment; reservation cancellation, shipment cancellation, assignment revocation, partner suspension, changed schedule and partial-leg completion need a complete transition matrix and proof that capacity is neither leaked nor double-released.
4. **Concurrency and idempotency remain unproven at runtime.** Reservation uses an idempotency key, row locks and `SKIP LOCKED`, but there is no concurrent two-shipment contention test, same-key replay, different-leg key collision, timeout-after-commit retry or invariant check against overbooking.
5. **Resource approval and evidence lifecycle require end-to-end checks.** Verify original uploader ownership, private bucket/path, MIME/size, independent reviewer, evidence expiry/revocation, resource suspension and downstream invalidation of availability/reservations.
6. **Driver assignment creation/changes require full authorization review.** Test partner dispatch permission, driver active membership and profile status, one driver per active leg policy, reassignment/revocation, driver unavailability, partner suspension and changes after assignment. Driver acceptance is not a substitute for partner dispatch authorization.
7. **Fleet assignment UI is not proof of a complete fleet control plane.** Legacy fleet/capacity routes redirect to the Partner workspace; no independent runtime validation of a complete vehicle registry, driver roster, equipment compatibility or schedule conflict handling was performed.
8. **Partner opportunity expiry and quote status synchronization need tests.** The expiry worker locks offered assignments with `SKIP LOCKED`, expires overdue responses and handles customer quote expiry; no worker schedule, retry, stuck-row alert, audit completeness or failure recovery was tested here.
9. **Operations coordination page is not an assignment engine.** Dated Page 75 review describes it as a preparation worksheet, not a verified capability/capacity/quote/driver assignment workflow.
10. **Customer and partner visibility need tenant-negative tests.** No two-partner/two-customer tests were run for confidential shipment fields, partner buy rates, competitor bids, assignment data, driver PII or capacity details.
11. **Global modes and non-road resource workflows are incomplete.** Existing automated reservation logic is limited to vehicle/weight resource types. Ocean vessel/container, rail wagon, air cargo allotment, warehouse slots, customs service and handling capacity require separate mode-specific reservation semantics; do not infer support from generic resource labels.
12. **No actual driver custody handover proof.** Assignment acceptance and trip-event recording are distinct from verified pickup handover, geofence/time proof, chain-of-custody evidence, exception escalation and partner control-tower acknowledgement.

## Required isolated Staging acceptance tests

- Create partner organizations with active, suspended, expired and revoked identity/compliance/capability states; ensure matching, marketplace read, quote submit, award and accept all fail closed when ineligible.
- Test stale persisted compliance label with expired/revoked underlying evidence; candidate generation must not surface a commercially eligible partner.
- Distinguish potential capability match, eligible quote candidate, partner-accepted assignment, capacity-held/confirmed and dispatched states in API and UI.
- Test inactive country, market, corridor dossier, location, mode and partner service-area; all must block quote/award/dispatch even if catalogue rows remain active.
- Register resource with valid/invalid/wrong-owner evidence; verify pending-review status, independent AAL2 reviewer, approval/rejection, expiry/revocation and downstream disablement.
- Test vehicle and weight capacity with kg, tonne, metric ton, vehicle count, unsupported units, mixed units, capacity exhaustion and time-window boundaries.
- Concurrently reserve the last unit for two shipments; only one may succeed. Test same idempotency key, key collision across legs, network timeout after commit and exact replay.
- Test reservation release/rebook on quote expiry, assignment cancellation, shipment cancellation, partner suspension, schedule change and partial leg completion.
- Test wrong partner, wrong shipment, wrong leg, wrong route-plan item, wrong customer, revoked membership, missing `shipment.update`/ `shipment.dispatch` and direct DML/legacy RPC attempts.
- Test driver invitation/provisioning, licence front/back and identity evidence, expiry, driver membership, partner assignment linkage, wrong driver, wrong vehicle, driver reassignment, acceptance replay and revoked assignment.
- Test driver pickup/in-transit/exception events; ensure delivery cannot be self-declared and requires verified POD. Verify custody handover and control-tower audit trail.
- Capture browser traces, RPC inputs/outputs, before/after database state, reservations and bindings, audit events, queue/worker traces and repeatable negative tests.

## Status

| Capability | Status | Basis |
|---|---|---|
| Partner opportunity/marketplace eligibility | PARTIAL PASS | Source gates exist; current-compliance matcher gap remains |
| Partner quote submission | PARTIAL PASS | Scoped exact-leg RPC; no runtime tests |
| Partner award and acceptance | PARTIAL PASS | Exact-leg binding and current eligibility in selected RPCs |
| Resource registration/review | PARTIAL PASS | Independent review and evidence ownership source controls |
| Automated capacity reservation | PARTIAL PASS | Guarded RPC and reservation ledger; no concurrency/recovery tests |
| Driver assignment and acceptance | PARTIAL PASS | Partner/leg binding and driver evidence gates |
| Driver custody handover and dispatch | BLOCKED | Complete workflow and runtime evidence absent |
| Global route/mode operational readiness | BLOCKED | Market/corridor approval chain not proven |
| Real partner supply and service availability | BLOCKED | No current verified operational inventory evidence |
| End-to-end partner-to-driver execution | NOT TESTED | No Staging journey executed |

## Safety boundary

No Production or Staging RPC/SQL, partner quote, opportunity, assignment, resource registration, evidence upload, capacity reservation, driver assignment, dispatch, notification, provider call or deployment was performed. No secrets or personal customer/driver records were read. No synthetic users were created. Dated 16 Nov production audit counts are historical evidence only.

## Exit criteria

Do not enable automated availability claims or live partner dispatch until current compliance is checked during candidate generation; country/market/corridor approval is enforced; verified capacity is reserved atomically; release and concurrency paths pass; all legacy/direct write paths are closed; driver/vehicle and custody gates are verified; and a full exact-leg partner-to-driver journey passes isolated Staging.
