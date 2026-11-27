# KRIM Route-Generation Consumer Inventory — 2026-11-27

## Scope
Staging project `qrpcivhdxobiaofppbkl`. Read-only catalog inspection. No schema or business rows changed.

## Current data
- Route-plan item count: 0.
- Prior direct Staging count checks showed route plans: 0 and shipment legs: 0.
- No route-generation migration has been applied.

## Existing planning and operational identity
- Plan header: `krim_shipment_leg_plans.plan_version`, `status`, `planning_snapshot`.
- Plan item: `krim_shipment_leg_plan_items.plan_id`, `leg_sequence`, planned times and status.
- Operational leg: `krim_shipment_legs.leg_sequence`, `leg_plan_item_id`, status, assignment status and planned times.
- There is no explicit route-generation ID column on the inspected plan, plan-item or operational-leg tables.
- `leg_sequence` is unique across a shipment, not merely within one plan.

## Database routines referencing leg sequence or plan-item identity
Catalog search found the following routines; each must be reviewed for whether it reads, creates, mutates, authorizes or displays current-vs-historical legs:

### Planning / sourcing
- `public.krim_create_shipment_leg_plan`
- `public.krim_evaluate_shipment_leg_plan`
- `public.krim_activate_shipment_leg_plan`
- `private.krim_guard_leg_sourcing_state`
- `private.krim_validate_leg_scoped_partner_opportunity`
- `private.krim_validate_leg_scoped_partner_quote`
- `public.krim_create_leg_partner_opportunity`
- `public.krim_submit_leg_partner_quote`
- `public.krim_award_leg_partner_quote`
- `public.krim_award_partner_quote`

### Dispatch / execution / custody
- `private.krim_guard_leg_dispatch_authorization`
- `private.krim_leg_dispatch_authorization_is_current`
- `private.krim_require_accepted_custody_before_next_leg_dispatch`
- `public.krim_authorize_leg_dispatch`
- `public.krim_dispatch_shipment`
- `public.krim_create_leg_custody_transfer`
- `public.krim_driver_accept_assignment_unchecked`
- `public.krim_internal_arrive_shipment`
- `public.krim_internal_start_shipment_transit`
- `public.krim_internal_authorize_delivery`
- `public.krim_internal_submit_delivery_pod`
- `public.krim_request_shipment_return`
- `public.krim_respond_to_partner_assignment`
- `public.krim_ensure_initial_shipment_leg`

### Operations / warehouse / read surfaces
- `public.krim_admin_list_delivery_pods`
- `public.krim_operations_dispatch_readiness`
- `public.krim_warehouse_list_assigned_shipment_legs`
- `public.krim_warehouse_list_tasks`

This is a catalog name inventory based on function-definition text matches. It is not a completed semantic review of each function's call graph or every frontend consumer.

## Critical compatibility rule
Do not add a route-generation column and immediately enable replacement. Existing routines may use shipment-wide `leg_sequence` as a current-route ordering key, and authorization guards compare operational leg rows with active plan items. A new generation would be unsafe until all these routines, triggers, frontend queries and background workers consistently distinguish:
1. immutable operational leg ID;
2. route generation/version;
3. within-generation sequence;
4. current active generation vs retained historical generation.

## Next review order
1. Fetch and inspect the complete definitions of create/evaluate/activate and sourcing guard.
2. Inspect every routine in the execution/custody list and all triggers on affected tables.
3. Search frontend and Edge Function code for `leg_sequence`, `leg_plan_item_id`, and ordering/grouping assumptions.
4. Build a consumer compatibility matrix with a required change and test per consumer.
5. Only after that review, propose additive schema and compatibility views/functions. No direct data backfill is needed in this empty Staging snapshot, but legacy behavior still needs a regression test.
6. Keep route replacement disabled until the entire matrix passes.

## Gate
- Consumer names discovered: PASS (inventory only).
- Full semantic/call-graph review: OPEN.
- Frontend/Edge Function consumer review: OPEN.
- Route-generation schema: NOT IMPLEMENTED.
- Runtime E2E: PENDING.
- Phase 00: OPEN / NOT APPROVED.
- Production: untouched.
