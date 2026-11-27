-- Phase 00: do not restore an in-progress driver trip after exception unless its dispatch authorization remains current.
DO $migration$
DECLARE
 v_definition text;
 v_old text := $old$  UPDATE public.krim_driver_assignments SET status = v_restore_status, updated_at = pg_catalog.now()$old$;
 v_new text := $new$  IF v_restore_status IN ('pickup_complete','in_transit')
     AND private.krim_leg_dispatch_authorization_is_current(
       v_assignment.shipment_id,
       v_assignment.shipment_leg_id,
       v_assignment.partner_assignment_id,
       v_assignment.organization_id
     ) IS NOT TRUE THEN
    RAISE EXCEPTION USING errcode = '55000',
      message = 'Trip progress cannot be restored: the linked dispatch authorization or live driver, vehicle, capacity, compliance or handover evidence is no longer current; operations review is required';
  END IF;
  UPDATE public.krim_driver_assignments SET status = v_restore_status, updated_at = pg_catalog.now()$new$;
BEGIN
 SELECT pg_get_functiondef('public.krim_partner_resolve_driver_exception(uuid,text)'::regprocedure)
 INTO v_definition;
 IF position(v_old IN v_definition)=0 THEN
  RAISE EXCEPTION 'Expected exception-resolution status update not found; no change applied';
 END IF;
 v_definition:=replace(v_definition,v_old,v_new);
 EXECUTE v_definition;
END
$migration$;