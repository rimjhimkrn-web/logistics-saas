DO $migration$
DECLARE
 v_def text;
 v_old text;
 v_new text;
BEGIN
 v_def:=pg_get_functiondef('public.krim_warehouse_review_inventory_quality(uuid,uuid,text,text)'::regprocedure);
 v_old:=$old$ select * into v_inventory from public.krim_warehouse_inventory
 where id=p_inventory_id and organization_id=v_task.organization_id and facility_id=v_task.facility_id
   and lower(sku)=lower(v_task.sku) and lot_code is not distinct from v_task.lot_code
 for update;
 if not found then raise exception 'Inventory SKU/lot does not match the reviewed task' using errcode='23514'; end if;
 v_previous:=v_inventory.quality_status;$old$;
 v_new:=$new$ select * into v_inventory from public.krim_warehouse_inventory
 where id=p_inventory_id and organization_id=v_task.organization_id and facility_id=v_task.facility_id
   and lower(sku)=lower(v_task.sku) and lot_code is not distinct from v_task.lot_code
 for update;
 if not found then raise exception 'Inventory SKU/lot does not match the reviewed task' using errcode='23514'; end if;

 IF EXISTS(
  SELECT 1
  FROM public.krim_warehouse_inventory_movements m
  LEFT JOIN public.krim_warehouse_tasks receipt_task
    ON m.reference_type='warehouse_task' AND m.reference_id=receipt_task.id::text
  WHERE m.inventory_id=v_inventory.id AND m.movement_type='receipt'
    AND (
      receipt_task.id IS NULL
      OR receipt_task.status<>'completed'
      OR receipt_task.task_type<>'goods_receipt'
      OR receipt_task.created_by=v_user
      OR receipt_task.completed_by=v_user
      OR NOT EXISTS(
        SELECT 1
        FROM public.krim_warehouse_evidence e
        JOIN storage.objects o
          ON o.bucket_id=e.bucket_id AND o.name=e.storage_path AND o.owner=e.created_by
        WHERE e.task_id=receipt_task.id AND e.evidence_type='inspection_report'
          AND e.organization_id=receipt_task.organization_id AND e.facility_id=receipt_task.facility_id
          AND e.bucket_id='krim-warehouse-evidence' AND e.created_by IS DISTINCT FROM v_user
          AND split_part(e.storage_path,'/',1)=e.organization_id::text
          AND split_part(e.storage_path,'/',2)=e.created_by::text
          AND cardinality(string_to_array(e.storage_path,'/'))=3
          AND coalesce(o.metadata->>'mimetype','') IN ('image/jpeg','image/png','application/pdf')
          AND coalesce(o.metadata->>'size','') ~ '^[0-9]+$'
          AND (o.metadata->>'size')::bigint BETWEEN 1 AND 10485760
      )
    )
 ) THEN
  RAISE EXCEPTION 'Every receipt contributing to this SKU/lot balance requires a completed goods-receipt task, independent reviewer and valid private inspection report before stock can be released' USING errcode='23514';
 END IF;
 v_previous:=v_inventory.quality_status;$new$;
 IF position(v_old in v_def)=0 THEN RAISE EXCEPTION 'Warehouse quality review inventory anchor changed'; END IF;
 EXECUTE replace(v_def,v_old,v_new);
END;
$migration$;
