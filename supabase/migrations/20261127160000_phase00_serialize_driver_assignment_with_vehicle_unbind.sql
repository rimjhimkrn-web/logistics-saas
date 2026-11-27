-- Phase 00: serialize driver assignment against vehicle-binding revocation and reject expiry-day licences.
DO $migration$
DECLARE
 v_definition text;
 v_old_lock text := $old$FOR UPDATE OF v;$old$;
 v_new_lock text := $new$FOR UPDATE OF v,b;$new$;
 v_old_expiry text := $old$dp.licence_expiry_date>=current_date AND nullif(btrim(dp.licence_number),'') IS NOT NULL$old$;
 v_new_expiry text := $new$dp.licence_expiry_date>current_date AND nullif(btrim(dp.licence_number),'') IS NOT NULL$new$;
BEGIN
 SELECT pg_get_functiondef('public.krim_assign_driver_to_partner_shipment(bigint,uuid)'::regprocedure)
 INTO v_definition;
 IF position(v_old_lock IN v_definition)=0 OR position(v_old_expiry IN v_definition)=0 THEN
  RAISE EXCEPTION 'Expected vehicle binding lock or licence predicate not found; no change applied';
 END IF;
 v_definition:=replace(v_definition,v_old_lock,v_new_lock);
 v_definition:=replace(v_definition,v_old_expiry,v_new_expiry);
 EXECUTE v_definition;
END
$migration$;