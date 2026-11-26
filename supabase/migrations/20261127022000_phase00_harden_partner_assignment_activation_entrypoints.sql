-- Phase 00: harden legacy/internal assignment activation entry points.
-- Pending activation requests remain possible; actual activation requires a confirmed modern reservation.
CREATE OR REPLACE FUNCTION krim_internal.create_capacity_binding(
  p_shipment_id bigint,
  p_shipment_leg_id bigint,
  p_requested_by uuid,
  p_idempotency_key text
) RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog','public'
AS $function$
DECLARE
  v_id bigint;
BEGIN
  IF p_shipment_id IS NULL OR p_shipment_id <= 0
     OR p_shipment_leg_id IS NULL OR p_shipment_leg_id <= 0 THEN
    RAISE EXCEPTION 'valid_shipment_and_leg_required';
  END IF;
  IF p_idempotency_key IS NULL OR length(btrim(p_idempotency_key)) < 10 OR length(p_idempotency_key) > 120 THEN
    RAISE EXCEPTION 'valid_idempotency_key_required';
  END IF;

  PERFORM pg_advisory_xact_lock(hashtextextended('capacity-binding:'||p_shipment_id::text||':'||p_idempotency_key,0));

  IF NOT EXISTS (
    SELECT 1 FROM public.krim_shipment_legs l
    WHERE l.id=p_shipment_leg_id AND l.shipment_id=p_shipment_id
  ) THEN
    RAISE EXCEPTION 'shipment_leg_mismatch';
  END IF;

  SELECT id INTO v_id
  FROM public.krim_capacity_leg_bindings
  WHERE shipment_id=p_shipment_id AND idempotency_key=p_idempotency_key
  FOR UPDATE;

  IF v_id IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.krim_capacity_leg_bindings
      WHERE id=v_id AND shipment_leg_id=p_shipment_leg_id
        AND requested_by IS NOT DISTINCT FROM p_requested_by
    ) THEN
      RAISE EXCEPTION 'idempotency_key_reused_with_different_binding_parameters';
    END IF;
    RETURN v_id;
  END IF;

  INSERT INTO public.krim_capacity_leg_bindings(
    shipment_id,shipment_leg_id,binding_number,status,idempotency_key,requested_by
  ) VALUES (
    p_shipment_id,p_shipment_leg_id,
    'KRIM-CAPB-'||to_char(clock_timestamp(),'YYYYMMDDHH24MISSMS'),
    'pending',p_idempotency_key,p_requested_by
  ) RETURNING id INTO v_id;

  INSERT INTO public.krim_capacity_leg_binding_events(
    binding_id,event_type,new_status,actor_user_id,payload
  ) VALUES (
    v_id,'binding_requested','pending',p_requested_by,
    jsonb_build_object('shipment_id',p_shipment_id,'shipment_leg_id',p_shipment_leg_id)
  );
  RETURN v_id;
END;
$function$;

CREATE OR REPLACE FUNCTION krim_internal.create_partner_assignment_activation(
  p_shipment_id bigint,
  p_shipment_leg_id bigint,
  p_assignment_id bigint,
  p_requested_by uuid,
  p_idempotency_key text
) RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public','pg_catalog'
AS $function$
DECLARE
  v_assignment public.krim_shipment_partner_assignments%rowtype;
  v_id bigint;
  v_existing public.krim_partner_assignment_activations%rowtype;
BEGIN
  IF p_assignment_id IS NULL OR p_assignment_id <= 0
     OR p_shipment_id IS NULL OR p_shipment_id <= 0
     OR p_shipment_leg_id IS NULL OR p_shipment_leg_id <= 0 THEN
    RAISE EXCEPTION 'valid_assignment_shipment_and_leg_required';
  END IF;
  IF p_idempotency_key IS NULL OR length(btrim(p_idempotency_key)) < 10 OR length(p_idempotency_key) > 120 THEN
    RAISE EXCEPTION 'valid_idempotency_key_required';
  END IF;

  SELECT * INTO v_assignment
  FROM public.krim_shipment_partner_assignments
  WHERE id=p_assignment_id
  FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'assignment_not_found'; END IF;

  IF v_assignment.shipment_id IS DISTINCT FROM p_shipment_id
     OR v_assignment.shipment_leg_id IS DISTINCT FROM p_shipment_leg_id
     OR v_assignment.status NOT IN ('accepted','active') THEN
    RAISE EXCEPTION 'assignment_shipment_leg_or_status_mismatch';
  END IF;

  PERFORM pg_advisory_xact_lock(hashtextextended('assignment-activation:'||p_assignment_id::text,0));

  SELECT * INTO v_existing
  FROM public.krim_partner_assignment_activations
  WHERE assignment_id=p_assignment_id
  FOR UPDATE;

  IF FOUND THEN
    IF v_existing.shipment_id IS DISTINCT FROM p_shipment_id
       OR v_existing.shipment_leg_id IS DISTINCT FROM p_shipment_leg_id
       OR v_existing.requested_by IS DISTINCT FROM p_requested_by
       OR v_existing.idempotency_key IS DISTINCT FROM p_idempotency_key THEN
      RAISE EXCEPTION 'activation_idempotency_conflict';
    END IF;
    RETURN v_existing.id;
  END IF;

  INSERT INTO public.krim_partner_assignment_activations(
    shipment_id,shipment_leg_id,assignment_id,activation_number,status,
    requested_by,idempotency_key,validation_snapshot
  ) VALUES (
    p_shipment_id,p_shipment_leg_id,p_assignment_id,
    'KRIM-PAA-'||to_char(clock_timestamp(),'YYYYMMDDHH24MISSMS'),
    'pending',p_requested_by,p_idempotency_key,
    jsonb_build_object('assignment_status',v_assignment.status)
  ) RETURNING id INTO v_id;

  INSERT INTO public.krim_partner_assignment_activation_events(
    activation_id,event_type,new_status,actor_user_id,payload
  ) VALUES (
    v_id,'activation_requested','pending',p_requested_by,
    jsonb_build_object('shipment_id',p_shipment_id,'shipment_leg_id',p_shipment_leg_id,'assignment_id',p_assignment_id)
  );
  RETURN v_id;
END;
$function$;

CREATE OR REPLACE FUNCTION krim_internal.activate_partner_assignment(
  p_assignment_id bigint,
  p_capacity_binding_id bigint DEFAULT NULL,
  p_requested_by uuid DEFAULT NULL,
  p_idempotency_key text DEFAULT NULL
) RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public','pg_catalog'
AS $function$
DECLARE
  v_assignment public.krim_shipment_partner_assignments%rowtype;
  v_readiness public.krim_shipment_execution_readiness%rowtype;
  v_binding public.krim_capacity_leg_bindings%rowtype;
  v_reservation public.krim_capacity_reservations%rowtype;
  v_id bigint;
  v_existing public.krim_partner_assignment_activations%rowtype;
  v_binding_id bigint;
BEGIN
  IF p_assignment_id IS NULL OR p_assignment_id <= 0 THEN RAISE EXCEPTION 'valid_assignment_required'; END IF;
  IF p_idempotency_key IS NULL OR length(btrim(p_idempotency_key)) < 10 OR length(p_idempotency_key) > 120 THEN
    RAISE EXCEPTION 'valid_idempotency_key_required';
  END IF;

  SELECT * INTO v_assignment
  FROM public.krim_shipment_partner_assignments
  WHERE id=p_assignment_id
  FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'assignment_not_found'; END IF;
  IF v_assignment.status NOT IN ('accepted','active') THEN
    RAISE EXCEPTION 'assignment_must_be_accepted_before_activation';
  END IF;

  SELECT * INTO v_readiness
  FROM public.krim_shipment_execution_readiness
  WHERE shipment_id=v_assignment.shipment_id
  FOR UPDATE;
  IF NOT FOUND OR v_readiness.overall_result IS DISTINCT FROM 'ready' THEN
    RAISE EXCEPTION 'execution_prerequisites_not_ready';
  END IF;

  v_binding_id := coalesce(p_capacity_binding_id,v_assignment.capacity_binding_id);
  IF v_binding_id IS NULL THEN RAISE EXCEPTION 'confirmed_capacity_binding_required'; END IF;

  SELECT * INTO v_binding
  FROM public.krim_capacity_leg_bindings
  WHERE id=v_binding_id
  FOR UPDATE;
  IF NOT FOUND
     OR v_binding.status <> 'confirmed'
     OR v_binding.shipment_id IS DISTINCT FROM v_assignment.shipment_id
     OR v_binding.shipment_leg_id IS DISTINCT FROM v_assignment.shipment_leg_id
     OR v_binding.reservation_id IS NULL THEN
    RAISE EXCEPTION 'capacity_binding_not_confirmed_or_assignment_mismatch';
  END IF;

  SELECT * INTO v_reservation
  FROM public.krim_capacity_reservations
  WHERE id=v_binding.reservation_id
  FOR UPDATE;
  IF NOT FOUND
     OR v_reservation.status <> 'confirmed'
     OR v_reservation.shipment_id IS DISTINCT FROM v_assignment.shipment_id
     OR v_reservation.shipment_leg_id IS DISTINCT FROM v_assignment.shipment_leg_id
     OR v_reservation.organization_id IS DISTINCT FROM v_assignment.partner_organization_id
     OR v_reservation.capacity_availability_id IS DISTINCT FROM v_binding.capacity_availability_id THEN
    RAISE EXCEPTION 'confirmed_capacity_reservation_required';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.krim_shipment_legs l
    WHERE l.id=v_assignment.shipment_leg_id
      AND l.shipment_id=v_assignment.shipment_id
      AND l.partner_organization_id=v_assignment.partner_organization_id
  ) THEN RAISE EXCEPTION 'assignment_leg_partner_mismatch'; END IF;

  PERFORM pg_advisory_xact_lock(hashtextextended('assignment-activation:'||p_assignment_id::text,0));

  SELECT * INTO v_existing
  FROM public.krim_partner_assignment_activations
  WHERE assignment_id=p_assignment_id
  FOR UPDATE;

  IF FOUND THEN
    IF v_existing.shipment_id IS DISTINCT FROM v_assignment.shipment_id
       OR v_existing.shipment_leg_id IS DISTINCT FROM v_assignment.shipment_leg_id
       OR v_existing.capacity_binding_id IS DISTINCT FROM v_binding_id
       OR v_existing.requested_by IS DISTINCT FROM p_requested_by
       OR v_existing.idempotency_key IS DISTINCT FROM p_idempotency_key THEN
      RAISE EXCEPTION 'activation_idempotency_conflict';
    END IF;
    IF v_assignment.status='active' THEN RETURN v_existing.id; END IF;
    RAISE EXCEPTION 'activation_record_exists_but_assignment_is_not_active';
  END IF;

  INSERT INTO public.krim_partner_assignment_activations(
    shipment_id,shipment_leg_id,assignment_id,capacity_binding_id,
    activation_number,status,requested_by,idempotency_key,
    validation_snapshot,result_snapshot,started_at,completed_at,updated_at
  ) VALUES (
    v_assignment.shipment_id,v_assignment.shipment_leg_id,p_assignment_id,v_binding_id,
    'PA-'||p_assignment_id||'-'||extract(epoch from clock_timestamp())::bigint,
    'activated',p_requested_by,p_idempotency_key,
    jsonb_build_object('readiness_id',v_readiness.id,'reservation_id',v_reservation.id),
    jsonb_build_object('assignment_id',p_assignment_id,'capacity_binding_id',v_binding_id,'reservation_id',v_reservation.id),
    now(),now(),now()
  ) RETURNING id INTO v_id;

  UPDATE public.krim_shipment_partner_assignments
  SET status='active',capacity_binding_id=v_binding_id,accepted_at=coalesce(accepted_at,now()),updated_at=now()
  WHERE id=p_assignment_id;

  RETURN v_id;
END;
$function$;

REVOKE ALL ON FUNCTION krim_internal.create_capacity_binding(bigint,bigint,uuid,text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION krim_internal.create_partner_assignment_activation(bigint,bigint,bigint,uuid,text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION krim_internal.activate_partner_assignment(bigint,bigint,uuid,text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION krim_internal.create_capacity_binding(bigint,bigint,uuid,text) TO service_role;
GRANT EXECUTE ON FUNCTION krim_internal.create_partner_assignment_activation(bigint,bigint,bigint,uuid,text) TO service_role;
GRANT EXECUTE ON FUNCTION krim_internal.activate_partner_assignment(bigint,bigint,uuid,text) TO service_role;
