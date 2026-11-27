DO $migration$
DECLARE
  v_definition text;
  v_old text := $old$
   update public.krim_driver_assignments
   set status='delivered',updated_at=now()
   where partner_assignment_id=v_pod.assignment_id
     and status not in ('delivered','cancelled')
   returning id,user_id into v_driver_assignment_id,v_driver_user_id;
$old$;
  v_new text := $new$
   update public.krim_driver_assignments
   set status='delivered',updated_at=now()
   where id=(v_pod.evidence_metadata->>'driver_assignment_id')::uuid
     and partner_assignment_id=v_pod.assignment_id
     and shipment_id=v_pod.shipment_id
     and shipment_leg_id=v_pod.shipment_leg_id
     and organization_id=v_pod.partner_organization_id
     and status not in ('delivered','cancelled')
   returning id,user_id into v_driver_assignment_id,v_driver_user_id;
$new$;
BEGIN
  SELECT pg_get_functiondef('public.krim_admin_review_delivery_pod(bigint,text,text)'::regprocedure)
    INTO v_definition;
  IF position(v_old in v_definition)=0 THEN
    RAISE EXCEPTION 'Expected POD driver-closure block not found; migration aborted';
  END IF;
  IF position(v_old in substring(v_definition from position(v_old in v_definition)+length(v_old)))>0 THEN
    RAISE EXCEPTION 'Multiple POD driver-closure blocks found; migration aborted';
  END IF;
  EXECUTE replace(v_definition,v_old,v_new);
END
$migration$;