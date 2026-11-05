-- Bind warehouse evidence metadata to the actual uploaded object owner.
-- Permit users to clean up only their own unregistered uploads.
create or replace function public.krim_warehouse_register_evidence(
 p_task_id uuid,p_evidence_type text,p_storage_path text,p_description text,
 p_captured_at timestamp with time zone default null
) returns jsonb language plpgsql security definer set search_path to ''
as $function$
declare v_user uuid:=auth.uid();v_task public.krim_warehouse_tasks%rowtype;v_ev public.krim_warehouse_evidence%rowtype;
begin
 if v_user is null then raise exception 'Authentication required' using errcode='28000';end if;
 select * into v_task from public.krim_warehouse_tasks where id=p_task_id;
 if not found then raise exception 'Task not found' using errcode='P0002';end if;
 if not private.krim_warehouse_is_operator(v_user,v_task.organization_id,v_task.facility_id) then raise exception 'Warehouse evidence permission denied' using errcode='42501';end if;
 if p_evidence_type not in ('arrival_photo','seal_record','damage_photo','count_sheet','inspection_report','dispatch_proof','other') then raise exception 'Unsupported evidence type' using errcode='22023';end if;
 if p_storage_path is null or split_part(p_storage_path,'/',1)<>v_task.organization_id::text
    or split_part(p_storage_path,'/',2)<>v_user::text or cardinality(string_to_array(p_storage_path,'/'))<>3 then
  raise exception 'Evidence path must use organisation/user/file structure for the submitting user' using errcode='42501';
 end if;
 if not exists(select 1 from storage.objects o where o.bucket_id='krim-warehouse-evidence' and o.name=p_storage_path
   and o.owner=v_user and coalesce(o.metadata->>'mimetype','') in ('image/jpeg','image/png','application/pdf')
   and coalesce(o.metadata->>'size','') ~ '^[0-9]+$' and (o.metadata->>'size')::bigint between 1 and 10485760) then
  raise exception 'An owned private JPEG, PNG or PDF evidence object up to 10 MB is required' using errcode='42501';
 end if;
 insert into public.krim_warehouse_evidence(task_id,organization_id,facility_id,storage_path,evidence_type,description,captured_at,created_by)
 values(v_task.id,v_task.organization_id,v_task.facility_id,p_storage_path,p_evidence_type,left(coalesce(p_description,''),2000),p_captured_at,v_user)
 returning * into v_ev;
 insert into public.krim_warehouse_task_events(task_id,organization_id,facility_id,event_type,metadata,actor_user_id)
 values(v_task.id,v_task.organization_id,v_task.facility_id,'task.evidence_added',jsonb_build_object('evidence_id',v_ev.id,'evidence_type',p_evidence_type),v_user);
 return jsonb_build_object('evidence_id',v_ev.id,'task_id',v_task.id,'status','stored_privately');
end;$function$;
drop policy if exists "krim_wh_evidence_cleanup_unregistered" on storage.objects;
create policy "krim_wh_evidence_cleanup_unregistered" on storage.objects for delete to authenticated using (
 bucket_id='krim-warehouse-evidence' and owner=(select auth.uid())
 and (storage.foldername(name))[2]=(select auth.uid())::text
 and (storage.foldername(name))[1] ~ '^[0-9]+$'
 and private.krim_warehouse_org_eligible(((storage.foldername(name))[1])::bigint)
 and private.krim_has_permission((select auth.uid()),((storage.foldername(name))[1])::bigint,'partner.manage')
 and exists(select 1 from public.krim_organization_members m where m.organization_id=((storage.foldername(objects.name))[1])::bigint and m.user_id=(select auth.uid()) and m.status='active')
 and not exists(select 1 from public.krim_warehouse_evidence e where e.bucket_id='krim-warehouse-evidence' and e.storage_path=objects.name)
);
