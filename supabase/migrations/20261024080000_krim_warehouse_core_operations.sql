-- KRIM warehouse operational foundation.
-- Applied to Supabase project ebltviniygljwwseplph.
create table if not exists public.krim_warehouse_facilities (
 id uuid primary key default gen_random_uuid(),
 organization_id bigint not null references public.krim_organizations(id) on delete restrict,
 facility_code text not null, facility_name text not null, country_code text,
 address_text text, timezone text not null default 'UTC',
 status text not null default 'active' check (status in ('active','inactive','maintenance')),
 created_by uuid not null default auth.uid(), created_at timestamptz not null default now(),
 unique (organization_id, facility_code)
);
create table if not exists public.krim_warehouse_receipts (
 id uuid primary key default gen_random_uuid(),
 organization_id bigint not null references public.krim_organizations(id) on delete restrict,
 facility_id uuid not null references public.krim_warehouse_facilities(id) on delete restrict,
 shipment_id bigint references public.krim_shipments(id) on delete restrict,
 receipt_reference text not null,
 status text not null default 'expected' check (status in ('expected','received','quality_hold','put_away','cancelled')),
 notes text not null default '', created_by uuid not null default auth.uid(), created_at timestamptz not null default now(),
 unique (organization_id, receipt_reference)
);
create table if not exists public.krim_warehouse_inventory (
 id uuid primary key default gen_random_uuid(),
 organization_id bigint not null references public.krim_organizations(id) on delete restrict,
 facility_id uuid not null references public.krim_warehouse_facilities(id) on delete restrict,
 sku text not null, item_description text not null, lot_code text,
 quantity numeric(18,3) not null default 0 check (quantity >= 0),
 unit_code text not null default 'unit', storage_location text,
 quality_status text not null default 'pending' check (quality_status in ('pending','released','hold','rejected')),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 unique (organization_id, facility_id, sku, lot_code), unique (id, organization_id, facility_id)
);
create table if not exists public.krim_warehouse_inventory_movements (
 id uuid primary key default gen_random_uuid(),
 organization_id bigint not null references public.krim_organizations(id) on delete restrict,
 facility_id uuid not null references public.krim_warehouse_facilities(id) on delete restrict,
 inventory_id uuid not null,
 movement_type text not null check (movement_type in ('receipt','putaway','pick','dispatch','adjustment','return','transfer')),
 quantity_delta numeric(18,3) not null check (quantity_delta <> 0),
 reference_type text, reference_id text, notes text not null default '',
 created_by uuid not null default auth.uid(), created_at timestamptz not null default now(),
 constraint krim_warehouse_movements_inventory_fk foreign key (inventory_id, organization_id, facility_id)
 references public.krim_warehouse_inventory(id, organization_id, facility_id) on delete restrict
);
create index if not exists idx_krim_wh_facilities_org on public.krim_warehouse_facilities(organization_id);
create index if not exists idx_krim_wh_receipts_facility_status on public.krim_warehouse_receipts(facility_id,status);
create index if not exists idx_krim_wh_inventory_facility_sku on public.krim_warehouse_inventory(facility_id,sku);
create index if not exists idx_krim_wh_movements_inventory_time on public.krim_warehouse_inventory_movements(inventory_id,created_at desc);
alter table public.krim_warehouse_facilities enable row level security;
alter table public.krim_warehouse_receipts enable row level security;
alter table public.krim_warehouse_inventory enable row level security;
alter table public.krim_warehouse_inventory_movements enable row level security;
create policy krim_wh_facilities_org_member on public.krim_warehouse_facilities for all to authenticated
using (exists (select 1 from public.krim_organization_members m join public.krim_organizations o on o.id=m.organization_id where m.organization_id=krim_warehouse_facilities.organization_id and m.user_id=auth.uid() and m.status='active' and (o.organization_type ilike '%warehouse%' or o.organization_type_code ilike '%warehouse%' or o.organization_type ilike '%fulfilment%' or o.organization_type_code ilike '%fulfilment%' or o.organization_type ilike '%fulfillment%' or o.organization_type_code ilike '%fulfillment%')))
with check (exists (select 1 from public.krim_organization_members m join public.krim_organizations o on o.id=m.organization_id where m.organization_id=krim_warehouse_facilities.organization_id and m.user_id=auth.uid() and m.status='active' and (o.organization_type ilike '%warehouse%' or o.organization_type_code ilike '%warehouse%' or o.organization_type ilike '%fulfilment%' or o.organization_type_code ilike '%fulfilment%' or o.organization_type ilike '%fulfillment%' or o.organization_type_code ilike '%fulfillment%')));
create policy krim_wh_receipts_org_member on public.krim_warehouse_receipts for all to authenticated
using (exists (select 1 from public.krim_organization_members m where m.organization_id=krim_warehouse_receipts.organization_id and m.user_id=auth.uid() and m.status='active') and exists (select 1 from public.krim_warehouse_facilities f where f.id=krim_warehouse_receipts.facility_id and f.organization_id=krim_warehouse_receipts.organization_id))
with check (exists (select 1 from public.krim_organization_members m where m.organization_id=krim_warehouse_receipts.organization_id and m.user_id=auth.uid() and m.status='active') and exists (select 1 from public.krim_warehouse_facilities f where f.id=krim_warehouse_receipts.facility_id and f.organization_id=krim_warehouse_receipts.organization_id));
create policy krim_wh_inventory_org_member on public.krim_warehouse_inventory for all to authenticated
using (exists (select 1 from public.krim_organization_members m where m.organization_id=krim_warehouse_inventory.organization_id and m.user_id=auth.uid() and m.status='active') and exists (select 1 from public.krim_warehouse_facilities f where f.id=krim_warehouse_inventory.facility_id and f.organization_id=krim_warehouse_inventory.organization_id))
with check (exists (select 1 from public.krim_organization_members m where m.organization_id=krim_warehouse_inventory.organization_id and m.user_id=auth.uid() and m.status='active') and exists (select 1 from public.krim_warehouse_facilities f where f.id=krim_warehouse_inventory.facility_id and f.organization_id=krim_warehouse_inventory.organization_id));
create policy krim_wh_movements_select_member on public.krim_warehouse_inventory_movements for select to authenticated
using (exists (select 1 from public.krim_organization_members m where m.organization_id=krim_warehouse_inventory_movements.organization_id and m.user_id=auth.uid() and m.status='active'));
create policy krim_wh_movements_insert_member on public.krim_warehouse_inventory_movements for insert to authenticated
with check (created_by=auth.uid() and exists (select 1 from public.krim_organization_members m where m.organization_id=krim_warehouse_inventory_movements.organization_id and m.user_id=auth.uid() and m.status='active') and exists (select 1 from public.krim_warehouse_facilities f where f.id=krim_warehouse_inventory_movements.facility_id and f.organization_id=krim_warehouse_inventory_movements.organization_id));
grant select,insert,update,delete on public.krim_warehouse_facilities, public.krim_warehouse_receipts, public.krim_warehouse_inventory to authenticated;
grant select,insert on public.krim_warehouse_inventory_movements to authenticated;
