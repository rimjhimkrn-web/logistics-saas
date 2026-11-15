DO $migration$
DECLARE
 v_def text;
 v_old text;
 v_new text;
BEGIN
 v_def:=pg_get_functiondef('public.krim_warehouse_create_linked_goods_receipt_task(bigint,uuid,bigint,bigint,text,text,text,text,numeric,text,text,text,text,uuid)'::regprocedure);
 v_old:=$old$  IF v_task.facility_id<>p_facility_id OR v_task.task_type<>'goods_receipt'
   OR v_task.reference_code<>btrim(p_reference_code) OR v_task.shipment_id<>p_shipment_id
   OR v_task.shipment_leg_id<>p_shipment_leg_id OR v_task.sku IS DISTINCT FROM nullif(btrim(p_sku),'')
   OR v_task.quantity IS DISTINCT FROM p_quantity
   OR v_task.quality_status<>coalesce(p_quality_status,'pending') THEN$old$;
 v_new:=$new$  IF v_task.facility_id<>p_facility_id OR v_task.task_type<>'goods_receipt'
   OR v_task.reference_code<>btrim(p_reference_code) OR v_task.shipment_id<>p_shipment_id
   OR v_task.shipment_leg_id<>p_shipment_leg_id OR v_task.sku IS DISTINCT FROM nullif(btrim(p_sku),'')
   OR v_task.item_description IS DISTINCT FROM nullif(btrim(p_item_description),'')
   OR v_task.lot_code IS DISTINCT FROM nullif(btrim(p_lot_code),'')
   OR v_task.quantity IS DISTINCT FROM p_quantity
   OR v_task.unit_code<>coalesce(nullif(btrim(p_unit_code),''),'unit')
   OR v_task.destination_location IS DISTINCT FROM nullif(btrim(p_destination_location),'')
   OR v_task.quality_status<>coalesce(p_quality_status,'pending')
   OR v_task.notes<>left(coalesce(p_notes,''),4000) THEN$new$;
 IF position(v_old in v_def)=0 THEN RAISE EXCEPTION 'Linked goods receipt idempotency guard anchor changed'; END IF;
 EXECUTE replace(v_def,v_old,v_new);

 v_def:=pg_get_functiondef('public.krim_warehouse_create_linked_pick_task(bigint,uuid,bigint,bigint,text,text,text,text,numeric,text,text,text,uuid)'::regprocedure);
 v_old:=$old$  IF v_task.facility_id<>p_facility_id OR v_task.task_type<>'picking_packing'
   OR v_task.reference_code<>btrim(p_reference_code) OR v_task.shipment_id<>p_shipment_id
   OR v_task.shipment_leg_id<>p_shipment_leg_id OR v_task.sku IS DISTINCT FROM nullif(btrim(p_sku),'')
   OR v_task.quantity IS DISTINCT FROM p_quantity THEN$old$;
 v_new:=$new$  IF v_task.facility_id<>p_facility_id OR v_task.task_type<>'picking_packing'
   OR v_task.reference_code<>btrim(p_reference_code) OR v_task.shipment_id<>p_shipment_id
   OR v_task.shipment_leg_id<>p_shipment_leg_id OR v_task.sku IS DISTINCT FROM nullif(btrim(p_sku),'')
   OR v_task.item_description IS DISTINCT FROM nullif(btrim(p_item_description),'')
   OR v_task.lot_code IS DISTINCT FROM nullif(btrim(p_lot_code),'')
   OR v_task.quantity IS DISTINCT FROM p_quantity
   OR v_task.unit_code<>coalesce(nullif(btrim(p_unit_code),''),'unit')
   OR v_task.source_location IS DISTINCT FROM nullif(btrim(p_source_location),'')
   OR v_task.notes<>left(coalesce(p_notes,''),4000) THEN$new$;
 IF position(v_old in v_def)=0 THEN RAISE EXCEPTION 'Linked pick task idempotency guard anchor changed'; END IF;
 EXECUTE replace(v_def,v_old,v_new);

 v_def:=pg_get_functiondef('public.krim_warehouse_create_linked_handover_task(bigint,uuid,bigint,bigint,text,text,uuid)'::regprocedure);
 v_old:=$old$   OR v_task.shipment_leg_id<>p_shipment_leg_id THEN$old$;
 v_new:=$new$   OR v_task.shipment_leg_id<>p_shipment_leg_id
   OR v_task.notes<>left(coalesce(p_notes,''),4000) THEN$new$;
 IF position(v_old in v_def)=0 THEN RAISE EXCEPTION 'Linked handover task idempotency guard anchor changed'; END IF;
 EXECUTE replace(v_def,v_old,v_new);
END;
$migration$;
