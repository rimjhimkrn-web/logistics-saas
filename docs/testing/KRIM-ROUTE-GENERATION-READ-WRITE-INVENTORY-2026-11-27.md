# KRIM Route-Generation Read/Write Inventory — 2026-11-27

Environment: Staging Supabase project qrpcivhdxobiaofppbkl.
Method: read-only PostgreSQL catalog inspection of public/private function definitions for references to krim_shipment_legs, krim_shipment_leg_plan_items and leg_sequence. Writer flags are text-pattern indicators and require manual body review; they are not a complete SQL parser. Production untouched.

## Confirmed operational leg writers
The catalog query identified these functions with apparent INSERT/UPDATE/DELETE statements against krim_shipment_legs:
- public.krim_activate_shipment_leg_plan(bigint,text)
- public.krim_assign_shipment_leg(bigint,bigint,text,jsonb)
- public.krim_driver_record_trip_event(uuid,text,text)
- public.krim_ensure_initial_shipment_leg()
- public.krim_internal_arrive_shipment(bigint)
- public.krim_internal_authorize_delivery(bigint,uuid)
- public.krim_internal_finalize_partner_assignment(bigint)
- public.krim_internal_start_shipment_transit(bigint)
- public.krim_partner_reserve_shipment_leg_capacity(bigint,timestamptz,timestamptz,text)
- public.krim_respond_to_partner_assignment(bigint,boolean,text)

## Confirmed route-plan item writer
- public.krim_create_shipment_leg_plan(bigint,jsonb,text,jsonb) writes krim_shipment_leg_plan_items and reads operational legs for compatibility/evaluation.

## Critical readers / guards / operational workflows
Catalog references include:
- private.krim_guard_leg_dispatch_authorization()
- private.krim_guard_leg_sourcing_state()
- private.krim_guard_partner_assignment_quote_integrity()
- private.krim_guard_shipment_terminal_state()
- private.krim_leg_dispatch_authorization_is_current(bigint,bigint,bigint,bigint)
- private.krim_partner_capability_covers_shipment_leg(bigint,bigint)
- private.krim_require_accepted_custody_before_next_leg_dispatch()
- private.krim_validate_leg_scoped_partner_opportunity()
- private.krim_validate_leg_scoped_partner_quote()
- public.krim_admin_list_delivery_pods()
- public.krim_assign_driver_to_partner_shipment(bigint,uuid)
- public.krim_authorize_leg_dispatch(bigint,text)
- public.krim_award_leg_partner_quote(bigint)
- public.krim_award_partner_quote(bigint)
- public.krim_create_leg_custody_transfer(bigint,bigint,jsonb,text,text,text,text,text)
- public.krim_create_leg_partner_opportunity(bigint,bigint,timestamptz)
- public.krim_dispatch_shipment(bigint,text,jsonb)
- public.krim_driver_accept_assignment_unchecked(uuid)
- public.krim_evaluate_shipment_leg_plan(bigint)
- public.krim_internal_create_partner_payable(bigint)
- public.krim_internal_create_partner_payable_for_delivered_shipment(bigint)
- public.krim_internal_submit_delivery_pod(bigint,text,text,text,jsonb)
- public.krim_operations_dispatch_readiness()
- public.krim_partner_dispatch_assigned_shipment(bigint,text)
- public.krim_request_shipment_return(bigint,bigint,text,jsonb,timestamptz,uuid)
- public.krim_respond_to_leg_custody_transfer(bigint,boolean,text)
- public.krim_submit_leg_partner_quote(bigint,numeric,text,timestamptz,text)
- public.krim_warehouse_create_linked_goods_receipt_task(...)
- public.krim_warehouse_create_linked_handover_task(...)
- public.krim_warehouse_create_linked_inbound_task(...)
- public.krim_warehouse_create_linked_pick_task(...)
- public.krim_warehouse_list_assigned_shipment_legs(bigint,uuid)
- public.krim_warehouse_list_tasks(text)
- public.krim_warehouse_reserve_shipment_inventory(...)

## Generation-sensitive sequence dependencies
The catalog query flagged sequence use in activation, initial-leg creation, arrival/transit, delivery authorization, partner response, custody predecessor guard, dispatch authorization, quote award/opportunity, POD submission, operations readiness, returns and warehouse listing. These require manual source review to determine whether the sequence is historical display, ordering, or current-generation eligibility.

## Scope limitations
- Catalog text scanning may miss dynamic SQL, indirect calls, generated SQL, application-side direct table queries, external workers and functions outside public/private schemas.
- It can flag comments/string literals or non-mutating SQL as apparent writes; manual body review remains mandatory.
- Frontend review remains bounded to previously inspected customer quote comparison and partner workspace pages.
- This inventory is a dependency register, not a declaration that each routine is safe or already generation-aware.

## Required next gate
Review each writer/reader definition in dependency order, map trigger invocation paths and direct grants, inspect application source for direct leg table queries, and classify each consumer as:
1. preserve exact historical leg ID only;
2. must enforce current generation;
3. must sequence within generation;
4. must expose generation history;
5. must be blocked for superseded generations.
No schema migration until all writers and critical guards have an owner-reviewed disposition.

## Status
- Read/write function catalog inventory: PASS (bounded textual scan).
- Manual review of every routine: OPEN.
- Trigger/application direct access inventory: OPEN.
- Generation migration: NOT STARTED.
- Runtime E2E: PENDING.
- Phase 00: OPEN — NOT APPROVED.
