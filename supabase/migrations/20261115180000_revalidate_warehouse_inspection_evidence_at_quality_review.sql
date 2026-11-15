do $migration$
declare
  v_def text;
  v_old text;
  v_new text;
begin
  v_def := pg_get_functiondef('public.krim_warehouse_review_inventory_quality(uuid,uuid,text,text)'::regprocedure);
  if position('join storage.objects o' in v_def)>0 then
    return;
  end if;
  v_old := $old$ if not exists(
  select 1 from public.krim_warehouse_evidence e
  where e.task_id=v_task.id and e.evidence_type='inspection_report'
    and e.organization_id=v_task.organization_id and e.facility_id=v_task.facility_id
 ) then
  raise exception 'An inspection report must be attached to the task before quality review' using errcode='23514';
 end if;$old$;
  v_new := $new$ if not exists(
  select 1
  from public.krim_warehouse_evidence e
  join storage.objects o
    on o.bucket_id=e.bucket_id
   and o.name=e.storage_path
   and o.owner=e.created_by
  where e.task_id=v_task.id
    and e.evidence_type='inspection_report'
    and e.organization_id=v_task.organization_id
    and e.facility_id=v_task.facility_id
    and e.bucket_id='krim-warehouse-evidence'
    and e.created_by is distinct from v_user
    and split_part(e.storage_path,'/',1)=e.organization_id::text
    and split_part(e.storage_path,'/',2)=e.created_by::text
    and cardinality(string_to_array(e.storage_path,'/'))=3
    and coalesce(o.metadata->>'mimetype','') in ('image/jpeg','image/png','application/pdf')
    and coalesce(o.metadata->>'size','') ~ '^[0-9]+$'
    and (o.metadata->>'size')::bigint between 1 and 10485760
 ) then
  raise exception 'Independent quality review requires an existing, private, uploader-owned inspection report; the reviewer cannot approve their own evidence' using errcode='23514';
 end if;$new$;
  if position(v_old in v_def)=0 then
    raise exception 'Warehouse quality evidence validation block changed; no function was modified';
  end if;
  execute replace(v_def,v_old,v_new);
end;
$migration$;
