-- Phase 00 Checkpoint 16: authenticate lane-specific capacity registration
-- before reading lane metadata, so unauthenticated callers cannot probe lane state.

CREATE OR REPLACE FUNCTION public.krim_partner_register_capacity_resource_for_lane(
  p_organization_id bigint,
  p_lane_id bigint,
  p_resource_type text,
  p_resource_name text,
  p_transport_mode_id bigint,
  p_location_id bigint,
  p_capacity_value numeric,
  p_capacity_unit text,
  p_availability_type text,
  p_available_from timestamp with time zone,
  p_available_until timestamp with time zone,
  p_document_paths text[],
  p_notes text DEFAULT ''::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public'
AS $function$
DECLARE
  v_lane public.krim_network_lanes%rowtype;
  v_result jsonb;
  v_availability_id bigint;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION USING errcode='28000', message='Authentication required';
  END IF;

  IF p_lane_id IS NULL THEN
    RAISE EXCEPTION USING errcode='22023', message='A network lane is required for lane-specific capacity registration';
  END IF;

  SELECT * INTO v_lane
  FROM public.krim_network_lanes
  WHERE id=p_lane_id
  FOR SHARE;

  IF NOT FOUND
     OR v_lane.status <> 'active'
     OR v_lane.origin_location_id <> p_location_id
     OR v_lane.transport_mode_id IS DISTINCT FROM p_transport_mode_id THEN
    RAISE EXCEPTION USING errcode='23514',
      message='Selected lane must be active and match the resource origin and transport mode';
  END IF;

  v_result := public.krim_partner_register_capacity_resource(
    p_organization_id,
    p_resource_type,
    p_resource_name,
    p_transport_mode_id,
    p_location_id,
    p_capacity_value,
    p_capacity_unit,
    p_availability_type,
    p_available_from,
    p_available_until,
    p_document_paths,
    p_notes
  );

  v_availability_id := nullif(v_result->>'availability_id','')::bigint;
  IF v_availability_id IS NULL THEN
    RAISE EXCEPTION USING errcode='55000', message='Capacity registration did not return an availability record';
  END IF;

  UPDATE public.krim_partner_capacity_availability
  SET lane_id=p_lane_id, updated_at=now()
  WHERE id=v_availability_id
    AND organization_id=p_organization_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION USING errcode='55000', message='Could not attach the selected lane to the new availability record';
  END IF;

  RETURN v_result || jsonb_build_object('lane_id',p_lane_id);
END;
$function$;
