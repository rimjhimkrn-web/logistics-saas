create or replace function public.krim_warehouse_register_evidence(
 p_task_id uuid,
 p_evidence_type text,
 p_storage_path text,
 p_description text,
 p_captured_at timestamptz default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
 v_user uuid := auth.uid();
 v_task public.krim_warehouse_tasks%rowtype;
 v_ev public.krim_warehouse_evidence%rowtype;
 v_object storage.objects%rowtype;
begin
 if v_user is null then
  raise exception 'Authentication required' using errcode='28000';
 end if;
 if p_task_id is null then
  raise exception 'Task is required' using errcode='22023';
 end if;
 if p_evidence_type not in ('arrival_photo','seal_record','damage_photo','count_sheet','inspection_report','dispatch_proof','other') then
  raise exception 'Unsupported evidence type' using errcode='22023';
 end if;
 if p_storage_path is null or length(p_storage_path)>500
    or cardinality(string_to_array(p_storage_path,'/'))<>3 then
  raise exception 'Evidence path must contain organisation, submitting user and one file name' using errcode='22023';
 end if;
 if split_part(p_storage_path,'/',1) !~ '^[0-9]+$'
    or split_part(p_storage_path,'/',1) !~ '^[0-9]+$'
    or split_part(p_storage_path,'/',2) <> v_user::text
    or split_part(p_storage_path,'/',3) in ('','.', '..') then
  raise exception 'Evidence path must be inside the submitting organisation and user folder' using errcode='42501';
 end if;
 if length(coalesce(p_description,''))>2000 then
  raise exception 'Evidence description exceeds 2,000 characters' using errcode='22023';
 end if;
 select * into v_task
 from public.krim_warehouse_tasks
 where id=p_task_id;
 if not found then
  raise exception 'Task not found' using errcode='P0002';
 end if;
 if not private.krim_warehouse_is_operator(v_user,v_task.organization_id,v_task.facility_id) then
  raise exception 'Warehouse evidence permission denied' using errcode='42501';
 end if;
 if split_part(p_storage_path,'/',1) <> v_task.organization_id::text then
  raise exception 'Evidence object organisation does not match the task' using errcode='42501';
 end if;
 select * into v_object
 from storage.objects
 where bucket_id='krim-warehouse-evidence'
   and name=p_storage_path
   and owner=v_user;
 if not found then
  raise exception 'Uploaded private evidence object owned by this user was not found' using errcode='P0002';
 end if;
 if coalesce((v_object.metadata->>'size')::bigint,0) not between 1 and 10485760 then
  raise exception 'Evidence file must be between 1 byte and 10 MB' using errcode='22023';
 end if;
 if coalesce(v_object.metadata->>'mimetype','') not in ('image/jpeg','image/png','application/pdf') then
  raise exception 'Unsupported evidence file type' using errcode='22023';
 end if;
 insert into public.krim_warehouse_evidence(
  task_id,organization_id,facility_id,storage_path,evidence_type,description,captured_at,created_by
 )
 values(
  v_task.id,v_task.organization_id,v_task.facility_id,p_storage_path,p_evidence_type,
  left(coalesce(p_description,''),2000),p_captured_at,v_user
 )
 returning * into v_ev;
 insert into public.krim_warehouse_task_events(
  task_id,organization_id,facility_id,event_type,metadata,actor_user_id
 )
 values(
  v_task.id,v_task.organization_id,v_task.facility_id,'task.evidence_added',
  jsonb_build_object('evidence_id',v_ev.id,'evidence_type',p_evidence_type),v_user
 );
 return jsonb_build_object('evidence_id',v_ev.id,'task_id',v_task.id,'status','stored_privately');
end;
$function$;
