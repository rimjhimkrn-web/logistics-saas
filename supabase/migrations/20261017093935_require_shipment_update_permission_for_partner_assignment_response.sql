-- Require the existing shipment.update RBAC permission before accepting/rejecting a partner assignment.
-- This keeps the RPC available to signed-in partner users while enforcing least privilege.
DO $migration$
DECLARE
  v_definition text;
  v_old text := 'IF v_assignment.status=''accepted'' AND p_accept THEN RETURN v_assignment; END IF;';
  v_new text := $replacement$
IF NOT private.krim_has_permission(v_user_id, v_assignment.partner_organization_id, 'shipment.update') THEN
    RAISE EXCEPTION USING errcode='42501', message='Permission denied: shipment.update';
  END IF;
  IF v_assignment.status='accepted' AND p_accept THEN RETURN v_assignment; END IF;
$replacement$;
BEGIN
  v_definition := pg_get_functiondef('public.krim_respond_to_partner_assignment(bigint,boolean,text)'::regprocedure);
  IF position('Permission denied: shipment.update' IN v_definition) > 0 THEN
    RETURN;
  END IF;
  IF position(v_old IN v_definition) = 0 THEN
    RAISE EXCEPTION 'Expected partner assignment guard was not found; aborting migration';
  END IF;
  v_definition := replace(v_definition, v_old, v_new);
  EXECUTE v_definition;
END
$migration$;
