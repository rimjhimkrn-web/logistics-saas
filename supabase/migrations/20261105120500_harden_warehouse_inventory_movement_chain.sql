-- Warehouse inventory must only change through the task lifecycle.
-- Prevent direct browser RPC bypass, unsupported one-sided transfers/dispatch,
-- stale quality-state picks, and concurrent idempotency-key reuse.

alter table public.krim_warehouse_inventory_movements
  add constraint krim_wh_movement_org_idempotency_unique
  unique (organization_id, idempotency_key);

create or replace function public.krim_warehouse_record_movement(
  p_organization_id bigint,
  p_facility_id uuid,
  p_sku text,
  p_quantity_delta numeric,
  p_movement_type text,
  p_idempotency_key uuid,
  p_item_description text default ''::text,
  p_lot_code text default null::text,
  p_unit_code text default 'unit'::text,
  p_storage_location text default null::text,
  p_quality_status text default 'pending'::text,
  p_reference_type text default null::text,
  p_reference_id text default null::text,
  p_notes text default ''::text
)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
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
  if p_quantity_delta is null or p_quantity_delta=0 or p_quantity_delta='NaN'::numeric
     or p_quantity_delta='Infinity'::numeric or p_quantity_delta='-Infinity'::numeric then
    raise exception 'Quantity change must be finite and non-zero' using errcode='22023';
  end if;

  if p_movement_type not in ('receipt','pick') then
    raise exception 'Use an approved warehouse task workflow; direct dispatch, transfer, return and adjustment movements are disabled' using errcode='42501';
  end if;
  if p_movement_type='receipt' and p_quantity_delta<=0 then raise exception 'Receipt movements must add stock' using errcode='22023'; end if;
  if p_movement_type='pick' and p_quantity_delta>=0 then raise exception 'Pick movements must remove stock' using errcode='22023'; end if;
  if coalesce(p_quality_status,'pending') not in ('pending','released','hold','rejected') then raise exception 'Unsupported quality status' using errcode='22023'; end if;

  select o.organization_type || ' ' || coalesce(o.organization_type_code,'') into v_org_type
  from public.krim_organizations o
  join public.krim_organization_members m on m.organization_id=o.id
  where o.id=p_organization_id and lower(coalesce(o.status,''))='active'
    and m.user_id=v_user_id and m.status='active'
    and private.krim_warehouse_org_eligible(o.id)
  limit 1;

  if v_org_type is null
     or not exists(select 1 from public.krim_organizations o where o.id=p_organization_id
       and o.partner_account_mode='registered_business'
       and o.partner_verification_status in ('verified','approved')
       and o.partner_lifecycle_status in ('active','verified')
       and o.partner_compliance_status in ('clear','compliant','approved','verified','not_required','not_applicable'))
     or not private.krim_has_permission(v_user_id,p_organization_id,'partner.manage') then
    raise exception 'Verified registered-business warehouse organisation required' using errcode='42501';
  end if;

  if not exists(select 1 from public.krim_warehouse_facilities f where f.id=p_facility_id
    and f.organization_id=p_organization_id and f.status='active' and f.review_status='approved') then
    raise exception 'Active facility not found in the authorized organization' using errcode='42501';
  end if;

  perform pg_advisory_xact_lock(hashtextextended('krim_wh_movement:'||p_organization_id::text||':'||p_idempotency_key::text,0));

  select * into v_movement from public.krim_warehouse_inventory_movements
  where organization_id=p_organization_id and idempotency_key=p_idempotency_key;

  if found then
    select * into v_inventory from public.krim_warehouse_inventory where id=v_movement.inventory_id;
    if v_movement.facility_id<>p_facility_id
       or v_movement.movement_type<>p_movement_type
       or v_movement.quantity_delta<>p_quantity_delta
       or lower(v_inventory.sku)<>lower(btrim(p_sku))
       or v_inventory.lot_code is distinct from nullif(btrim(p_lot_code),'')
       or v_movement.reference_type is distinct from nullif(btrim(p_reference_type),'')
       or v_movement.reference_id is distinct from nullif(btrim(p_reference_id),'') then
      raise exception 'Idempotency key was already used for a different warehouse movement' using errcode='23505';
    end if;
    return jsonb_build_object('replayed',true,'movement',to_jsonb(v_movement),'inventory',to_jsonb(v_inventory));
  end if;

  perform pg_advisory_xact_lock(hashtextextended(p_organization_id::text||':'||p_facility_id::text||':'||
    lower(btrim(p_sku))||':'||coalesce(nullif(btrim(p_lot_code),''),'<NULL>'),0));

  select * into v_inventory from public.krim_warehouse_inventory i
  where i.organization_id=p_organization_id and i.facility_id=p_facility_id
    and lower(i.sku)=lower(btrim(p_sku)) and i.lot_code is not distinct from nullif(btrim(p_lot_code),'')
  order by i.created_at limit 1 for update;

  if not found then
    if p_quantity_delta<0 then raise exception 'Cannot remove stock: no matching inventory balance exists' using errcode='23514'; end if;
    insert into public.krim_warehouse_inventory(organization_id,facility_id,sku,item_description,lot_code,quantity,unit_code,storage_location,quality_status)
    values(p_organization_id,p_facility_id,btrim(p_sku),coalesce(nullif(btrim(p_item_description),''),btrim(p_sku)),
      nullif(btrim(p_lot_code),''),p_quantity_delta,coalesce(nullif(btrim(p_unit_code),''),'unit'),
      nullif(btrim(p_storage_location),''),coalesce(p_quality_status,'pending'))
    returning * into v_inventory;
  else
    if p_movement_type='pick' and v_inventory.quality_status<>'released' then
      raise exception 'Picking is permitted only from released inventory; current quality status is %',v_inventory.quality_status using errcode='23514';
    end if;
    if v_inventory.quantity+p_quantity_delta<0 then raise exception 'Insufficient stock: movement would make inventory negative' using errcode='23514'; end if;
    update public.krim_warehouse_inventory set quantity=quantity+p_quantity_delta,updated_at=now(),
      storage_location=coalesce(nullif(btrim(p_storage_location),''),storage_location)
    where id=v_inventory.id returning * into v_inventory;
  end if;

  insert into public.krim_warehouse_inventory_movements(organization_id,facility_id,inventory_id,movement_type,quantity_delta,
    reference_type,reference_id,notes,created_by,idempotency_key)
  values(p_organization_id,p_facility_id,v_inventory.id,p_movement_type,p_quantity_delta,
    nullif(btrim(p_reference_type),''),nullif(btrim(p_reference_id),''),coalesce(p_notes,''),v_user_id,p_idempotency_key)
  returning * into v_movement;

  return jsonb_build_object('replayed',false,'movement',to_jsonb(v_movement),'inventory',to_jsonb(v_inventory));
end;
$function$;

revoke all on function public.krim_warehouse_record_movement(bigint,uuid,text,numeric,text,uuid,text,text,text,text,text,text,text,text)
  from public, anon, authenticated;
grant execute on function public.krim_warehouse_record_movement(bigint,uuid,text,numeric,text,uuid,text,text,text,text,text,text,text,text)
  to service_role;
