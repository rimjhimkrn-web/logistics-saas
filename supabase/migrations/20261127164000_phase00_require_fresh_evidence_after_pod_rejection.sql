DO $migration$
DECLARE
  v_def text;
  v_old text;
  v_new text;
BEGIN
  SELECT pg_get_functiondef('public.krim_driver_submit_delivery_pod(uuid,text,text,text)'::regprocedure) INTO v_def;
  v_old := $old$
  IF v_driver_assignment.status<>'in_transit' THEN
    RAISE EXCEPTION USING ERRCODE='55000', MESSAGE='Record pickup and in-transit milestones before submitting delivery evidence';
  END IF;
$old$;
  v_new := $new$
  IF v_driver_assignment.status<>'in_transit' THEN
    RAISE EXCEPTION USING ERRCODE='55000', MESSAGE='Record pickup and in-transit milestones before submitting delivery evidence';
  END IF;
  IF EXISTS (
    SELECT 1 FROM public.krim_pod_records r
    WHERE r.assignment_id=v_driver_assignment.partner_assignment_id
      AND r.shipment_id=v_driver_assignment.shipment_id
      AND r.shipment_leg_id=v_driver_assignment.shipment_leg_id
      AND r.pod_type='delivery' AND r.status='rejected'
  ) AND NOT EXISTS (
    SELECT 1 FROM public.krim_driver_delivery_evidence e
    WHERE e.assignment_id=v_driver_assignment.id AND e.user_id=v_user
      AND e.created_at > (
        SELECT max(r.verified_at) FROM public.krim_pod_records r
        WHERE r.assignment_id=v_driver_assignment.partner_assignment_id
          AND r.shipment_id=v_driver_assignment.shipment_id
          AND r.shipment_leg_id=v_driver_assignment.shipment_leg_id
          AND r.pod_type='delivery' AND r.status='rejected'
      )
  ) THEN
    RAISE EXCEPTION USING ERRCODE='55000',
      MESSAGE='Upload new delivery evidence after the latest POD rejection before resubmitting';
  END IF;
$old$;
  IF position(v_old in v_def)=0 THEN RAISE EXCEPTION 'Driver POD submission anchor missing'; END IF;
  EXECUTE replace(v_def,v_old,v_new);

  SELECT pg_get_functiondef('public.krim_admin_review_delivery_pod(bigint,text,text)'::regprocedure) INTO v_def;
  v_old := $old$
     and da.organization_id=v_pod.partner_organization_id
 ) then
$old$;
  v_new := $new$
     and da.organization_id=v_pod.partner_organization_id
     and e.created_at > coalesce((
       select max(r.verified_at) from public.krim_pod_records r
       where r.assignment_id=v_pod.assignment_id
         and r.shipment_id=v_pod.shipment_id
         and r.shipment_leg_id=v_pod.shipment_leg_id
         and r.pod_type='delivery' and r.status='rejected'
     ), '-infinity'::timestamptz)
 ) then
$old$;
  IF position(v_old in v_def)=0 THEN RAISE EXCEPTION 'Admin POD evidence freshness anchor missing'; END IF;
  EXECUTE replace(v_def,v_old,v_new);
END
$migration$;