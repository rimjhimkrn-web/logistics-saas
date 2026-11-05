create or replace function private.krim_warehouse_guard_goods_receipt_quality()
returns trigger
language plpgsql
set search_path = ''
as $function$
begin
 if new.task_type='goods_receipt' and new.quality_status='released' then
  raise exception 'Goods receipt stock cannot be released by the receiving operator. Complete receipt, attach an inspection report, and use the independent quality review workflow.' using errcode='42501';
 end if;
 return new;
end;
$function$;

drop trigger if exists krim_wh_goods_receipt_quality_guard on public.krim_warehouse_tasks;
create trigger krim_wh_goods_receipt_quality_guard
before insert or update of task_type, quality_status
on public.krim_warehouse_tasks
for each row execute function private.krim_warehouse_guard_goods_receipt_quality();

create or replace function public.krim_warehouse_review_inventory_quality(
 p_task_id uuid,
 p_inventory_id uuid,
 p_decision text,
 p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
 v_user uuid:=auth.uid();
 v_task public.krim_warehouse_tasks%rowtype;
 v_inventory public.krim_warehouse_inventory%rowtype;
 v_previous text;
begin
 if v_user is null then raise exception 'Authentication required' using errcode='28000'; end if;
 if p_task_id is null or p_inventory_id is null then raise exception 'A completed task and inventory record are required' using errcode='22023'; end if;
 if p_decision not in ('released','hold','rejected') then raise exception 'Unsupported quality decision' using errcode='22023'; end if;
 if nullif(btrim(p_reason),'') is null or length(btrim(p_reason))<5 or length(btrim(p_reason))>1000 then raise exception 'Quality review reason must contain 5–1,000 characters' using errcode='22023'; end if;

 select * into v_task from public.krim_warehouse_tasks where id=p_task_id for update;
 if not found then raise exception 'Quality source task not found' using errcode='P0002'; end if;
 if v_task.task_type not in ('goods_receipt','damage_exception') or v_task.status<>'completed' then
  raise exception 'Quality review requires a completed goods receipt or damage exception task' using errcode='23514';
 end if;
 if not private.krim_warehouse_is_operator(v_user,v_task.organization_id,v_task.facility_id) then
  raise exception 'Verified warehouse operator access required' using errcode='42501';
 end if;
 if v_task.created_by=v_user or v_task.completed_by=v_user then
  raise exception 'Independent quality review required: reviewer must differ from task creator and completer' using errcode='42501';
 end if;
 if not exists(
  select 1 from public.krim_warehouse_evidence e
  where e.task_id=v_task.id and e.evidence_type='inspection_report'
    and e.organization_id=v_task.organization_id and e.facility_id=v_task.facility_id
 ) then
  raise exception 'An inspection report must be attached to the task before quality review' using errcode='23514';
 end if;

 select * into v_inventory from public.krim_warehouse_inventory
 where id=p_inventory_id and organization_id=v_task.organization_id and facility_id=v_task.facility_id
   and lower(sku)=lower(v_task.sku) and lot_code is not distinct from v_task.lot_code
 for update;
 if not found then raise exception 'Inventory SKU/lot does not match the reviewed task' using errcode='23514'; end if;
 v_previous:=v_inventory.quality_status;
 update public.krim_warehouse_inventory
 set quality_status=p_decision,updated_at=now()
 where id=v_inventory.id returning * into v_inventory;

 insert into public.krim_warehouse_task_events(
  task_id,organization_id,facility_id,event_type,previous_status,new_status,metadata,actor_user_id
 ) values(
  v_task.id,v_task.organization_id,v_task.facility_id,'inventory.quality_reviewed',
  v_previous,p_decision,
  jsonb_build_object('inventory_id',v_inventory.id,'sku',v_inventory.sku,'lot_code',v_inventory.lot_code,'reason',btrim(p_reason),'independent_review',true),
  v_user
 );
 insert into public.krim_audit_events(
  actor_user_id,organization_id,event_type,entity_type,entity_id,source,metadata,previous_state,new_state
 ) values(
  v_user,v_task.organization_id,'warehouse.inventory.quality_reviewed','warehouse_inventory',v_inventory.id::text,'rpc',
  jsonb_build_object('task_id',v_task.id,'reason',btrim(p_reason)),
  jsonb_build_object('quality_status',v_previous),
  jsonb_build_object('quality_status',p_decision)
 );
 return jsonb_build_object('inventory_id',v_inventory.id,'quality_status',v_inventory.quality_status,'reviewed_by',v_user,'task_id',v_task.id);
end;
$function$;

revoke all on function public.krim_warehouse_review_inventory_quality(uuid,uuid,text,text) from public, anon;
grant execute on function public.krim_warehouse_review_inventory_quality(uuid,uuid,text,text) to authenticated;
