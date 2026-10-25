-- Assign a location to an existing active KRIM market only when exactly one
-- active market exists for its country. Never create/activate markets here.
begin;

create or replace function public.krim_assign_active_market_to_location()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $function$
declare
  v_market_count integer;
  v_market_id bigint;
begin
  if new.market_id is null and new.country_id is not null then
    select count(*)::integer, min(m.id)
      into v_market_count, v_market_id
    from public.krim_markets m
    where m.country_id = new.country_id
      and m.is_active is true
      and m.status = 'active';

    -- Fail closed if no active market exists or the country has ambiguous markets.
    if v_market_count = 1 then
      new.market_id := v_market_id;
    end if;
  end if;
  return new;
end;
$function$;

drop trigger if exists trg_krim_locations_assign_active_market on public.krim_locations;
create trigger trg_krim_locations_assign_active_market
before insert or update of country_id, market_id
on public.krim_locations
for each row
execute function public.krim_assign_active_market_to_location();

-- Backfill only locations whose country has exactly one active market.
update public.krim_locations l
set market_id = candidates.market_id
from (
  select m.country_id, min(m.id) as market_id
  from public.krim_markets m
  where m.is_active is true and m.status = 'active'
  group by m.country_id
  having count(*) = 1
) candidates
where l.market_id is null
  and l.country_id = candidates.country_id;

commit;
