# KRIM Unified Operational State Machine — Production Lifecycle Audit and Target Contract — 2026-11-16

## 1. Scope and release decision
Read-only review of live production shipment lifecycle tables, transition rules, quote/assignment/capacity/dispatch/POD functions and current records.

**Release decision: NO-GO for end-to-end commercial operations and physical dispatch.** This is an audit/specification, not a production state-machine rewrite. Production migration history still materially diverges from repository SQL history; no production DDL, grants, migration replay or business RPC execution is permitted until the sanitized schema manifest is reconciled.

## 2. Live baseline
Current shipment rows: 18 total (8 draft, 3 quoted, 6 confirmed, 1 closed). One shipment leg is assigned. Previous operational audit established no partner assignments/capacity reservations/dispatches/verified PODs in the tested execution tables; this review's status grouping also shows no rows for partner assignments, capacity reservations, dispatch authorizations, custody transfers or POD records. This means the platform has workflow code but not a demonstrated live execution chain.

The database has two transition-rule structures:
- `krim_shipment_status_transitions`: 15 rows currently define the legacy shipment status graph.
- `krim_shipment_transition_rules`: zero rows.

The newer transition-rules table is empty. The active generic transition function reads the older status-transition table.

## 3. Existing transition graph and defects

Current allowed transitions:
- draft → quoted
- draft → cancelled
- quoted → confirmed
- quoted → cancelled
- confirmed → assigned
- confirmed → cancelled
- assigned → cancelled
- delivered → closed
- delivered → exception (reason required)
- dispatched → cancelled
- dispatched → exception (reason required)

Present but explicitly denied:
- assigned → dispatched
- dispatched → in_transit
- in_transit → delivered

The graph is incomplete and internally unsafe:
1. `dispatched → cancelled` is currently allowed, and cancellation does not require a reason. A shipment already physically dispatched must not be treated as an ordinary cancellation. It must enter a disruption/return/recovery process with custody, partner and customer notifications.
2. The ordinary graph denies `dispatched → in_transit` and `in_transit → delivered`, while a separate dispatch/POD workflow exists. These execution events must be authoritative; status updates should be derived from verified physical events rather than arbitrary generic transitions.
3. `assigned → dispatched` is denied in the generic graph, which is appropriate as a safety barrier; dispatch must occur only through leg-level authorization and physical departure evidence.
4. The new `krim_shipment_transition_rules` table has no rows, so it cannot currently serve as a complete canonical policy catalogue.
5. `krim_transition_shipment` locks the shipment, checks the legacy allowed transition row and permission, enforces reason only where configured, then writes status/history. It does not itself orchestrate resource release, assignment cancellation, capacity release, warehouse inventory, customs, custody, partner notifications or refund/claims workflows.
6. Permission check uses `krim_has_permission(auth.uid(), COALESCE(customer_organization_id,1), required_permission)`; the transition function is not a substitute for actor/organization ownership checks and domain-specific transition authorization.

## 4. Quote and partner acceptance path

### Stronger global quote path
`krim_accept_global_quote(p_quote_id)`:
- Locks quote and shipment.
- Requires customer organization access and shipment.update permission.
- Requires shipment status quoted and quote valid.
- Requires quote bound to accepted partner quote and accepted assignment for same shipment.
- Requires active/verified/compliant partner and current capability.
- Transitions shipment to confirmed and finalizes matching partner assignment.

This is a meaningful commercial binding, but the global quote path still needs the unified compliance/corridor gate before customer confirmation and before dispatch.

### Exact-leg partner quote award
`krim_award_leg_partner_quote(p_partner_quote_id)`:
- Locks quote/opportunity/shipment/leg/plan.
- Requires customer quote/shipment permissions.
- Requires open opportunity, eligible quote, registered business partner, active verified status, current partner compliance and exact-leg capability.
- Requires target leg to match active plan item and prevents multiple active/completed assignments.
- Creates an offered partner assignment and records audit event.

The function does not establish physical capacity; capacity reservation is a later step and must remain a separate gate.

### Legacy customer quote acceptance
`krim_customer_accept_quote(p_quote_id)` directly changes a sent customer quote to accepted after customer organization access and validity checks. It does not itself enforce a matching accepted partner quote/assignment. Its direct EXECUTE privilege is not granted to authenticated or anon in the inspected catalog, but its internal use and callers still require dependency review. Keep it out of public client journeys unless the caller proves provider-backed binding.

## 5. Physical execution chain already present

| Stage | Existing table/function | Required invariant |
|---|---|---|
| Partner offer/acceptance | `krim_shipment_partner_assignments`, partner response RPCs | One active partner per exact leg; provider verified and eligible |
| Capacity reservation | `krim_partner_reserve_shipment_leg_capacity`, `krim_capacity_reservations`, `krim_capacity_leg_bindings` | Confirmed, non-expired physical capacity bound to exact assignment/leg; concurrency-safe |
| Driver/vehicle | `krim_driver_assignments`, driver/vehicle evidence and acceptance RPCs | Verified driver, current licence, verified compatible vehicle and partner binding |
| Warehouse handover | warehouse tasks, allocations, QC evidence and reviewer records | Picked allocation, no conflicting reservation, independent review where required, private evidence |
| Dispatch authorization | `krim_authorize_leg_dispatch`, `krim_shipment_leg_dispatch_authorizations` | Re-evaluate partner, exact assignment, capacity, compliance, route and handover immediately before authorization |
| Physical departure | dispatch and tracking event pipeline | Authorization is not departure; require trusted event/actor/time/location proof |
| In-transit tracking | `krim_tracking_events`, event receipts/sequences and driver tracking | Authenticated source, idempotent event identity, sequence ordering, consent where driver tracking used |
| Inter-leg custody | `krim_create_leg_custody_transfer`, `krim_shipment_leg_custody_transfers` | Releasing partner handover plus receiving partner acceptance; exact adjacent legs, manifest and evidence |
| Delivery evidence | `krim_driver_submit_delivery_pod`, `krim_pod_records`, internal verification RPC | POD submission is not delivery verification; independent authorized reviewer validates evidence |
| Shipment closure | shipment status/history and closure workflow | Only after every leg is delivered/closed, verified POD exists and exceptions are resolved |
| Finance/revenue | referral fee, invoice, ledger and reconciliation tables | Only KRIM's separately earned fee is KRIM revenue; provider freight GMV is not KRIM revenue |

## 6. Unified lifecycle target

Do not force all nine workspaces into a single overloaded shipment.status column. Use a shipment aggregate plus separately controlled domain state machines, with shipment status derived from authoritative events.

### Commercial lifecycle
`enquiry_received → qualified → quote_requested → provider_quotes_received → provider_selected → customer_quote_issued → customer_accepted → commercial_commitment_confirmed`

Guardrails:
- Quote validity and version must be explicit.
- Customer acceptance must bind to exact provider quote/partner/leg scope and frozen terms.
- No accepted legacy quote may be represented as a provider-backed booking.
- A customer acceptance does not itself prove capacity, legal clearance or dispatch readiness.

### Planning and execution lifecycle
`route_draft → route_structurally_valid → corridor_compliance_pending → compliance_approved → partner_assigned → capacity_confirmed → warehouse_handover_complete (if applicable) → dispatch_authorized → physically_dispatched → in_transit → arrival_recorded → custody_pending (if next leg) → delivered_pending_verification → delivered_verified → closed`

Rules:
- Route structure validation is not legal clearance.
- Market activation, country packs, corridor dossier and all applicable controls must pass for each jurisdiction/direction/mode.
- Shipment cargo/commodity controls and customs requirements must pass.
- Every leg requires a verified partner, exact-leg capability, current compliance and confirmed physical capacity.
- Road dispatch requires eligible driver, vehicle, licence and required documents.
- Authorization is revocable and short-lived; re-evaluate all gates at departure.
- Physical dispatch must record actual departure, not merely authorization.
- Next leg cannot begin until previous-leg custody is accepted by receiving party.
- Delivery is not complete until POD is independently verified.
- Closure waits for all legs, open exceptions and customer/provider disputes to be resolved under policy.

### Exception and recovery lifecycle
`exception_detected → triaged → owner_assigned → mitigation_in_progress → customer_partner_notified → recovery_or_return_planned → recovered_or_returned → reviewed → resolved`

Post-dispatch cancellation is not a valid shortcut. The state machine must preserve actual custody and location and trigger partner/customer coordination, capacity/warehouse reconciliation, claims and any applicable refund process. A refund request is not proof of provider refund execution.

### KRIM referral revenue lifecycle
`referral_attributed → partner_agreement_active → qualifying_service_completed → evidence_reviewed → KRIM_fee_due → invoice_issued → fee_collected → reconciled`

Only an agreed KRIM referral/coordination fee supported by agreement, attribution, actual service evidence, invoice and receipt is KRIM revenue. Freight value, provider collections and provider payouts must never be booked as KRIM revenue under the initial non-custodial model.

## 7. Required canonical transition envelope
Every state-changing domain RPC should enforce, in one database transaction:
1. Authenticated actor and fresh permission/organization membership.
2. Actor role and allowed source/target state.
3. Exact object ownership and scope (shipment, leg, organization, quote, route-plan version).
4. Domain prerequisites derived server-side, never trusted from client JSON.
5. AAL2 + separation of duties for sensitive admin, compliance, finance and verification decisions.
6. Required reason, evidence and source references.
7. Idempotency key with payload fingerprint and deterministic replay response.
8. Row locking in a consistent lock order to avoid races/deadlocks.
9. Append-only event and audit record with actor, time, source, correlation ID and before/after snapshot.
10. Transactional outbox event; external notification/provider calls happen asynchronously and are retried safely.
11. No status mutation on failed prerequisites; record safe failed attempt where appropriate.
12. Explicit compensating action for partial multi-domain failures; do not silently reverse physical events.

## 8. P0 defects and required fixes (do not execute until migration reconciliation)

| Priority | Finding | Required correction |
|---|---|---|
| P0 | Generic transition permits dispatched → cancelled without reason | Disallow ordinary cancellation after dispatch; route to disruption/recovery/return workflow |
| P0 | New transition rules table empty; legacy table still drives generic transition | Reconcile intended canonical policy table, populate through reviewed migration and migrate callers atomically |
| P0 | Generic transition function is not an orchestrator | Restrict generic transitions to safe administrative/pre-execution states; require domain-specific RPC for execution events |
| P0 | Multiple quote acceptance paths have different guarantees | Retire/guard legacy customer acceptance; all customer acceptance must bind to accepted provider quote and assignment |
| P0 | Dispatch authorization not the same as physical dispatch | Separate authorized, departed, in-transit, arrived states with proof and source integrity |
| P0 | Shipment compliance evaluator can return clear with zero checks | Expected-control set required; missing controls block |
| P0 | Route and dispatch predicates omit corridor/market activation composition | Use one authoritative eligibility evaluator at quote/assignment/reservation/authorization/departure |
| P1 | No single aggregate consistency check across legs | Derive shipment-level status from all leg states and open exceptions |
| P1 | Event/notification delivery is not proven by event creation or HTTP 2xx | Transactional outbox, delivery receipts, retries and dead-letter/replay monitoring |
| P1 | Refund/finance event completion not equivalent to provider execution | Provider confirmation + bank/ledger reconciliation required |
| P1 | Warehouse transfer can consume stock reserved for a shipment (previous audit) | Enforce ATP = on-hand less active reservations under shared locks |
| P1 | Claims respondent may be misattributed in multi-leg shipments (previous audit) | Resolve respondent from exact affected leg/assignment, not latest shipment assignment |

## 9. Test matrix before any supervised pilot
All tests must run in isolated staging with synthetic tenants, shipments, partner organizations and evidence. Never use live customer/provider rows or execute financial/dispatch RPCs as test fixtures.

- Invalid transition and unauthorized organization.
- Customer accepts expired quote.
- Customer accepts quote without provider-backed accepted assignment.
- Duplicate quote acceptance / idempotency replay.
- Partner quote from unverified, suspended, test-mode or expired-capability partner.
- Concurrent attempts to award two partners to one leg.
- Capacity contention, expiry, overbooking attempt and duplicate reservation.
- Market suspension or source expiry after booking but before dispatch.
- Corridor dossier missing, draft, wrong direction, wrong mode, wrong cargo scope or stale control.
- Missing/unknown/expired shipment compliance check.
- Missing customs broker, expired licence, unaccepted document or no official release where mandatory.
- Driver licence expiry, unverified vehicle, wrong partner binding.
- Missing warehouse handover evidence or stock already reserved.
- Dispatch authorization replay, revocation, expiry and market suspension between authorization and actual departure.
- Tracking duplicate, out-of-order, forged source and late-arriving event.
- Custody transfer rejected, wrong adjacent leg, cargo manifest mismatch and receiving partner timeout.
- POD rejected, uploader self-approval, wrong leg/assignment and duplicate submission.
- Shipment closure with an incomplete leg, open exception or unverified POD.
- Dispatched shipment cancellation attempt must fail and direct operator into disruption workflow.
- Referral fee cannot be recognized without active agreement, attribution, completed qualifying service, invoice and receipt.
- Provider freight GMV must not enter KRIM revenue/settlement ledger.

## 10. Implementation sequence
1. Reconcile production schema/migration history and sanitized manifest.
2. Inventory all callers of status transition and quote acceptance RPCs; remove/guard ambiguous paths.
3. Design canonical domain transition catalogue and event envelope.
4. Correct compliance and corridor eligibility composition.
5. Separate authorization from physical departure and delivery verification.
6. Add aggregate leg-consistency evaluator and safe exception/recovery orchestration.
7. Harden finance/referral fee recognition against non-custodial business model.
8. Build staging tenant fixture and negative/concurrency/idempotency tests.
9. Verify every user workspace consumes the same server-side states and safe blocker codes.
10. Pilot one low-risk domestic corridor only after independent legal, partner and operational approval.

## 11. Verification boundary
Read-only production catalog, function-definition and status-table queries only. No production data mutation, RPC execution, grants, migrations, external calls, payment actions, dispatches or partner/customer notifications were performed. This report does not certify that any shipment, corridor, partner, quote or payment is operationally ready.
