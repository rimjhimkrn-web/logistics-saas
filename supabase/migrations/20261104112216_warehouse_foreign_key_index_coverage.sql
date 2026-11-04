-- Cover all warehouse foreign-key lookup paths identified by Supabase Performance Advisor.
create index if not exists krim_wh_evidence_created_by_idx on public.krim_warehouse_evidence(created_by);
create index if not exists krim_wh_evidence_facility_idx on public.krim_warehouse_evidence(facility_id);
create index if not exists krim_wh_evidence_org_idx on public.krim_warehouse_evidence(organization_id);
create index if not exists krim_wh_movements_inventory_org_facility_idx on public.krim_warehouse_inventory_movements(inventory_id,organization_id,facility_id);
create index if not exists krim_wh_task_events_actor_idx on public.krim_warehouse_task_events(actor_user_id);
create index if not exists krim_wh_task_events_facility_idx on public.krim_warehouse_task_events(facility_id);
create index if not exists krim_wh_task_events_org_idx on public.krim_warehouse_task_events(organization_id);
create index if not exists krim_wh_tasks_completed_by_idx on public.krim_warehouse_tasks(completed_by);
create index if not exists krim_wh_tasks_created_by_idx on public.krim_warehouse_tasks(created_by);
create index if not exists krim_wh_tasks_facility_idx on public.krim_warehouse_tasks(facility_id);