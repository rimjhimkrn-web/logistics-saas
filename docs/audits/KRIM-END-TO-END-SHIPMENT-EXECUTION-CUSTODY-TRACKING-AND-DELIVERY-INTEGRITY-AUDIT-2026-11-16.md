# KRIM End-to-End Shipment Execution, Custody, Tracking and Delivery Integrity Audit
**Date:** 16 November 2026  
**Scope:** Read-only production PostgreSQL inspection of driver assignments, exact-leg dispatch authorization, route-plan and custody guards, warehouse picked-stock handover, operational milestones, tracking, POD submission and UI source paths. No dispatch, driver assignment, GPS session, milestone, POD, custody transfer, warehouse movement or shipment state was created or changed.

## Executive decision
**NO-GO for real shipment execution, dispatch and delivery certification.** The design has meaningful layered controls: verified partner assignment, exact-leg capacity, current driver/vehicle evidence, warehouse pick/handover proof, route-plan matching, custody acceptance between legs, private POD evidence and separate delivery authorization. However, there is no live execution population, and this audit found a significant functional gate: the dispatch authorization trigger requires an active multi-leg route plan with more than one leg. That conflicts with the RPC's broader exact-leg interface and blocks single-leg dispatch authorization. Non-road dispatch is explicitly held. These are material limitations, not evidence of safe global execution.

## 1. Live production baseline
Read-only exact counts at the audit snapshot:

| Record | Rows |
|---|---:|
| Driver assignments | 0 |
| Driver tracking sessions | 0 |
| Shipment legs | 1 |
| Route plans | 0 |
| Route-plan items | 0 |
| Leg activations | 0 |
| Dispatch authorizations | 0 |
| Custody transfers | 0 |
| Warehouse shipment allocations | 0 |
| Shipment milestones | 2 |
| Tracking events | 1 |
| POD records | 0 |
| Shipment POD documents | 0 |
| Shipment dispatches (legacy) | 0 |
| Operational exceptions | 0 |
| Exception timers | 0 |

There is no current evidence of an actual driver trip, activated route plan, dispatched leg, custody handover or verified delivery. Prior live audits also found zero verified driver profiles, verified vehicles, vehicle-driver bindings, GPS sessions, warehouse facilities or inventory. A single leg row and two milestone rows are not an operating delivery network.

## 2. Partner dispatch authorization and critical route-plan gate
### Positive controls
- `krim_authorize_leg_dispatch` requires authenticated identity, an accepted/active exact-leg partner assignment, `shipment.dispatch` permission and a bounded idempotency key.
- It locks assignment, leg and shipment rows; requires the exact leg to be assigned and shipment non-terminal.
- It requires a confirmed exact-leg capacity binding and matching partner-owned confirmed capacity reservation.
- For ROAD, it requires an accepted driver assignment, verified driver profile, current licence, accepted front/back licence evidence, active verified vehicle, active driver–vehicle binding and all mandatory current vehicle documents.
- For later legs, it requires an accepted custody transfer from the immediately preceding leg to the receiving partner.
- A duplicate idempotency key cannot be reused for a different assignment/leg; revoked authorization keys cannot be silently replayed.
- A BEFORE trigger independently checks active route plan, exact plan item, leg sequence, origin/destination/mode, assigned partner and assignment; active registered-business partner, verification, current compliance and capability.
- A second BEFORE trigger requires completed exact-leg warehouse handover, picked inventory allocation(s) and current private dispatch proof.
- The current-authorization helper rechecks the active route plan, assignment, partner compliance/capability, capacity binding/reservation, warehouse handover and previous-leg custody.

### Finding EXEC-01 — P1: single-leg dispatch is blocked by trigger
The public dispatch RPC supports an exact shipment-leg assignment and does not itself restrict the route plan to multi-leg. However, the BEFORE INSERT trigger `private.krim_guard_leg_dispatch_authorization()` requires the leg to link to an active route plan whose `total_legs > 1`, and its exact plan-item match. The authorization-current helper also requires an active multi-leg plan. Therefore, a normal single-leg shipment cannot pass the database trigger even if all its assignment, capacity, driver, warehouse and evidence prerequisites are satisfied.

This is a functional contradiction between the dispatch API and its trigger guard. It is not safe to bypass or alter it during this audit. After migration reconciliation, decide whether single-leg shipments need their own route-plan item (including one-leg plans) or a separately specified safe authorization path. Test both single-leg and multi-leg journeys in staging.

### Finding EXEC-02 — P1: global mode coverage is not implemented
The trigger explicitly rejects non-ROAD modes with a hold message. This is a safe fail-closed restriction, but it means rail, air, ocean and other non-road legs cannot be dispatched through this workflow. Each mode needs its own verified resource, operator, custody, safety and dispatch controls before activation.

### Finding EXEC-03 — P1: dispatch readiness is not actual departure
The authorization RPC writes an authorization and execution event stating physical departure must be recorded separately. Do not present authorized as departed, in transit or delivered. A separate, verified departure/milestone workflow is required.

## 3. Driver assignment and vehicle readiness
### Positive controls
- `krim_driver_accept_assignment` is authenticated and scopes the assignment to `auth.uid()`; checks active driver membership.
- It requires a verified driver profile, licence number and future expiry, independently accepted front/back licence and identity documents.
- It requires a linked verified active vehicle and active vehicle-driver binding, current required vehicle documents and a valid recognized payload unit.
- It checks shipment weight against vehicle payload capacity.
- It verifies the parent partner assignment is accepted/active and matches shipment, exact leg and partner organization.
- It checks shipment and leg state and verifies current partner capability/compliance and service-area coverage before driver acceptance.
- Road dispatch later rechecks current driver/vehicle evidence rather than trusting acceptance alone.

### Findings
1. **P1 — No actual driver/vehicle population:** zero assignments, zero driver tracking sessions and prior audits found no verified driver profiles, vehicles or bindings. No driver journey has been proven with a real participant.
2. **P1 — Evidence expiry/revocation must be tested between acceptance and dispatch:** dispatch correctly rechecks core driver/vehicle evidence. Staging must verify expired licence, revoked vehicle, changed binding, suspended membership and changed partner compliance all block dispatch.
3. **P2 — Driver UI session assurance:** reviewed driver pages use `getSession()` for client-side page gating. This is not backend authorization; server RPCs must remain the authority and must verify identity, membership, assignment ownership and permission independently.

## 4. Warehouse outbound handover
### Positive controls
- Shipment allocation and picking routines lock the shipment allocation and inventory rows, require active authorized warehouse operator, active approved facility and released stock.
- Picking is limited to a reserved shipment allocation and uses an idempotency key.
- A trigger blocks legacy shipment-linked picking task completion.
- Dispatch-handover task must link to an exact shipment leg.
- Handover creation/completion serializes on the shipment row and locks existing allocations to prevent a new reservation racing with handover.
- It requires at least one picked allocation and rejects any remaining reserved/unpicked allocation for that exact leg/facility.
- Dispatch authorization has a second guard requiring the completed handover and current private dispatch proof.

### Findings
1. **P1 — No warehouse execution evidence:** zero facility/inventory/receipt/allocation/task/transfer/return records in the warehouse baseline. No actual outbound handover has been executed.
2. **P1 — Known reservation integrity risks remain:** the separate warehouse deep audit identified transfer dispatch not subtracting outstanding shipment reservations, a generic picking task alternate path that may consume reserved stock, and a SQL NULL validation issue in authorized return receipt. These require staging tests and migration-safe remediation before operational stock use.
3. **P1 — Exact manifest and custody:** staging must prove picked SKU/lot/quantity, shipment leg, facility, partner, vehicle/driver, seal/condition and handover evidence are bound to one immutable handover record.

## 5. Custody transfer between legs
- Dispatch authorization for a leg after the first requires an accepted custody transfer from the immediately preceding leg, with the receiving organization matching the partner on the next leg.
- The separate custody-transfer design checks adjacent legs, accepted receiving assignment, capacity, exact manifest and private evidence.
- The live custody-transfer count is zero. No cross-partner physical custody change has been tested.
- Required controls: releasing party and receiving party must be distinct authorized actors; exact shipment/leg/manifest; quantity and package/condition reconciliation; timestamp/location; seal or exception evidence; private proof; idempotent acceptance; rejected/missing/partial handover holds; prior leg cannot be treated as delivered merely because the next party accepts custody.
- Customs and authority release must remain separate from internal KRIM custody acceptance. Internal partner or broker acceptance is not government clearance.

## 6. Milestones, tracking and GPS
### Positive controls
- `krim_record_operational_milestone` authenticates the actor, locks the shipment, identifies a single eligible partner assignment available to the actor, checks driver assignment ownership or partner shipment permission, validates milestone type, note length and coordinate ranges.
- It refuses to record final `delivered` through this generic milestone path, reserving delivery for verified POD and delivery authorization.
- It writes a shipment milestone and tracking event with actor, partner assignment, leg, source type and time.
- If more than one active assignment/leg is available, it refuses ambiguous shipment-wide recording.
- GPS sessions are consent-gated and verified driver-session controls exist; GPS is currently deliberately disabled under earlier legal/consent safeguards.

### Findings
1. **P1 — Milestone predecessor sequencing:** the reviewed routine validates milestone vocabulary and actor assignment but does not enforce strict predecessor order. Earlier milestone audit found the same issue. A user could record a later permitted checkpoint before the required prior checkpoint unless another independent transition guard exists. Add a canonical per-leg state machine with concurrency-safe sequence/idempotency.
2. **P1 — 60-second duplicate suppression is not durable idempotency:** the routine treats a same-type event within 60 seconds as a duplicate, but this is time-window suppression, not a caller-provided durable idempotency key. A retry after the window may duplicate a milestone; two different legitimate events within the window may be suppressed.
3. **P1 — Manual coordinates are not verified GPS:** milestone coordinates can be supplied by the client and are range-checked, but manual source does not establish device GPS provenance. UI must label manual location accurately; never display it as verified live GPS.
4. **P1 — GPS not production-ready:** no active GPS sessions, and the service remains intentionally disabled pending consent/legal notice and staging assurance. Do not advertise live tracking coverage.
5. **P2 — Tracking history is not delivery proof:** tracking events are operational reports, not independent proof of custody, arrival or delivery.

## 7. Proof of delivery and final delivery
### Positive controls
- Driver POD page limits selectable trips to the driver's own `in_transit` assignments, requires recipient name and PDF/photo evidence, and enforces a 10 MB client-side file limit.
- It uploads to the private `krim-driver-evidence` bucket under a user/assignment-scoped random path, registers evidence metadata, then calls `krim_driver_submit_delivery_pod`.
- The UI explicitly says evidence upload is separate from delivery authorization and shipment closure; submission remains awaiting authorized verification.
- If upload succeeds but metadata insert fails, it attempts to remove the uploaded object. If metadata is saved but POD submission fails, it retains the evidence and tells the operator to reconcile rather than re-upload blindly.
- Prior POD audit found driver-owned private evidence, independent AAL2 review and verified POD required for customer-visible delivery.

### Findings
1. **P1 — Two-step upload/metadata/RPC is not atomic:** upload, metadata insert and POD submission are separate calls. The page handles partial failures transparently, but orphan/reconciliation workflows and retry idempotency must be tested.
2. **P1 — Client-side file validation is not a security boundary:** enforce MIME, size, object owner, path, assignment and file content checks server-side/storage policy.
3. **P1 — No POD records or delivery evidence:** zero live POD rows. No recipient, signature, image, independent review or delivery authorization has been tested.
4. **P1 — No delivery closure:** maintain separate states for POD submitted, POD verified, delivery authorized, shipment delivered and customer notified. Only verified and authorized evidence may close delivery.
5. **P2 — Recipient name alone is not recipient authority:** define how recipient identity/authority is evidenced, without collecting unnecessary sensitive identity data.

## 8. Required staging-only acceptance tests
1. Single-leg road shipment with all valid prerequisites; dispatch should succeed only after the corrected one-leg route-plan design is approved.
2. Multi-leg road shipment: exact route item, partner, assignment, capacity, warehouse handover and driver evidence.
3. Rail/air/ocean: remain blocked until mode-specific resource and control suites pass.
4. Wrong tenant, revoked membership, forged assignment ID and missing `shipment.dispatch` permission.
5. Expired driver licence, rejected evidence, vehicle suspension, invalid payload and missing vehicle document.
6. Reservation concurrency: handover versus new allocation; no new reservation after final handover.
7. Unpicked or reserved stock; dispatch handover must reject.
8. Previous-leg custody missing, wrong receiving partner, partial quantity or disputed condition; next-leg dispatch must reject.
9. Out-of-order milestone, duplicate retries, simultaneous same-type events and stale assignment.
10. Manual coordinate source versus verified GPS source; no false live-location label.
11. POD upload success + metadata failure; metadata success + POD RPC failure; retry and orphan reconciliation.
12. POD submitted but rejected, expired evidence, wrong uploader/tenant, independent reviewer conflict; shipment must remain undelivered.
13. Notification provider accepts but recipient delivery is unconfirmed; customer status must not claim received.
14. Full end-to-end staging journey from accepted quote through partner/driver/warehouse dispatch, transit, custody, POD verification and delivery closure.

None of these end-to-end staging tests was executed in this audit.

## 9. Remediation order
1. Resolve the single-leg dispatch trigger/API contradiction; preserve exact-leg route and handover guards.
2. Implement strict per-leg milestone predecessor state machine and durable idempotency.
3. Keep non-road dispatch blocked until each mode's control framework is verified.
4. Close warehouse reserved-stock alternate paths and NULL validation defect after migration reconciliation.
5. Complete custody transfer and POD evidence lifecycle tests.
6. Keep GPS disabled until consent/legal notice and source verification are complete.
7. Run synthetic staging E2E tests with tenant isolation, revocation, retries and partial failures.
8. No production DDL/function/policy change until migration-history reconciliation is complete. No live freight collection or refunds; finance remains final phase.

## 10. Change control and release decision
Read-only audit only. No RPC was invoked. No driver assignment, capacity reservation, warehouse movement, dispatch authorization, custody transfer, GPS session, milestone, POD or shipment transition was performed. No production schema or data changed.

The migration-history mismatch and sanitized schema-manifest gate remain unresolved. Do not replay migrations or deploy corrective production DDL before reconciliation.

**Release status: NO-GO for live shipment execution and delivery certification.** The layered controls are promising, but the single-leg dispatch gate is contradictory, all operational execution tables are effectively empty, milestones lack strict sequence/idempotency assurance, GPS is disabled and no full staging journey has passed.
