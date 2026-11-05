create or replace function public.krim_warehouse_create_task(
 p_organization_id bigint,p_facility_id uuid,p_task_type text,p_reference_code text,
 p_sku text,p_item_description text,p_lot_code text,p_quantity numeric,p_unit_code text,
 p_source_location text,p_destination_location text,p_quality_status text,p_severity text,
 p_notes text,p_idempotency_key uuid
)
returns jsonb language plpgsql security definer set search_path to ''
as $function$
declare v_user uuid:=auth.uid();v_task public.krim_warehouse_tasks%rowtype;
begin
 if v_user is null then raise exception 'Authentication required' using errcode='28000';end if;
 if not private.krim_warehouse_is_operator(v_user,p_organization_id,p_facility_id) then raise exception 'Verified warehouse facility access and partner.manage permission required' using errcode='42501';end if;
 if p_task_type not in ('inbound_receiving','goods_receipt','putaway_storage','picking_packing','dispatch_handover','damage_exception','cycle_count') then raise exception 'Unsupported warehouse task type' using errcode='22023';end if;
 if nullif(btrim(p_reference_code),'') is null or length(btrim(p_reference_code))>120 or p_idempotency_key is null then raise exception 'Valid operation reference and idempotency key are required' using errcode='22023';end if;
 if p_task_type in ('goods_receipt','putaway_storage','picking_packing') and (nullif(btrim(p_sku),'') is null or p_quantity is null or p_quantity<=0 or p_quantity>='Infinity'::numeric or p_quantity='NaN'::numeric) then raise exception 'SKU and finite positive quantity are required' using errcode='22023';end if;
 if coalesce(p_quality_status,'pending') not in ('pending','released','hold','rejected') or coalesce(p_severity,'normal') not in ('normal','low','medium','high','critical') then raise exception 'Invalid quality or severity status' using errcode='22023';end if;
 perform pg_advisory_xact_lock(hashtextextended('krim_wh_task:'||p_organization_id::text||':'||p_idempotency_key::text,0));
 select * into v_task from public.krim_warehouse_tasks where organization_id=p_organization_id and idempotency_key=p_idempotency_key;
 if found then
  if v_task.facility_id<>p_facility_id or v_task.task_type<>p_task_type or v_task.reference_code<>btrim(p_reference_code)
   or v_task.sku is distinct from nullif(btrim(p_sku),'') or v_task.item_description is distinct from nullif(btrim(p_item_description),'')
   or v_task.lot_code is distinct from nullif(btrim(p_lot_code),'') or v_task.quantity is distinct from p_quantity
   or v_task.unit_code<>coalesce(nullif(btrim(p_unit_code),''),'unit') or v_task.source_location is distinct from nullif(btrim(p_source_location),'')
   or v_task.destination_location is distinct from nullif(btrim(p_destination_location),'') or v_task.quality_status<>coalesce(p_quality_status,'pending')
   or v_task.severity<>coalesce(p_severity,'normal') or v_task.notes<>left(coalesce(p_notes,''),4000) then
   raise exception 'Idempotency key was already used for a different warehouse task' using errcode='23505';
  end if;
  return jsonb_build_object('replayed',true,'task',to_jsonb(v_task));
 end if;
 if p_task_type='inbound_receiving' then
  insert into public.krim_warehouse_receipts(organization_id,facility_id,receipt_reference,status,notes)
  values(p_organization_id,p_facility_id,btrim(p_reference_code),'expected',coalesce(p_notes,''));
 elsif p_task_type='goods_receipt' then
  if not exists(select 1 from public.krim_warehouse_receipts r where r.organization_id=p_organization_id and r.facility_id=p_facility_id and r.receipt_reference=btrim(p_reference_code) and r.status='received') then
   raise exception 'Goods receipt requires a completed inbound receipt with no quality hold' using errcode='23514';
  end if;
 elsif p_task_type='putaway_storage' then
  if nullif(btrim(p_destination_location),'') is null then raise exception 'Destination storage location is required' using errcode='22023';end if;
  if not exists(select 1 from public.krim_warehouse_inventory i where i.organization_id=p_organization_id and i.facility_id=p_facility_id and lower(i.sku)=lower(btrim(p_sku)) and i.lot_code is not distinct from nullif(btrim(p_lot_code),'') and i.quantity=p_quantity) then
   raise exception 'Put-away requires the full matching SKU/lot balance; partial lot splits are not enabled' using errcode='23514';
  end if;
 elsif p_task_type='picking_packing' then
  if not exists(select 1 from public.krim_warehouse_inventory i where i.organization_id=p_organization_id and i.facility_id=p_facility_id and lower(i.sku)=lower(btrim(p_sku)) and i.lot_code is not distinct from nullif(btrim(p_lot_code),'') and i.quantity>=p_quantity and i.quality_status='released') then
   raise exception 'Insufficient released inventory for this pick' using errcode='23514';
  end if;
 end if;
 insert into public.krim_warehouse_tasks(organization_id,facility_id,task_type,reference_code,sku,item_description,lot_code,quantity,unit_code,source_location,destination_location,quality_status,severity,notes,idempotency_key,created_by)
 values(p_organization_id,p_facility_id,p_task_type,btrim(p_reference_code),nullif(btrim(p_sku),''),nullif(btrim(p_item_description),''),nullif(btrim(p_lot_code),''),p_quantity,
  coalesce(nullif(btrim(p_unit_code),''),'unit'),nullif(btrim(p_source_location),''),nullif(btrim(p_destination_location),''),coalesce(p_quality_status,'pending'),
  coalesce(p_severity,'normal'),left(coalesce(p_notes,''),4000),p_idempotency_key,v_user) returning * into v_task;
 insert into public.krim_warehouse_task_events(task_id,organization_id,facility_id,event_type,new_status,metadata,actor_user_id)
 values(v_task.id,p_organization_id,p_facility_id,'task.created','open',jsonb_build_object('task_type',p_task_type,'reference_code',p_reference_code),v_user);
 return jsonb_build_object('replayed',false,'task',to_jsonb(v_task));
end;$function$;
