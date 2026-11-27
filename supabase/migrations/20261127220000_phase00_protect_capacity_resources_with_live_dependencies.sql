-- Phase 00: prevent resource retirement or material edits while live bookings depend on it.
create or replace function private.krim_guard_capacity_resource_live_dependencies()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_live_reservations bigint;
  v_live_bindings bigint;
begin
  if tg_op <> 'UPDATE' then
    return new;
  end if;

  select count(*) into v_live_reservations
  from public.krim_partner_capacity_availability a
  join public.krim_capacity_reservations r
    on r.capacity_availability_id = a.id
  where a.capacity_resource_id = old.id
    and r.status in ('held','confirmed')
    and (r.status <> 'held' or r.hold_expires_at is null or r.hold_expires_at > pg_catalog.now());

  select count(*) into v_live_bindings
  from public.krim_capacity_leg_bindings b
  join public.krim_partner_capacity_availability a
    on a.id = b.capacity_availability_id
  where a.capacity_resource_id = old.id
    and b.status in ('pending','held','confirmed');

  if v_live_reservations = 0 and v_live_bindings = 0 then
    return new;
  end if;

  if new.status not in ('available','verified') then
    raise exception using errcode='23514',
      message='Capacity resource cannot be retired, rejected or withdrawn while live reservations or bindings depend on it';
  end if;

  if new.organization_id is distinct from old.organization_id
     or new.resource_type is distinct from old.resource_type
     or new.transport_mode_id is distinct from old.transport_mode_id
     or new.location_id is distinct from old.location_id
     or lower(btrim(new.capacity_unit)) is distinct from lower(btrim(old.capacity_unit)) then
    raise exception using errcode='23514',
      message='Capacity resource ownership, type, mode, location or unit cannot change while live reservations or bindings depend on it';
  end if;

  if new.capacity_value < old.capacity_value
     or new.available_from > old.available_from
     or new.available_until < old.available_until then
    raise exception using errcode='23514',
      message='Capacity or operating window cannot be reduced while live reservations or bindings depend on the resource';
  end if;

  return new;
end;
$function$;

drop trigger if exists trg_krim_guard_capacity_resource_live_dependencies
  on public.krim_capacity_resources;

create trigger trg_krim_guard_capacity_resource_live_dependencies
before update on public.krim_capacity_resources
for each row execute function private.krim_guard_capacity_resource_live_dependencies();

comment on function private.krim_guard_capacity_resource_live_dependencies() is
  'Prevents capacity resource retirement, withdrawal, capacity reduction, operating-window narrowing or identity changes while live reservations or bindings depend on it.';
