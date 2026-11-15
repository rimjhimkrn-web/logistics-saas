-- Shipment inventory allocation: reservation, controlled pick and pre-pick release.
create table public.krim_warehouse_shipment_allocations (
 id uuid primary key default gen_random_uuid(),
 organization_id bigint not null,
 facility_id uuid not null references public.krim_warehouse_facilities(id) on delete restrict,
 inventory_id uuid not null references public.krim_warehouse_inventory(id) on delete restrict,
 shipment_id bigint not null references public.krim_shipments(id) on delete restrict,
 shipment_leg_id bigint references public.krim_shipment_legs(id) on delete restrict,
 quantity numeric not null check(quantity>0 and quantity<>'NaN'::numeric and quantity<>'Infinity'::numeric and quantity<>'-Infinity'::numeric),
 unit_code text not null,
 status text not null default 'reserved' check(status in ('reserved','picked','released','cancelled')),
 idempotency_key uuid not null,
 reserved_by uuid not null references auth.users(id),
 picked_by uuid references auth.users(id),
 picked_at timestamptz,
 released_by uuid references auth.users(id),
 released_at timestamptz,
 cancellation_reason text,
 release_idempotency_key uuid,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 unique(organization_id,idempotency_key)
);
create index krim_wh_alloc_inventory_active_idx on public.krim_warehouse_shipment_allocations(inventory_id,status) where status='reserved';
create index krim_wh_alloc_shipment_idx on public.krim_warehouse_shipment_allocations(shipment_id,shipment_leg_id,status);
create unique index uq_krim_wh_alloc_release_key on public.krim_warehouse_shipment_allocations(organization_id,release_idempotency_key) where release_idempotency_key is not null;
alter table public.krim_warehouse_shipment_allocations enable row level security;
revoke all on public.krim_warehouse_shipment_allocations from public,anon,authenticated,service_role;
grant select on public.krim_warehouse_shipment_allocations to authenticated;
create policy krim_wh_allocations_party_read on public.krim_warehouse_shipment_allocations for select to authenticated
using(private.krim_has_permission((select auth.uid()),organization_id,'partner.manage')
 or exists(select 1 from public.krim_shipments s where s.id=shipment_id and private.krim_has_permission((select auth.uid()),s.customer_organization_id,'shipment.view')));

create function public.krim_warehouse_reserve_shipment_inventory(
 p_organization_id bigint,p_facility_id uuid,p_inventory_id uuid,p_shipment_id bigint,p_shipment_leg_id bigint,
 p_quantity numeric,p_idempotency_key uuid,p_notes text default ''
) returns jsonb language plpgsql security definer set search_path='' as $fn$
declare v_user uuid:=auth.uid(); v_inv public.krim_warehouse_inventory%rowtype;
 v_ship public.krim_shipments%rowtype; v_leg public.krim_shipment_legs%rowtype;
 v_alloc public.krim_warehouse_shipment_allocations%rowtype; v_reserved numeric;
begin
 if v_user is null then raise exception 'Authentication required' using errcode='28000'; end if;
 if p_organization_id is null or p_facility_id is null or p_inventory_id is null or p_shipment_id is null or p_quantity is null or p_quantity<=0 or p_quantity='NaN'::numeric or p_quantity in ('Infinity'::numeric,'-Infinity'::numeric) or p_idempotency_key is null then raise exception 'Organisation, facility, inventory, shipment, finite positive quantity and idempotency key are required' using errcode='22023'; end if;
 if not private.krim_has_permission(v_user,p_organization_id,'partner.manage') or not private.krim_warehouse_is_operator(v_user,p_organization_id,p_facility_id) then raise exception 'Authorised warehouse operator with partner management permission required' using errcode='42501'; end if;
 select * into v_ship from public.krim_shipments where id=p_shipment_id for update;
 if not found or v_ship.status in ('delivered','cancelled','rejected') then raise exception 'Shipment not found or no longer allocatable' using errcode='23514'; end if;
 if p_shipment_leg_id is not null then
  select * into v_leg from public.krim_shipment_legs where id=p_shipment_leg_id and shipment_id=p_shipment_id for update;
  if not found or v_leg.partner_organization_id<>p_organization_id or v_leg.status in ('completed','delivered','cancelled') then raise exception 'Shipment leg must belong to this shipment and assigned warehouse partner and remain active' using errcode='23514'; end if;
  if not exists(select 1 from public.krim_shipment_partner_assignments a where a.shipment_id=p_shipment_id and a.shipment_leg_id=p_shipment_leg_id and a.partner_organization_id=p_organization_id and a.status in ('accepted','active')) then raise exception 'Exact-leg partner assignment must be accepted or active' using errcode='23514'; end if;
 else
  if not exists(select 1 from public.krim_shipment_partner_assignments a where a.shipment_id=p_shipment_id and a.partner_organization_id=p_organization_id and a.status in ('accepted','active')) then raise exception 'Shipment-wide allocation requires an accepted or active partner assignment' using errcode='23514'; end if;
 end if;
 perform pg_advisory_xact_lock(hashtextextended('krim_wh_alloc:'||p_organization_id::text||':'||p_idempotency_key::text,0));
 select * into v_alloc from public.krim_warehouse_shipment_allocations where organization_id=p_organization_id and idempotency_key=p_idempotency_key;
 if found then
  if v_alloc.facility_id<>p_facility_id or v_alloc.inventory_id<>p_inventory_id or v_alloc.shipment_id<>p_shipment_id or v_alloc.shipment_leg_id is distinct from p_shipment_leg_id or v_alloc.quantity<>p_quantity then raise exception 'Allocation idempotency key reused with conflicting request' using errcode='23505'; end if;
  return jsonb_build_object('replayed',true,'allocation',to_jsonb(v_alloc));
 end if;
 select * into v_inv from public.krim_warehouse_inventory where id=p_inventory_id and organization_id=p_organization_id and facility_id=p_facility_id for update;
 if not found then raise exception 'Inventory not found at selected facility' using errcode='P0002'; end if;
 if v_inv.quality_status<>'released' then raise exception 'Only independently released inventory can be allocated' using errcode='23514'; end if;
 if not exists(select 1 from public.krim_warehouse_facilities f where f.id=p_facility_id and f.organization_id=p_organization_id and f.status='active' and f.review_status='approved') then raise exception 'Facility is not active and approved' using errcode='23514'; end if;
 select coalesce(sum(quantity),0) into v_reserved from public.krim_warehouse_shipment_allocations where inventory_id=p_inventory_id and status='reserved';
 if v_inv.quantity-v_reserved<p_quantity then raise exception 'Insufficient unallocated released inventory' using errcode='23514'; end if;
 insert into public.krim_warehouse_shipment_allocations(organization_id,facility_id,inventory_id,shipment_id,shipment_leg_id,quantity,unit_code,idempotency_key,reserved_by)
 values(p_organization_id,p_facility_id,p_inventory_id,p_shipment_id,p_shipment_leg_id,p_quantity,v_inv.unit_code,p_idempotency_key,v_user) returning * into v_alloc;
 insert into public.krim_audit_events(actor_user_id,organization_id,event_type,entity_type,entity_id,source,metadata)
 values(v_user,p_organization_id,'warehouse.shipment_inventory.reserved','warehouse_shipment_allocation',v_alloc.id::text,'rpc',jsonb_build_object('shipment_id',p_shipment_id,'shipment_leg_id',p_shipment_leg_id,'inventory_id',p_inventory_id,'quantity',p_quantity,'unit',v_inv.unit_code,'notes',coalesce(p_notes,'')));
 return jsonb_build_object('replayed',false,'allocation',to_jsonb(v_alloc),'available_after_reservation',v_inv.quantity-v_reserved-p_quantity);
end $fn$;

create function public.krim_warehouse_pick_shipment_allocation(p_allocation_id uuid,p_idempotency_key uuid,p_notes text default '')
returns jsonb language plpgsql security definer set search_path='' as $fn$
declare v_user uuid:=auth.uid(); v_alloc public.krim_warehouse_shipment_allocations%rowtype; v_inv public.krim_warehouse_inventory%rowtype; v_move jsonb;
begin
 if v_user is null then raise exception 'Authentication required' using errcode='28000'; end if;
 if p_allocation_id is null or p_idempotency_key is null then raise exception 'Allocation and idempotency key required' using errcode='22023'; end if;
 select * into v_alloc from public.krim_warehouse_shipment_allocations where id=p_allocation_id for update;
 if not found then raise exception 'Allocation not found' using errcode='P0002'; end if;
 if not private.krim_has_permission(v_user,v_alloc.organization_id,'partner.manage') or not private.krim_warehouse_is_operator(v_user,v_alloc.organization_id,v_alloc.facility_id) then raise exception 'Authorised warehouse operator required' using errcode='42501'; end if;
 if v_alloc.status='picked' then
  if exists(select 1 from public.krim_warehouse_inventory_movements where organization_id=v_alloc.organization_id and idempotency_key=p_idempotency_key and reference_type='shipment_allocation' and reference_id=v_alloc.id::text) then return jsonb_build_object('replayed',true,'allocation',to_jsonb(v_alloc)); end if;
  raise exception 'Allocation already picked with a different request key' using errcode='23505';
 end if;
 if v_alloc.status<>'reserved' then raise exception 'Only reserved allocations can be picked' using errcode='23514'; end if;
 select * into v_inv from public.krim_warehouse_inventory where id=v_alloc.inventory_id for update;
 if not found or v_inv.quality_status<>'released' or v_inv.quantity<v_alloc.quantity then raise exception 'Released stock is no longer sufficient for this pick' using errcode='23514'; end if;
 v_move:=public.krim_warehouse_record_movement(v_alloc.organization_id,v_alloc.facility_id,v_inv.sku,-v_alloc.quantity,'pick',p_idempotency_key,v_inv.item_description,v_inv.lot_code,v_inv.unit_code,v_inv.storage_location,'released','shipment_allocation',v_alloc.id::text,coalesce(p_notes,'Shipment allocation pick'));
 update public.krim_warehouse_shipment_allocations set status='picked',picked_by=v_user,picked_at=now(),updated_at=now() where id=v_alloc.id returning * into v_alloc;
 insert into public.krim_audit_events(actor_user_id,organization_id,event_type,entity_type,entity_id,source,metadata) values(v_user,v_alloc.organization_id,'warehouse.shipment_inventory.picked','warehouse_shipment_allocation',v_alloc.id::text,'rpc',jsonb_build_object('shipment_id',v_alloc.shipment_id,'shipment_leg_id',v_alloc.shipment_leg_id,'quantity',v_alloc.quantity,'movement',v_move->'movement'));
 return jsonb_build_object('replayed',false,'allocation',to_jsonb(v_alloc),'movement',v_move->'movement');
end $fn$;

create function public.krim_warehouse_release_shipment_allocation(p_allocation_id uuid,p_reason text,p_idempotency_key uuid)
returns jsonb language plpgsql security definer set search_path='' as $fn$
declare v_user uuid:=auth.uid(); v_alloc public.krim_warehouse_shipment_allocations%rowtype;
begin
 if v_user is null then raise exception 'Authentication required' using errcode='28000'; end if;
 if p_allocation_id is null or p_idempotency_key is null or length(btrim(coalesce(p_reason,'')))<5 or length(btrim(p_reason))>1000 then raise exception 'Allocation, idempotency key and cancellation reason are required' using errcode='22023'; end if;
 select * into v_alloc from public.krim_warehouse_shipment_allocations where id=p_allocation_id for update;
 if not found then raise exception 'Allocation not found' using errcode='P0002'; end if;
 if not private.krim_has_permission(v_user,v_alloc.organization_id,'partner.manage') or not private.krim_warehouse_is_operator(v_user,v_alloc.organization_id,v_alloc.facility_id) then raise exception 'Authorised warehouse operator required' using errcode='42501'; end if;
 if v_alloc.status='released' then
  if v_alloc.release_idempotency_key=p_idempotency_key and v_alloc.cancellation_reason=btrim(p_reason) then return jsonb_build_object('replayed',true,'allocation',to_jsonb(v_alloc)); end if;
  raise exception 'Allocation already released; conflicting replay rejected' using errcode='23505';
 end if;
 if exists(select 1 from public.krim_warehouse_shipment_allocations where organization_id=v_alloc.organization_id and release_idempotency_key=p_idempotency_key) then raise exception 'Release idempotency key already used' using errcode='23505'; end if;
 if v_alloc.status<>'reserved' then raise exception 'Picked allocations cannot be released; use a controlled reverse-pick workflow' using errcode='23514'; end if;
 update public.krim_warehouse_shipment_allocations set status='released',released_by=v_user,released_at=now(),cancellation_reason=btrim(p_reason),release_idempotency_key=p_idempotency_key,updated_at=now() where id=v_alloc.id returning * into v_alloc;
 insert into public.krim_audit_events(actor_user_id,organization_id,event_type,entity_type,entity_id,source,metadata) values(v_user,v_alloc.organization_id,'warehouse.shipment_inventory.reservation_released','warehouse_shipment_allocation',v_alloc.id::text,'rpc',jsonb_build_object('reason',btrim(p_reason),'idempotency_key',p_idempotency_key));
 return jsonb_build_object('replayed',false,'allocation',to_jsonb(v_alloc));
end $fn$;
revoke all on function public.krim_warehouse_reserve_shipment_inventory(bigint,uuid,uuid,bigint,bigint,numeric,uuid,text) from public,anon;
revoke all on function public.krim_warehouse_pick_shipment_allocation(uuid,uuid,text) from public,anon;
revoke all on function public.krim_warehouse_release_shipment_allocation(uuid,text,uuid) from public,anon;
grant execute on function public.krim_warehouse_reserve_shipment_inventory(bigint,uuid,uuid,bigint,bigint,numeric,uuid,text) to authenticated;
grant execute on function public.krim_warehouse_pick_shipment_allocation(uuid,uuid,text) to authenticated;
grant execute on function public.krim_warehouse_release_shipment_allocation(uuid,text,uuid) to authenticated;