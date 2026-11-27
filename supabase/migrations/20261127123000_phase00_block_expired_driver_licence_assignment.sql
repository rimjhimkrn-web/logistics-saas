-- Phase 00: prevent assigning drivers whose licence is already expired.
-- Staging-only. Preserve the existing function body and replace one exact eligibility predicate.
DO $migration$
DECLARE
  v_definition text;
  v_old text := $$dp.verification_status IN('verified','approved') AND nullif(btrim(dp.licence_number),'') IS NOT NULL$$;
  v_new text := $$dp.verification_status IN('verified','approved') AND dp.licence_expiry_date>=current_date AND nullif(btrim(dp.licence_number),'') IS NOT NULL$$;
BEGIN
  SELECT pg_get_functiondef('public.krim_assign_driver_to_partner_shipment(bigint,uuid)'::regprocedure)
    INTO v_definition;
  IF position(v_old IN v_definition)=0 THEN
    RAISE EXCEPTION 'Expected driver eligibility predicate not found; migration stopped without changing function';
  END IF;
  v_definition := replace(v_definition, v_old, v_new);
  EXECUTE v_definition;
END
$migration$;

REVOKE ALL ON FUNCTION public.krim_assign_driver_to_partner_shipment(bigint,uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.krim_assign_driver_to_partner_shipment(bigint,uuid) TO authenticated, service_role;
