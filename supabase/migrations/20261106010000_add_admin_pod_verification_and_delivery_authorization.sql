-- AAL2-gated administration of submitted POD evidence and final delivery authorization.
do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname='storage' and tablename='objects'
      and policyname='Platform admins preview driver POD evidence'
  ) then
    create policy "Platform admins preview driver POD evidence"
    on storage.objects
    for select
    to authenticated
    using (
      bucket_id='krim-driver-evidence'
      and coalesce(auth.jwt()->>'aal','')='aal2'
      and private.krim_has_permission(auth.uid(),1,'admin.platform')
    );
  end if;
end $$;

create or replace function public.krim_admin_list_delivery_pods()
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
declare
 v_user uuid:=auth.uid();
 v_result jsonb;
begin
 if v_user is null then raise exception using errcode='28000',message='Authentication required'; end if;
 if coalesce(auth.jwt()->>'aal','')<>'aal2' then raise exception using errcode='42501',message='AAL2 MFA is required'; end if;
 if not private.krim_has_permission(v_user,1,'admin.platform') then
   raise exception using errcode='42501',message='Platform administrator permission required';
 end if;

 select jsonb_build_object('items',coalesce(jsonb_agg(to_jsonb(x) order by x.submitted_at desc),'[]'::jsonb))
 into v_result
 from (
   select p.id as pod_id,p.assignment_id,p.shipment_id,p.shipment_leg_id,p.partner_organization_id,
          p.status,p.pod_type,p.delivered_at,p.received_by_name,p.received_by_role,
          p.signature_reference,p.evidence_metadata,p.submitted_at,p.verified_at,
          s.shipment_number,s.status as shipment_status,
          o.legal_name as partner_name,l.leg_sequence,l.status as leg_status,
          l.destination_location_id
   from public.krim_pod_records p
   join public.krim_shipments s on s.id=p.shipment_id
   join public.krim_organizations o on o.id=p.partner_organization_id
   join public.krim_shipment_legs l on l.id=p.shipment_leg_id and l.shipment_id=p.shipment_id
   where p.pod_type='delivery' and p.status in ('submitted','under_review')
   order by p.submitted_at desc
   limit 100
 ) x;
 return coalesce(v_result,jsonb_build_object('items','[]'::jsonb));
end;
$function$;

create or replace function public.krim_admin_review_delivery_pod(
 p_pod_id bigint,
 p_decision text,
 p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
declare
 v_user uuid:=auth.uid();
 v_pod public.krim_pod_records%rowtype;
 v_review jsonb;
 v_authorization jsonb;
 v_driver_assignment_id uuid;
 v_driver_user_id uuid;
begin
 if v_user is null then raise exception using errcode='28000',message='Authentication required'; end if;
 if coalesce(auth.jwt()->>'aal','')<>'aal2' then raise exception using errcode='42501',message='AAL2 MFA is required'; end if;
 if not private.krim_has_permission(v_user,1,'admin.platform') then
   raise exception using errcode='42501',message='Platform administrator permission required';
 end if;
 if p_pod_id is null or p_decision not in ('verify','reject') then
   raise exception using errcode='22023',message='A valid POD and decision are required';
 end if;
 if nullif(btrim(p_reason),'') is null or length(btrim(p_reason))<5 or length(btrim(p_reason))>1000 then
   raise exception using errcode='22023',message='Decision reason must contain 5–1000 characters';
 end if;

 select * into v_pod
 from public.krim_pod_records
 where id=p_pod_id and pod_type='delivery'
 for update;
 if not found then raise exception using errcode='P0002',message='Delivery POD not found'; end if;
 if v_pod.status not in ('submitted','under_review') then
   raise exception using errcode='55000',message='POD is no longer awaiting review';
 end if;

 v_review:=public.krim_internal_verify_delivery_pod(v_pod.id,v_user,p_decision,p_reason);

 if p_decision='verify' then
   v_authorization:=public.krim_internal_authorize_delivery(v_pod.id,v_user);
   update public.krim_driver_assignments
   set status='delivered',updated_at=now()
   where partner_assignment_id=v_pod.assignment_id
     and status not in ('delivered','cancelled')
   returning id,user_id into v_driver_assignment_id,v_driver_user_id;
   if v_driver_assignment_id is not null then
     insert into public.krim_driver_trip_events(assignment_id,user_id,event_type,notes)
     values(v_driver_assignment_id,v_driver_user_id,'delivered',
       'Delivery authorized after POD verification by platform operations.');
   end if;
 end if;

 insert into public.krim_audit_events
 (actor_user_id,organization_id,event_type,entity_type,entity_id,source,metadata,previous_state,new_state,created_at)
 select v_user,s.customer_organization_id,'shipment.pod.review_decision','shipment',s.id::text,'platform_admin',
        jsonb_build_object('pod_id',v_pod.id,'decision',p_decision,'reason',btrim(p_reason),'partner_assignment_id',v_pod.assignment_id),
        jsonb_build_object('pod_status',v_pod.status),
        jsonb_build_object('pod_status',case when p_decision='verify' then 'verified_and_delivery_authorized' else 'rejected' end),
        now()
 from public.krim_shipments s where s.id=v_pod.shipment_id;

 return jsonb_build_object(
   'pod_id',v_pod.id,'decision',p_decision,'review',v_review,
   'delivery_authorization',v_authorization,
   'driver_assignment_id',v_driver_assignment_id
 );
end;
$function$;

revoke all on function public.krim_admin_list_delivery_pods() from public,anon;
revoke all on function public.krim_admin_review_delivery_pod(bigint,text,text) from public,anon;
grant execute on function public.krim_admin_list_delivery_pods() to authenticated;
grant execute on function public.krim_admin_review_delivery_pod(bigint,text,text) to authenticated;
