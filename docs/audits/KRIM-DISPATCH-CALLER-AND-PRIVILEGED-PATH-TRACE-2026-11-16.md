# KRIM Dispatch Caller and Privileged-Path Trace — Follow-up Audit
Date: 2026-11-16

## Result

The dispatch authorization gap is confirmed as a database-level integration gap, not merely a frontend issue. The current repository has no dedicated dispatch Edge Function in the active Edge Function inventory. The active execution routes are PostgreSQL RPCs and their privileged callers.

No business RPC was invoked. Inspection was read-only.

## Caller and privilege map

| Function | Execute ACL observed in production | Important behavior |
|---|---|---|
| `krim_authorize_leg_dispatch(bigint,text)` | authenticated, service_role, postgres | Creates exact-leg authorization only after confirmed capacity binding and reservation, partner permission, and mode-specific checks. |
| `krim_internal_dispatch_assigned_shipment(bigint)` | service_role, postgres | Privileged shipment-wide transition to `dispatched`; checks abstract capacity commitment and accepted driver/vehicle, plus shared readiness. Does not call `krim_authorize_leg_dispatch` or directly require a physical reservation/binding. |
| `krim_dispatch_shipment(bigint,text,jsonb)` | service_role, postgres | Legacy shipment-wide dispatch path; checks abstract capacity commitment, partner compliance and capability, then transitions shipment and writes legacy dispatch/event rows. Does not call exact-leg authorization or require physical reservation/binding. |

All three are SECURITY DEFINER. The two dispatch finalizers are not executable by authenticated users directly under their observed ACLs, but service-role callers can invoke them. This does not remove the risk: any trusted backend/worker using the service role must enforce the canonical gate, and service-role execution bypasses RLS.

## Driver execution route

Production `krim_driver_record_trip_event(uuid,text,text)`:
- Authenticates the driver and binds the event to the exact driver assignment, partner assignment, shipment and shipment leg.
- Requires an accepted driver assignment and exact commercial partner assignment.
- For active multi-leg shipments, requires current exact-leg dispatch authorization before pickup/transit.
- For single-leg shipments, it does not require that authorization; it relies on shipment status already being `dispatched` and the leg being assigned/in-transit.

This means the single-leg authorization gap propagates into driver execution: single-leg pickup/transit can proceed without an exact-leg authorization record, provided the earlier shipment-wide dispatch path has set shipment status to `dispatched`.

## Existing multi-leg protection

Repository migration `20261116016000_block_shipment_wide_dispatch_for_multileg.sql` adds a trigger preventing shipment-wide dispatch for active multi-leg plans. This is a useful guard, but it only blocks multi-leg shipments. It does not make exact-leg authorization mandatory for single-leg shipments.

## No dedicated dispatch Edge Function found

The production Edge Function inventory returned no dedicated dispatch function. The active functions include driver GPS/tracking and other platform services, but no dispatch-specific edge entrypoint. Repository tree likewise contains no dispatch-specific function under `supabase/functions`.

The current path is therefore centered on privileged database functions, not a dedicated dispatch Edge Function. This audit did not inspect external infrastructure or unlisted deployment code; the conclusion is limited to the connected Supabase Edge Function inventory and repository snapshot.

## Required correction plan — not applied

1. Make exact-leg authorization and current confirmed physical capacity binding/reservation mandatory for single-leg and multi-leg dispatch.
2. Update both privileged finalizers to accept an exact assignment/leg and require a current authorization bound to that same assignment, leg, partner, binding and reservation. Revalidate all evidence under transaction locks immediately before status transition.
3. Update the single-leg driver pickup/transit path to require current exact-leg authorization just like the multi-leg path.
4. Retire the legacy `krim_dispatch_shipment` RPC or make it delegate to the same canonical exact-leg dispatch workflow. Do not leave a service-role bypass.
5. Reconcile the existing trigger and lifecycle semantics so single-leg and multi-leg status updates remain consistent without creating duplicate departure events.
6. Add staging tests for missing, mismatched, expired, revoked and replayed authorization/reservation; concurrent dispatch; wrong assignment/leg; and positive ROAD/non-road mode-specific evidence.
7. Do not apply production DDL until the production migration-history mismatch has been reconciled.

## Release impact

**NO-GO for real dispatch execution.** The canonical exact-leg authorization function is a strong building block, but it is not yet a mandatory invariant for single-leg dispatch and driver execution. No production changes were made.
