# KRIM Quote Acceptance, Partner Award, Assignment Acceptance and Capacity Reservation — End-to-End Integrity Audit — 2026-11-16

## Executive decision

**NO-GO for live commercial quote acceptance, partner assignment and dispatch.**

This audit followed the production SQL state machine from partner quote award through customer quote preparation/acceptance, partner assignment response, assignment finalization and physical capacity reservation. It reviewed current function bodies, effective EXECUTE grants, relevant triggers/indexes, live records and the latest quote/assignment/capacity migrations.

This was a read-only audit. No quote, assignment, reservation, payment, shipment, partner, customer or capacity record was created or modified. No production RPC was invoked. No schema, function, grant, trigger, policy or migration was changed.

## Live production snapshot

| Record type | Current count |
|---|---:|
| Customer quotes | 7 |
| Partner quotes | 0 |
| Quote acceptance records | 0 |
| Quote event records | 0 |
| Partner assignments | 0 |
| Assignment activations | 0 |
| Shipment capacity commitments | 0 |
| Verified capacity resources | 0 |
| Capacity availability rows | 0 |
| Capacity reservations | 0 |
| Capacity leg bindings | 0 |

The seven customer quote rows include six accepted and one sent (previously observed); there are no partner quotes or assignments. Historical quote rows are not proof that the present customer-to-partner acceptance journey works. No current transaction exists with which to validate the complete sequence.

## Intended state machine observed

### Shipment-wide / single-leg route

1. Partner submits a quote against an open opportunity.
2. Customer selects a partner quote through the checkout preparation path.
3. The platform creates a customer quote and an offered partner assignment; the shipment remains quoted.
4. Partner accepts or rejects the offered assignment.
5. Partner acceptance creates a shipment-capacity commitment through an assignment trigger.
6. Customer accepts the linked customer quote through `krim_accept_global_quote`.
7. The shipment becomes confirmed and assignment finalization activates the assignment.
8. Partner separately reserves a verified physical capacity resource for the exact leg and schedule.
9. Dispatch authorization is a later independent gate and requires a confirmed capacity binding/reservation and other operational evidence.

### Multi-leg route

1. Partner submits an exact-leg quote.
2. Customer awards that leg quote; the system creates an offered assignment for that exact plan-linked leg.
3. Partner accepts the assignment.
4. Each accepted leg receives a shipment-capacity commitment.
5. Assignment finalization marks that leg active but leaves the shipment confirmed until every plan leg has an active/completed assignment and a committed capacity commitment.
6. Each partner must separately reserve physical capacity against a verified resource and exact active network lane.
7. Shipment-level assigned status is reached only when all plan legs satisfy the finalizer's active assignment and commitment check.

The distinction between a shipment-weight commitment and a time/equipment-specific physical reservation is essential. They are different records and different controls.

## Positive controls confirmed

- Customer quote acceptance locks the quote and shipment, checks active customer organization access and `shipment.update`, rejects expired/unavailable quote states, and requires a linked accepted partner quote and matching accepted assignment before confirming the shipment.
- The shipment-wide checkout preparation function locks the partner quote/opportunity/shipment, constrains quote validity to partner quote expiry, blocks active multi-leg plans, prevents a second active customer quote for the shipment and creates a pricing snapshot/version and quote event in one transaction.
- Exact-leg award validates customer access and `quote.update` + `shipment.update`, opportunity deadline/state, quote validity, current partner compliance, exact plan-linked leg and route-plan item, and rejects non-empty special cargo requirements.
- A unique partial index prevents more than one offered/accepted/active/completed assignment for a given shipment leg. Another unique index binds a partner quote to at most one assignment.
- Partner assignment response requires active partner organization membership and `shipment.update`, locks the assignment, checks the response deadline, linked quote and exact leg/opportunity bindings, and rechecks current compliance before first acceptance.
- Assignment acceptance trigger creates or validates a matching committed shipment-weight commitment. Finalization requires the matching commitment and prevents shipment-level assigned state until all multi-leg plan items are assigned.
- Physical capacity reservation requires an accepted/active assignment, active partner membership, current compliance, exact shipment leg, current capability, a verified resource and availability row, an active exact origin/destination/mode network lane, matching units and a valid planned departure/arrival window.
- Capacity reservation locks resource and availability rows with `FOR UPDATE ... SKIP LOCKED`, subtracts overlapping active holds/confirmed reservations at both availability and resource level, writes reservation and binding, updates leg schedule and assignment binding, and emits reservation/binding/audit events in one transaction.
- Global idempotency-key uniqueness is enforced by a unique partial index. Assignment rejection releases linked capacity through a terminal-state trigger.

## Findings

### P0 — Multi-leg customer quote preparation/acceptance has no complete discovered path

The only authenticated customer-facing quote preparation function found, `krim_customer_prepare_partner_quote`, delegates to `krim_award_partner_quote_for_checkout`. That checkout function explicitly rejects shipments with an active multi-leg plan.

The multi-leg award function, `krim_award_leg_partner_quote`, marks the selected partner quote accepted and creates an offered partner assignment. It does **not** create a customer `krim_quotes` row, quote version, customer terms snapshot or customer quote acceptance record.

The partner assignment response function deliberately defers finalization when the shipment is still `quoted`, returning `next_step='customer_quote_acceptance'`. However, the discovered customer quote preparation path is blocked for active multi-leg shipments, while `krim_accept_global_quote` accepts only an existing customer quote row.

**Impact:** for an ordinary quoted multi-leg shipment, the inspected database functions do not provide the full customer-price-preparation → customer-acceptance path required to complete the intended sequence. A partner can be selected/offered, but the journey has no discovered supported customer quote artifact to accept. This is a functional release blocker, not evidence of a data leak.

**Required remediation:** design a first-class multi-leg customer quote aggregate or leg quote acceptance model. It must snapshot all selected partner legs, per-leg price/currency/tax/terms/validity, validate that every required leg is covered, and accept the complete customer offer atomically before shipment confirmation. Do not reuse the shipment-wide checkout RPC by bypassing its multi-leg guard.

### P1 — Customer acceptance does not recheck current compliance evidence

`krim_accept_global_quote` checks partner organization status, verification/lifecycle labels, persisted compliance status, verified active capability and shipment coverage. It does not call `private.krim_partner_compliance_is_current`.

Partner acceptance checks current compliance at the time the partner first accepts. But evidence can expire or be revoked between partner acceptance and customer acceptance. The customer acceptance function could then confirm the quote using a stale stored compliance label.

**Required remediation:** re-evaluate current compliance evidence, capability validity and any required approved coverage/corridor controls inside the customer acceptance transaction, immediately before state transition. Add tests for expiry/revocation between award, partner acceptance and customer acceptance.

### P1 — Shipment-wide award path also relies on persisted compliance status

`krim_award_partner_quote_for_checkout` calls `krim_award_partner_quote`. The underlying shipment-wide award function checks organization status and stored compliance labels plus active verified capability, but does not call the authoritative current-compliance helper in the inspected definition.

The exact-leg award function does call the current-compliance helper. This leaves different assurance levels between the shipment-wide and exact-leg award routes.

**Required remediation:** make current compliance validation consistent across every award/checkout path, or retire the weaker shipment-wide path after confirming no remaining callers and reconciling migration history.

### P1 — “Assignment accepted/active” and “physical capacity reserved” are separate states

The assignment acceptance trigger creates a row in `krim_partner_shipment_capacity_commitments` using shipment weight and the partner quote validity. The assignment finalizer requires this commitment and can mark the assignment active (and shipment assigned after all multi-leg commitments exist).

The actual physical reservation is a separate call to `krim_partner_reserve_shipment_leg_capacity`. That RPC must find a verified vehicle/weight availability row on an active exact route lane and creates `krim_capacity_reservations` plus `krim_capacity_leg_bindings`.

Therefore, the assignment finalizer's commitment is not proof that a physical vehicle or other resource has been reserved. Dispatch separately checks the physical binding, which is the correct final safety barrier, but the intermediate UI/status language must not imply a vehicle or time slot is already booked.

**Required remediation:** expose explicit states such as `partner_committed`, `physical_capacity_pending`, `capacity_confirmed`, `dispatch_authorized`. Do not label the abstract shipment-weight commitment as confirmed vehicle capacity. Require reservation completion before an operational handoff or dispatch-ready label.

### P1 — Capacity reservation idempotent reuse does not compare the requested schedule

At the start of `krim_partner_reserve_shipment_leg_capacity`, if an assignment already has a held/confirmed binding and linked active reservation, the function returns that existing reservation immediately. It does not compare the new `p_planned_departure` / `p_planned_arrival` inputs with the schedule stored in the existing reservation metadata.

The later idempotency-key lookup checks that the reservation belongs to the same shipment and leg and remains active, but does not compare the original schedule payload either.

**Impact:** a retry using a different planned time for the same assignment can return the old reservation as an idempotent success, while the persisted reservation/leg schedule remains unchanged. A client may believe the newly requested time was reserved when it was not.

**Required remediation:** persist a canonical request fingerprint containing assignment, shipment, leg, resource/availability, capacity quantity/unit and planned time interval. Reuse only when the incoming payload matches exactly; otherwise return a conflict requiring an explicit release/reschedule workflow. Add tests for same-key/same-payload retry, same-key/different-window conflict, different-key/same-assignment/different-window conflict, and schedule changes after reservation.

### P1 — Assignment finalization can precede physical capacity reservation

The finalizer requires a committed shipment-weight commitment but does not require a confirmed `krim_capacity_leg_bindings` row or a confirmed `krim_capacity_reservations` row. This is consistent with the current split workflow but means the shipment may reach `assigned` before physical capacity has been reserved.

Dispatch authorization reportedly requires the physical binding, so this should not permit dispatch by itself. The risk is premature operational status and dashboards/notifications that equate assigned with resource-booked.

**Required remediation:** either require confirmed physical capacity before marking a leg/shipment `active/assigned`, or introduce a distinct assigned-but-capacity-pending state and ensure every dashboard, customer notification and downstream workflow respects it. Preserve dispatch's independent reservation check.

### P1 — Assignment response and customer acceptance are multi-step, but no end-to-end recovery tests exist

The code handles some retry cases: repeated partner acceptance can return an existing accepted/active assignment; accepted quote retries can locate the matching assignment; unique indexes prevent duplicate assignments per quote/leg and multiple active assignments per leg. These are useful controls.

However, no authenticated staging test has exercised:
- simultaneous awards of two quotes for one leg;
- partner acceptance racing customer quote acceptance;
- customer acceptance racing quote expiry/revocation;
- assignment acceptance and its capacity-commitment trigger under retry;
- physical reservation retries after an ambiguous client timeout;
- partner rejection after award and reopening of competing quotes;
- capacity release on assignment rejection/cancellation/expiry;
- multi-leg partial acceptance and final leg completion.

The source code alone does not prove those concurrency paths are correct.

### P2 — Shipment-wide quote and exact-leg quote have different evidence snapshots

Shipment-wide checkout creates a customer quote, version, customer terms and pricing snapshot. Exact-leg award creates an assignment and audit event but no corresponding per-leg customer quote version/snapshot. A multi-leg aggregate needs immutable versioned snapshots so that customer acceptance is bound to the exact collection of partner prices, route-plan version, partner identities, terms and expiry values shown to the customer.

### P2 — Quote and assignment lifecycle evidence is incomplete in production

Production currently has seven customer quote rows, zero quote acceptance rows/events, zero partner quotes, zero assignments and zero capacity records. No end-to-end commercial execution evidence exists. Historical quote status alone does not establish that the current RPC sequence created all required artifacts or that a partner accepted a real job.

## Required remediation order

1. Resolve migration history and sanitized production schema reconciliation. Do not hot-patch production functions.
2. Design and implement a multi-leg customer quote aggregate/acceptance journey with immutable versioned per-leg pricing and terms.
3. Add current compliance/coverage/corridor rechecks to customer acceptance and shipment-wide checkout award.
4. Resolve capacity state semantics: abstract shipment commitment vs physical resource reservation vs dispatch authorization.
5. Add canonical reservation request fingerprints and strict idempotency conflict behavior for changed schedules/payloads.
6. Make assignment/shipment states accurately reflect physical capacity pending/confirmed.
7. Run isolated staging tests with synthetic organizations, shipments, quotes, legs, capacity resources and two concurrent sessions. Never use production customer/partner records for these tests.
8. Verify UI copy, notification events and operational dashboards do not claim accepted/assigned/booked/available/dispatch-ready prematurely.
9. Only after a fully verified staging journey, consider a limited real-world pilot with independently verified partners and routes.

## Security and exposure notes

- `krim_accept_global_quote`, `krim_award_leg_partner_quote`, `krim_award_partner_quote_for_checkout`, `krim_respond_to_partner_assignment` and `krim_partner_reserve_shipment_leg_capacity` are executable by authenticated users and contain server-side organization/permission checks.
- `krim_award_partner_quote` and `krim_internal_finalize_partner_assignment` are not executable by authenticated users; they are internal dependencies of privileged functions.
- `krim_customer_accept_quote` is not executable by authenticated users in the current ACL snapshot; it should not be mistaken for the active public acceptance route.
- No anon execution was observed for the inspected customer/partner award, response and reservation RPCs.

## Verification and limits

- Read-only live catalog, function source, trigger definitions, index definitions, effective EXECUTE grants and production row counts inspected.
- No production RPC was invoked; no live state was changed.
- No authenticated browser test, staging integration test, concurrent-session test or dispatch test was performed.
- The prior partner-matching audit commit `0d4a21dab37420f15c9afc91b2af0b1b08143114` passed production smoke, static link audit and Pages deployment. Those checks do not certify quote/assignment business logic.
- Migration reconciliation remains a critical blocker. Do not apply/replay/baseline/squash migrations or alter production DDL/functions until the sanitized schema manifest and complete migration crosswalk are reconciled.

## Release gate

**NO-GO for live quote acceptance, partner assignment, capacity/availability promises, dispatch and financial collection.** The multi-leg customer acceptance gap, stale compliance recheck gaps, reservation idempotency payload mismatch and absence of staging E2E/concurrency evidence must be resolved first.
