-- Atomic, idempotent KRIM warehouse inventory movement and tightened warehouse-only RLS.
alter table public.krim_warehouse_inventory_movements
  add column if not exists idempotency_key uuid;
create unique index if not exists uq_krim_wh_movement_org_idempotency
  on public.krim_warehouse_inventory_movements (organization_id, idempotency_key)
  where idempotency_key is not null;

drop policy if exists krim_wh_facilities_org_member on public.krim_warehouse_facilities;
create policy krim_wh_facilities_org_member on public.krim_warehouse_facilities for all to authenticated
using (exists (
 select 1 from public.krim_organization_members m
 join public.krim_organizations o on o.id=m.organization_id
 where m.organization_id=krim_warehouse_facilities.organization_id
 and m.user_id=auth.uid() and m.status='active' and lower(coalesce(o.status,''))='active'
 and (o.organization_type ilike '%warehouse%' or o.organization_type_code ilike '%warehouse%'
 or o.organization_type ilike '%fulfilment%' or o.organization_type_code ilike '%fulfilment%'
 or o.organization_type ilike '%fulfillment%' or o.organization_type_code ilike '%fulfillment%')
))
with check (exists (
 select 1 from public.krim_organization_members m
 join public.krim_organizations o on o.id=m.organization_id
 where m.organization_id=krim_warehouse_facilities.organization_id
 and m.user_id=auth.uid() and m.status='active' and lower(coalesce(o.status,''))='active'
 and (o.organization_type ilike '%warehouse%' or o.organization_type_code ilike '%warehouse%'
 or o.organization_type ilike '%fulfilment%' or o.organization_type_code ilike '%fulfilment%'
 or o.organization_type ilike '%fulfillment%' or o.organization_type_code ilike '%fulfillment%')
));

drop policy if exists krim_wh_receipts_org_member on public.krim_warehouse_receipts;
create policy krim_wh_receipts_org_member on public.krim_warehouse_receipts for all to authenticated
using (exists (
 select 1 from public.krim_organization_members m join public.krim_organizations o on o.id=m.organization_id
 where m.organization_id=krim_warehouse_receipts.organization_id and m.user_id=auth.uid()
 and m.status='active' and lower(coalesce(o.status,''))='active'
 and (o.organization_type ilike '%warehouse%' or o.organization_type_code ilike '%warehouse%'
 or o.organization_type ilike '%fulfilment%' or o.organization_type_code ilike '%fulfilment%'
 or o.organization_type ilike '%fulfillment%' or o.organization_type_code ilike '%fulfillment%')
) and exists (
 select 1 from public.krim_warehouse_facilities f
 where f.id=krim_warehouse_receipts.facility_id and f.organization_id=krim_warehouse_receipts.organization_id
))
with check (exists (
 select 1 from public.krim_organization_members m join public.krim_organizations o on o.id=m.organization_id
 where m.organization_id=krim_warehouse_receipts.organization_id and m.user_id=auth.uid()
 and m.status='active' and lower(coalesce(o.status,''))='active'
 and (o.organization_type ilike '%warehouse%' or o.organization_type_code ilike '%warehouse%'
 or o.organization_type ilike '%fulfilment%' or o.organization_type_code ilike '%fulfilment%'
 or o.organization_type ilike '%fulfillment%' or o.organization_type_code ilike '%fulfillment%')
) and exists (
 select 1 from public.krim_warehouse_facilities f
 where f.id=krim_warehouse_receipts.facility_id and f.organization_id=krim_warehouse_receipts.organization_id
));

drop policy if exists krim_wh_inventory_org_member on public.krim_warehouse_inventory;
create policy krim_wh_inventory_org_member on public.krim_warehouse_inventory for all to authenticated
using (exists (
 select 1 from public.krim_organization_members m join public.krim_organizations o on o.id=m.organization_id
 where m.organization_id=krim_warehouse_inventory.organization_id and m.user_id=auth.uid()
 and m.status='active' and lower(coalesce(o.status,''))='active'
 and (o.organization_type ilike '%warehouse%' or o.organization_type_code ilike '%warehouse%'
 or o.organization_type ilike '%fulfilment%' or o.organization_type_code ilike '%fulfilment%'
 or o.organization_type ilike '%fulfillment%' or o.organization_type_code ilike '%fulfillment%')
) and exists (
 select 1 from public.krim_warehouse_facilities f
 where f.id=krim_warehouse_inventory.facility_id and f.organization_id=krim_warehouse_inventory.organization_id
))
with check (exists (
 select 1 from public.krim_organization_members m join public.krim_organizations o on o.id=m.organization_id
 where m.organization_id=krim_warehouse_inventory.organization_id and m.user_id=auth.uid()
 and m.status='active' and lower(coalesce(o.status,''))='active'
 and (o.organization_type ilike '%warehouse%' or o.organization_type_code ilike '%warehouse%'
 or o.organization_type ilike '%fulfilment%' or o.organization_type_code ilike '%fulfilment%'
 or o.organization_type ilike '%fulfillment%' or o.organization_type_code ilike '%fulfillment%')
) and exists (
 select 1 from public.krim_warehouse_facilities f
 where f.id=krim_warehouse_inventory.facility_id and f.organization_id=krim_warehouse_inventory.organization_id
));

drop policy if exists krim_wh_movements_select_member on public.krim_warehouse_inventory_movements;
create policy krim_wh_movements_select_member on public.krim_warehouse_inventory_movements for select to authenticated
using (exists (
 select 1 from public.krim_organization_members m join public.krim_organizations o on o.id=m.organization_id
 where m.organization_id=krim_warehouse_inventory_movements.organization_id and m.user_id=auth.uid()
 and m.status='active' and lower(coalesce(o.status,''))='active'
 and (o.organization_type ilike '%warehouse%' or o.organization_type_code ilike '%warehouse%'
 or o.organization_type ilike '%fulfilment%' or o.organization_type_code ilike '%fulfilment%'
 or o.organization_type ilike '%fulfillment%' or o.organization_type_code ilike '%fulfillment%')
));
drop policy if exists krim_wh_movements_insert_member on public.krim_warehouse_inventory_movements;
create policy krim_wh_movements_insert_member on public.krim_warehouse_inventory_movements for insert to authenticated
with check (created_by=auth.uid() and exists (
 select 1 from public.krim_organization_members m join public.krim_organizations o on o.id=m.organization_id
 where m.organization_id=krim_warehouse_inventory_movements.organization_id and m.user_id=auth.uid()
 and m.status='active' and lower(coalesce(o.status,''))='active'
 and (o.organization_type ilike '%warehouse%' or o.organization_type_code ilike '%warehouse%'
 or o.organization_type ilike '%fulfilment%' or o.organization_type_code ilike '%fulfilment%'
 or o.organization_type ilike '%fulfillment%' or o.organization_type_code ilike '%fulfillment%')
) and exists (
 select 1 from public.krim_warehouse_facilities f
 where f.id=krim_warehouse_inventory_movements.facility_id
 and f.organization_id=krim_warehouse_inventory_movements.organization_id and f.status='active'
));

create or replace function public.krim_warehouse_record_movement(
 p_organization_id bigint, p_facility_id uuid, p_sku text, p_quantity_delta numeric,
 p_movement_type text, p_idempotency_key uuid, p_item_description text default '',
 p_lot_code text default null, p_unit_code text default 'unit', p_storage_location text default null,
 p_quality_status text default 'pending', p_reference_type text default null,
 p_reference_id text default null, p_notes text default ''
) returns jsonb
language plpgsql security definer set search_path = public, pg_temp
as $$
declare
 v_user_id uuid := auth.uid();
 v_inventory public.krim_warehouse_inventory%rowtype;
 v_movement public.krim_warehouse_inventory_movements%rowtype;
 v_org_type text;
begin
 if v_user_id is null then raise exception 'Authentication required' using errcode='28000'; end if;
 if p_idempotency_key is null then raise exception 'An idempotency key is required' using errcode='22023'; end if;
 if p_organization_id is null or p_facility_id is null then raise exception 'Organization and facility are required' using errcode='22023'; end if;
 if nullif(btrim(p_sku),'') is null or length(btrim(p_sku))>120 then raise exception 'A valid SKU is required' using errcode='22023'; end if;
 if p_quantity_delta is null or p_quantity_delta=0 then raise exception 'Quantity change must be non-zero' using errcode='22023'; end if;
 if p_movement_type not in ('receipt','putaway','pick','dispatch','adjustment','return','transfer') then raise exception 'Unsupported movement type' using errcode='22023'; end if;
 if p_movement_type in ('receipt','return') and p_quantity_delta<0 then raise exception 'Receipt and return movements must add stock' using errcode='22023'; end if;
 if p_movement_type in ('pick','dispatch') and p_quantity_delta>0 then raise exception 'Pick and dispatch movements must remove stock' using errcode='22023'; end if;
 if coalesce(p_quality_status,'pending') not in ('pending','released','hold','rejected') then raise exception 'Unsupported quality status' using errcode='22023'; end if;

 select o.organization_type || ' ' || coalesce(o.organization_type_code,'') into v_org_type
 from public.krim_organizations o join public.krim_organization_members m on m.organization_id=o.id
 where o.id=p_organization_id and lower(coalesce(o.status,''))='active'
 and m.user_id=v_user_id and m.status='active'
 and (o.organization_type ilike '%warehouse%' or o.organization_type_code ilike '%warehouse%'
 or o.organization_type ilike '%fulfilment%' or o.organization_type_code ilike '%fulfilment%'
 or o.organization_type ilike '%fulfillment%' or o.organization_type_code ilike '%fulfillment%')
 limit 1;
 if v_org_type is null then raise exception 'Active warehouse organization membership required' using errcode='42501'; end if;
 if not exists(select 1 from public.krim_warehouse_facilities f where f.id=p_facility_id and f.organization_id=p_organization_id and f.status='active') then
 raise exception 'Active facility not found in the authorized organization' using errcode='42501'; end if;

 select * into v_movement from public.krim_warehouse_inventory_movements
 where organization_id=p_organization_id and idempotency_key=p_idempotency_key;
 if found then
  select * into v_inventory from public.krim_warehouse_inventory where id=v_movement.inventory_id;
  return jsonb_build_object('replayed',true,'movement',to_jsonb(v_movement),'inventory',to_jsonb(v_inventory));
 end if;

 perform pg_advisory_xact_lock(hashtextextended(p_organization_id::text||':'||p_facility_id::text||':'||lower(btrim(p_sku))||':'||coalesce(nullif(btrim(p_lot_code),''),'<NULL>'),0));
 select * into v_inventory from public.krim_warehouse_inventory i
 where i.organization_id=p_organization_id and i.facility_id=p_facility_id
 and lower(i.sku)=lower(btrim(p_sku)) and i.lot_code is not distinct from nullif(btrim(p_lot_code),'')
 order by i.created_at limit 1 for update;
 if not found then
  if p_quantity_delta<0 then raise exception 'Cannot remove stock: no matching inventory balance exists' using errcode='23514'; end if;
  insert into public.krim_warehouse_inventory(organization_id,facility_id,sku,item_description,lot_code,quantity,unit_code,storage_location,quality_status)
  values(p_organization_id,p_facility_id,btrim(p_sku),coalesce(nullif(btrim(p_item_description),''),btrim(p_sku)),nullif(btrim(p_lot_code),''),p_quantity_delta,coalesce(nullif(btrim(p_unit_code),''),'unit'),nullif(btrim(p_storage_location),''),coalesce(p_quality_status,'pending'))
  returning * into v_inventory;
 else
  if v_inventory.quantity+p_quantity_delta<0 then raise exception 'Insufficient stock: movement would make inventory negative' using errcode='23514'; end if;
  update public.krim_warehouse_inventory set quantity=quantity+p_quantity_delta,updated_at=now(),
   storage_location=coalesce(nullif(btrim(p_storage_location),''),storage_location)
  where id=v_inventory.id returning * into v_inventory;
 end if;
 insert into public.krim_warehouse_inventory_movements(organization_id,facility_id,inventory_id,movement_type,quantity_delta,reference_type,reference_id,notes,created_by,idempotency_key)
 values(p_organization_id,p_facility_id,v_inventory.id,p_movement_type,p_quantity_delta,nullif(btrim(p_reference_type),''),nullif(btrim(p_reference_id),''),coalesce(p_notes,''),v_user_id,p_idempotency_key)
 returning * into v_movement;
 return jsonb_build_object('replayed',false,'movement',to_jsonb(v_movement),'inventory',to_jsonb(v_inventory));
end;
$$;
revoke all on function public.krim_warehouse_record_movement(bigint,uuid,text,numeric,text,uuid,text,text,text,text,text,text,text,text) from public, anon;
grant execute on function public.krim_warehouse_record_movement(bigint,uuid,text,numeric,text,uuid,text,text,text,text,text,text,text,text) to authenticated;
