DO $migration$
DECLARE
  v_definition text;
  v_old text := $old$
     and da.organization_id=v_pod.partner_organization_id
$old$;
  v_new text := $replacement$
     and da.organization_id=v_pod.partner_organization_id
     and e.created_at > (
       select max(coalesce(r.verified_at,r.updated_at))
       from public.krim_pod_records r
       where r.assignment_id=v_pod.assignment_id
         and r.shipment_id=v_pod.shipment_id
         and r.shipment_leg_id=v_pod.shipment_leg_id
         and r.pod_type='delivery'
         and r.status='rejected'
     )
$replacement$;
BEGIN
  SELECT pg_get_functiondef('public.krim_admin_review_delivery_pod(bigint,text,text)'::regprocedure)
  INTO v_definition;
  IF position(v_old in v_definition)=0 THEN
    RAISE EXCEPTION 'Expected exact POD assignment scope in admin review not found; migration aborted';
  END IF;
  EXECUTE replace(v_definition,v_old,v_new);
END
$migration$;