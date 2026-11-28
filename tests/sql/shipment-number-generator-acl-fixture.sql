-- Isolated ACL fixture for the shipment-number generator hardening.
do $$
begin
 if not exists(select 1 from pg_roles where rolname='anon') then create role anon nologin; end if;
 if not exists(select 1 from pg_roles where rolname='authenticated') then create role authenticated nologin; end if;
 if not exists(select 1 from pg_roles where rolname='service_role') then create role service_role nologin bypassrls; end if;
end $$;

create sequence public.krim_shipment_number_seq;
create function public.generate_krim_shipment_number()
returns text language sql
set search_path to 'public','pg_catalog'
as $$ select 'KRIM-'||to_char(current_date,'YYYY')||'-'||lpad(nextval('public.krim_shipment_number_seq')::text,8,'0') $$;

create table public.krim_shipments(
 id bigint generated always as identity primary key,
 shipment_number text not null default public.generate_krim_shipment_number()
);
grant insert on public.krim_shipments to service_role;
grant usage,select,update on sequence public.krim_shipment_number_seq to public,anon,authenticated,service_role;
grant execute on function public.generate_krim_shipment_number() to public,anon,authenticated,service_role;
