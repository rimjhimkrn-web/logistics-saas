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

## Implementation update — atomic activation RPC

Added `public.krim_activate_shipment_leg_plan(bigint,text)`.

Activation behavior:
- Locks the shipment row and plan row to serialize competing activation attempts.
- Requires the caller to hold `shipment.update` for the owning customer organisation.
- Re-runs the read-only evaluation gate while locks are held.
- Uses a per-shipment idempotency key with a unique index; identical completed retries return the original activation result, while key reuse for another plan is rejected.
- Enforces one activation per plan.
- Materializes every plan item as a shipment leg in one database transaction.
- Reuses an existing initial leg only when it is the exact unassigned/planned first-leg match; it is linked to the plan item without deleting or rewriting route history.
- Creates remaining legs with planned/unassigned state and preserves plan-item linkage.
- Verifies the exact expected-versus-materialized leg count.
- Records activation start/completion and plan activation events with the leg-to-plan-item mapping.
- Any exception or count mismatch aborts the transaction, so partial leg materialization is rolled back.
- Does not select partners, reserve capacity, dispatch, collect freight, or advance shipment status.

Live verification:
- Function created successfully and has empty search_path.
- anon/PUBLIC EXECUTE=false; authenticated EXECUTE=true.
- Unique per-shipment activation idempotency index exists.
- A transaction-scoped synthetic plan fixture was used only to test unrelated-user denial for both evaluation and activation; transaction rolled back.
- Production counts after test: 0 plans, 0 plan items, 0 activations; existing shipment-leg count unchanged at 1.
- No successful activation was attempted because there is no genuine authorised draft plan and no authorised customer test account was used.

Remaining release gates:
- Verify the activation happy path with a controlled, authorised customer-owned test shipment and a genuine route plan.
- Verify identical retries and conflicting-key retries against a test plan.
- Confirm no trigger/child workflow duplicates initial legs on real shipment creation.
- Continue partner offer, capacity reservation, leg handover, warehouse/customs and POD integration testing.
- Multi-leg is not production-certified until those tests pass with real verified participants and evidence.

## Customer visibility update

The canonical customer shipment-details page now includes a read-only route-plan and transport-leg panel. It loads:
- The customer's visible plan versions for the already-authorised shipment.
- Plan-item route sequence and transport mode.
- Actual shipment-leg status and partner-assignment status when a plan item is materialized.
- Legacy unlinked shipment legs separately, without misrepresenting them as a versioned plan.

The page uses existing shipment ownership checks and table RLS. It explicitly warns that a planned leg is not proof of partner acceptance, capacity commitment or dispatch. It does not expose GPS or infer live carrier state.

## Implementation update — operational route-planning interface

The operations route-planning page now has a controlled draft → validate → activate interface:
- Shipment choices are loaded only from shipments visible through the signed-in user's existing RLS scope and pre-execution statuses.
- Active location and transport-mode reference data populate each leg editor.
- Supports 1–20 ordered legs, optional planned timestamps and paired capacity/unit inputs.
- Draft creation calls the authenticated, ownership-checked plan RPC with a stable idempotency key.
- Validation calls the read-only evaluation RPC.
- Activation requires a separate explicit confirmation and calls the atomic activation RPC.
- Network/permission failures are surfaced without claiming that a write succeeded.
- The page distinguishes plan activation from partner assignment, capacity commitment and dispatch.

No route plan was created from the operations page during this code change. Browser-level interaction with a real authorised customer/operations identity remains outstanding.

## Additional integrity fix — duplicate leg creation audit trigger

Live inspection found two AFTER INSERT triggers on `krim_shipment_legs` invoking the same `krim_log_shipment_leg_creation()` function. This generated two identical `shipment_leg_created` audit rows for one historical leg (IDs 5 and 6 for leg 1).

Corrected:
- Removed the redundant `trg_krim_shipment_leg_creation_audit` trigger.
- Retained one creation-audit trigger.
- Hardened the trigger function to an empty search_path and schema-qualified built-ins.
- Kept historical audit rows intact; no audit records were deleted or rewritten.

Live verification:
- Exactly one shipment-leg creation trigger remains.
- Trigger function remains SECURITY DEFINER with empty search_path.
- Direct anon/authenticated execution is denied.
- Historical duplicate rows remain visible as immutable history; future inserts should emit one event.

## Additional integrity fix — adjacent leg schedule continuity

The evaluation RPC now rejects a later leg whose planned departure is earlier than the previous leg's planned arrival (`overlapping_leg_time_window`). This repeats the creation-time check at activation time, so stale or changed plan items cannot bypass schedule continuity validation.

## Partner sourcing integration audit — leg scope is not yet supported

A deeper live function/schema review found a critical integration boundary:
- `krim_partner_opportunities` and `krim_partner_quotes` are shipment-scoped; neither table has a `shipment_leg_id`.
- `krim_award_partner_quote(bigint)` selects the first shipment leg and creates an assignment for that leg.
- `krim_respond_to_partner_assignment` can update the linked leg, but the current commercial award path does not select a separate partner quote per plan item.
- `krim_internal_finalize_partner_assignment` finalises the shipment-level status as `assigned` after one accepted assignment and capacity commitment. It is not a multi-leg orchestration engine.

This means the existing quote/award path must not be reused to source a multi-leg route: it could award a shipment-wide quote to only the first leg and incorrectly imply full-route coverage.

Fail-closed safeguards added:
- Plan evaluation blocks activation while a live shipment-wide partner opportunity, partner quote, or customer quote exists.
- Shipment-wide partner opportunity creation is blocked after a multi-leg plan becomes active.
- Shipment-wide partner quote submission is blocked for active multi-leg plans.
- Shipment-wide partner quote award is blocked for active multi-leg plans.
- Existing single-leg flows remain unchanged.

Live verification:
- All three guards are present in the live function definitions.
- Anonymous execution remains denied for the guarded public RPCs; the legacy award helper remains restricted to internal/service callers.
- No active partner opportunities, partner quotes or partner assignments exist at the time of this review.
- This is a deliberate safety block, not a completed leg-specific marketplace.

Required next implementation:
1. Add explicit `shipment_leg_id` scope to partner opportunities and partner quotes, with foreign keys and uniqueness/idempotency rules.
2. Add leg-specific opportunity creation and capability checks for exact leg mode, route countries/regions, cargo and time window.
3. Make quote submission, customer award and partner acceptance bind to the exact plan item and shipment leg.
4. Add per-leg capacity commitment and driver/vehicle readiness.
5. Keep shipment status separate from each leg's execution state; do not mark the whole shipment assigned or dispatched after only one leg is covered.
6. Test partner rejection/expiry/re-award on one leg without changing other legs.

## Historical shipment-leg anomaly — preserved for review

The only current shipment-leg row belongs to a closed legacy shipment. Its row has `status='assigned'`, `assignment_status='unassigned'`, and a non-null partner organisation, while no corresponding row exists in `krim_shipment_partner_assignments`. Its historical audit stream also contains two identical `shipment_leg_created` events from the duplicate trigger that has now been removed.

No historical shipment or audit record was modified. This closed-shipment inconsistency must be reconciled against original business records before any cleanup; it is excluded from new plan activation and is not treated as proof of a current active assignment.

A final bypass review also added a guard to `krim_award_partner_quote_for_checkout` before its existing-quote idempotent return. Thus a previously prepared shipment-wide customer quote cannot be replayed through that wrapper for a shipment with an active multi-leg plan.

Activation audit records now use the plan's actual pre-activation status (rather than assuming every plan was `draft`), preserving accurate history if a controlled `ready` state is introduced later.

## Inter-leg custody and warehouse handover audit

The current warehouse `dispatch_handover` task is an outbound warehouse workflow, not a complete inter-leg custody-transfer protocol:
- It requires a completed picking/packing task for the exact shipment and leg.
- Its creation path currently requires the warehouse organisation to equal the leg's assigned partner organisation.
- Completing the task only rechecks that same-leg picking is complete; it does not record an independent receiving organisation's acceptance of custody.
- The schema has no dedicated public table for leg-to-leg handover or custody transfer.
- `krim_partner_execution_events` currently has no `handover` event type.
- A handover task therefore must not be treated as proof that the next carrier accepted the cargo.

Required future custody workflow:
1. Require two adjacent legs of the same shipment and validate previous destination equals next origin.
2. Identify the releasing and receiving verified organisations and their authorised representatives.
3. Record location, timestamp, cargo quantity/unit, package/handling-unit identifiers, seal references, visible condition, discrepancies and private evidence ownership.
4. Require explicit receiver acceptance; rejection creates a controlled exception and prevents onward dispatch.
5. Enforce one idempotent custody transfer per leg boundary and immutable event history.
6. Block next-leg dispatch until custody acceptance and all applicable warehouse/customs releases are complete.
7. Keep shipment-level status distinct from each leg's status; a single leg's handover must not mark the whole shipment delivered or assigned.

Live data currently has zero warehouse tasks/facilities in this audit snapshot, so no real handover can be tested. The existing warehouse task is retained for its current outbound workflow; it is not being re-labelled as full custody transfer.

## Leg-specific partner capability and partial assignment finalisation

Additional database safeguards now prepare the execution layer for separate carriers on separate legs:

- Added internal-only `private.krim_partner_capability_covers_shipment_leg(organization_id, shipment_leg_id)`.
- The helper evaluates the exact leg's active transport mode, active origin/destination locations and countries, verified partner capability coverage for both endpoints, effective dates, region scope and shipment weight limit.
- Unknown/non-positive shipment weight fails closed; KRIM must not match a carrier against an unverified cargo weight.
- Capacity reservation now checks the exact assigned leg rather than the shipment's legacy single-mode/full-route fields.
- Partner acceptance on an active multi-leg plan checks capability against the exact leg; legacy single-leg assignments retain the existing whole-shipment check.
- The internal assignment finalizer now activates a multi-leg assignment individually and keeps the shipment in `confirmed` while other plan legs remain uncovered.
- The shipment can move to `assigned` only when every plan item has a matching leg, an active/completed assignment for the exact partner, and a committed capacity commitment.
- Each partial leg assignment emits a `shipment.partner_leg_assigned` audit event; whole-shipment assignment is recorded only after the all-legs gate passes.

Verification:
- All four function-definition safeguards are present in live Postgres.
- The exact-leg helper uses an empty search path and cannot be executed by anon or authenticated directly.
- The internal finalizer remains unavailable to anon/authenticated callers.
- The partner acceptance RPC remains authenticated-only.
- Health advisor currently reports no findings.

Important limitation:
The marketplace still lacks leg-scoped opportunity/quote creation and award. Current shipment-wide quote creation/submission/award remains deliberately blocked for active multi-leg plans. Therefore this is not yet a complete multi-leg carrier marketplace and no live leg assignments have been tested. The next work must add leg-scoped commercial sourcing and bind each award to the exact plan item, then verify driver/vehicle readiness and per-leg dispatch without prematurely advancing the shipment.


## Leg-scoped partner sourcing schema foundation (16 Nov 2026)

Added nullable `shipment_leg_id` foreign-key columns to partner opportunities and partner quotes, preserving existing single-leg records and legacy flows. Added partial indexes for exact-leg lookups.

Database trigger validation now enforces:
- A leg-scoped opportunity must reference a shipment leg belonging to the same shipment.
- That leg must be linked to an item in the shipment's active route plan.
- A partner quote must reference an opportunity for the same shipment.
- The quote's leg scope must exactly equal its opportunity's leg scope.
- A scoped quote cannot point to a non-plan-linked leg.

The validation trigger functions use an empty search path and are not directly executable by PUBLIC, anon or authenticated roles. Existing RLS and table grants remain unchanged. This is an additive data-model foundation only: it does not yet create leg-specific opportunities, accept partner quotes, award them, or create assignments. The legacy shipment-wide sourcing gates remain in place for active multi-leg plans.

Release gates still required:
1. Implement narrow authenticated RPCs to create leg-specific opportunities and submit partner quotes with organisation, capability, compliance, cargo, schedule and capacity validation.
2. Implement customer award and partner acceptance bound to the exact opportunity, quote, plan item and shipment leg.
3. Enforce assignment/quote scope consistency, one active assignment per leg, and independent rejection/expiry/re-award.
4. Run positive and negative tests with authorised partner and customer accounts before enabling the workflow.

No production opportunity, quote, assignment, or shipment data was created or modified by this schema migration.


## Leg-specific partner opportunity creation RPC (16 Nov 2026)

Added `public.krim_create_leg_partner_opportunity(bigint,bigint,timestamptz)` as the first write operation for multi-leg partner sourcing.

The authenticated RPC:
- Requires access to the shipment's customer organisation plus `quote.create` and `shipment.update`.
- Locks the shipment and exact shipment leg.
- Allows only pre-execution shipment states.
- Requires a plan-linked leg belonging to the shipment's active route plan.
- Rechecks leg sequence, origin, destination and transport mode against the linked plan item.
- Allows sourcing only for an unassigned planned leg.
- Enforces a response deadline 1 hour to 30 days ahead (default 72 hours).
- Returns an existing still-open opportunity for the same shipment+leg instead of creating a duplicate.
- Creates an auditable leg-scoped opportunity without changing shipment status or creating an assignment.

Security: SECURITY DEFINER with empty search_path; PUBLIC and anon EXECUTE revoked; authenticated EXECUTE granted with in-function organisation/permission checks.

This is not yet a complete sourcing path. Partner quote submission, exact-leg capability checks at quote time, customer award, partner acceptance, capacity reservation and UI integration remain release gates. No production opportunities were created during implementation.


## Leg-specific partner quote submission RPC (16 Nov 2026)

Added `public.krim_submit_leg_partner_quote(bigint,numeric,text,timestamptz,text)`.

The RPC requires an active member of exactly one eligible registered-business partner organisation, `quote.create`, current partner compliance, active currency, a live leg-scoped opportunity, and a plan-linked leg in the active route plan. It rechecks exact leg sequence, endpoints and transport mode, then uses the existing private exact-leg capability evaluator for transport mode, both route countries and shipment weight.

It rejects non-empty free-form leg requirements until a reviewed canonical requirement-to-capability evaluator exists. This is intentionally fail-closed: refrigerated, hazardous or other special cargo must not be priced by a partner whose corresponding capability cannot be proven from normalized requirements.

Quote amount, currency, notes and validity are validated; validity cannot exceed the opportunity deadline. Updates reuse only the same partner's active quote for the same opportunity and exact leg. Every submission writes an audit event.

Security: SECURITY DEFINER with empty search_path; PUBLIC and anon EXECUTE revoked; authenticated EXECUTE granted with in-function membership, organisation, permission and compliance checks.

This is not yet an end-to-end sourcing release. Customer award must bind the exact opportunity/quote/leg, partner acceptance must preserve that binding, and capacity reservation must be proven for that leg. No production quote rows were created during implementation.


## Leg-specific quote award and one-active-assignment-per-leg guard (16 Nov 2026)

Added `public.krim_award_leg_partner_quote(bigint)` and a partial unique index on `shipment_leg_id` for assignment states `offered`, `accepted`, `active` and `completed`.

The award RPC is customer-authorised (`quote.update` + `shipment.update`), locks the quote, opportunity, shipment, active route plan and exact leg, and verifies all shipment/opportunity/quote/leg identifiers agree. It revalidates the partner's registered-business eligibility, current compliance and exact-leg capability, rejects expired or ineligible quotes, and refuses special-requirement legs until their normalized evaluator exists.

On award it accepts only the selected quote, rejects competing quotes for that same opportunity+leg, marks that opportunity awarded, creates an `offered` assignment bound to the exact leg, and writes an audit event. It does not mark the leg assigned, reserve capacity, or dispatch. The unique partial index prevents two concurrent live/completed assignments from occupying one leg; historical rejected/cancelled/failed/expired offers remain possible.

This does not yet complete partner acceptance or capacity reservation. No live assignments or shipment rows were created by the migration.


## Exact unassigned-state and assignment-binding database guards (16 Nov 2026)

Added a private trigger guard across leg-scoped opportunities, active partner quotes and offered partner assignments. It requires both leg lifecycle fields to remain in an unassigned/planned state when sourcing is opened or priced, and requires the exact leg to still match an item in the active route plan. Offered assignments additionally must reference an accepted quote and awarded opportunity with identical shipment, leg and partner identifiers.

This database-level guard closes a permissive status-condition edge case in RPC validation and protects against direct table writes or future RPC regressions. The trigger function is SECURITY DEFINER with empty search_path and no execute grants to PUBLIC, anon or authenticated; it is invoked only by its table triggers.


## Exact-leg partner acceptance hardening (16 Nov 2026)

Hardened `public.krim_respond_to_partner_assignment(bigint,boolean,text)` for commercial leg-scoped assignments.

On acceptance, the function now verifies the assignment's quote matches the same shipment and partner. For active multi-leg plans it additionally requires the quote and awarded opportunity to bind the exact same shipment leg and partner, and verifies that leg still matches an item in the active route plan and remains unassigned. Leg-scoped single-leg awards receive the same quote/opportunity binding checks. Partner eligibility is rechecked at acceptance: active organisation, registered-business account mode, approved verification/lifecycle/compliance states, and current compliance evidence. Existing exact-leg capability and quote-expiry checks remain in place.

Legacy shipment-wide single-leg assignments are retained where no leg-scoped quote and no active multi-leg plan are involved. No production assignments were accepted or changed during this migration. A real acceptance/capacity/dispatch journey remains untested because there are no verified commercial partners, active capacity resources, vehicles or drivers.


## Exact-route capacity reservation guard (16 Nov 2026)

Updated `public.krim_partner_reserve_shipment_leg_capacity(bigint,timestamptz,timestamptz,text)` so an available resource is eligible only when its availability record references an active `krim_network_lanes` row whose origin, destination and transport mode exactly match the assigned shipment leg. The physical capacity resource's transport mode must also match the leg. This closes a route mismatch: previously, an availability row could match partner, mode, resource origin and time window without proving that its declared lane ended at the exact leg destination.

The reservation still requires verified availability and resource evidence, valid booking windows, overlapping-time capacity checks, a matching assignment and partner membership, current compliance, and exact-leg capability. The change is fail-closed: no matching active route lane means no reservation. The current environment has no network-lane rows or capacity reservations, so no real reservation was created or claimed tested.


## Dispatch safety update — shipment-wide multi-leg dispatch blocked

Live review found that the internal dispatch worker still advances the shipment-level status to `dispatched` after handling one assignment/leg. Its existing readiness evaluator and capacity trigger provide useful gates, but a shipment-global transition is not a safe multi-leg execution primitive: it can make the shipment appear dispatched while later legs have not started, and the evaluator's driver count is not itself proof of an accepted driver assignment for every leg.

A database-level fail-closed guard has therefore been added:
- `private.krim_block_shipment_wide_dispatch_for_multileg()` blocks any shipment status transition to `dispatched` while an active route plan has more than one leg.
- The guard runs as a BEFORE UPDATE trigger on `krim_shipments.status`, so it covers the legacy/internal dispatch RPC and other status writers.
- The private trigger function uses an empty search_path and EXECUTE is revoked from PUBLIC, anon, authenticated and service_role; the trigger invokes it as the owning database role.
- Single-leg shipment dispatch remains governed by the existing dispatch readiness and capacity controls.
- No shipment or plan data was changed; live plan count remains zero.

This is an intentional safety barrier, not completion of multi-leg dispatch. The next implementation must introduce a leg-scoped dispatch command and state, exact-leg driver/vehicle/capacity binding, custody handover acceptance between legs, and shipment-level aggregation only after the appropriate leg milestones. Do not enable multi-leg dispatch until those controls and real-participant end-to-end tests exist.
