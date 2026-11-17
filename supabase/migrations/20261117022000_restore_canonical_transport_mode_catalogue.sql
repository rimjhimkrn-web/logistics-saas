-- Restore the canonical transport-mode reference catalogue.
-- IDs are allocated from the current table maximum (not hard-coded), and code is
-- the stable natural key used by booking and partner-opportunity workflows.
begin;

lock table public.krim_transport_modes in share row exclusive mode;

with canonical(code, name, category) as (
  values
    ('ROAD', 'Road Freight', 'surface'),
    ('RAIL', 'Rail Freight', 'surface'),
    ('OCEAN', 'Ocean Freight', 'international'),
    ('AIR', 'Air Freight', 'international'),
    ('MULTIMODAL', 'Multimodal Transport', 'combined'),
    ('WAREHOUSE', 'Warehouse Transfer', 'logistics'),
    ('SPECIALIST', 'Specialist Transport', 'specialist')
),
numbered as (
  select
    coalesce((select max(id) from public.krim_transport_modes), 0)
      + row_number() over (order by code) as id,
    code, name, category
  from canonical
)
insert into public.krim_transport_modes (id, code, name, is_active, category)
select id, code, name, true, category
from numbered
on conflict (code) do update
set name = excluded.name,
    is_active = true,
    category = excluded.category;

commit;

do $verify$
declare
  v_count integer;
  v_missing text[];
begin
  select count(*) into v_count
  from public.krim_transport_modes
  where code in ('ROAD','RAIL','OCEAN','AIR','MULTIMODAL','WAREHOUSE','SPECIALIST')
    and is_active is true;

  select array_agg(expected.code order by expected.code) into v_missing
  from (values
    ('ROAD'),('RAIL'),('OCEAN'),('AIR'),
    ('MULTIMODAL'),('WAREHOUSE'),('SPECIALIST')
  ) as expected(code)
  where not exists (
    select 1 from public.krim_transport_modes actual
    where actual.code=expected.code and actual.is_active is true
  );

  if v_count <> 7 or v_missing is not null then
    raise exception 'Transport-mode catalogue verification failed; active_count %, missing %', v_count, v_missing;
  end if;
end;
$verify$;
