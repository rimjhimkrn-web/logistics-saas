# KRIM Dispatch Authorization and Single-Leg Execution Gate P0 Audit — 2026-11-16

## Result

**Release gate: NO-GO for real dispatch / physical execution.** The database contains a strong exact-leg dispatch authorization path, but the legacy shipment-level dispatch path and driver event path are not consistently bound to it. In particular, single-leg execution does not require the exact-leg physical capacity reservation and road driver/vehicle evidence enforced by the newer authorization RPC.

This is a read-only production definition audit. No RPC that creates, changes, dispatches, reserves, assigns, or posts business records was invoked. No production data, schema, grants, or policies were changed.

## Evidence reviewed

### 1. Strong exact-leg authorization exists

Production definition `public.krim_authorize_leg_dispatch(bigint,text)`:

- Requires an authenticated caller, an accepted/active partner assignment bound to an exact shipment leg, and `shipment.dispatch` permission for that partner.
- Requires the exact leg to be assigned.
- Requires a confirmed `krim_capacity_leg_bindings` row for that shipment and leg.
- Requires a confirmed `krim_capacity_reservations` row bound to that exact shipment, leg, and partner organization.
- For ROAD legs, requires an accepted driver assignment, active driver membership, verified driver profile, current licence, accepted licence-front/back documents, active verified vehicle, active driver/vehicle binding, and required current vehicle documents.
- For later legs, requires accepted custody transfer from the immediately preceding leg.
- Writes a dispatch authorization and an execution event.

The helper `private.krim_leg_dispatch_authorization_is_current(...)` revalidates the active multi-leg plan/plan item, exact leg and assignment binding, partner status/compliance/capability, confirmed capacity binding/reservation, handover, and custody.

### 2. The legacy shipment-level dispatch path does not consume that authorization

Production definition `public.krim_dispatch_shipment(bigint,text,jsonb)`:

- Selects the first assigned shipment leg rather than accepting an exact leg identifier.
- Requires partner access/dispatch permission, an accepted assignment, an active shipment-weight capacity commitment, current partner compliance, and shipment-level capability coverage.
- Does **not** require or validate a confirmed physical capacity binding/reservation.
- Does **not** enforce the ROAD driver/vehicle/document checks in `krim_authorize_leg_dispatch`.
- Does **not** require a current exact-leg dispatch authorization.
- Calls the shipment transition to `dispatched` and creates/updates a legacy shipment dispatch record.

Its current function ACL is postgres/service_role only (no authenticated EXECUTE grant), so this is not evidence that ordinary authenticated users can call it directly. It remains a privileged execution path whose callers must be audited and whose readiness contract is weaker than the exact-leg authorization path.

### 3. Driver trip-event enforcement is multi-leg conditional

Production definition `public.krim_driver_record_trip_event(uuid,text,text)` checks `private.krim_leg_dispatch_authorization_is_current(...)` for pickup/transit only when an active multi-leg plan exists.

For single-leg shipments, pickup/transit instead rely on shipment status being `dispatched` or `in_transit`, linked active partner assignment, driver assignment acceptance, and a non-terminal leg. The exact-leg physical reservation and dispatch authorization helper are not checked in this single-leg branch.

This creates an inconsistent safety boundary: multi-leg driver events require current exact-leg authorization; single-leg driver events do not.

### 4. Scope and risk

- A shipment-weight capacity commitment is not proof that a physical vehicle/slot was reserved.
- The newer exact-leg authorization checks are useful positive controls but do not protect all dispatch paths.
- The legacy dispatch RPC is privileged-only, but any trusted backend/service-role caller can invoke it; service-role code bypasses RLS and must enforce the full business contract itself.
- Multi-leg and single-leg dispatch semantics should converge on one exact-leg authorization contract.
- No actual dispatch, pickup, transit, capacity reservation, or driver assignment was attempted during this audit.

## Required remediation before live operations

1. Reconcile the migration history and deployed function definitions against repository migration sources before preparing any database change. Do not apply/replay/baseline/squash migrations or execute corrective production DDL while that reconciliation is incomplete.
2. Make dispatch authorization exact-leg for **all** transport modes and shipment plan types. A single-leg shipment should be represented as one executable leg, not an exception to physical readiness.
3. Require the current exact-leg dispatch authorization and its confirmed reservation/binding in every privileged dispatch transition and every pickup/transit event path.
4. Ensure ROAD checks remain mandatory; add mode-specific resource/operator evidence for rail, air, ocean, and other modes rather than applying ROAD-specific driver requirements globally.
5. Remove or hard-disable any privileged legacy route that can set `dispatched` without the same authorization contract, after tracing all callers and compatibility requirements.
6. Add staging negative tests: missing reservation, wrong partner reservation, wrong leg reservation, expired/revoked reservation, missing driver acceptance, expired licence, missing licence document, unverified vehicle, missing required vehicle document, stale compliance/capability, revoked authorization, and unauthorized tenant. Add positive single-leg ROAD and non-road mode controls.
7. Verify the resulting function ACLs, SECURITY DEFINER search paths, caller chain, RLS, audit trail, and idempotency. Do not treat a successful frontend smoke test as proof of backend authorization.

## Operational conclusion

The dispatch subsystem is **not yet proven safe for real-world execution**. Keep real onboarding, shipment dispatch, driver pickup/transit, and customer-facing live service disabled until the single-leg and multi-leg authorization paths share the same tested exact-leg physical readiness gate.
