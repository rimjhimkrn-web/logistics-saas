do $migration$
declare
  v_def text;
  v_old text;
  v_new text;
begin
  v_def := pg_get_functiondef('private.krim_guard_capacity_resource_overbooking()'::regprocedure);
  v_old := $old$declare v_resource_id bigint; v_org_id bigint; v_resource_org_id bigint; v_capacity numeric; v_unit text; v_resource_unit text; v_resource_status text; v_verification text; v_availability_status text; v_from timestamptz; v_until timestamptz; v_reserved numeric; begin$old$;
  v_new := $new$declare v_resource_id bigint; v_org_id bigint; v_resource_org_id bigint; v_capacity numeric; v_unit text; v_resource_unit text; v_resource_status text; v_verification text; v_availability_status text; v_from timestamptz; v_until timestamptz; v_booking_from timestamptz; v_booking_until timestamptz; v_resource_from timestamptz; v_resource_until timestamptz; v_planned_departure timestamptz; v_planned_arrival timestamptz; v_reserved numeric; begin$new$;
  if position(v_old in v_def)=0 then raise exception 'Capacity guard declaration changed'; end if;
  v_def := replace(v_def,v_old,v_new);

  v_old := $old$select r.id,r.organization_id,r.capacity_value,r.capacity_unit,r.status,r.metadata->>'verification_state',a.organization_id,a.status,a.available_from,a.available_until into v_resource_id,v_resource_org_id,v_capacity,v_resource_unit,v_resource_status,v_verification,v_org_id,v_availability_status,v_from,v_until from public.krim_capacity_resources r join public.krim_partner_capacity_availability a on a.capacity_resource_id=r.id where a.id=new.capacity_availability_id for update of r,a;$old$;
  v_new := $new$select r.id,r.organization_id,r.capacity_value,r.capacity_unit,r.status,r.metadata->>'verification_state',a.organization_id,a.status,a.available_from,a.available_until,a.booking_window_start,a.booking_window_end,r.available_from,r.available_until into v_resource_id,v_resource_org_id,v_capacity,v_resource_unit,v_resource_status,v_verification,v_org_id,v_availability_status,v_from,v_until,v_booking_from,v_booking_until,v_resource_from,v_resource_until from public.krim_capacity_resources r join public.krim_partner_capacity_availability a on a.capacity_resource_id=r.id where a.id=new.capacity_availability_id for update of r,a;$new$;
  if position(v_old in v_def)=0 then raise exception 'Capacity guard resource/availability lookup changed'; end if;
  v_def := replace(v_def,v_old,v_new);

  v_old := $old$if now()<v_from or now()>=v_until then raise exception using errcode='23514',message='Capacity availability window is not currently active'; end if;$old$;
  v_new := $new$begin
  v_planned_departure := nullif(new.metadata->>'planned_departure','')::timestamptz;
  v_planned_arrival := nullif(new.metadata->>'planned_arrival','')::timestamptz;
 exception when others then
  raise exception using errcode='22007',message='Reservation planned departure and arrival metadata must be valid timestamps';
 end;
 if v_planned_departure is null or v_planned_arrival is null
    or not isfinite(v_planned_departure) or not isfinite(v_planned_arrival)
    or v_planned_departure<now() or v_planned_arrival<=v_planned_departure then
  raise exception using errcode='23514',message='Reservation requires a valid future departure and later arrival';
 end if;
 if v_planned_departure<v_from or v_planned_arrival>v_until
    or v_resource_from is null or v_planned_departure<v_resource_from
    or v_resource_until is null or v_planned_arrival>v_resource_until
    or (v_booking_from is not null and v_planned_departure<v_booking_from)
    or (v_booking_until is not null and v_planned_arrival>v_booking_until) then
  raise exception using errcode='23514',message='Planned shipment interval must fit the verified resource, availability and booking windows';
 end if;$new$;
  if position(v_old in v_def)=0 then raise exception 'Capacity guard current-window check changed'; end if;
  v_def := replace(v_def,v_old,v_new);

  v_old := $old$select coalesce(sum(cr.requested_capacity),0) into v_reserved from public.krim_capacity_reservations cr join public.krim_partner_capacity_availability ca on ca.id=cr.capacity_availability_id where ca.capacity_resource_id=v_resource_id and cr.status in ('held','confirmed') and (cr.status<>'held' or cr.hold_expires_at is null or cr.hold_expires_at>now()) and (tg_op<>'UPDATE' or cr.id is distinct from old.id);$old$;
  v_new := $new$select coalesce(sum(cr.requested_capacity),0) into v_reserved
 from public.krim_capacity_reservations cr
 join public.krim_partner_capacity_availability ca on ca.id=cr.capacity_availability_id
 where ca.capacity_resource_id=v_resource_id
   and cr.status in ('held','confirmed')
   and (cr.status<>'held' or cr.hold_expires_at is null or cr.hold_expires_at>now())
   and (tg_op<>'UPDATE' or cr.id is distinct from old.id)
   and (
     cr.metadata->>'planned_departure' is null
     or cr.metadata->>'planned_arrival' is null
     or not pg_catalog.pg_input_is_valid(cr.metadata->>'planned_departure','timestamp with time zone')
     or not pg_catalog.pg_input_is_valid(cr.metadata->>'planned_arrival','timestamp with time zone')
     or (
       (cr.metadata->>'planned_departure')::timestamptz < v_planned_arrival
       and (cr.metadata->>'planned_arrival')::timestamptz > v_planned_departure
     )
   );$new$;
  if position(v_old in v_def)=0 then raise exception 'Capacity guard overbooking aggregation changed'; end if;
  v_def := replace(v_def,v_old,v_new);
  execute v_def;

  v_def := pg_get_functiondef('public.krim_partner_reserve_shipment_leg_capacity(bigint,timestamp with time zone,timestamp with time zone,text)'::regprocedure);
  v_old := $old$v_required numeric;v_reserved numeric;v_remaining numeric;v_unit text;$old$;
  v_new := $new$v_required numeric;v_reserved numeric;v_reserved_resource numeric;v_remaining numeric;v_unit text;$new$;
  if position(v_old in v_def)=0 then raise exception 'Capacity reservation RPC declaration changed'; end if;
  v_def := replace(v_def,v_old,v_new);

  v_old := $old$select coalesce(sum(rq.requested_capacity),0) into v_reserved from public.krim_capacity_reservations rq
  where rq.capacity_availability_id=v_availability.id
   and (rq.status='confirmed' or (rq.status='held' and (rq.hold_expires_at is null or rq.hold_expires_at>now())));
  v_remaining:=least(v_availability.capacity_value,v_availability.resource_capacity)-v_reserved;$old$;
  v_new := $new$select coalesce(sum(rq.requested_capacity),0) into v_reserved
  from public.krim_capacity_reservations rq
  where rq.capacity_availability_id=v_availability.id
   and (rq.status='confirmed' or (rq.status='held' and (rq.hold_expires_at is null or rq.hold_expires_at>now())))
   and (
     rq.metadata->>'planned_departure' is null
     or rq.metadata->>'planned_arrival' is null
     or not pg_catalog.pg_input_is_valid(rq.metadata->>'planned_departure','timestamp with time zone')
     or not pg_catalog.pg_input_is_valid(rq.metadata->>'planned_arrival','timestamp with time zone')
     or (
       (rq.metadata->>'planned_departure')::timestamptz < p_planned_arrival
       and (rq.metadata->>'planned_arrival')::timestamptz > p_planned_departure
     )
   );
  select coalesce(sum(rq.requested_capacity),0) into v_reserved_resource
  from public.krim_capacity_reservations rq
  join public.krim_partner_capacity_availability ra on ra.id=rq.capacity_availability_id
  where ra.capacity_resource_id=v_availability.capacity_resource_id
   and (rq.status='confirmed' or (rq.status='held' and (rq.hold_expires_at is null or rq.hold_expires_at>now())))
   and (
     rq.metadata->>'planned_departure' is null
     or rq.metadata->>'planned_arrival' is null
     or not pg_catalog.pg_input_is_valid(rq.metadata->>'planned_departure','timestamp with time zone')
     or not pg_catalog.pg_input_is_valid(rq.metadata->>'planned_arrival','timestamp with time zone')
     or (
       (rq.metadata->>'planned_departure')::timestamptz < p_planned_arrival
       and (rq.metadata->>'planned_arrival')::timestamptz > p_planned_departure
     )
   );
  v_remaining:=least(v_availability.capacity_value-v_reserved,v_availability.resource_capacity-v_reserved_resource);$new$;
  if position(v_old in v_def)=0 then raise exception 'Capacity reservation remaining-capacity calculation changed'; end if;
  v_def := replace(v_def,v_old,v_new);
  execute v_def;
end;
$migration$;
