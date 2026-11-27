DO $migration$
DECLARE
  v_definition text;
  v_old text := $old$
  IF v_driver_assignment.status<>'in_transit' THEN
    RAISE EXCEPTION USING ERRCODE='55000', MESSAGE='Record pickup and in-transit milestones before submitting delivery evidence';
  END IF;
$old$;
  v_new text := $replacement$
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
    WHERE e.assignment_id=v_driver_assignment.id
      AND e.user_id=v_user
      AND e.created_at > (
        SELECT max(coalesce(r.verified_at,r.updated_at))
        FROM public.krim_pod_records r
        WHERE r.assignment_id=v_driver_assignment.partner_assignment_id
          AND r.shipment_id=v_driver_assignment.shipment_id
          AND r.shipment_leg_id=v_driver_assignment.shipment_leg_id
          AND r.pod_type='delivery' AND r.status='rejected'
      )
  ) THEN
    RAISE EXCEPTION USING ERRCODE='55000',
      MESSAGE='Upload new delivery evidence after the latest POD rejection before resubmitting';
  END IF;
$replacement$;
BEGIN
  SELECT pg_get_functiondef('public.krim_driver_submit_delivery_pod(uuid,text,text,text)'::regprocedure)
  INTO v_definition;
  IF position(v_old in v_definition)=0 THEN
    RAISE EXCEPTION 'Expected driver POD submission status guard not found; migration aborted';
  END IF;
  EXECUTE replace(v_definition,v_old,v_new);
END
$migration$;