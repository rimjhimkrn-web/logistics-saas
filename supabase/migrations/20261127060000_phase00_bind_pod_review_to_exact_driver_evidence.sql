DO $migration$
DECLARE
  v_oid oid;
  v_def text;
  v_old text := $old$
   where da.partner_assignment_id=v_pod.assignment_id
 ) then
   raise exception using errcode='55000',message='POD verification requires at least one existing private delivery evidence object owned by the assigned driver';
$old$;
  v_new text := $new$
   where da.partner_assignment_id=v_pod.assignment_id
     and da.id::text = v_pod.evidence_metadata->>'driver_assignment_id'
     and da.shipment_id=v_pod.shipment_id
     and da.shipment_leg_id=v_pod.shipment_leg_id
     and da.organization_id=v_pod.partner_organization_id
 ) then
   raise exception using errcode='55000',message='POD verification requires private delivery evidence owned by the exact driver assignment, shipment leg and partner';
$new$;
BEGIN
  SELECT p.oid INTO v_oid
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid=p.pronamespace
  WHERE n.nspname='public'
    AND p.proname='krim_admin_review_delivery_pod'
    AND pg_get_function_identity_arguments(p.oid)='p_pod_id bigint, p_decision text, p_reason text';
  IF v_oid IS NULL THEN
    RAISE EXCEPTION 'Target POD review function not found';
  END IF;
  v_def := pg_get_functiondef(v_oid);
  IF position(v_old in v_def)=0 THEN
    RAISE EXCEPTION 'Expected evidence ownership check was not found; migration aborted';
  END IF;
  IF position(v_new in v_def)>0 THEN
    RAISE NOTICE 'Exact POD evidence binding already present';
    RETURN;
  END IF;
  EXECUTE replace(v_def,v_old,v_new);
END
$migration$;