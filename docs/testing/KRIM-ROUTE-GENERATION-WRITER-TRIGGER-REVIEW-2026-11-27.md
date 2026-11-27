# KRIM Route-Generation Writer and Trigger Review — 2026-11-27

Environment: Staging Supabase project qrpcivhdxobiaofppbkl. Read-only review. Production untouched.

## Functions manually inspected in this checkpoint

### A. public.krim_activate_shipment_leg_plan(bigint,text)
- SECURITY DEFINER; empty search_path.
- Authenticated EXECUTE is granted; anon denied.
- Requires auth.uid(), locks shipment and plan, and checks customer organization shipment.update permission.
- Idempotency and activation audit records are present.
- Critical legacy behavior: it selects the first operational leg by shipment-wide leg_sequence, and maps plan item sequence 1 onto that existing leg if leg_plan_item_id is NULL. Other plan items are inserted using plan-item leg_sequence directly as shipment-wide leg_sequence.
- This is not safe for a second generation under the current unique(shipment_id,leg_sequence) constraint.
- The activation routine must be replaced/updated atomically with generation-aware mapping before any route replacement is enabled.

### B. public.krim_ensure_initial_shipment_leg()
- Trigger function, SECURITY INVOKER; search_path public, pg_temp.
- Not directly executable by anon/authenticated.
- Trigger is AFTER INSERT OR UPDATE OF requested_transport_mode, origin_location_id, destination_location_id on public.krim_shipments.
- For supported single transport modes and draft/quoted shipments, it inserts sequence 1 if no operational leg exists.
- It does not attach a route plan item or route-generation identity.
- Activation later treats this unlinked first leg as a legacy bootstrap leg and may attach it to the first plan item.
- New-generation design must define explicit behavior for these auto-created legacy legs and prevent them from being accidentally assigned to a later generation.

### C. public.krim_assign_shipment_leg(bigint,bigint,text,jsonb)
- SECURITY DEFINER; search_path is set to public.
- EXECUTE is denied to anon and authenticated in the current catalog.
- This is a legacy routine and is not an exposed client RPC in the current grants snapshot.
- Do not assume it is an active application writer; retain it in the compatibility inventory until call sites, triggers and ownership are checked.
- Its search_path configuration is less hardened than the newer empty-search_path routines. Since direct EXECUTE is currently denied, this is a hardening review item, not proof of an exploitable path. Prefer empty search_path and fully qualified references if retained.

### D. public.krim_partner_reserve_shipment_leg_capacity(...)
- SECURITY DEFINER; empty search_path.
- Authenticated EXECUTE granted; anon denied.
- Locks assignment, shipment, organization, exact leg and capacity records; checks active partner membership, shipment.update, assignment status, partner compliance, exact partner/leg binding, route capability and capacity availability.
- Reservation, capacity binding, leg planned times and assignment binding are persisted against the exact immutable shipment_leg_id.
- It must additionally reject a leg from a superseded/non-current generation once generation support is introduced. Existing historical reservations must remain linked to their original leg.

### E. public.krim_internal_finalize_partner_assignment(bigint)
- SECURITY DEFINER; empty search_path.
- Direct EXECUTE denied to anon and authenticated.
- Called internally from the reservation flow when shipment is confirmed.
- It validates the assignment and exact capacity binding/reservation identity before finalizing. It is a private internal lifecycle step, not an exposed client RPC.

## Trigger inventory confirmed

### Shipment triggers
- Initial operational leg creation: trg_krim_ensure_initial_shipment_leg.
- Shipment readiness enforcement, terminal-state guard, multi-leg shipment-wide dispatch block, capacity confirmation guard, warehouse handover guard, terminal capacity release, status/audit/history and operational snapshot triggers.

### Shipment-leg triggers
- Accepted custody required before a next-leg status transition.
- Leg creation/change/route-segment audit and status history.
- Origin/destination, route-segment, shipment and transport-mode validation.

### Partner-assignment triggers
- Sourcing-state and quote-integrity guards.
- Assignment identity and status-transition guards.
- Capacity commitment maintenance.
- Capacity release on terminal assignment.
- Partner assignment audit and in-app event emission.
- Partner quote response evidence.
- Partner rejection quote cleanup.
- Delete/truncate prevention.

## Generation migration implications
1. Trigger-created legacy sequence-1 legs must be deterministically classified as legacy/current-generation bootstrap legs.
2. Activation must not attach a previously used or execution-linked leg to a new generation.
3. Custody sequencing must be scoped by route_generation_id.
4. Partner assignment and capacity reservation must reject superseded generation legs for new work while retaining existing historical links.
5. All status/audit/event triggers must preserve generation identity in their snapshots and events where needed.
6. The legacy SECURITY DEFINER assign routine must be call-site checked and hardened or retired before the migration gate closes.

## Status
- Five high-impact functions reviewed individually (bounded to this checkpoint).
- Trigger inventory for shipments, shipment legs and partner assignments captured.
- Remaining writers/readers, trigger-function bodies, application direct table access and linked frontend pages remain OPEN.
- No migration or runtime test was run.
- Phase 00 remains OPEN — NOT APPROVED.
