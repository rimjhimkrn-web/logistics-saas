# KRIM Multi-Leg Shipment Execution — Release Specification

Status: Existing schema and workflow inventory reviewed; this document defines required release validation and unresolved gaps. No production schema changes made by this document.
Date: 2026-11-15

## Current production evidence

- `krim_shipment_leg_plans`: 0 rows.
- `krim_shipment_leg_plan_items`: no live plan data evidenced in this audit.
- `krim_shipment_leg_activations`: 0 rows.
- `krim_shipment_legs`: 1 row.
- POD records: 0.
- Driver delivery evidence: 0.
- Legacy POD document records: 0.
- Legacy delivery proof records: 0.

The schema contains plan, plan-item, activation, activation-event and plan-event tables. The public function inventory did not reveal a public plan/activation command RPC; it revealed leg assignment, initial-leg creation, capacity reservation and warehouse leg listing. Confirm the client-side workflow and any private/service functions before treating planning/activation as operational.

## Required lifecycle and invariants

### 1. Plan creation
- Customer/authorised operations user creates a versioned plan.
- Validate contiguous sequence numbers, origin/destination continuity, transport mode, service area, time windows, cargo constraints and country/jurisdiction transitions.
- Reject gaps, duplicate sequence numbers, impossible time windows and disconnected legs.
- Snapshot the user-approved plan and constraints; never silently mutate an activated plan.

### 2. Activation
- Activate a single immutable plan version under a shipment-level lock.
- Idempotency key + canonical request fingerprint required.
- Create exactly the expected number of shipment legs and link each to the correct plan item.
- If any leg creation fails, roll back the whole activation or persist an explicit failed activation that cannot be mistaken for a partially active plan.
- Verify created count equals expected count before marking activation complete.
- Supersede prior unexecuted plan version with explicit audit event; do not rewrite completed historical legs.

### 3. Partner sourcing and award
- Each leg is independently sourced only to partners with current registered-business verification, compliance, capability, service area and available capacity for the leg's exact dates/mode/cargo.
- Partner quote and assignment must bind to shipment + exact leg + partner organisation.
- Partner acceptance is explicit; customer acceptance alone does not imply partner acceptance.
- Rejection/expiry reopens only that leg's sourcing state; it must not corrupt other leg assignments.

### 4. Capacity and dispatch
- Capacity reservation references exact assignment and leg, planned departure/arrival, physical resource and availability window.
- Prevent overbooking across concurrent legs and across availability windows.
- Driver/vehicle verification and accepted driver assignment required before dispatch.
- Dispatch each leg only after its own accepted partner assignment, committed capacity and driver/vehicle readiness.
- Do not allow a generic shipment-level dispatch action to bypass leg-specific gates.

### 5. Handover
- At each transfer point, record inbound arrival, custody handover, receiving organisation/operator, timestamp, condition, quantity/seal/serial data where applicable and evidence.
- Outgoing leg cannot start until previous leg handover is accepted, except for a documented direct-through movement where no custody change occurs.
- Warehouse/customs hold must block onward dispatch where the route requires release.

### 6. Trip events and tracking
- Trip events must be tied to the exact driver assignment, partner assignment, shipment and leg.
- Enforce legal event order and idempotent retries.
- Public/customer tracking shows only authorised operational milestones; precise GPS remains disabled until separate consent and legal gates are approved.
- Never infer arrival/delivery from geofence or GPS alone.

### 7. POD and leg completion
- Driver POD submission requires an in-transit driver assignment linked to accepted partner assignment and exact shipment leg.
- Require private evidence object uploaded by assigned driver; verify object owner, path, MIME, size and existence.
- Independent reviewer must verify POD; driver cannot review own evidence.
- Verify only the exact leg and assignment. Shipment becomes delivered only when all required legs are completed or explicitly cancelled under approved rules.
- A delivered shipment retry must not manufacture a new delivery result; return the original verified POD/authorization only after checking exact POD and assignment linkage.
- Rejected POD must leave leg/shipment undelivered and open a controlled resubmission/exception path.

## Findings from current function review

### Driver submission
`krim_driver_submit_delivery_pod(uuid,text,text,text)`:
- Requires authenticated user, own driver assignment, active driver membership and in_transit status.
- Requires linked partner assignment in accepted/active state.
- Requires at least one driver evidence record with matching private storage object owned by driver.
- Calls internal POD submit function and includes driver evidence metadata.

### Internal submission
`krim_internal_submit_delivery_pod(bigint,text,text,text,jsonb)`:
- Requires shipment in_transit and assignment accepted/active with matching leg.
- Creates submitted delivery POD and tracking/execution/audit events.
- Returns idempotently if shipment already delivered or an active submitted/review/verified POD already exists for that assignment+leg.
- Uses no caller-supplied idempotency key or payload fingerprint. The active-POD replay path returns the existing record without checking whether the new receiver/signature/evidence payload matches. Treat this as an idempotency precision gap; do not rely on it for conflicting retries.
- Function is SECURITY DEFINER and EXECUTE is restricted to postgres/service_role; its current search_path is `public`. Review and harden its search_path to empty with schema-qualified references before further use.

### Internal verification and authorization
`krim_internal_verify_delivery_pod` and `krim_internal_authorize_delivery`:
- EXECUTE restricted to postgres/service_role.
- Verification transitions submitted/under_review POD to verified/rejected and writes events.
- Authorization verifies POD/assignment/shipment/leg linkage, completes the exact leg and partner assignment, and marks shipment delivered only when no other non-delivered/non-completed/non-cancelled legs remain.
- Both functions use SECURITY DEFINER; internal verifier currently has search_path `public`. Harden to empty after a compatibility test.
- The admin review wrapper requires AAL2, platform admin permission, a reason, prevents the submitting driver from reviewing, and verifies a private evidence object owned by the assigned driver before invoking verification and delivery authorization.

### Evidence counts
All four inspected evidence sources currently contain zero rows: driver delivery evidence, KRIM POD records, legacy shipment POD documents and legacy delivery proofs. No actual POD journey has been completed.

## Required fixes/tests before enabling multi-leg operations

1. Inspect actual plan/activation UI and private RPCs; document exact client call path.
2. Verify plan validation and activation atomicity, including expected-vs-created count.
3. Harden internal POD function search_path and replay fingerprint semantics.
4. Confirm POD verification rejects missing or mismatched evidence and enforces reviewer separation.
5. Confirm a rejected POD cannot complete the leg or shipment.
6. Test final-leg logic with two or more legs, including one cancelled leg and one rejected POD.
7. Test repeated POD submission with identical payload and conflicting payload.
8. Test simultaneous POD reviews and duplicate authorization.
9. Verify all tracking/audit/partner execution events exactly once.
10. Verify customer, assigned partner, driver, warehouse, customs and unrelated organisation read scopes.
11. Browser/mobile test with real authorised test accounts and private evidence.
12. Do not enable universal multi-leg execution until at least one real corridor completes the full test.

## Release decision

Multi-leg planning/execution is **not operationally validated**. The schema and parts of the lifecycle exist, but there are no active plans/activations, no verified operating participants, and no POD evidence. GPS stays legally gated off.

## Additional live database inspection (15 Nov 2026)

- Plan, plan-item, activation, activation-event and plan-event tables all have RLS enabled.
- Authenticated has SELECT only; authenticated INSERT and UPDATE are denied; anon SELECT is denied. No direct client-side table mutation path is available.
- Plan items enforce unique (plan_id, leg_sequence) and a constrained status set. Plans enforce unique (shipment_id, plan_version) and constrained status. Activations enforce unique activation number and one activation per plan.
- The live public/private function inventory contains no shipment-leg-plan create, validate, evaluate, or activation RPC. Existing functions are limited to initial-leg creation, leg assignment, capacity reservation, warehouse leg listing, validation/history triggers and market activation. Thus the plan/activation tables currently have no discovered application write API.
- This is a concrete missing operational path, not merely a lack of sample data. Do not create direct table grants or expose a generic SECURITY DEFINER writer as a shortcut. Implement narrow authenticated RPCs with shipment ownership/operations permission checks, full route continuity validation, immutable plan snapshots, atomic activation and expected-vs-created count checks.

The absence of an application write RPC and the absence of real partner/capacity data mean the multi-leg plan lifecycle is not release-ready even though the supporting schema exists.

## Implementation update — secure draft plan creation

A narrow production RPC has now been added:

- `public.krim_create_shipment_leg_plan(bigint,jsonb,text,jsonb)`
- Authenticated execution only; anon and PUBLIC execution revoked.
- Requires the authenticated user to hold `shipment.update` for the shipment's owning customer organisation.
- Locks the shipment and only accepts pre-execution shipment statuses.
- Validates 1–20 legs, active location IDs, active transport modes, non-identical endpoints, route continuity, shipment origin/destination alignment, valid time windows, and paired positive capacity/unit inputs.
- Stores a canonical planning snapshot and per-leg plan items.
- Adds request idempotency key + SHA-256 request fingerprint; identical retry returns the existing plan, conflicting retry is rejected.
- Creates an immutable event record for the draft plan.
- Does not activate legs, alter shipment execution status, select a partner, reserve capacity, or dispatch anything.

Live verification:
- RPC exists with empty search_path.
- anon EXECUTE=false; authenticated EXECUTE=true.
- A simulated unrelated authenticated user was denied with the expected shipment permission error.
- No test plan was inserted; production plan/item/activation counts remain zero.

Still required before real use:
- Test with a real authorised customer account and a controlled test shipment.
- Add an explicit plan-read RPC/UI binding if not already present.
- Implement separate plan evaluation and atomic activation, including compatibility with the automatic initial-leg trigger and existing one-leg shipments.
- Verify idempotency under concurrent requests.
- Do not mark multi-leg planning/execution production-ready yet.

## Implementation update — authorized plan evaluation gate

Added `public.krim_evaluate_shipment_leg_plan(bigint)` as a read-only activation gate.

It checks:
- The caller's `shipment.update` permission for the owning customer organisation.
- Shipment remains in a pre-execution status.
- Plan remains draft/ready and item count exactly matches the declared total (1–20).
- Leg sequence continuity, active origin/destination locations and active transport modes.
- Route continuity and exact shipment origin/destination alignment.
- Per-leg planned time-window validity and capacity/unit pairing.
- No other active route plan exists for the shipment.
- Existing legacy leg records are preserved: activation is blocked unless the only existing leg is an unassigned, planned sequence-1 leg that exactly matches the first plan item. It is never silently deleted or rewritten.

Security:
- Empty search path.
- `PUBLIC` and anon execution revoked.
- Authenticated execution granted; ownership permission checked inside the RPC.
- The RPC is read-only; it does not create, update, assign, reserve or dispatch legs.

Live checks:
- anon EXECUTE=false; authenticated EXECUTE=true; PUBLIC EXECUTE=false.
- Empty search_path verified.
- Fake user has no shipment.update permission for the test customer organisation.
- A transaction-scoped unauthorised plan-creation attempt was rolled back; plan/item/activation counts remain zero.
- No real plan exists yet, so a positive evaluation path cannot be demonstrated against genuine data.

Release limitation:
- Plan creation and read-only evaluation are now present, but atomic activation is still not implemented.
- Do not treat a plan as active or execution-ready until activation, partner/capacity handoff, and a real controlled end-to-end test are complete.
