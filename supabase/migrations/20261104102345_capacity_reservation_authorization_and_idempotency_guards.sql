create or replace function public.krim_partner_reserve_shipment_leg_capacity(p_assignment_id bigint,p_planned_departure timestamptz,p_planned_arrival timestamptz,p_idempotency_key text)
returns jsonb language plpgsql security definer set search_path = ''
as $function$
declare
 v_user_id uuid:=auth.uid();v_assignment public.krim_shipment_partner_assignments%rowtype;v_shipment public.krim_shipments%rowtype;
 v_leg public.krim_shipment_legs%rowtype;v_org public.krim_organizations%rowtype;v_availability record;
 v_binding public.krim_capacity_leg_bindings%rowtype;v_reservation_id bigint;v_binding_id bigint;v_reservation_status text;
 v_required numeric;v_reserved numeric;v_remaining numeric;v_unit text;v_selected boolean:=false;
begin
 if v_user_id is null then raise exception using errcode='28000',message='Authentication required';end if;
 if p_assignment_id is null or p_assignment_id<=0 then raise exception using errcode='22023',message='A valid partner assignment is required';end if;
 if p_idempotency_key is null or length(btrim(p_idempotency_key))<10 or length(p_idempotency_key)>120 then raise exception using errcode='22023',message='A 10–120 character idempotency key is required';end if;
 if p_planned_departure is null or p_planned_arrival is null or not isfinite(p_planned_departure) or not isfinite(p_planned_arrival) or p_planned_departure<now() or p_planned_arrival<=p_planned_departure then
  raise exception using errcode='22023',message='Provide a valid future departure and a later arrival time';
 end if;
 select * into v_assignment from public.krim_shipment_partner_assignments where id=p_assignment_id for update;
 if not found then raise exception using errcode='P0002',message='Partner assignment not found';end if;
 if not exists(select 1 from public.krim_organization_members m where m.user_id=v_user_id and m.organization_id=v_assignment.partner_organization_id and lower(m.status)='active')
  or not private.krim_has_permission(v_user_id,v_assignment.partner_organization_id,'shipment.update') then
  raise exception using errcode='42501',message='Active partner membership and shipment.update permission are required';
 end if;
 if v_assignment.status not in ('accepted','active') then raise exception using errcode='55000',message='Only an accepted or active assignment can reserve capacity';end if;
 if v_assignment.shipment_leg_id is null then raise exception using errcode='23514',message='Assignment has no shipment leg; accept the assignment first';end if;
 select * into v_org from public.krim_organizations where id=v_assignment.partner_organization_id for update;
 if not found or coalesce(v_org.status,'')<>'active' or coalesce(v_org.partner_account_mode,'')<>'registered_business'
  or coalesce(v_org.partner_verification_status,'') not in ('verified','approved') or coalesce(v_org.partner_lifecycle_status,'') not in ('active','verified')
  or coalesce(v_org.partner_compliance_status,'') not in ('clear','compliant','approved','verified','not_required','not_applicable') then
  raise exception using errcode='42501',message='Partner organisation is not commercially eligible for capacity reservation';
 end if;
 select * into v_shipment from public.krim_shipments where id=v_assignment.shipment_id for update;
 if not found or v_shipment.status in ('cancelled','completed','delivered','failed') then raise exception using errcode='55000',message='Shipment is missing or no longer eligible for capacity reservation';end if;
 select * into v_leg from public.krim_shipment_legs where id=v_assignment.shipment_leg_id and shipment_id=v_assignment.shipment_id for update;
 if not found or v_leg.partner_organization_id is distinct from v_assignment.partner_organization_id or v_leg.transport_mode_id is null then
  raise exception using errcode='23514',message='Shipment leg does not match the assigned partner and transport mode';
 end if;
 if v_leg.status not in ('planned','assigned') then raise exception using errcode='55000',message='Capacity can only be reserved before dispatch or transit';end if;
 if not private.krim_partner_capability_covers_shipment(v_assignment.partner_organization_id,v_shipment.id) then
  raise exception using errcode='42501',message='Verified partner capability no longer covers this shipment route, mode or weight';
 end if;
 select * into v_binding from public.krim_capacity_leg_bindings where shipment_leg_id=v_leg.id for update;
 if found and v_binding.status in ('held','confirmed') and v_binding.reservation_id is not null then
  update public.krim_shipment_partner_assignments set capacity_binding_id=v_binding.id,updated_at=now() where id=v_assignment.id and capacity_binding_id is distinct from v_binding.id;
  return jsonb_build_object('assignment_id',v_assignment.id,'reservation_id',v_binding.reservation_id,'binding_id',v_binding.id,'status',v_binding.status,'idempotent_reuse',true);
 end if;
 select r.id,b.id,r.status into v_reservation_id,v_binding_id,v_reservation_status from public.krim_capacity_reservations r
 left join public.krim_capacity_leg_bindings b on b.reservation_id=r.id
 where r.organization_id=v_assignment.partner_organization_id and r.idempotency_key=p_idempotency_key limit 1;
 if v_reservation_id is not null then
  if not exists(select 1 from public.krim_capacity_reservations r where r.id=v_reservation_id and r.shipment_id=v_assignment.shipment_id and r.shipment_leg_id=v_leg.id) then
   raise exception using errcode='23505',message='Idempotency key has already been used for another shipment leg';
  end if;
  if v_reservation_status not in ('held','confirmed') then raise exception using errcode='55000',message='This idempotency key belongs to a released or inactive reservation';end if;
  if v_binding_id is null then raise exception using errcode='55000',message='Existing reservation has no linked capacity binding; contact platform operations';end if;
  return jsonb_build_object('assignment_id',v_assignment.id,'reservation_id',v_reservation_id,'binding_id',v_binding_id,'status',v_reservation_status,'idempotent_reuse',true);
 end if;
 for v_availability in
  select a.*,r.resource_type,r.resource_name,r.capacity_value as resource_capacity,r.capacity_unit as resource_unit,r.location_id as resource_location_id,
   r.available_from as resource_available_from,r.available_until as resource_available_until
  from public.krim_partner_capacity_availability a join public.krim_capacity_resources r on r.id=a.capacity_resource_id
  where a.organization_id=v_assignment.partner_organization_id and a.transport_mode_id=v_leg.transport_mode_id and a.status='available'
   and a.metadata->>'verification_state'='verified' and a.available_from<=p_planned_departure and a.available_until>=p_planned_arrival
   and (a.booking_window_start is null or a.booking_window_start<=p_planned_departure) and (a.booking_window_end is null or a.booking_window_end>=p_planned_arrival)
   and r.status='available' and r.metadata->>'verification_state'='verified' and r.location_id=v_leg.origin_location_id
   and r.available_from<=p_planned_departure and r.available_until>=p_planned_arrival
   and lower(a.capacity_unit)=lower(r.capacity_unit) and a.availability_type in ('weight','vehicle')
  order by case when a.availability_type='weight' then 0 else 1 end,a.available_until,a.id for update of a skip locked
 loop
  if v_availability.availability_type='weight' then
   if v_shipment.total_weight_kg is null or v_shipment.total_weight_kg<=0 then continue;end if;
   v_unit:=lower(btrim(v_availability.capacity_unit));
   if v_unit in ('kg','kgs','kilogram','kilograms') then v_required:=v_shipment.total_weight_kg;
   elsif v_unit in ('t','tonne','tonnes','metric ton','metric tons') then v_required:=v_shipment.total_weight_kg/1000;else continue;end if;
  else v_required:=1;end if;
  select coalesce(sum(rq.requested_capacity),0) into v_reserved from public.krim_capacity_reservations rq
  where rq.capacity_availability_id=v_availability.id and (rq.status='confirmed' or (rq.status='held' and (rq.hold_expires_at is null or rq.hold_expires_at>now())));
  v_remaining:=least(v_availability.capacity_value,v_availability.resource_capacity)-v_reserved;
  if v_remaining>=v_required then v_selected:=true;exit;end if;
 end loop;
 if not v_selected then raise exception using errcode='P0001',message='No approved and available vehicle or weight capacity matches this partner, route, mode and scheduled time window';end if;
 insert into public.krim_capacity_reservations(organization_id,capacity_availability_id,shipment_id,shipment_leg_id,reservation_number,requested_capacity,capacity_unit,status,confirmed_at,overbooking_allowed,idempotency_key,metadata)
 values(v_assignment.partner_organization_id,v_availability.id,v_shipment.id,v_leg.id,'KRIM-RES-'||to_char(clock_timestamp(),'YYYYMMDDHH24MISSMS')||'-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,6)),
  v_required,v_availability.capacity_unit,'confirmed',now(),false,p_idempotency_key,jsonb_build_object('source','partner_assignment_capacity_reservation','resource_id',v_availability.capacity_resource_id,'resource_type',v_availability.resource_type,'planned_departure',p_planned_departure,'planned_arrival',p_planned_arrival,'reserved_by',v_user_id))
 returning id into v_reservation_id;
 if v_binding.id is null then
  insert into public.krim_capacity_leg_bindings(shipment_id,shipment_leg_id,reservation_id,capacity_availability_id,binding_number,status,requested_capacity,capacity_unit,bound_capacity,idempotency_key,requested_by,bound_at,metadata)
  values(v_shipment.id,v_leg.id,v_reservation_id,v_availability.id,'KRIM-CAPB-'||to_char(clock_timestamp(),'YYYYMMDDHH24MISSMS')||'-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,6)),
   'confirmed',v_required,v_availability.capacity_unit,v_required,p_idempotency_key,v_user_id,now(),jsonb_build_object('resource_id',v_availability.capacity_resource_id,'availability_type',v_availability.availability_type))
  returning id into v_binding_id;
 else
  update public.krim_capacity_leg_bindings set reservation_id=v_reservation_id,capacity_availability_id=v_availability.id,status='confirmed',requested_capacity=v_required,capacity_unit=v_availability.capacity_unit,bound_capacity=v_required,
   idempotency_key=p_idempotency_key,requested_by=v_user_id,bound_at=now(),released_at=null,release_reason=null,
   metadata=coalesce(metadata,'{}'::jsonb)||jsonb_build_object('resource_id',v_availability.capacity_resource_id,'availability_type',v_availability.availability_type),updated_at=now()
  where id=v_binding.id returning id into v_binding_id;
 end if;
 update public.krim_capacity_leg_bindings set reservation_id=v_reservation_id,capacity_availability_id=v_availability.id,status='confirmed',bound_capacity=v_required,updated_at=now() where id=v_binding_id;
 update public.krim_shipment_legs set planned_departure=p_planned_departure,planned_arrival=p_planned_arrival,updated_at=now() where id=v_leg.id;
 update public.krim_shipment_partner_assignments set capacity_binding_id=v_binding_id,updated_at=now() where id=v_assignment.id;
 insert into public.krim_capacity_reservation_events(reservation_id,event_type,previous_status,new_status,actor_user_id,reason,payload)
 values(v_reservation_id,'capacity_reserved',null,'confirmed',v_user_id,'Partner accepted assignment and reserved verified capacity',jsonb_build_object('assignment_id',v_assignment.id,'binding_id',v_binding_id,'availability_id',v_availability.id));
 insert into public.krim_capacity_leg_binding_events(binding_id,event_type,previous_status,new_status,actor_user_id,payload)
 values(v_binding_id,'capacity_confirmed',v_binding.status,'confirmed',v_user_id,jsonb_build_object('reservation_id',v_reservation_id,'availability_id',v_availability.id));
 insert into public.krim_audit_events(actor_user_id,organization_id,event_type,entity_type,entity_id,source,metadata,previous_state,new_state)
 values(v_user_id,v_assignment.partner_organization_id,'partner.capacity.reserved','capacity_reservation',v_reservation_id::text,'partner_assignment_capacity',
  jsonb_build_object('assignment_id',v_assignment.id,'shipment_id',v_shipment.id,'shipment_leg_id',v_leg.id),jsonb_build_object('availability_id',v_availability.id,'remaining_before',v_remaining),
  jsonb_build_object('requested_capacity',v_required,'capacity_unit',v_availability.capacity_unit,'binding_id',v_binding_id));
 return jsonb_build_object('assignment_id',v_assignment.id,'shipment_id',v_shipment.id,'shipment_leg_id',v_leg.id,'reservation_id',v_reservation_id,'binding_id',v_binding_id,'availability_id',v_availability.id,'requested_capacity',v_required,'capacity_unit',v_availability.capacity_unit,'status','confirmed','resource_name',v_availability.resource_name);
end;
$function$;
revoke all on function public.krim_partner_reserve_shipment_leg_capacity(bigint,timestamptz,timestamptz,text) from public,anon,authenticated;
grant execute on function public.krim_partner_reserve_shipment_leg_capacity(bigint,timestamptz,timestamptz,text) to authenticated;