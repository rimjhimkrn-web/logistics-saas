-- KRIM Global Operations: secure persistence for the 12 operational registers.
-- Initial access is per-user only. Do not broaden to team/org sharing until role/RLS tests pass.
create table if not exists public.krim_global_ops_records (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references auth.users(id) on delete cascade,
 module_key text not null check (module_key in ('network-coverage','trade-lane-management','trade-document-packs','landed-cost','customer-support-cases','cargo-claims-disputes','carrier-contracts','fleet-maintenance','order-fulfilment','reverse-logistics','market-regulatory-config','business-continuity')),
 record_data jsonb not null default '{}'::jsonb,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 constraint krim_global_ops_record_data_object check (jsonb_typeof(record_data) = 'object'),
 constraint krim_global_ops_record_data_size check (octet_length(record_data::text) <= 16384)
);
create index if not exists krim_global_ops_records_owner_module_created_idx on public.krim_global_ops_records(user_id,module_key,created_at desc);
alter table public.krim_global_ops_records enable row level security;
revoke all on public.krim_global_ops_records from anon, public;
grant select, insert, update, delete on public.krim_global_ops_records to authenticated;
drop policy if exists krim_global_ops_records_select_own on public.krim_global_ops_records;
create policy krim_global_ops_records_select_own on public.krim_global_ops_records for select to authenticated using (user_id = (select auth.uid()));
drop policy if exists krim_global_ops_records_insert_own on public.krim_global_ops_records;
create policy krim_global_ops_records_insert_own on public.krim_global_ops_records for insert to authenticated with check (user_id = (select auth.uid()));
drop policy if exists krim_global_ops_records_update_own on public.krim_global_ops_records;
create policy krim_global_ops_records_update_own on public.krim_global_ops_records for update to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
drop policy if exists krim_global_ops_records_delete_own on public.krim_global_ops_records;
create policy krim_global_ops_records_delete_own on public.krim_global_ops_records for delete to authenticated using (user_id = (select auth.uid()));
create or replace function public.krim_global_ops_set_updated_at() returns trigger language plpgsql set search_path = '' as $$
begin new.updated_at = now(); return new; end; $$;
revoke all on function public.krim_global_ops_set_updated_at() from public, anon, authenticated;
drop trigger if exists krim_global_ops_records_updated_at on public.krim_global_ops_records;
create trigger krim_global_ops_records_updated_at before update on public.krim_global_ops_records for each row execute function public.krim_global_ops_set_updated_at();
