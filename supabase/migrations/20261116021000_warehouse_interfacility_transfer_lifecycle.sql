-- Inter-facility warehouse transfer lifecycle.
-- Dispatch removes only released stock from the source. Receipt creates/updates
-- destination stock on quality hold; a separate independent review is required
-- before that stock can be picked or dispatched.
create table if not exists public.krim_warehouse_transfers (
  id uuid primary key default gen_random_uuid(),
  organization_id bigint not null references public.krim_organizations(id) on delete restrict,
  source_facility_id uuid not null references public.krim_warehouse_facilities(id) on delete restrict,
  destination_facility_id uuid not null references public.krim_warehouse_facilities(id) on delete restrict,
  source_inventory_id uuid not null references public.krim_warehouse_inventory(id) on delete restrict,
  destination_inventory_id uuid references public.krim_warehouse_inventory(id) on delete restrict,
  sku text not null,
  item_description text not null,
  lot_code text,
  quantity numeric not null check (quantity > 0 and quantity < 'Infinity'::numeric and quantity <> 'NaN'::numeric),
  unit_code text not null,
  reference_code text not null check (length(btrim(reference_code)) between 1 and 120),
  status text not null default 'dispatched' check (status in ('dispatched','received','cancelled')),
  notes text not null default '',
  receive_notes text not null default '',
  idempotency_key uuid not null,
  receive_idempotency_key uuid,
  dispatched_by uuid not null references auth.users(id),
  dispatched_at timestamptz not null default now(),
  received_by uuid references auth.users(id),
  received_at timestamptz,
  created_at timestamptz not null default now(),
  constraint krim_warehouse_transfers_distinct_facilities check (source_facility_id <> destination_facility_id),
  constraint krim_warehouse_transfers_receive_state check (
    (status = 'dispatched' and destination_inventory_id is null and received_by is null and received_at is null and receive_idempotency_key is null)
    or (status = 'received' and destination_inventory_id is not null and received_by is not null and received_at is not null and receive_idempotency_key is not null)
    or status = 'cancelled'
  ),
  constraint krim_warehouse_transfers_org_idempotency unique (organization_id,idempotency_key),
  constraint krim_warehouse_transfers_org_receive_idempotency unique (organization_id,receive_idempotency_key)
);
create index if not exists idx_krim_warehouse_transfers_source_status on public.krim_warehouse_transfers(organization_id,source_facility_id,status,dispatched_at desc);
create index if not exists idx_krim_warehouse_transfers_destination_status on public.krim_warehouse_transfers(organization_id,destination_facility_id,status,dispatched_at desc);
alter table public.krim_warehouse_transfers enable row level security;
revoke all on public.krim_warehouse_transfers from public, anon, authenticated, service_role;
grant select on public.krim_warehouse_transfers to authenticated;
create policy krim_warehouse_transfers_operator_read on public.krim_warehouse_transfers for select to authenticated
using (
 private.krim_warehouse_is_operator((select auth.uid()),organization_id,source_facility_id)
 or private.krim_warehouse_is_operator((select auth.uid()),organization_id,destination_facility_id)
);

create or replace function public.krim_warehouse_dispatch_transfer(
 p_organization_id bigint,p_source_facility_id uuid,p_destination_facility_id uuid,
 p_inventory_id uuid,p_quantity numeric,p_reference_code text,p_idempotency_key uuid,p_notes text default ''
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare
 v_user uuid:=auth.uid(); v_source public.krim_warehouse_inventory%rowtype;
 v_transfer public.krim_warehouse_transfers%rowtype;
 v_reference text:=btrim(coalesce(p_reference_code,'')); v_notes text:=left(coalesce(p_notes,''),4000);
begin
 if v_user is null then raise exception 'Authentication required' using errcode='28000'; end if;
 if p_idempotency_key is null or p_organization_id is null or p_source_facility_id is null
  or p_destination_facility_id is null or p_inventory_id is null or p_source_facility_id=p_destination_facility_id
  or nullif(v_reference,'') is null or length(v_reference)>120 then
  raise exception 'Valid source, destination, inventory, reference and idempotency key are required' using errcode='22023';
 end if;
 if p_quantity is null or p_quantity<=0 or p_quantity>='Infinity'::numeric or p_quantity in ('NaN'::numeric,'-Infinity'::numeric) then
  raise exception 'Transfer quantity must be finite and positive' using errcode='22023';
 end if;
 if not private.krim_warehouse_is_operator(v_user,p_organization_id,p_source_facility_id)
  or not private.krim_warehouse_is_operator(v_user,p_organization_id,p_destination_facility_id) then
  raise exception 'Approved source and destination facility operator access required' using errcode='42501';
 end if;
 perform pg_advisory_xact_lock(hashtextextended('krim_wh_transfer:'||p_organization_id::text||':'||p_idempotency_key::text,0));
 select * into v_transfer from public.krim_warehouse_transfers where organization_id=p_organization_id and idempotency_key=p_idempotency_key for update;
 if found then
  if v_transfer.source_facility_id<>p_source_facility_id or v_transfer.destination_facility_id<>p_destination_facility_id
   or v_transfer.source_inventory_id<>p_inventory_id or v_transfer.quantity<>p_quantity
   or v_transfer.reference_code<>v_reference or v_transfer.notes<>v_notes then
   raise exception 'Idempotency key reused with a different transfer payload' using errcode='23505';
  end if;
  return jsonb_build_object('replayed',true,'transfer',to_jsonb(v_transfer));
 end if;
 select * into v_source from public.krim_warehouse_inventory
  where id=p_inventory_id and organization_id=p_organization_id and facility_id=p_source_facility_id for update;
 if not found then raise exception 'Source inventory balance not found in source facility' using errcode='P0002'; end if;
 if v_source.quality_status<>'released' then raise exception 'Only released inventory may be transferred' using errcode='23514'; end if;
 if v_source.quantity<p_quantity then raise exception 'Insufficient source stock or invalid unit' using errcode='23514'; end if;
 if not exists(select 1 from public.krim_warehouse_facilities f where f.id=p_source_facility_id and f.organization_id=p_organization_id and f.status='active' and f.review_status='approved')
  or not exists(select 1 from public.krim_warehouse_facilities f where f.id=p_destination_facility_id and f.organization_id=p_organization_id and f.status='active' and f.review_status='approved') then
  raise exception 'Both facilities must remain active and approved' using errcode='23514';
 end if;
 insert into public.krim_warehouse_transfers(organization_id,source_facility_id,destination_facility_id,source_inventory_id,
  sku,item_description,lot_code,quantity,unit_code,reference_code,notes,idempotency_key,dispatched_by)
 values(p_organization_id,p_source_facility_id,p_destination_facility_id,p_inventory_id,
  v_source.sku,v_source.item_description,v_source.lot_code,p_quantity,v_source.unit_code,v_reference,v_notes,p_idempotency_key,v_user)
 returning * into v_transfer;
 update public.krim_warehouse_inventory set quantity=quantity-p_quantity,updated_at=now()
  where id=v_source.id returning * into v_source;
 insert into public.krim_warehouse_inventory_movements(organization_id,facility_id,inventory_id,movement_type,quantity_delta,
  reference_type,reference_id,notes,created_by,idempotency_key)
 values(p_organization_id,p_source_facility_id,v_source.id,'transfer',-p_quantity,'warehouse_transfer',v_transfer.id::text,v_notes,v_user,p_idempotency_key);
 insert into public.krim_audit_events(actor_user_id,organization_id,event_type,entity_type,entity_id,source,metadata)
 values(v_user,p_organization_id,'warehouse.transfer.dispatched','warehouse_transfer',v_transfer.id::text,'rpc',
  jsonb_build_object('source_facility_id',p_source_facility_id,'destination_facility_id',p_destination_facility_id,
   'sku',v_transfer.sku,'lot_code',v_transfer.lot_code,'quantity',p_quantity,'unit_code',v_transfer.unit_code));
 return jsonb_build_object('replayed',false,'transfer',to_jsonb(v_transfer),'source_inventory',to_jsonb(v_source));
end; $$;

create or replace function public.krim_warehouse_receive_transfer(p_transfer_id uuid,p_idempotency_key uuid,p_notes text default '')
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
 v_user uuid:=auth.uid(); v_transfer public.krim_warehouse_transfers%rowtype;
 v_destination public.krim_warehouse_inventory%rowtype; v_notes text:=left(coalesce(p_notes,''),4000);
begin
 if v_user is null then raise exception 'Authentication required' using errcode='28000'; end if;
 if p_transfer_id is null or p_idempotency_key is null then raise exception 'Transfer and idempotency key are required' using errcode='22023'; end if;
 select * into v_transfer from public.krim_warehouse_transfers where id=p_transfer_id for update;
 if not found then raise exception 'Transfer not found' using errcode='P0002'; end if;
 if not private.krim_warehouse_is_operator(v_user,v_transfer.organization_id,v_transfer.destination_facility_id) then
  raise exception 'Approved destination facility operator access required' using errcode='42501';
 end if;
 if v_transfer.status='received' then
  if v_transfer.receive_idempotency_key<>p_idempotency_key or v_transfer.receive_notes<>v_notes then
   raise exception 'Transfer already received with a different receipt payload' using errcode='23505';
  end if;
  select * into v_destination from public.krim_warehouse_inventory where id=v_transfer.destination_inventory_id;
  return jsonb_build_object('replayed',true,'transfer',to_jsonb(v_transfer),'destination_inventory',to_jsonb(v_destination));
 end if;
 if v_transfer.status<>'dispatched' then raise exception 'Only dispatched transfers can be received' using errcode='23514'; end if;
 if v_transfer.dispatched_by=v_user then raise exception 'Receiving must be confirmed by a different authorised warehouse operator' using errcode='42501'; end if;
 perform pg_advisory_xact_lock(hashtextextended('krim_wh_transfer_receive:'||v_transfer.organization_id::text||':'||p_idempotency_key::text,0));
 if exists(select 1 from public.krim_warehouse_transfers where organization_id=v_transfer.organization_id
  and receive_idempotency_key=p_idempotency_key and id<>v_transfer.id) then
  raise exception 'Receipt idempotency key already used for another transfer' using errcode='23505';
 end if;
 select * into v_destination from public.krim_warehouse_inventory i
  where i.organization_id=v_transfer.organization_id and i.facility_id=v_transfer.destination_facility_id
   and lower(i.sku)=lower(v_transfer.sku) and i.lot_code is not distinct from v_transfer.lot_code for update;
 if found then
  if v_destination.unit_code<>v_transfer.unit_code then raise exception 'Destination SKU/lot unit mismatch; conversion is not supported' using errcode='23514'; end if;
  if v_destination.quality_status<>'hold' then
   raise exception 'Destination SKU/lot already has a different quality state; transfer receipt is blocked to prevent unsafe stock merging' using errcode='23514';
  end if;
  update public.krim_warehouse_inventory set quantity=quantity+v_transfer.quantity,updated_at=now()
   where id=v_destination.id returning * into v_destination;
 else
  insert into public.krim_warehouse_inventory(organization_id,facility_id,sku,item_description,lot_code,quantity,unit_code,quality_status)
  values(v_transfer.organization_id,v_transfer.destination_facility_id,v_transfer.sku,v_transfer.item_description,
   v_transfer.lot_code,v_transfer.quantity,v_transfer.unit_code,'hold') returning * into v_destination;
 end if;
 update public.krim_warehouse_transfers set status='received',destination_inventory_id=v_destination.id,
  receive_idempotency_key=p_idempotency_key,receive_notes=v_notes,received_by=v_user,received_at=now()
  where id=v_transfer.id returning * into v_transfer;
 insert into public.krim_warehouse_inventory_movements(organization_id,facility_id,inventory_id,movement_type,quantity_delta,
  reference_type,reference_id,notes,created_by,idempotency_key)
 values(v_transfer.organization_id,v_transfer.destination_facility_id,v_destination.id,'transfer',v_transfer.quantity,
  'warehouse_transfer',v_transfer.id::text,v_notes,v_user,p_idempotency_key);
 insert into public.krim_audit_events(actor_user_id,organization_id,event_type,entity_type,entity_id,source,metadata)
 values(v_user,v_transfer.organization_id,'warehouse.transfer.received','warehouse_transfer',v_transfer.id::text,'rpc',
  jsonb_build_object('destination_facility_id',v_transfer.destination_facility_id,'destination_inventory_id',v_destination.id,
   'quantity',v_transfer.quantity,'unit_code',v_transfer.unit_code,'quality_status','hold'));
 return jsonb_build_object('replayed',false,'transfer',to_jsonb(v_transfer),'destination_inventory',to_jsonb(v_destination));
end; $$;

revoke all on function public.krim_warehouse_dispatch_transfer(bigint,uuid,uuid,uuid,numeric,text,uuid,text) from public,anon;
revoke all on function public.krim_warehouse_receive_transfer(uuid,uuid,text) from public,anon;
grant execute on function public.krim_warehouse_dispatch_transfer(bigint,uuid,uuid,uuid,numeric,text,uuid,text) to authenticated;
grant execute on function public.krim_warehouse_receive_transfer(uuid,uuid,text) to authenticated;
