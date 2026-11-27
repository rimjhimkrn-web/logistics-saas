-- Phase 00: protect partner availability edits from stranding live reservations.
create or replace function private.krim_guard_capacity_availability_live_reservations()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_live_count bigint;
  v_live_capacity numeric;
begin
  if tg_op <> 'UPDATE' then
    return new;
  end if;

  select count(*), coalesce(sum(r.requested_capacity),0)
    into v_live_count, v_live_capacity
  from public.krim_capacity_reservations r
  where r.capacity_availability_id = old.id
    and r.status in ('held','confirmed')
    and (r.status <> 'held' or r.hold_expires_at is null or r.hold_expires_at > pg_catalog.now());

  if v_live_count = 0 then
    return new;
  end if;

  if new.organization_id is distinct from old.organization_id
     or new.capacity_resource_id is distinct from old.capacity_resource_id
     or new.lane_id is distinct from old.lane_id
     or new.transport_mode_id is distinct from old.transport_mode_id
     or lower(btrim(new.capacity_unit)) is distinct from lower(btrim(old.capacity_unit)) then
    raise exception using errcode='23514',
      message='Availability ownership, resource, lane, mode or unit cannot change while live reservations depend on it';
  end if;

  if new.status <> 'available' then
    raise exception using errcode='23514',
      message='Availability cannot be withdrawn while live reservations depend on it; release or reconcile reservations first';
  end if;

  if new.capacity_value < v_live_capacity then
    raise exception using errcode='23514',
      message='Availability capacity cannot be reduced below its live held and confirmed reservations';
  end if;

  if exists (
    select 1
    from public.krim_capacity_reservations r
    where r.capacity_availability_id = old.id
      and r.status in ('held','confirmed')
      and (r.status <> 'held' or r.hold_expires_at is null or r.hold_expires_at > pg_catalog.now())
      and (
        not pg_catalog.pg_input_is_valid(r.metadata->>'planned_departure','timestamp with time zone')
        or not pg_catalog.pg_input_is_valid(r.metadata->>'planned_arrival','timestamp with time zone')
        or (r.metadata->>'planned_departure')::timestamptz < new.available_from
        or (r.metadata->>'planned_arrival')::timestamptz > new.available_until
        or (new.booking_window_start is not null and (r.metadata->>'planned_departure')::timestamptz < new.booking_window_start)
        or (new.booking_window_end is not null and (r.metadata->>'planned_arrival')::timestamptz > new.booking_window_end)
      )
  ) then
    raise exception using errcode='23514',
      message='Availability or booking windows cannot be narrowed around live reservations';
  end if;

  return new;
end;
$function$;

drop trigger if exists trg_krim_guard_capacity_availability_live_reservations
  on public.krim_partner_capacity_availability;

create trigger trg_krim_guard_capacity_availability_live_reservations
before update on public.krim_partner_capacity_availability
for each row execute function private.krim_guard_capacity_availability_live_reservations();

comment on function private.krim_guard_capacity_availability_live_reservations() is
  'Prevents availability withdrawal, ownership/routing/unit changes, capacity reduction, or window narrowing while live held/confirmed reservations depend on the record.';
