# KRIM Dispatch Authorization and Single-Leg Execution Gate — P0 Audit
Date: 2026-11-16

## Executive finding

**P0 — the privileged single-leg dispatch execution path can transition a shipment to `dispatched` without requiring a confirmed physical capacity reservation or a current exact-leg dispatch authorization.** The newer `krim_authorize_leg_dispatch` function enforces those controls, but the legacy/internal dispatch finalizer does not call it and the shared operations readiness function only requires that authorization for active multi-leg plans. This creates inconsistent enforcement between single-leg and multi-leg dispatch.

No dispatch, assignment, shipment, reservation, authorization, tracking event or other business record was created or changed during this audit. All database inspection was read-only.

## Production evidence

### 1. Dedicated exact-leg authorization has strong controls

Production `public.krim_authorize_leg_dispatch(bigint,text)`:
- Requires authenticated user and active assignment on an exact shipment leg.
- Requires `shipment.dispatch` permission for the partner organization.
- Requires the exact leg to be assigned.
- Requires a confirmed capacity-leg binding for that shipment and leg.
- Requires the linked reservation to be confirmed, for the same shipment, leg and partner organization.
- For ROAD, requires an accepted driver assignment, verified driver, current licence evidence, active verified vehicle and required current vehicle documents.
- For legs after the first, requires accepted custody transfer from the immediately preceding leg.
- Writes a dispatch authorization and partner execution event only after the gates pass.
- Reused authorization idempotency keys are checked against assignment/leg and current authorization state.

Its execute ACL is limited to `authenticated` and `service_role` (plus postgres).

### 2. Operations readiness only enforces that authorization for multi-leg shipments

Production `public.krim_operations_dispatch_readiness()`:
- Scopes accepted/active assignments to partner `shipment.dispatch` permission (or service role).
- Checks shipment/leg/assignment lifecycle, partner verification/current compliance, completed warehouse dispatch handover, compatible verified ROAD driver/vehicle and required vehicle evidence.
- For active multi-leg plans, it additionally requires an exact active route-plan item, accepted driver assignment for the exact leg, and `private.krim_leg_dispatch_authorization_is_current(...)`, which represents current exact-leg authorization and physical capacity/custody proof.
- For a non-multi-leg shipment, it does **not** check for a confirmed capacity-leg binding, confirmed physical reservation, or current exact-leg dispatch authorization. It checks route capability instead.

Therefore a single-leg row can be labelled `ready_for_authorized_review` without the physical-capacity and authorization evidence that the multi-leg path requires.

### 3. Privileged internal dispatch finalizer bypasses the dedicated authorization function

Production `public.krim_internal_dispatch_assigned_shipment(bigint)`:
- Requires assigned shipment, accepted/active assignment linked to quote and leg, current abstract kg capacity commitment, accepted exact-leg driver assignment and verified driver/vehicle/licence/document evidence.
- Calls `krim_internal_evaluate_shipment_readiness` and requires status `ready`.
- Calls `krim_operations_dispatch_readiness()` and requires `ready_for_authorized_review`.
- It does **not** require or inspect `krim_capacity_leg_bindings`, `krim_capacity_reservations`, or a current dispatch authorization directly.
- On passing, it changes shipment status to `dispatched` and writes a `departed` tracking event and partner execution event.

Because the readiness function omits physical reservation/authorization for single-leg shipments, the internal finalizer inherits that gap.

The shipment readiness evaluator also checks compliance, documents, customs status and partner assignment, but it does not add physical reservation or dispatch authorization evidence. It records the readiness evaluation and returns `ready` when its own listed gates pass.

### 4. Separate legacy shipment dispatch RPC is not the primary authenticated path

Production `public.krim_dispatch_shipment(bigint,text,jsonb)` is `SECURITY DEFINER`, but its current execute ACL is limited to `service_role` and postgres. It checks an abstract capacity commitment, partner compliance and capability, then transitions the shipment and creates a legacy dispatch row/event. It does not enforce the newer exact-leg dispatch authorization or physical reservation. It should be treated as a privileged legacy path requiring retirement or equivalent hardening, not as proof of the authenticated partner workflow.

### 5. UI evidence

`app/operations/dispatch-control.html` is preparation/read-only UI. It calls the readiness RPC and explicitly says it does not authorize or execute dispatch. It displays compatible driver counts and blockers. Its text says backend dispatch authorization independently enforces the handover gate, but the readiness result does not prove physical reservation for single-leg shipments.

The legacy `public/shipments/dispatch.html` is a static demo form with hard-coded example values and a browser alert; it is not a valid production dispatch workflow. The old partner dispatch-execution page redirects to the authenticated partner workspace.

## Required remediation — not applied

1. Make one authoritative exact-leg dispatch gate mandatory for every shipment, including single-leg shipments. It must require current confirmed physical reservation and binding for the same shipment, leg, partner, mode, resource and planned window.
2. Require a current exact-leg dispatch authorization in every privileged dispatch finalizer, not only in multi-leg readiness logic. The authorization must be bound to the same assignment and leg and revalidated transactionally immediately before dispatch.
3. Make driver/vehicle checks mode-specific. ROAD must require a verified accepted driver and vehicle; rail/air/ocean/warehouse handoffs need their own verified resource and operational evidence rather than being forced through ROAD checks or treated as ready by default.
4. Make dispatch idempotency and retry semantics compare the canonical assignment, leg, reservation, binding, resource and schedule. Do not return an idempotent success for a different or stale execution context.
5. Retire or harden the service-role-only legacy `krim_dispatch_shipment` path so no privileged caller can bypass the canonical dispatch gate.
6. Keep the Operations UI read-only until backend enforcement is reconciled and staging tests pass.
7. Reconcile production migration history and source definitions before preparing any migration or production DDL.

## Required staging tests

- Single-leg accepted assignment with only abstract kg commitment: dispatch must fail.
- Single-leg assignment with a confirmed reservation but missing binding: fail.
- Wrong partner, shipment, leg, mode, resource or schedule binding: fail.
- Expired/released reservation or revoked authorization: fail.
- ROAD dispatch without accepted verified driver, current licence, verified active vehicle or required vehicle documents: fail.
- Non-road dispatch without mode-specific resource and execution proof: fail closed.
- Multi-leg dispatch without exact active plan item or accepted prior-leg custody: fail.
- Complete exact-leg evidence: authorization succeeds; dispatch succeeds once; exact retry is idempotent; conflicting retry is rejected.
- Concurrent dispatch attempts cannot create duplicate departure events or bypass reservation state.
- Service-role/edge callers cannot invoke an alternate legacy path that omits canonical gates.

## Release impact

**NO-GO for real dispatch execution.** The current system has useful independent controls, including exact-leg authorization and driver/vehicle evidence, but they are not consistently mandatory across all privileged dispatch paths. Do not onboard real shipments or mark a shipment dispatched until the canonical gate is enforced and staging evidence demonstrates both positive and negative cases.

## Evidence boundaries

Inspected live function definitions, execute ACLs, the operations readiness function, and relevant repository HTML. No production RPC that changes business state was invoked. No production DDL, grants, policies, records, assignments, capacity reservations, dispatch authorizations or tracking events were changed.
