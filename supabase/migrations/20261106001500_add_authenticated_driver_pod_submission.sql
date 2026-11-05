-- Bridge the authenticated driver assignment/evidence model to the verified partner-assignment POD lifecycle.
create or replace function public.krim_driver_submit_delivery_pod(
 p_driver_assignment_id uuid,
 p_received_by_name text,
 p_received_by_role text default null,
 p_signature_reference text default null
)
returns jsonb
language plpgsql
security definer
set search_path to 'public','auth','pg_temp'
as $function$
declare
 v_user uuid:=auth.uid();
 v_driver_assignment public.krim_driver_assignments%rowtype;
 v_partner_assignment public.krim_shipment_partner_assignments%rowtype;
 v_evidence jsonb;
 v_result jsonb;
begin
 if v_user is null then
   raise exception using errcode='28000',message='Authentication required';
 end if;
 if p_driver_assignment_id is null then
   raise exception using errcode='22023',message='Driver assignment is required';
 end if;
 if nullif(btrim(p_received_by_name),'') is null or length(btrim(p_received_by_name))>200 then
   raise exception using errcode='22023',message='A valid recipient name is required';
 end if;
 if length(coalesce(p_received_by_role,''))>120 or length(coalesce(p_signature_reference,''))>240 then
   raise exception using errcode='22023',message='Recipient role or signature reference is too long';
 end if;

 select * into v_driver_assignment
 from public.krim_driver_assignments
 where id=p_driver_assignment_id and user_id=v_user
 for update;
 if not found then
   raise exception using errcode='42501',message='Driver assignment not found for this account';
 end if;
 if not exists (
   select 1 from public.krim_organization_members m
   where m.user_id=v_user
     and m.organization_id=v_driver_assignment.organization_id
     and lower(m.role)='driver'
     and lower(m.status)='active'
 ) then
   raise exception using errcode='42501',message='Active driver membership is required';
 end if;
 if v_driver_assignment.status<>'in_transit' then
   raise exception using errcode='55000',message='Record pickup and in-transit milestones before submitting delivery evidence';
 end if;
 if v_driver_assignment.partner_assignment_id is null then
   raise exception using errcode='55000',message='This driver assignment is not linked to a commercial partner shipment leg; contact dispatch';
 end if;

 select * into v_partner_assignment
 from public.krim_shipment_partner_assignments
 where id=v_driver_assignment.partner_assignment_id
   and shipment_id=v_driver_assignment.shipment_id
   and partner_organization_id=v_driver_assignment.organization_id
   and status in ('accepted','active')
 for update;
 if not found then
   raise exception using errcode='42501',message='The linked partner shipment assignment is no longer eligible for POD submission';
 end if;

 select jsonb_agg(jsonb_build_object(
   'storage_path',e.storage_path,
   'file_name',e.original_file_name,
   'content_type',e.content_type,
   'file_size',e.file_size,
   'uploaded_at',e.created_at
 ) order by e.created_at)
 into v_evidence
 from public.krim_driver_delivery_evidence e
 join storage.objects o
   on o.bucket_id='krim-driver-evidence'
  and o.name=e.storage_path
  and o.owner=v_user
 where e.assignment_id=v_driver_assignment.id
   and e.user_id=v_user;
 if coalesce(jsonb_array_length(v_evidence),0)=0 then
   raise exception using errcode='55000',message='Register at least one private delivery evidence file before POD submission';
 end if;

 v_result:=public.krim_internal_submit_delivery_pod(
   v_partner_assignment.id,
   btrim(p_received_by_name),
   nullif(btrim(p_received_by_role),''),
   nullif(btrim(p_signature_reference),''),
   jsonb_build_object('driver_assignment_id',v_driver_assignment.id,'driver_evidence',v_evidence)
 );
 return v_result || jsonb_build_object('driver_assignment_id',v_driver_assignment.id,'shipment_leg_id',v_partner_assignment.shipment_leg_id);
end;
$function$;

revoke all on function public.krim_driver_submit_delivery_pod(uuid,text,text,text) from public,anon;
grant execute on function public.krim_driver_submit_delivery_pod(uuid,text,text,text) to authenticated;
