CREATE OR REPLACE FUNCTION private.krim_guard_dispatch_handover_evidence()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
 IF NEW.task_type='dispatch_handover' AND NEW.status='completed' AND OLD.status IS DISTINCT FROM NEW.status THEN
  IF NEW.shipment_id IS NULL OR NEW.shipment_leg_id IS NULL THEN
   RAISE EXCEPTION 'Dispatch handover must be linked to a shipment and shipment leg' USING errcode='23514';
  END IF;
  IF NOT EXISTS(
   SELECT 1 FROM public.krim_warehouse_evidence e
   JOIN storage.objects o ON o.bucket_id=e.bucket_id AND o.name=e.storage_path AND o.owner=e.created_by
   WHERE e.task_id=NEW.id AND e.organization_id=NEW.organization_id AND e.facility_id=NEW.facility_id
    AND e.evidence_type='dispatch_proof' AND e.bucket_id='krim-warehouse-evidence'
    AND split_part(e.storage_path,'/',1)=e.organization_id::text
    AND split_part(e.storage_path,'/',2)=e.created_by::text
    AND cardinality(string_to_array(e.storage_path,'/'))=3
    AND coalesce(o.metadata->>'mimetype','') IN ('image/jpeg','image/png','application/pdf')
    AND pg_catalog.pg_input_is_valid(o.metadata->>'size','bigint')
    AND (o.metadata->>'size')::bigint BETWEEN 1 AND 10485760
  ) THEN
   RAISE EXCEPTION 'Dispatch handover cannot be completed until current private, uploader-owned dispatch proof is registered for this exact task' USING errcode='23514';
  END IF;
 END IF;
 RETURN NEW;
END;
$function$;
