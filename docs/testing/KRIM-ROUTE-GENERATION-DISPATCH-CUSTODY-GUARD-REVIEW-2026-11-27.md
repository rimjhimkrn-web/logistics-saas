# KRIM Route-Generation Dispatch/Custody Guard Review — 2026-11-27

Environment: Staging Supabase project qrpcivhdxobiaofppbkl. Read-only catalog inspection. Production untouched.

## 1. Shared dispatch-currentness helper
Reviewed: private.krim_leg_dispatch_authorization_is_current(bigint,bigint,bigint,bigint)
- SECURITY DEFINER with empty search_path.
- Direct EXECUTE denied to anon and authenticated (used internally).
- Verifies dispatch authorization, exact partner assignment, exact shipment leg, organization standing, confirmed capacity binding/reservation, partner compliance/capability, handover readiness and ROAD driver/vehicle evidence.
- For active multi-leg plans it currently requires:
  * active plan and exact plan-item link;
  * plan-item sequence equals operational leg_sequence;
  * matching origin/destination/mode and partner assignment;
  * active plan total_legs equals count of all non-cancelled operational legs for the shipment.
- For a single legacy leg it permits the unlinked sequence-1 bootstrap case only when there is exactly one non-cancelled leg and no active plan.
- The all-shipment non-cancelled leg count is not generation-scoped. Retaining superseded legs would cause false rejection or incorrect readiness calculations until this helper is rewritten.
- Custody validation currently accepts a transfer from a prior leg whose shipment-wide sequence is current leg sequence - 1. It must scope both legs to the same active route_generation_id and local sequence.

## 2. Custody transition trigger
Reviewed: private.krim_require_accepted_custody_before_next_leg_dispatch()
- SECURITY DEFINER, empty search_path; trigger-only execution.
- On transition to in_transit, for a later leg of an active multi-leg plan, it requires accepted custody from a leg in the same shipment with sequence one less.
- It also checks releasing/receiving partner identity against the exact prior leg and current leg.
- It does not currently scope the prior leg by route generation or plan identity.
- Must be updated in lockstep with the dispatch-currentness helper; otherwise direct status transitions and dispatch RPC may disagree about custody eligibility.

## 3. Internal transit/arrival call-site tracing
- Catalog search of public/private stored function definitions found no direct function-body references to krim_internal_start_shipment_transit() or krim_internal_arrive_shipment().
- This is only a database function-body text scan. It does not prove there are no dynamic SQL calls, trigger wrappers outside the scanned schemas, Edge Function calls, application RPC calls, jobs or external integrations.
- These two routines remain SECURITY DEFINER internal routines with direct anon/authenticated EXECUTE denied, as previously recorded.
- Before changing them, inspect all deployed Edge Function source and application code call sites, plus trigger definitions and runtime logs if available. Do not infer they are unused solely from this scan.

## 4. Required implementation constraints
1. Route-generation identity must be included in the dispatch-currentness helper and custody trigger.
2. Current-generation leg count must replace shipment-wide count in all active-plan predicates.
3. Historical authorization and custody records remain tied to immutable historical leg IDs.
4. Internal transit/arrival must update the exact assignment leg, not select a leg by shipment-wide minimum sequence.
5. Keep helper functions non-exposed; only guarded public workflows should be executable by authenticated users.
6. Add regression tests for active generation, superseded generation, legacy single-leg bootstrap, multi-leg custody, cross-generation custody rejection, retries and tenant isolation.

## Status
- Shared dispatch-currentness helper reviewed: PASS (reviewed, not modified).
- Custody trigger reviewed: PASS (reviewed, not modified).
- No direct DB function-body callers found for internal transit/arrival: bounded finding only.
- Edge Function/application caller inventory: OPEN.
- Generation-aware changes: NOT IMPLEMENTED.
- Runtime JWT E2E: PENDING.
- Phase 00 remains OPEN — NOT APPROVED.
