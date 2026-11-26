-- Delivery authorization must require an activated partner assignment.
-- The lifecycle trigger permits active -> completed, not accepted -> completed.
-- The previous authorization predicate admitted accepted assignments and would
-- then fail at the status transition. Tighten the predicate to match lifecycle.
DO $migration$
DECLARE
  v_definition text;
  v_old text := 'if v_assignment.status not in(''active'',''accepted'') then';
  v_new text := 'if v_assignment.status<>''active'' then';
BEGIN
  SELECT pg_get_functiondef('public.krim_internal_authorize_delivery(bigint,uuid)'::regprocedure)
    INTO v_definition;
  IF position(v_old IN v_definition)=0 THEN
    RAISE EXCEPTION 'Expected delivery assignment predicate not found; aborting migration';
  END IF;
  IF position(v_old IN substring(v_definition from position(v_old IN v_definition)+length(v_old)))>0 THEN
    RAISE EXCEPTION 'Predicate occurs more than once; aborting migration';
  END IF;
  EXECUTE replace(v_definition,v_old,v_new);
END
$migration$;

COMMENT ON FUNCTION public.krim_internal_authorize_delivery(bigint,uuid) IS
'Service-role-only delivery authorization after verified POD; requires an active partner assignment and exact shipment/leg/partner identity.';
