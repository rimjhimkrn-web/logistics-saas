# KRIM Legacy Transit/Arrival Routine Reachability and Idempotency Review — 2026-11-27

## Scope
Staging Supabase project only: `qrpcivhdxobiaofppbkl`. Read-only catalog inspection of:
- `public.krim_internal_start_shipment_transit(bigint)`
- `public.krim_internal_arrive_shipment(bigint)`
- `public.krim_driver_record_trip_event(uuid,text,text)`

No schema or data changes were made.

## Verified routine properties

### Internal transit and arrival
Both internal routines are SECURITY DEFINER with an empty search_path. Their effective execute privileges are:
- anon: denied
- authenticated: denied
- service_role: denied
- postgres: owner execution only

A scan of stored routine definitions in public/private found no direct database-function callers of either routine. This is a bounded textual scan: it does not exclude dynamic SQL, external application/Edge Function calls, jobs, or direct owner-level invocation.

Both routines accept a partner assignment ID but select the first shipment leg by shipment-wide `leg_sequence`, rather than selecting and validating the exact `shipment_leg_id` on that assignment. They therefore remain unsafe for multi-leg execution if invoked. The idempotent early-return branches also occur before exact-leg validation:
- transit returns when shipment status is already `in_transit`;
- arrival returns when shipment status is already `delivered`.

No caller or workflow should be wired to these routines until they are retired or rewritten to validate assignment, shipment, exact leg, partner, current generation, and allowed lifecycle transition before any idempotent return or write.

### Driver trip event routine
`krim_driver_record_trip_event(uuid,text,text)` is SECURITY DEFINER with empty search_path. EXECUTE is granted to authenticated and service_role; anon is denied. It validates the driver's exact assignment, partner assignment, shipment and leg, then records tracking and partner execution events against that exact leg.

For the `in_transit` event it also updates the shipment's aggregate status from `dispatched` to `in_transit`. This is shipment-level status aggregation, not proof that all legs or the active route generation are in transit. Its generation safety still depends on the private dispatch-authorization guard and needs a route-generation-aware review before replacement support is enabled.

## Decision
- Do not expose or grant either legacy internal routine.
- Do not connect them to frontend or Edge Function workflows.
- Before multi-leg route-generation activation, replace/retire these routines or prove they are unreachable and remove them through a separately reviewed migration.
- Keep shipment aggregate status semantics separate from exact-leg state transitions.
- Add tests for wrong-assignment/wrong-leg IDs, idempotent retries, later-leg transit/arrival, stale generations, and cross-tenant attempts.

## Verification limits
The staging project currently has no operational shipment/leg/assignment fixtures, so no runtime lifecycle test was possible. Catalog inspection and privilege checks are structural evidence only. No production project was accessed.
