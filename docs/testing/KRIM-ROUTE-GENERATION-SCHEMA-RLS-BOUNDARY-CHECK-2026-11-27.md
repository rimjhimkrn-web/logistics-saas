# KRIM Route-Generation Schema and RLS Boundary Check — 2026-11-27

Environment: Staging Supabase project qrpcivhdxobiaofppbkl. Read-only database inspection. Production untouched.

## 1. Generation schema state
Checked information_schema.columns for krim_shipment_legs, krim_shipment_leg_plans and krim_shipment_leg_plan_items.
- No route_generation_id / generation identity column exists on these tables.
- Operational legs retain shipment_id, shipment-wide leg_sequence, status and nullable leg_plan_item_id.
- Plan items retain plan_id and per-plan leg_sequence.
- This confirms generation identity is not yet implemented. No schema migration was attempted.

## 2. RLS policy review
RLS is enabled on:
- krim_shipment_legs
- krim_shipment_leg_plans
- krim_shipment_leg_plan_items
- krim_shipment_leg_plan_events
- krim_shipment_leg_activations
- krim_shipment_leg_activation_events
- krim_shipments

Policy findings:
- Operational legs: authenticated SELECT policy scopes through parent shipment customer_organization_id and private.krim_has_organization_access(auth.uid(), ...).
- Route plans: authenticated SELECT policy scopes through parent shipment customer organization.
- Plan items: authenticated SELECT policy joins plan to shipment and checks customer organization access.
- Plan events: authenticated SELECT policy follows plan to shipment and checks customer organization access.
- Activation records/events: authenticated SELECT policy follows activation to shipment and checks customer organization access.
- Shipment SELECT policy includes active partner assignment, customer organization access, permitted operations access, and eligible verified partner opportunity access.
- No anon policies were found for these records in the policy listing.

## 3. Grants boundary
Current anon/authenticated table grants:
- Route plan, plan item, plan event, activation and activation-event tables: authenticated SELECT only; no anon grants and no authenticated writes.
- krim_shipments: authenticated SELECT only; no anon grants and no authenticated writes.
- krim_shipment_legs: no anon/authenticated table grants were present in the inspected grant snapshot. An authenticated SELECT RLS policy exists, but without a SELECT grant it cannot be used directly through PostgREST. Do not grant access casually; confirm the intended client read path and exact consumers first.

## 4. Implications for generation rollout
1. The new generation key must be introduced additively; no generation columns currently exist.
2. Existing org-scoped plan read policies are a useful boundary, but all new generation/history tables and views must inherit shipment tenant scoping.
3. Do not expose raw operational legs to clients merely to support generation history; prefer narrowly scoped RPC/views if the UI needs them.
4. New generation identifiers must not weaken the existing customer/partner opportunity separation in shipment SELECT.
5. Keep all direct writes to route-plan/leg tables denied; mutation must occur through guarded transactional RPCs.

## Status
- Schema generation-column check: PASS (confirmed absent).
- Route-plan RLS policy review: PASS (policies are customer-organization scoped).
- Direct grants review: PASS (least-privilege read/write grants confirmed; leg table currently has no client grant).
- Application consumer inventory: OPEN.
- Generation migration: NOT STARTED.
- Runtime JWT/tenant-isolation E2E: PENDING.
- Phase 00: OPEN — NOT APPROVED.
