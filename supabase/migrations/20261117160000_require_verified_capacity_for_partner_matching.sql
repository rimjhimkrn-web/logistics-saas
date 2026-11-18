-- Partner matching must require real, approved, unreserved capacity for the requested service day.
create or replace function private.krim_internal_partner_has_verified_capacity(
  p_organization_id bigint,
  p_origin_location_id bigint,
  p_destination_location_id bigint,
  p_transport_mode_id bigint,
  p_weight_kg numeric,
  p_service_date date
)
returns boolean
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $function$
declare
  v_day_start timestamptz;
  v_day_end timestamptz;
  v_required numeric;
  v_unit text;
  v_availability record;
  v_reserved_availability numeric;
  v_reserved_resource numeric;
begin
  if p_organization_id is null or p_origin_location_id is null
     or p_destination_location_id is null or p_transport_mode_id is null
     or p_weight_kg is null or p_weight_kg <= 0 then
    return false;
  end if;

  v_day_start := coalesce(p_service_date, current_date)::timestamp at time zone 'UTC';
  v_day_end := v_day_start + interval '1 day';

  for v_availability in
    select a.id availability_id, a.capacity_resource_id, a.availability_type,
           a.capacity_value availability_capacity, a.capacity_unit availability_unit,
           r.capacity_value resource_capacity, r.capacity_unit resource_unit
    from public.krim_partner_capacity_availability a
    join public.krim_capacity_resources r
      on r.id = a.capacity_resource_id
     and r.organization_id = a.organization_id
    join public.krim_network_lanes nl
      on nl.id = a.lane_id
     and nl.origin_location_id = p_origin_location_id
     and nl.destination_location_id = p_destination_location_id
     and nl.transport_mode_id = p_transport_mode_id
     and nl.status = 'active'
    where a.organization_id = p_organization_id
      and a.transport_mode_id = p_transport_mode_id
      and a.status = 'available'
      and a.metadata->>'verification_state' = 'verified'
      and r.status = 'available'
      and r.metadata->>'verification_state' = 'verified'
      and r.transport_mode_id = p_transport_mode_id
      and r.location_id = p_origin_location_id
      and a.available_from < v_day_end
      and a.available_until >= v_day_start
      and (a.booking_window_start is null or a.booking_window_start < v_day_end)
      and (a.booking_window_end is null or a.booking_window_end >= v_day_start)
      and (r.available_from is null or r.available_from < v_day_end)
      and (r.available_until is null or r.available_until >= v_day_start)
      and lower(btrim(a.capacity_unit)) = lower(btrim(r.capacity_unit))
    order by a.id
    for update of a, r skip locked
  loop
    v_unit := lower(btrim(v_availability.availability_unit));
    if v_availability.availability_type = 'vehicle' then
      v_required := 1;
    elsif v_availability.availability_type = 'weight'
      and v_unit in ('kg','kgs','kilogram','kilograms') then
      v_required := p_weight_kg;
    elsif v_availability.availability_type = 'weight'
      and v_unit in ('t','tonne','tonnes','metric ton','metric tons') then
      v_required := p_weight_kg / 1000;
    else
      continue;
    end if;

    select coalesce(sum(rq.requested_capacity),0)
      into v_reserved_availability
    from public.krim_capacity_reservations rq
    where rq.capacity_availability_id = v_availability.availability_id
      and (rq.status = 'confirmed'
        or (rq.status = 'held' and (rq.hold_expires_at is null or rq.hold_expires_at > now())))
      and (
        rq.metadata->>'planned_departure' is null
        or rq.metadata->>'planned_arrival' is null
        or not pg_catalog.pg_input_is_valid(rq.metadata->>'planned_departure','timestamp with time zone')
        or not pg_catalog.pg_input_is_valid(rq.metadata->>'planned_arrival','timestamp with time zone')
        or ((rq.metadata->>'planned_departure')::timestamptz < v_day_end
          and (rq.metadata->>'planned_arrival')::timestamptz > v_day_start)
      );

    select coalesce(sum(rq.requested_capacity),0)
      into v_reserved_resource
    from public.krim_capacity_reservations rq
    join public.krim_partner_capacity_availability ra
      on ra.id = rq.capacity_availability_id
    where ra.capacity_resource_id = v_availability.capacity_resource_id
      and (rq.status = 'confirmed'
        or (rq.status = 'held' and (rq.hold_expires_at is null or rq.hold_expires_at > now())))
      and (
        rq.metadata->>'planned_departure' is null
        or rq.metadata->>'planned_arrival' is null
        or not pg_catalog.pg_input_is_valid(rq.metadata->>'planned_departure','timestamp with time zone')
        or not pg_catalog.pg_input_is_valid(rq.metadata->>'planned_arrival','timestamp with time zone')
        or ((rq.metadata->>'planned_departure')::timestamptz < v_day_end
          and (rq.metadata->>'planned_arrival')::timestamptz > v_day_start)
      );

    if least(
      v_availability.availability_capacity - v_reserved_availability,
      v_availability.resource_capacity - v_reserved_resource
    ) >= v_required then
      return true;
    end if;
  end loop;

  return false;
end;
$function$;

revoke all on function private.krim_internal_partner_has_verified_capacity(bigint,bigint,bigint,bigint,numeric,date) from public, anon, authenticated;

-- Patch the existing matching RPC without duplicating or replacing its other eligibility rules.
do $migration$
declare
  v_definition text;
  v_old text := $old$
      and pc.max_weight_kg >= v_weight
      and o.partner_lifecycle_status = 'active'
$old$;
  v_new text := $new$
      and pc.max_weight_kg >= v_weight
      and private.krim_internal_partner_has_verified_capacity(
        pc.organization_id,
        v_req.origin_location_id,
        v_req.destination_location_id,
        v_mode_id,
        v_weight,
        coalesce(v_req.requested_service_date, current_date)
      )
      and o.partner_lifecycle_status = 'active'
$new$;
begin
  select pg_get_functiondef(
    'public.krim_internal_create_partner_matching_run(bigint,bigint)'::regprocedure
  ) into v_definition;

  if position(v_old in v_definition) = 0 then
    raise exception 'Expected partner matching eligibility clause was not found; refusing to patch';
  end if;
  if position(v_new in v_definition) > 0 then
    raise exception 'Partner matching capacity gate is already installed';
  end if;

  v_definition := replace(v_definition, v_old, v_new);
  v_definition := replace(
    v_definition,
    '''verified_origin_and_destination_or_verified_route_lane''',
    '''verified_origin_and_destination_or_verified_route_lane_and_verified_capacity'''
  );
  v_definition := replace(
    v_definition,
    '''verified_weight_capacity''',
    '''verified_weight_capacity'', ''verified_available_capacity_window'''
  );

  execute v_definition;
end;
$migration$;
