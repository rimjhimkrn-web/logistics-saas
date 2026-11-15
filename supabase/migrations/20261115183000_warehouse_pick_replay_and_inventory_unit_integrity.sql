DO $migration$
DECLARE
 v_pick text;
 v_movement text;
 v_stock text;
 v_replay_marker text;
 v_unit_guard text;
BEGIN
 v_pick:=pg_get_functiondef('public.krim_warehouse_create_linked_pick_task(bigint,uuid,bigint,bigint,text,text,text,text,numeric,text,text,text,uuid)'::regprocedure);
 v_stock:=$stock$ IF NOT EXISTS(SELECT 1 FROM public.krim_warehouse_inventory i WHERE i.organization_id=p_organization_id
  AND i.facility_id=p_facility_id AND lower(i.sku)=lower(btrim(p_sku))
  AND i.lot_code IS NOT DISTINCT FROM nullif(btrim(p_lot_code),'')
  AND i.quantity>=p_quantity AND i.quality_status='released') THEN
  RAISE EXCEPTION 'Insufficient released inventory for this shipment-linked pick' USING errcode='23514';
 END IF;
$stock$;
 IF position(v_stock in v_pick)=0 THEN RAISE EXCEPTION 'Pick inventory precheck anchor changed'; END IF;
 v_pick:=replace(v_pick,v_stock,'');
 v_replay_marker:=$marker$  RETURN jsonb_build_object('replayed',true,'task',to_jsonb(v_task));
 END IF;
 INSERT INTO public.krim_warehouse_tasks$marker$;
 v_unit_guard:=$unit$  IF NOT EXISTS(SELECT 1 FROM public.krim_warehouse_inventory i WHERE i.organization_id=p_organization_id
  AND i.facility_id=p_facility_id AND lower(i.sku)=lower(btrim(p_sku))
  AND i.lot_code IS NOT DISTINCT FROM nullif(btrim(p_lot_code),'')
  AND i.unit_code=coalesce(nullif(btrim(p_unit_code),''),'unit')
  AND i.quantity>=p_quantity AND i.quality_status='released') THEN
  RAISE EXCEPTION 'Insufficient released inventory or inventory unit does not match this shipment-linked pick' USING errcode='23514';
 END IF;
$unit$;
 IF position(v_replay_marker in v_pick)=0 THEN RAISE EXCEPTION 'Pick idempotency replay anchor changed'; END IF;
 v_pick:=replace(v_pick,v_replay_marker,
  '  RETURN jsonb_build_object(''replayed'',true,''task'',to_jsonb(v_task));'||chr(10)||' END IF;'||chr(10)||v_unit_guard||chr(10)||' INSERT INTO public.krim_warehouse_tasks');
 EXECUTE v_pick;

 v_movement:=pg_get_functiondef('public.krim_warehouse_record_movement(bigint,uuid,text,numeric,text,uuid,text,text,text,text,text,text,text,text)'::regprocedure);
 v_replay_marker:=$old$       or v_movement.reference_id is distinct from nullif(btrim(p_reference_id),'') then$old$;
 IF position(v_replay_marker in v_movement)=0 THEN RAISE EXCEPTION 'Movement replay validation anchor changed'; END IF;
 v_movement:=replace(v_movement,v_replay_marker,
  '       or v_movement.reference_id is distinct from nullif(btrim(p_reference_id),'''')'||chr(10)||
  '       or v_inventory.unit_code<>coalesce(nullif(btrim(p_unit_code),''''),''unit'')'||chr(10)||
  '       or v_movement.notes<>coalesce(p_notes,'''') then');
 v_replay_marker:=$old$    if p_movement_type='receipt' and v_inventory.quality_status is distinct from coalesce(p_quality_status,'pending') then$old$;
 IF position(v_replay_marker in v_movement)=0 THEN RAISE EXCEPTION 'Movement unit consistency anchor changed'; END IF;
 v_movement:=replace(v_movement,v_replay_marker,
  '    if v_inventory.unit_code<>coalesce(nullif(btrim(p_unit_code),''''),''unit'') then'||chr(10)||
  '      raise exception ''Inventory unit does not match movement unit; convert through an independently reviewed stock conversion workflow'' using errcode=''23514'';'||chr(10)||
  '    end if;'||chr(10)||v_replay_marker);
 EXECUTE v_movement;
END;
$migration$;

CREATE UNIQUE INDEX IF NOT EXISTS uq_krim_wh_inventory_normalized_sku_lot
ON public.krim_warehouse_inventory
(organization_id,facility_id,lower(sku),coalesce(lot_code,''));

DROP INDEX IF EXISTS public.uq_krim_wh_movement_org_idempotency;
