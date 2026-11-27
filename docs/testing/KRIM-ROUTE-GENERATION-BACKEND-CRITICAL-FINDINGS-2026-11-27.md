# KRIM Route-Generation Backend Compatibility Findings — 2026-11-27

Scope: Staging Supabase project qrpcivhdxobiaofppbkl. Read-only catalog/function inspection. Production untouched.

## Confirmed high-risk coupling

### 1. Activation currently assumes shipment-wide sequence equals plan-item sequence
The current public.krim_activate_shipment_leg_plan(p_plan_id bigint,p_idempotency_key text):
- locks the shipment and plan;
- evaluates the plan;
- selects the first operational leg by shipment_id ORDER BY leg_sequence;
- maps plan item sequence 1 onto that first leg if its leg_plan_item_id is NULL;
- otherwise inserts new operational legs using v_item.leg_sequence directly as shipment-wide leg_sequence;
- writes activation mapping and marks plan active.

Because krim_shipment_legs has a shipment-wide unique (shipment_id,leg_sequence) constraint, a second generation restarting item sequence at 1 cannot be materialized by this implementation. Existing activation logic is first-generation/legacy bootstrap logic, not replacement logic.

### 2. Capacity reservation is bound to immutable operational leg ID
public.krim_partner_reserve_shipment_leg_capacity locks the partner assignment, shipment and exact leg; validates partner ownership, leg status, capability and route; and ties reservation/binding identity to that exact shipment_leg_id. Replacement must not silently retarget an existing reservation or binding.

### 3. Driver assignment is bound to exact operational leg ID
public.krim_assign_driver_to_partner_shipment validates the partner assignment's shipment_leg_id against the operational leg, then creates driver assignment with exact shipment_leg_id. Driver/vehicle availability and identity evidence are also validated. Historical driver assignments must remain attached to their original leg.

### 4. Custody sequencing is sequence-based today
private.krim_require_accepted_custody_before_next_leg_dispatch() finds the immediately preceding leg using same shipment_id and leg_sequence = NEW.leg_sequence - 1. It checks an accepted custody transfer between exact leg IDs and partner organizations. A replacement model must scope predecessor selection to the current route generation, not merely sequence arithmetic.

### 5. Delivery finalization is generation-sensitive
The inspected internal delivery authorization/finalization body identifies the active multi-leg plan, counts plan items and completed operational legs by plan-item link, then checks all shipment legs for nonterminal status. This can mix historical and current generations if superseded legs are retained without generation-aware filtering. The existing finalization logic must be revised as part of the same release as route-generation support.

## Design constraints
- Preserve existing operational leg primary keys and all downstream foreign-key references.
- Never delete/resequence historical legs as a shortcut.
- Keep capacity, driver, dispatch, custody, POD and warehouse records attached to their original leg.
- A new generation requires an explicit mapping from plan-item sequence to unique operational leg identity and generation identity.
- Current-generation-only checks must be updated consistently in activation, custody, dispatch, POD finalization, shipment completion, operations views and UI.
- Replacement must be rejected after irreversible execution evidence (dispatch, pickup, transit, accepted custody, POD or equivalent) unless a separately designed recovery process authorizes it.
- Atomic locking, tenant authorization, idempotency and audit events are mandatory.

## Status
- Core function bodies inspected: activation, partner capacity reservation, driver assignment and custody trigger.
- Confirmed material replacement blockers: shipment-wide sequence uniqueness; sequence-based predecessor lookup; active-plan delivery completion checks.
- No route-generation schema or replacement code implemented in this checkpoint.
- Runtime tests remain unavailable until independent test identities and fixtures are provisioned and used.
- Phase 00 remains OPEN — NOT APPROVED.
