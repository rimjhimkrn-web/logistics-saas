# KRIM Shipment Lifecycle, Route, Milestone, Tracking, Exception and POD Integrity Review
**Date:** 16 November 2026  
**Method:** Read-only inspection of live PostgreSQL function definitions and authorization patterns. No RPCs were executed and no shipment, route, tracking, exception or POD data was changed.

## Executive summary
The shipment execution model has several strong controls: shipment leg plans validate route continuity and time ordering; plan activation is customer-authorized, locked and idempotent; dispatch checks accepted assignments and committed capacity; GPS sharing is restricted to active consented driver sessions; delivery POD submission is restricted to the assigned driver and private evidence; platform POD review requires AAL2 and excludes the assigned driver; final delivery authorization follows POD verification.

The remaining issues are material:
1. **Milestone sequencing:** `krim_record_operational_milestone` validates assignment scope and supported event types but does not enforce predecessor/transition order. The same assignment can record `delivered`-adjacent events in nonsensical order (final `delivered` itself is explicitly blocked). Duplicate protection is only a 60-second same-event window, not a durable idempotency key.
2. **Tracking authorization flag:** `krim_get_shipment_tracking` correctly restricts the returned shipment to customer organization or active partner membership and restricts GPS to consented, verified, in-transit driver sessions. However, its returned `can_record` boolean is based on any active partner membership/assignment, not the stricter driver ownership or `shipment.update`/`shipment.dispatch` permission checks used by the milestone write function. UI must not use this flag as write authorization.
3. **Route activation is structurally validated, not operationally activated:** route-plan evaluation validates contiguous locations, active locations/modes, times, shipment endpoints, plan state and commercial conflicts, but does not itself validate approved country operating packs, corridor dossier/controls, applicable customs release or cargo compliance. Broader shipment readiness/dispatch gates must independently enforce those conditions.
4. **Exception resolution:** resolution requires `compliance.manage`, locks the exception, records a reason, and cancels timers/actions/escalation runs. This is a strong control, but the reviewed path does not require a separate independent resolver or explicit AAL2; risk-tiered approval requirements should be verified for critical safety/compliance exceptions.
5. **No full end-to-end staging proof:** static definitions do not prove race safety, trigger behavior, RLS, signed evidence delivery, external carrier/GPS reliability or real operating partner coverage.

## 1. Shipment leg planning and activation
`krim_create_shipment_leg_plan`, `krim_evaluate_shipment_leg_plan` and `krim_activate_shipment_leg_plan` form a controlled workflow.

Positive controls observed:
- Plan creation requires authenticated user and owning customer organization's `shipment.update` permission.
- Plan and leg item creation use an idempotency key and request fingerprint.
- Evaluation requires plan state draft/ready and shipment pre-execution state draft/quoted/confirmed.
- Enforces 1–20 legs, exact count, contiguous sequence, non-null endpoints/mode, distinct origin/destination, active locations/mode, connected legs, shipment origin/destination match, arrival after departure, no overlapping leg windows, and valid capacity/unit pairing.
- Blocks conflicting existing shipment legs and concurrent active plan.
- Multi-leg activation blocks unresolved shipment-wide partner opportunity/quote flows because leg-specific sourcing is not yet supported.
- Activation locks shipment and plan, requires customer update permission, uses idempotency, records activation events/snapshots, maps plan items to legs and rolls back on count/state mismatch.

Limitations:
- Evaluation is structural; no corridor dossier, corridor control, country operating pack, customs authority release, cargo-specific regulatory clearance or partner capability proof is performed inside this evaluator.
- Active location and active transport mode metadata are not proof of service availability.
- Route-plan activation creates planned legs; it does not reserve capacity, assign partners, authorize dispatch or establish a carrier contract.

Release rule: never interpret `ready=true` from route-plan evaluation as permission to dispatch. Require independent operational, partner, capacity, customs, compliance, warehouse and dispatch gates.

## 2. Dispatch boundary
The inspected `krim_dispatch_shipment` function:
- Locks the shipment and assigned leg.
- Requires shipment status assigned.
- Requires the current user to belong to the exact partner organization and hold `shipment.dispatch`.
- Requires accepted/active partner assignment and a current committed capacity commitment.
- Rechecks current partner compliance and uses dispatch authorization controls described in the earlier partner/dispatch audit.

This is a positive control, but the legacy shipment-wide dispatch path should not be assumed equivalent to the newer exact-leg dispatch authorization/warehouse-handover model. Maintain one canonical route to dispatch and test that every entry point delegates to or enforces the same current exact-leg authorization, confirmed capacity, picked inventory, warehouse handover, partner compliance/capability and corridor gates.

## 3. Operational milestone sequencing — P1
`krim_record_operational_milestone`:
- Requires authentication and locks the shipment and selected partner assignment.
- Resolves one active assignment only; rejects ambiguous multi-leg shipment selection.
- Requires active organization membership and either driver ownership or partner `shipment.update`/`shipment.dispatch` permission.
- Driver must have an active driver assignment linked to the shipment.
- Validates event type, note length and paired GPS coordinate ranges.
- Rejects normal milestones for terminal shipments and blocks direct `delivered` milestone, which must follow verified POD and delivery authorization.
- Inserts milestone and tracking event in the same transaction.

Gap:
- No predecessor state check is visible. For example, the routine can accept `departed_origin` without proving `pickup_completed`, or `delivery_arrived` without proving an active transit/arrival chain.
- Duplicate suppression searches same assignment/event type in the previous 60 seconds. This can suppress a legitimate repeated event or allow a replay after the window; it is not a request idempotency key.
- GPS is optional and no freshness/accuracy requirement is imposed on manually supplied coordinates.

Required remediation:
- Define a per-mode/per-leg finite-state transition table with permitted predecessor states and actor classes.
- Use durable idempotency key and request fingerprint for client retries.
- Separate operational events from exceptions and enforce leg-specific sequencing/custody.
- Treat manually supplied GPS as unverified metadata; only a validated consented tracking session should be represented as live GPS.
- Preserve late corrections as append-only correction events rather than overwriting chronology.

## 4. Tracking read and GPS privacy
`krim_get_shipment_tracking`:
- Requires authenticated user and valid shipment number.
- Allows the customer organization or active partner organization member with a live accepted/active/in-progress/assigned shipment assignment.
- Returns no GPS through generic event history.
- Returns current position only for active tracking session joined to exact driver assignment, exact shipment/leg/partner organization, active driver membership, active partner organization, verified driver profile, licence number, non-empty consent notice and SHA-256 notice hash, supported mobile platform, and active in-transit driver assignment.
- GPS status distinguishes starting, active (<2 minutes), delayed (<15 minutes), stale and terminal completed.
- Suppresses GPS for terminal shipments and future-dated points beyond one minute.

Positive control: the GPS response is tied to an exact consented and verified driver session rather than merely any GPS event.

Authorization/UI gap:
- The `can_record` output is true when any active partner member has an accepted/active/in-progress/assigned shipment assignment. It does not test the current member's driver assignment ownership or `shipment.update`/`shipment.dispatch` permission. The milestone write RPC is stricter.
- Consumers must call the authoritative write RPC and handle authorization failure; do not rely on `can_record` for enabling actions.
- Review whether shipment detail fields (goods description, weight and estimated/actual delivery) are appropriate for every active partner member and whether field-level disclosure should be narrowed.
- Verify consent withdrawal stops future GPS collection promptly, and that location retention/deletion policies, access logs and driver notice are enforceable.

## 5. Delivery POD submission and verification
Driver submission:
- Requires authenticated user, driver assignment owned by the current user, active driver organization membership and in-transit state.
- Requires exact linked partner shipment assignment in accepted/active state.
- Requires at least one private `krim-driver-evidence` object owned by assigned driver and linked to the exact driver assignment.
- Delegates to internal POD submission with evidence metadata.

Platform review:
- Requires AAL2 and `admin.platform`.
- Requires a meaningful decision reason and submitted/under-review POD.
- Prevents the assigned driver from reviewing their own POD.
- Requires an existing private delivery evidence object owned by the assigned driver.
- Verification invokes delivery authorization and updates driver assignment status; rejection creates an exception event.
- Audit event records actor, decision and reason.

Internal verification:
- Locks POD record and validates pending state.
- Requires verifier identity.
- Records verified/rejected status and execution/audit events.

Important staging verification:
- Confirm the internal verifier can only be reached through the AAL2 platform review wrapper and is not executable by authenticated/anon.
- Confirm evidence metadata, object owner, bucket policy, file integrity and evidence-to-shipment/leg association are revalidated at review time.
- Confirm verified POD is immutable except through explicit supersession/correction, and duplicate concurrent reviews are safe.
- Confirm delivery authorization requires the correct leg/assignment, all legs/custody complete, and no open holds/exceptions; do not infer this solely from POD status.
- Verify the platform review transaction rolls back POD verification if delivery authorization fails.

## 6. Operational exception lifecycle
`krim_resolve_operational_exception`:
- Requires authenticated user and meaningful resolution text.
- Locks the exception and requires `compliance.manage` in its owning organization.
- Rejects already closed exceptions.
- Sets resolved status and timestamp, resolves open/acknowledged escalations, cancels pending/triggered timers, cancels pending/in-progress actions, cancels queued/running/waiting escalation runs and writes an audit event.
- `krim_acknowledge_exception_escalation` similarly locks escalation and exception, checks `compliance.manage`, and prevents acknowledging closed exceptions.

Positive control: parent resolution stops outstanding automated timers, actions and escalation orchestration in the same transaction.

Risk-tiering gap: reviewed routines do not visibly require AAL2 or a second reviewer for every critical exception. Define separate policies for routine service exceptions versus safety, cargo loss, customs hold, fraud, security incident and high-value damage. High-impact cases should require elevated assurance, maker-checker and mandatory evidence; resolution must not itself remove an independent shipment hold without an authorized release decision.

## 7. Staging-only end-to-end test plan
Use synthetic tenants, shipments, drivers, partners, routes and private evidence:
1. Plan create/evaluate/activate, exact retry, conflicting retry, concurrent activation and plan mutation after activation.
2. Disconnected route, wrong origin/destination, inactive mode/location, time overlap and multi-leg quote conflict.
3. Corridor/market/customs/compliance gate missing or expired; prove route structural readiness cannot bypass operational readiness.
4. Every milestone predecessor/successor transition, duplicate retry with same key, same event after long delay, out-of-order event, multi-leg ambiguity and terminal shipment.
5. Customer, assigned partner, unrelated partner, inactive member, revoked member, driver not assigned to this leg, driver assigned to another leg, missing permissions and AAL1/AAL2.
6. Tracking session without consent, malformed consent hash, unverified/expired driver, wrong partner/leg, inactive session, stale/future GPS, terminal shipment and consent withdrawal.
7. POD missing evidence, wrong owner/path/bucket, wrong shipment/leg, self-review, AAL1, concurrent verify/reject, delivery authorization failure and resubmission.
8. Exception resolution with open timers/actions/escalations, concurrent resolver, wrong tenant, routine versus critical exception approval and hold release.
9. Full chain: accepted partner → current capacity → driver/vehicle evidence → warehouse picked allocation → handover proof → dispatch authorization → leg custody/milestones → customs/route gates → POD → independent verification → delivery authorization → terminal status.

## 8. Release decision
**NO-GO for unrestricted live shipment execution.**
- Route planning/activation has strong structural validation but is not proof of corridor or customs authorization.
- Dispatch and POD boundaries have meaningful controls, subject to full entry-point equivalence and staging tests.
- Milestone ordering and durable idempotency need remediation.
- Tracking `can_record` is advisory and broader than write authorization.
- Exception resolution needs risk-tiered independent approval for critical cases.
- No staging end-to-end execution evidence was supplied by this read-only review.

No production schema, code, policies, grants or business records were changed. Migration-history reconciliation and sanitized schema manifest remain prerequisites before production remediation. Financial collection remains deferred to the final phase.
