-- Phase 00: keep exact-leg dispatch currentness valid across accepted and in-progress driver states.
DO $migration$
DECLARE
 v_definition text;
 v_old_status text := $old$AND driver_assignment.status='accepted'$old$;
 v_new_status text := $new$AND driver_assignment.status IN ('accepted','pickup_complete','in_transit','exception')$new$;
 v_old_expiry text := $old$AND dp.licence_expiry_date>=current_date$new$;
 v_new_expiry text := $new$AND dp.licence_expiry_date>current_date$new$;
BEGIN
 SELECT pg_get_functiondef('private.krim_leg_dispatch_authorization_is_current(bigint,bigint,bigint,bigint)'::regprocedure)
 INTO v_definition;
 IF position(v_old_status IN v_definition)=0 OR position(v_old_expiry IN v_definition)=0 THEN
  RAISE EXCEPTION 'Expected driver status/licence predicates not found; no change applied';
 END IF;
 v_definition:=replace(v_definition,v_old_status,v_new_status);
 v_definition:=replace(v_definition,v_old_expiry,v_new_expiry);
 EXECUTE v_definition;
END
$migration$;