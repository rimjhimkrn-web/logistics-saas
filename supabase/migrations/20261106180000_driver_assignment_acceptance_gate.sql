ALTER TABLE public.krim_driver_assignments
  ADD COLUMN IF NOT EXISTS accepted_at timestamptz,
  ADD COLUMN IF NOT EXISTS accepted_by uuid REFERENCES auth.users(id);

CREATE OR REPLACE FUNCTION public.krim_driver_accept_assignment(p_assignment_id uuid)
RETURNS public.krim_driver_assignments
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_user uuid := auth.uid();
  v_assignment public.krim_driver_assignments%ROWTYPE;
  v_partner public.krim_shipment_partner_assignments%ROWTYPE;
  v_shipment public.krim_shipments%ROWTYPE;
  v_leg public.krim_shipment_legs%ROWTYPE;
BEGIN
  IF v_user IS NULL THEN
    RAISE EXCEPTION USING errcode='28000', message='Authentication required';
  END IF;
  SELECT * INTO v_assignment FROM public.krim_driver_assignments
  WHERE id=p_assignment_id AND user_id=v_user FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION USING errcode='42501', message='Driver assignment not found for this account';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.krim_organization_members m
    WHERE m.user_id=v_user AND m.organization_id=v_assignment.organization_id
      AND lower(m.role)='driver' AND lower(m.status)='active') THEN
    RAISE EXCEPTION USING errcode='42501', message='Active driver membership is required';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.krim_driver_profiles dp
    WHERE dp.user_id=v_user AND dp.organization_id=v_assignment.organization_id
      AND dp.verification_status IN ('verified','approved')
      AND nullif(btrim(dp.licence_number),'') IS NOT NULL) THEN
    RAISE EXCEPTION USING errcode='42501', message='Current verified driver profile and licence are required';
  END IF;
  IF v_assignment.status='accepted' THEN
    IF v_assignment.accepted_by IS DISTINCT FROM v_user OR v_assignment.accepted_at IS NULL THEN
      RAISE EXCEPTION USING errcode='23514', message='Accepted assignment metadata is inconsistent; contact operations';
    END IF;
    RETURN v_assignment;
  END IF;
  IF v_assignment.status <> 'assigned' THEN
    RAISE EXCEPTION USING errcode='55000', message='Only a pending driver assignment can be accepted';
  END IF;
  SELECT * INTO v_partner FROM public.krim_shipment_partner_assignments
  WHERE id=v_assignment.partner_assignment_id AND shipment_id=v_assignment.shipment_id
    AND shipment_leg_id=v_assignment.shipment_leg_id
    AND partner_organization_id=v_assignment.organization_id AND status IN ('accepted','active')
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION USING errcode='23514', message='Accepted partner assignment does not match this driver assignment';
  END IF;
  SELECT * INTO v_shipment FROM public.krim_shipments
  WHERE id=v_assignment.shipment_id FOR UPDATE;
  IF NOT FOUND OR v_shipment.status <> 'assigned' THEN
    RAISE EXCEPTION USING errcode='55000', message='Shipment is not in an assignable state';
  END IF;
  SELECT * INTO v_leg FROM public.krim_shipment_legs
  WHERE id=v_assignment.shipment_leg_id AND shipment_id=v_assignment.shipment_id
    AND partner_organization_id=v_assignment.organization_id AND status='assigned'
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION USING errcode='23514', message='Shipment leg is no longer assigned to this partner';
  END IF;
  UPDATE public.krim_driver_assignments
  SET status='accepted',accepted_at=now(),accepted_by=v_user,updated_at=now()
  WHERE id=v_assignment.id RETURNING * INTO v_assignment;
  RETURN v_assignment;
END;
$function$;
REVOKE ALL ON FUNCTION public.krim_driver_accept_assignment(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.krim_driver_accept_assignment(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.krim_driver_record_trip_event(
  p_assignment_id uuid,p_event_type text,p_notes text DEFAULT ''
)
RETURNS public.krim_driver_assignments
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public','auth','pg_temp'
AS $function$
DECLARE
  v_user uuid := auth.uid();
  v_assignment public.krim_driver_assignments;
  v_next_status text;
BEGIN
  IF v_user IS NULL THEN
    RAISE EXCEPTION USING errcode='28000',message='Authentication required';
  END IF;
  IF p_event_type NOT IN ('pickup','in_transit','exception') THEN
    RAISE EXCEPTION USING errcode='22023',
      message='Unsupported trip event. Delivery completion is recorded only after authorized POD verification.';
  END IF;
  SELECT a.* INTO v_assignment FROM public.krim_driver_assignments a
  WHERE a.id=p_assignment_id AND a.user_id=v_user
    AND EXISTS (SELECT 1 FROM public.krim_organization_members m
      WHERE m.user_id=v_user AND m.organization_id=a.organization_id
        AND lower(m.role)='driver' AND lower(m.status)='active')
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION USING errcode='42501',message='Assignment not found or active driver access is unavailable';
  END IF;
  IF v_assignment.status IN ('delivered','cancelled','declined') THEN
    RAISE EXCEPTION USING errcode='55000',message='This assignment is already closed';
  END IF;
  IF p_event_type='pickup' THEN
    IF v_assignment.status<>'accepted' OR v_assignment.accepted_at IS NULL
       OR v_assignment.accepted_by IS DISTINCT FROM v_user THEN
      RAISE EXCEPTION USING errcode='55000',message='Accept the driver assignment before recording pickup';
    END IF;
    v_next_status:='pickup_complete';
  ELSIF p_event_type='in_transit' THEN
    IF v_assignment.status<>'pickup_complete' THEN
      RAISE EXCEPTION USING errcode='55000',message='Record pickup before transit';
    END IF;
    v_next_status:='in_transit';
  ELSE
    IF length(btrim(coalesce(p_notes,'')))<3 THEN
      RAISE EXCEPTION USING errcode='22023',message='Please provide details for an exception';
    END IF;
    v_next_status:='exception';
  END IF;
  INSERT INTO public.krim_driver_trip_events(assignment_id,user_id,event_type,notes)
  VALUES(p_assignment_id,v_user,p_event_type,left(btrim(coalesce(p_notes,'')),1000));
  UPDATE public.krim_driver_assignments SET status=v_next_status,updated_at=now()
  WHERE id=p_assignment_id RETURNING * INTO v_assignment;
  RETURN v_assignment;
END;
$function$;
REVOKE ALL ON FUNCTION public.krim_driver_record_trip_event(uuid,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.krim_driver_record_trip_event(uuid,text,text) TO authenticated;