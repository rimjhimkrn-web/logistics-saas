-- Prevent a partner member from recording milestones against another leg,
-- and reserve the delivered event for verified POD authorization.
create or replace function public.krim_record_operational_milestone(
 p_shipment_id bigint,p_milestone_type text,p_notes text default null,
 p_latitude numeric default null,p_longitude numeric default null
)
returns jsonb language plpgsql security definer
set search_path to 'public','private','auth','pg_catalog'
as $function$
declare
 v_uid uuid:=auth.uid();
 v_assignment public.krim_shipment_partner_assignments%rowtype;
 v_member_role text;
 v_shipment public.krim_shipments%rowtype;
 v_event_id bigint;
 v_milestone_id bigint;
 v_candidate_count integer;
 v_type text:=lower(trim(coalesce(p_milestone_type,'')));
 v_notes text:=nullif(trim(coalesce(p_notes,'')),'');
 v_now timestamptz:=now();
begin
 if v_uid is null then raise exception using errcode='28000',message='Authentication required'; end if;
 if p_shipment_id is null then raise exception 'Shipment is required'; end if;
 if v_type not in ('pickup_arrived','pickup_completed','departed_origin','in_transit','arrived_checkpoint','delivery_arrived','exception_reported') then
   if v_type='delivered' then raise exception using errcode='55000',message='Final delivery can only be recorded after verified POD and delivery authorization'; end if;
   raise exception 'Unsupported operational milestone';
 end if;
 if length(coalesce(v_notes,''))>1000 then raise exception 'Notes must be 1000 characters or fewer'; end if;
 if (p_latitude is not null and (p_latitude < -90 or p_latitude > 90)) or (p_longitude is not null and (p_longitude < -180 or p_longitude > 180)) then raise exception 'GPS coordinates are outside valid ranges'; end if;
 if (p_latitude is null) <> (p_longitude is null) then raise exception 'Provide both latitude and longitude, or neither'; end if;

 select * into v_shipment from public.krim_shipments where id=p_shipment_id for update;
 if not found then raise exception 'Shipment not found'; end if;

 select count(distinct a.id)::integer into v_candidate_count
 from public.krim_shipment_partner_assignments a
 join public.krim_organization_members m on m.organization_id=a.partner_organization_id and m.user_id=v_uid and lower(m.status)='active'
 where a.shipment_id=p_shipment_id and a.status in ('accepted','active','in_progress','assigned')
 and (
  (lower(m.role)='driver' and exists(select 1 from public.krim_driver_assignments da where da.partner_assignment_id=a.id and da.shipment_id=p_shipment_id and da.user_id=v_uid and da.status not in ('delivered','cancelled')))
  or
  (lower(m.role)<>'driver' and (public.krim_has_permission(v_uid,a.partner_organization_id,'shipment.update') or public.krim_has_permission(v_uid,a.partner_organization_id,'shipment.dispatch')))
 );
 if v_candidate_count=0 then raise exception using errcode='42501',message='No active partner assignment is available to this user'; end if;
 if v_candidate_count>1 then raise exception using errcode='22023',message='Multiple active shipment legs are available. Use the leg-specific milestone workflow; no ambiguous event was recorded'; end if;

 select a.* into v_assignment
 from public.krim_shipment_partner_assignments a
 join public.krim_organization_members m on m.organization_id=a.partner_organization_id and m.user_id=v_uid and lower(m.status)='active'
 where a.shipment_id=p_shipment_id and a.status in ('accepted','active','in_progress','assigned')
 and (
  (lower(m.role)='driver' and exists(select 1 from public.krim_driver_assignments da where da.partner_assignment_id=a.id and da.shipment_id=p_shipment_id and da.user_id=v_uid and da.status not in ('delivered','cancelled')))
  or
  (lower(m.role)<>'driver' and (public.krim_has_permission(v_uid,a.partner_organization_id,'shipment.update') or public.krim_has_permission(v_uid,a.partner_organization_id,'shipment.dispatch')))
 )
 order by a.accepted_at desc nulls last,a.created_at desc
 limit 1
 for update of a;

 select m.role into v_member_role
 from public.krim_organization_members m
 where m.organization_id=v_assignment.partner_organization_id and m.user_id=v_uid and lower(m.status)='active'
 order by case when lower(m.role)='driver' then 0 else 1 end
 limit 1;

 if v_shipment.status in ('cancelled','canceled','delivered','closed','archived') and v_type<>'exception_reported' then raise exception 'This shipment is closed; only an exception report may be added'; end if;

 select e.id into v_event_id from public.krim_tracking_events e
 where e.shipment_id=p_shipment_id and e.assignment_id=v_assignment.id and e.event_type=v_type and e.event_time>=v_now-interval '60 seconds'
 order by e.event_time desc limit 1;
 if v_event_id is not null then return jsonb_build_object('ok',true,'duplicate',true,'tracking_event_id',v_event_id); end if;

 insert into public.krim_shipment_milestones(shipment_id,milestone_type,actual_at,status,notes,responsible_partner_organization_id,responsible_assignment_id)
 values(p_shipment_id,v_type,v_now,'completed',v_notes,v_assignment.partner_organization_id,v_assignment.id)
 returning id into v_milestone_id;

 insert into public.krim_tracking_events(shipment_id,shipment_leg_id,event_type,event_time,source_type,source_reference,latitude,longitude,metadata,partner_organization_id,assignment_id)
 values(p_shipment_id,v_assignment.shipment_leg_id,v_type,v_now,'manual','assignment:'||v_assignment.id::text,p_latitude,p_longitude,
 jsonb_build_object('milestone_id',v_milestone_id,'notes',v_notes,'recorded_by',v_uid,'member_role',v_member_role),
 v_assignment.partner_organization_id,v_assignment.id)
 returning id into v_event_id;

 return jsonb_build_object('ok',true,'duplicate',false,'milestone_id',v_milestone_id,'tracking_event_id',v_event_id,'event_time',v_now);
end;
$function$;
