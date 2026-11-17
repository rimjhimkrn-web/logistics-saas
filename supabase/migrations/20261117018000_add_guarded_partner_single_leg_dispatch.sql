-- Guarded single-leg dispatch entry point. The internal dispatcher remains
-- non-executable by authenticated users; this wrapper binds it to the caller's
-- partner permission and a current exact-leg physical dispatch authorization.
CREATE OR REPLACE FUNCTION public.krim_partner_dispatch_assigned_shipment(
  p_partner_assignment_id bigint,
  p_idempotency_key text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_user uuid := auth.uid();
  v_assignment public.krim_shipment_partner_assignments%ROWTYPE;
  v_shipment public.krim_shipments%ROWTYPE;
  v_leg_count integer;
  v_auth public.krim_shipment_leg_dispatch_authorizations%ROWTYPE;
  v_result jsonb;
BEGIN
  IF v_user IS NULL THEN
    RAISE EXCEPTION USING errcode='28000', message='Authentication required';
  END IF;
  IF p_partner_assignment_id IS NULL
     OR nullif(btrim(p_idempotency_key),'') IS NULL
     OR length(p_idempotency_key)>160 THEN
    RAISE EXCEPTION USING errcode='22023', message='A valid assignment and idempotency key are required';
  END IF;

  SELECT * INTO v_assignment
  FROM public.krim_shipment_partner_assignments
  WHERE id=p_partner_assignment_id
  FOR UPDATE;
  IF NOT FOUND OR v_assignment.status NOT IN ('accepted','active')
     OR v_assignment.shipment_leg_id IS NULL THEN
    RAISE EXCEPTION USING errcode='55000', message='An accepted exact-leg partner assignment is required';
  END IF;
  IF NOT public.krim_has_permission(v_user,v_assignment.partner_organization_id,'shipment.dispatch') THEN
    RAISE EXCEPTION USING errcode='42501', message='Partner dispatch permission is required';
  END IF;

  SELECT * INTO v_shipment
  FROM public.krim_shipments
  WHERE id=v_assignment.shipment_id
  FOR UPDATE;
  IF NOT FOUND OR v_shipment.status NOT IN ('assigned','dispatched') THEN
    RAISE EXCEPTION USING errcode='55000', message='Shipment must be assigned before dispatch';
  END IF;

  SELECT count(*)::integer INTO v_leg_count
  FROM public.krim_shipment_legs
  WHERE shipment_id=v_shipment.id
    AND status NOT IN ('cancelled');
  IF v_leg_count<>1 THEN
    RAISE EXCEPTION USING errcode='0A000', message='Shipment-wide dispatch is restricted to a single active leg. Use exact-leg dispatch authorization for multi-leg shipments.';
  END IF;

  v_auth := public.krim_authorize_leg_dispatch(p_partner_assignment_id,p_idempotency_key);

  v_result := public.krim_internal_dispatch_assigned_shipment(p_partner_assignment_id);

  RETURN v_result || jsonb_build_object(
    'dispatch_authorization_id',v_auth.id,
    'dispatch_authorization_status',v_auth.status,
    'dispatch_scope','single_leg'
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.krim_partner_dispatch_assigned_shipment(bigint,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.krim_partner_dispatch_assigned_shipment(bigint,text) TO authenticated;
