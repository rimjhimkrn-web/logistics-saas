# KRIM Single-Leg Assignment vs Physical Capacity Reservation — P0 Operational Integrity Audit
Date: 2026-11-16

## Executive finding
**P0 — the single-leg assignment finalizer can mark a shipment `assigned` without any verified vehicle/resource reservation.** The automatic assignment-acceptance trigger creates a shipment-weight capacity commitment record (kg) and labels it `committed`, but it does not reserve a physical vehicle or bind an availability window. The assignment finalizer checks only for that abstract commitment and then marks the partner assignment active and the shipment assigned. Physical resource reservation is a separate RPC that must be invoked later.

This creates a dangerous semantic gap: `assigned` can mean only “partner accepted and a weight commitment row exists”, not “a verified vehicle/resource is reserved for the shipment's exact leg and time window”.

## Production evidence (read-only)
### 1. Automatic trigger creates an abstract weight commitment
Enabled trigger on `public.krim_shipment_partner_assignments`:
- `trg_krim_ensure_assignment_capacity_commitment`
- Fires AFTER INSERT or UPDATE OF status, partner_quote_id, partner_organization_id.

Trigger function `public.krim_ensure_assignment_capacity_commitment()`:
- Runs when assignment status becomes `accepted`.
- Requires positive shipment `total_weight_kg`.
- Requires a linked partner quote matching shipment and partner.
- Inserts into `krim_partner_shipment_capacity_commitments` with:
  - `committed_quantity = shipment.total_weight_kg`
  - `capacity_unit = 'kg'`
  - `status = 'committed'`
  - metadata source `assignment_acceptance_guard`.
- Checks the resulting abstract commitment has matching partner, committed status, enough weight and non-expired validity.
- Does not inspect a verified vehicle, capacity resource, route lane, schedule window, availability row, reservation row or capacity-leg binding.

### 2. Assignment finalizer treats the abstract commitment as sufficient
Production function `public.krim_internal_finalize_partner_assignment(bigint)`:
- Requires shipment status `confirmed`.
- Requires assignment status `accepted` and linked partner quote.
- Requires one `krim_partner_shipment_capacity_commitments` row with status `committed` and matching partner.
- For a single-leg shipment, updates assignment status to `active` and shipment status to `assigned`.
- It does not require `capacity_binding_id`, `krim_capacity_leg_bindings`, `krim_capacity_reservations`, a verified vehicle/resource, or scheduled departure/arrival.
- Multi-leg completion counting similarly uses the abstract commitment, not physical resource binding.

### 3. Physical reservation is a separate operation
Production function `public.krim_partner_reserve_shipment_leg_capacity(bigint,timestamptz,timestamptz,text)`:
- Requires authenticated active partner membership and `shipment.update`.
- Requires assignment status `accepted` or `active`, exact shipment leg, current partner compliance and verified capability.
- Requires future departure/arrival window.
- Searches verified active lane, mode, availability and vehicle/resource rows; checks overlapping reservations and remaining capacity.
- Creates a confirmed capacity reservation and a confirmed capacity-leg binding, then attaches the binding to the assignment.
- Fails if no verified, available resource matches the exact route/mode/window.
- This RPC can be called only after the assignment is already accepted/active, which is consistent with the current finalizer allowing assignment before resource reservation.

### 4. Production data context
Prior read-only operational snapshot recorded zero capacity resources/reservations and zero accepted assignments. No live reservation or assignment was created for this audit. Thus there is currently no evidence that the physical reservation path has been exercised successfully in production.

## Operational consequence
A shipment may transition:
`quoted → confirmed → assigned`
after partner acceptance and abstract kg commitment, while no truck, vehicle, rail slot, air cargo allocation, vessel slot or other mode-specific resource has been reserved.

This is not safe to interpret as dispatch-ready or as a guaranteed capacity commitment. It risks overpromising service, double-selling capacity, failed pickup and customer trust/revenue damage.

## Required remediation design — not applied
1. Define explicit state semantics:
   - `partner_accepted`: partner accepted commercial offer.
   - `capacity_pending`: waiting for exact resource and schedule.
   - `capacity_reserved`: verified resource reservation and binding confirmed.
   - `assigned` / `ready_for_dispatch`: only after all mandatory assignment and resource gates pass.
2. Make assignment finalization require a live confirmed capacity-leg binding whose reservation:
   - belongs to the same partner, shipment and exact leg;
   - matches the approved lane and transport mode;
   - is bound to a verified active resource and availability record;
   - has enough capacity for the shipment's required weight/units;
   - covers the exact planned departure/arrival window;
   - is not expired, released, cancelled or superseded.
3. If resource reservation is operationally performed after customer acceptance, keep shipment in a non-dispatchable `capacity_pending` state and do not call it fully assigned until reservation succeeds.
4. Ensure one transaction or a durable, retry-safe state machine coordinates reservation, binding, assignment activation and shipment status. A failed reservation must not leave a shipment marked assigned.
5. Make capacity reservation idempotency compare canonical payload (shipment, leg, partner, resource, quantity/unit, departure/arrival); reject a reused key with different details. Verify existing-binding reuse checks the same exact schedule/resource rather than merely a live binding.
6. For multi-leg shipments, require a separate confirmed physical binding for every leg before reporting the whole route assigned; do not count an abstract kg commitment as a ready leg.
7. Add staging tests: accepted-but-unreserved remains non-dispatchable; no resource; wrong lane/mode; stale/unverified resource; insufficient weight; overlapping reservation; conflicting idempotency replay; expired hold; released reservation; reservation retry; exact schedule mismatch; one leg reserved but another missing; all legs reserved and assignment finalized.
8. Reconcile production migration history and live definitions before preparing changes. No production DDL or RPC execution for testing.

## Release impact
- **NO-GO** for treating the current `assigned` state as verified physical capacity or dispatch readiness.
- Keep dispatch authorization dependent on exact resource reservation and separate dispatch controls.
- Do not auto-create fake vehicle records or weaken the physical capacity gate to satisfy the finalizer.

## Evidence boundaries
Production function definitions and trigger definitions were inspected read-only. No assignment, commitment, reservation, capacity binding or shipment was created or modified. No business RPC was invoked. The finding is a verified gap between the finalizer's required evidence and the separate physical reservation function; it is not a claim that every existing assigned shipment currently lacks capacity.
