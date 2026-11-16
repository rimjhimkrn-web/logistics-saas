# KRIM Booking UI-to-Production RPC Chain — Confirmed P0 End-to-End Contract Defect
Date: 2026-11-16

## Executive finding
The canonical public booking form calls `krim_create_global_shipment_idempotent(bigint,jsonb,jsonb,text,numeric,text,text,uuid)`, not the five-argument RPC directly. Production catalog inspection confirms the idempotent function delegates to the seven-argument `krim_create_global_shipment_from_places(...,text,text)`. That overload delegates to the six-argument `krim_create_global_shipment_from_places(...,text)`, which delegates to the five-argument `krim_create_global_shipment(bigint,bigint,bigint,text,numeric)`.

The six-argument overload calls the five-argument shipment creator first, then attempts to update `requested_transport_mode`. The five-argument creator inserts without that column. The enabled `BEFORE INSERT` corridor-compliance trigger rejects the insert because `requested_transport_mode` is null. Therefore the later update that would set the mode is unreachable. This confirms the booking failure affects the actual canonical customer UI path, not only a legacy RPC entry point.

## Exact call chain from live definitions
1. `public/krim_create_global_shipment_idempotent(bigint,jsonb,jsonb,text,numeric,text,text,uuid)`
   - Validates auth, organization membership/access, `shipment.create`, active organization, booking request idempotency and payload equality.
   - Calls the seven-argument `krim_create_global_shipment_from_places(...,p_transport_mode,p_route_type)`.
2. Seven-argument `krim_create_global_shipment_from_places(...,text,text)`
   - Validates route type and domestic/cross-border country consistency.
   - Calls the six-argument overload.
   - Updates `requested_route_type` after that call returns.
3. Six-argument `krim_create_global_shipment_from_places(...,text)`
   - Validates transport preference.
   - Calls the five-argument overload.
   - Only after it returns, updates `requested_transport_mode` and place metadata.
4. Five-argument `krim_create_global_shipment(bigint,bigint,bigint,text,numeric)`
   - Inserts shipment without `requested_transport_mode`.
5. Enabled trigger `krim_enforce_corridor_compliance_before_shipment_write`
   - Fires before insert and rejects null/blank mode; also requires exact active corridor, approved dossier and current mandatory controls.

The defect is a sequencing/contract error in the nested RPC chain: the mode must be written in the initial insert, not applied in a subsequent update.

## Frontend evidence
`public/shipper/booking-request.html` submits the selected `p_transport_mode`, `p_route_type` and stable `p_booking_request_id` to the idempotent RPC. It performs a preliminary active-market lookup and correctly tells users not to retry after ambiguous outcomes. The UI does not call the five-argument overload directly.

## Safe remediation design — not applied
1. Complete the existing production migration-history and live-schema reconciliation before changing any function.
2. Replace the nested creation chain with one atomic canonical implementation that:
   - validates supported transport mode and route type;
   - validates the customer organization, membership and `shipment.create` permission;
   - resolves or creates endpoint location records under controlled rules;
   - writes `requested_transport_mode` and `requested_route_type` in the initial shipment INSERT;
   - preserves active market and exact approved corridor/dossier/control triggers;
   - writes place labels/coordinates and booking request id atomically;
   - compares every canonical field on idempotent replay and rejects conflicting retries.
3. Ensure any initial-leg trigger sees the same requested mode and route.
4. Revoke/retire obsolete overloads only after enumerating all callers and compatibility requirements.
5. Add staging tests for missing/unsupported mode, unsupported route, domestic/cross-border mismatch, missing/inactive markets, no exact approved corridor, unapproved/expired mandatory controls, no customer membership, missing permission, duplicate identical request, conflicting payload replay, and successful draft creation only when every gate passes.
6. Test transaction rollback so a failed corridor gate cannot leave orphan location rows or partial shipment records.

## Release decision
Shipment booking remains **NO-GO**. Do not disable or weaken the corridor trigger. Do not attempt live booking as a diagnostic. Do not apply a production function replacement until migration reconciliation, staging verification and explicit production-change authorization.

## Evidence boundaries
Production function definitions and trigger definitions were inspected read-only. No RPC was executed, no shipment was created, and no production data, schema, permissions or business state was changed. Failure is inferred from the complete live call chain and active trigger definition; it was not tested by attempting a live booking.
