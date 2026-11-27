# KRIM Route-Generation Execution Workflow Review — 2026-11-27

Environment: Staging Supabase project qrpcivhdxobiaofppbkl. Read-only catalog/function review. Production untouched.

## Functions reviewed

### 1. public.krim_driver_record_trip_event(uuid,text,text)
- SECURITY DEFINER, empty search_path; authenticated EXECUTE, anon denied.
- Verifies auth.uid(), active driver membership, driver-owned assignment, exact linked partner assignment, shipment and exact shipment_leg_id.
- Pickup/transit require ROAD mode and current exact-leg dispatch authorization.
- Writes trip event and, for transit, updates the exact leg and shipment.
- This is a strong exact-leg execution path. Generation support still needs the current-generation predicate to be enforced by the shared dispatch-readiness helper, and historical trip records must remain linked to their original leg.

### 2. public.krim_internal_arrive_shipment(bigint)
- SECURITY DEFINER, empty search_path; direct anon/authenticated EXECUTE denied.
- Locks partner assignment and shipment, then selects the first shipment leg by shipment_id ORDER BY leg_sequence, without filtering by partner_assignment.shipment_leg_id or active plan/generation.
- Updates that selected leg to arrived and writes tracking, partner execution and audit events.
- This is a material legacy shipment-wide assumption. Before this routine is used for multi-leg/current-generation execution, it must target the exact assignment leg and verify that leg belongs to the active generation. Confirm call sites before changing it.

### 3. public.krim_internal_start_shipment_transit(bigint)
- SECURITY DEFINER, empty search_path; direct anon/authenticated EXECUTE denied.
- Locks assignment and shipment, then selects the first shipment leg by shipment_id ORDER BY leg_sequence, without filtering by assignment.shipment_leg_id or active plan/generation.
- Updates shipment and selected leg to in_transit and writes tracking, partner execution and audit events.
- This is another material legacy shipment-wide assumption. It must target the exact assignment leg and validate current-generation membership before use in multi-leg execution. Confirm call sites first.

### 4. public.krim_respond_to_partner_assignment(bigint,boolean,text)
- SECURITY DEFINER, empty search_path; authenticated EXECUTE, anon denied.
- Requires authenticated partner organization access and shipment.update permission; locks assignment; validates quote and opportunity identity; uses exact shipment_leg_id for active multi-leg plans.
- For active multi-leg plans it checks assignment/quote/opportunity exact-leg identity and joins the operational leg to plan item and active plan, including equality of plan-item sequence and operational leg_sequence.
- This sequence equality must become generation-aware; after route replacement, old generation assignments must not be accepted as current work.
- Acceptance/finalization also depends on exact confirmed capacity binding/reservation.

### 5. public.krim_authorize_leg_dispatch(bigint,text)
- SECURITY DEFINER, empty search_path; authenticated EXECUTE, anon denied.
- Requires auth.uid(), accepted exact-leg partner assignment and shipment.dispatch permission.
- Locks exact partner assignment, leg, shipment, confirmed physical capacity binding and reservation; idempotency key is scoped to partner and must map to same assignment and leg.
- ROAD dispatch requires accepted driver, verified profile/licence/identity documents, active verified vehicle binding and required current vehicle documents.
- For later sequence legs, it checks accepted custody from the preceding leg. That predecessor check currently depends on shipment-wide sequence, so it must be changed to same-generation predecessor selection.
- Shared current-readiness helper should reject superseded generations before new authorization.

## Cross-workflow blockers confirmed
1. Internal transit and arrival routines choose the first leg by shipment-wide sequence rather than the assignment's exact leg.
2. Partner acceptance uses plan-item sequence = operational leg_sequence and active plan status; this must include explicit generation identity.
3. Driver trip events rely on current dispatch authorization, so the shared helper is a critical enforcement point.
4. Dispatch authorization's custody predecessor logic must use route_generation_id plus local sequence.
5. Keep internal routines unexposed; their EXECUTE grants are currently denied to anon/authenticated.

## Required follow-up
- Trace all call sites for internal start/arrival routines (triggers, RPC wrappers, Edge Functions, jobs and application code) before modifying behavior.
- Review full source of shared dispatch-readiness helper and custody guard.
- Inspect partner acceptance remainder and all callers.
- Map exact assignment leg in internal start/arrival and test single-leg, multi-leg, retry and stale-generation cases.
- No schema migration until all readers/writers and call sites are mapped.

## Status
- Five additional execution functions reviewed.
- Two unsafe shipment-wide leg selectors confirmed in internal start/arrival.
- Partner acceptance and dispatch generation-sensitive coupling confirmed.
- No code or database migration applied.
- Runtime E2E pending.
- Phase 00 remains OPEN — NOT APPROVED.
