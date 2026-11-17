-- Restore a driver assignment after partner operations resolves an exception.
-- Recovery is auditable and returns the assignment to its last safe milestone.
CREATE OR REPLACE FUNCTION public.krim_partner_resolve_driver_exception(
  p_assignment_id uuid,
  p_resolution_notes text
)
RETURNS public.krim_driver_assignments
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_user uuid := auth.uid();
  v_assignment public.krim_driver_assignments%ROWTYPE;
  v_partner_assignment public.krim_shipment_partner_assignments%ROWTYPE;
  v_previous_event text;
  v_restore_status text;
  v_notes text := left(btrim(coalesce(p_resolution_notes, '')), 1000);
BEGIN
  IF v_user IS NULL THEN RAISE EXCEPTION USING errcode = '28000', message = 'Authentication required'; END IF;
  IF length(v_notes) < 5 THEN RAISE EXCEPTION USING errcode = '22023', message = 'Provide at least 5 characters explaining how the exception was resolved'; END IF;
  SELECT a.* INTO v_assignment FROM public.krim_driver_assignments a WHERE a.id = p_assignment_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION USING errcode = 'P0002', message = 'Driver assignment not found'; END IF;
  IF NOT public.krim_has_permission(v_user, v_assignment.organization_id, 'shipment.dispatch') THEN
    RAISE EXCEPTION USING errcode = '42501', message = 'Shipment dispatch permission is required to resolve a driver exception';
  END IF;
  IF v_assignment.status <> 'exception' THEN RAISE EXCEPTION USING errcode = '55000', message = 'Only an assignment currently in exception status can be resolved'; END IF;
  IF v_assignment.partner_assignment_id IS NULL OR v_assignment.shipment_id IS NULL OR v_assignment.shipment_leg_id IS NULL THEN
    RAISE EXCEPTION USING errcode = '23514', message = 'Driver assignment is missing its shipment, leg or partner assignment linkage';
  END IF;
  SELECT pa.* INTO v_partner_assignment FROM public.krim_shipment_partner_assignments pa
  WHERE pa.id = v_assignment.partner_assignment_id AND pa.shipment_id = v_assignment.shipment_id
    AND pa.shipment_leg_id = v_assignment.shipment_leg_id AND pa.partner_organization_id = v_assignment.organization_id
  FOR UPDATE;
  IF NOT FOUND OR v_partner_assignment.status NOT IN ('accepted', 'active') THEN
    RAISE EXCEPTION USING errcode = '55000', message = 'The linked partner assignment is no longer active; operations review is required';
  END IF;
  SELECT e.event_type INTO v_previous_event FROM public.krim_driver_trip_events e
  WHERE e.assignment_id = p_assignment_id AND e.user_id = v_assignment.user_id
    AND e.event_type IN ('pickup', 'in_transit')
    AND (e.created_at, e.id) < (
      SELECT x.created_at, x.id FROM public.krim_driver_trip_events x
      WHERE x.assignment_id = p_assignment_id AND x.user_id = v_assignment.user_id AND x.event_type = 'exception'
      ORDER BY x.created_at DESC, x.id DESC LIMIT 1
    )
  ORDER BY e.created_at DESC, e.id DESC LIMIT 1;
  IF NOT EXISTS (SELECT 1 FROM public.krim_driver_trip_events x
    WHERE x.assignment_id = p_assignment_id AND x.user_id = v_assignment.user_id AND x.event_type = 'exception') THEN
    RAISE EXCEPTION USING errcode = '23514', message = 'No recorded driver exception exists for this assignment';
  END IF;
  v_restore_status := CASE WHEN v_previous_event = 'in_transit' THEN 'in_transit'
                           WHEN v_previous_event = 'pickup' THEN 'pickup_complete'
                           ELSE 'accepted' END;
  UPDATE public.krim_driver_assignments SET status = v_restore_status, updated_at = pg_catalog.now()
  WHERE id = p_assignment_id RETURNING * INTO v_assignment;
  INSERT INTO public.krim_audit_events (
    actor_user_id, organization_id, event_type, entity_type, entity_id, source, metadata, previous_state, new_state
  ) VALUES (
    v_user, v_assignment.organization_id, 'driver.exception.resolved', 'driver_assignment',
    v_assignment.id::text, 'partner-operations',
    pg_catalog.jsonb_build_object('shipment_id', v_assignment.shipment_id,
      'shipment_leg_id', v_assignment.shipment_leg_id, 'driver_user_id', v_assignment.user_id,
      'resolution_notes', v_notes, 'restored_from_event', coalesce(v_previous_event, 'assignment_accepted')),
    pg_catalog.jsonb_build_object('status', 'exception'),
    pg_catalog.jsonb_build_object('status', v_restore_status)
  );
  RETURN v_assignment;
END;
$function$;
REVOKE ALL ON FUNCTION public.krim_partner_resolve_driver_exception(uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.krim_partner_resolve_driver_exception(uuid, text) FROM anon;
GRANT EXECUTE ON FUNCTION public.krim_partner_resolve_driver_exception(uuid, text) TO authenticated;
