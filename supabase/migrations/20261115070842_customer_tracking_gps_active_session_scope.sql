CREATE OR REPLACE FUNCTION public.krim_get_shipment_tracking(p_shipment_number text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_shipment public.krim_shipments%rowtype;
  v_allowed boolean := false;
  v_result jsonb;
  v_tracking_session_id uuid;
  v_tracking_session_started_at timestamptz;
  v_latest_gps public.krim_tracking_events%rowtype;
  v_terminal boolean := false;
  v_gps_status text := 'inactive';
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Authentication required'; END IF;
  IF p_shipment_number IS NULL OR length(trim(p_shipment_number)) < 4 OR length(trim(p_shipment_number)) > 80 THEN
    RAISE EXCEPTION 'Enter a valid shipment reference';
  END IF;
  SELECT * INTO v_shipment FROM public.krim_shipments
   WHERE upper(shipment_number) = upper(trim(p_shipment_number)) LIMIT 1;
  IF NOT FOUND THEN RAISE EXCEPTION 'Shipment not found or access is not permitted'; END IF;

  SELECT private.krim_has_organization_access(v_uid, v_shipment.customer_organization_id)
    INTO v_allowed WHERE v_shipment.customer_organization_id IS NOT NULL;
  IF NOT coalesce(v_allowed, false) THEN
    SELECT EXISTS (
      SELECT 1 FROM public.krim_shipment_partner_assignments a
      JOIN public.krim_organization_members m ON m.organization_id=a.partner_organization_id
       AND m.user_id=v_uid AND m.status='active'
      WHERE a.shipment_id=v_shipment.id AND a.status IN ('accepted','active','in_progress','assigned')
    ) INTO v_allowed;
  END IF;
  IF NOT coalesce(v_allowed, false) THEN RAISE EXCEPTION 'Shipment not found or access is not permitted'; END IF;

  v_terminal := lower(coalesce(v_shipment.status,'')) IN ('delivered','cancelled','closed','completed');

  IF NOT v_terminal THEN
    SELECT ts.id, ts.started_at INTO v_tracking_session_id, v_tracking_session_started_at
    FROM public.krim_driver_tracking_sessions ts
    JOIN public.krim_driver_assignments d ON d.id=ts.driver_assignment_id
      AND d.user_id=ts.user_id AND d.organization_id=ts.organization_id
      AND d.shipment_id=v_shipment.id AND d.shipment_leg_id=ts.shipment_leg_id
      AND d.status='in_transit'
    JOIN public.krim_shipment_partner_assignments a ON a.id=ts.partner_assignment_id
      AND a.shipment_id=v_shipment.id AND a.shipment_leg_id=ts.shipment_leg_id
      AND a.partner_organization_id=ts.organization_id
      AND a.status IN ('accepted','active','in_progress','assigned')
    JOIN public.krim_organization_members m ON m.organization_id=ts.organization_id
      AND m.user_id=ts.user_id AND m.role='driver' AND m.status='active'
    JOIN public.krim_organizations o ON o.id=ts.organization_id AND o.status='active'
    JOIN public.krim_driver_profiles dp ON dp.user_id=ts.user_id
      AND dp.organization_id=ts.organization_id
      AND lower(dp.verification_status) IN ('verified','approved')
      AND NULLIF(btrim(dp.licence_number),'') IS NOT NULL
    WHERE ts.shipment_id=v_shipment.id AND ts.status='active'
      AND NULLIF(btrim(ts.consent_notice_text),'') IS NOT NULL
      AND ts.consent_notice_sha256 ~ '^[0-9a-f]{64}$'
      AND ts.platform IN ('android','ios')
    ORDER BY ts.started_at DESC LIMIT 1;

    IF v_tracking_session_id IS NOT NULL THEN
      SELECT e.* INTO v_latest_gps FROM public.krim_tracking_events e
      WHERE e.shipment_id=v_shipment.id AND e.source_type='gps'
        AND e.event_type='gps_position'
        AND e.metadata->>'tracking_session_id'=v_tracking_session_id::text
        AND e.event_time<=now()+interval '1 minute'
      ORDER BY e.event_time DESC LIMIT 1;
    END IF;
  END IF;

  IF v_terminal THEN v_gps_status:='completed';
  ELSIF v_tracking_session_id IS NULL THEN v_gps_status:='inactive';
  ELSIF v_latest_gps.id IS NULL THEN
    v_gps_status:=CASE WHEN v_tracking_session_started_at>=now()-interval '2 minutes' THEN 'starting' ELSE 'stale' END;
  ELSIF v_latest_gps.event_time>=now()-interval '2 minutes' THEN v_gps_status:='active';
  ELSIF v_latest_gps.event_time>=now()-interval '15 minutes' THEN v_gps_status:='delayed';
  ELSE v_gps_status:='stale';
  END IF;

  SELECT jsonb_build_object(
    'shipment',jsonb_build_object(
      'id',v_shipment.id,'shipment_number',v_shipment.shipment_number,'status',v_shipment.status,
      'origin',coalesce(v_shipment.origin_place_label,'Origin not specified'),
      'destination',coalesce(v_shipment.destination_place_label,'Destination not specified'),
      'goods_description',v_shipment.goods_description,'total_weight_kg',v_shipment.total_weight_kg,
      'transport_mode',v_shipment.requested_transport_mode,'estimated_delivery_at',v_shipment.estimated_delivery_at,
      'actual_delivery_at',v_shipment.actual_delivery_at,'created_at',v_shipment.created_at
    ),
    'gps_sharing_status',v_gps_status,
    'latest_position',CASE WHEN v_tracking_session_id IS NOT NULL AND v_latest_gps.id IS NOT NULL
      AND v_latest_gps.event_time>=now()-interval '15 minutes'
      AND v_latest_gps.event_time<=now()+interval '1 minute'
      THEN jsonb_build_object(
        'latitude',v_latest_gps.latitude,'longitude',v_latest_gps.longitude,
        'recorded_at',v_latest_gps.event_time,'accuracy_m',v_latest_gps.metadata->'accuracy_m',
        'freshness',CASE WHEN v_latest_gps.event_time>=now()-interval '2 minutes' THEN 'live' ELSE 'recent' END
      ) ELSE NULL END,
    'events',coalesce((
      SELECT jsonb_agg(jsonb_build_object('id',e.id,'event_type',e.event_type,'event_time',e.event_time,'source_type',e.source_type) ORDER BY e.event_time DESC)
      FROM (SELECT * FROM public.krim_tracking_events WHERE shipment_id=v_shipment.id
        AND source_type IS DISTINCT FROM 'gps' AND event_type<>'gps_position'
        ORDER BY event_time DESC LIMIT 100) e
    ),'[]'::jsonb),
    'milestones',coalesce((
      SELECT jsonb_agg(jsonb_build_object('id',m.id,'milestone_type',m.milestone_type,'status',m.status,
        'planned_at',m.planned_at,'actual_at',m.actual_at,'notes',m.notes)
        ORDER BY coalesce(m.actual_at,m.planned_at,m.created_at) DESC)
      FROM (SELECT * FROM public.krim_shipment_milestones WHERE shipment_id=v_shipment.id
        ORDER BY coalesce(actual_at,planned_at,created_at) DESC LIMIT 100) m
    ),'[]'::jsonb),
    'can_record',EXISTS(
      SELECT 1 FROM public.krim_shipment_partner_assignments a
      JOIN public.krim_organization_members m ON m.organization_id=a.partner_organization_id
        AND m.user_id=v_uid AND m.status='active'
      WHERE a.shipment_id=v_shipment.id AND a.status IN ('accepted','active','in_progress','assigned')
    )
  ) INTO v_result;
  RETURN v_result;
END;
$function$;

REVOKE ALL ON FUNCTION public.krim_get_shipment_tracking(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.krim_get_shipment_tracking(text) TO authenticated, service_role;
