do $migration$
declare
  v_def text;
  v_old text;
  v_new text;
begin
  v_def := pg_get_functiondef('public.krim_warehouse_review_inventory_quality(uuid,uuid,text,text)'::regprocedure);
  if position('already has a final quality decision' in v_def)>0 then
    return;
  end if;
  v_old := $old$ if v_task.task_type not in ('goods_receipt','damage_exception') or v_task.status<>'completed' then
  raise exception 'Quality review requires a completed goods receipt or damage exception task' using errcode='23514';
 end if;$old$;
  v_new := $new$ if v_task.task_type not in ('goods_receipt','damage_exception') or v_task.status<>'completed' then
  raise exception 'Quality review requires a completed goods receipt or damage exception task' using errcode='23514';
 end if;
 if exists(
  select 1 from public.krim_warehouse_task_events e
  where e.task_id=v_task.id and e.event_type='inventory.quality_reviewed'
 ) then
  raise exception 'This task already has a final quality decision; create a separately authorised reinspection task for any later review' using errcode='55000';
 end if;$new$;
  if position(v_old in v_def)=0 then raise exception 'Warehouse quality task-state guard changed; no function was modified'; end if;
  execute replace(v_def,v_old,v_new);
end;
$migration$;
