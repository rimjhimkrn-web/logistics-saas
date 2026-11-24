-- Secure partner exception reporting with mandatory in-app service notifications.
-- No direct table INSERT grants or RLS policies are added.
CREATE UNIQUE INDEX IF NOT EXISTS uq_krim_exceptions_exception_code
  ON public.krim_exceptions (exception_code);

CREATE OR REPLACE FUNCTION public.krim_report_operational_exception(
  p_shipment_id bigint,
  p_exception_type text,
  p_severity text,
  p_description text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_type text := lower(pg_catalog.btrim(coalesce(p_exception_type, '')));
  v_severity text := lower(pg_catalog.btrim(coalesce(p_severity, 'medium')));
  v_description text := pg_catalog.btrim(coalesce(p_description, ''));
  v_shipment public.krim_shipments%ROWTYPE;
  v_assignment public.krim_shipment_partner_assignments%ROWTYPE;
  v_member_role text;
  v_candidate_count integer := 0;
  v_exception_id bigint;
  v_exception_code text;
  v_notification_count integer := 0;
  v_now timestamptz := pg_catalog.now();
  v_evidence_required boolean;
  v_notification_message text;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION USING errcode = '28000', message = 'Authentication required'; END IF;
  IF p_shipment_id IS NULL THEN RAISE EXCEPTION USING errcode = '22023', message = 'Shipment is required'; END IF;
  IF v_type NOT IN ('vehicle_breakdown','traffic_route_disruption','weather_impact','pickup_delivery_delay','cargo_damage_discrepancy','documentation_clearance_hold','safety_security_concern','other_operational_exception') THEN
    RAISE EXCEPTION USING errcode = '22023', message = 'Unsupported operational exception category';
  END IF;
  IF v_severity NOT IN ('low','medium','high','critical') THEN RAISE EXCEPTION USING errcode = '22023', message = 'Severity must be low, medium, high or critical'; END IF;
  IF pg_catalog.length(v_description) < 20 OR pg_catalog.length(v_description) > 1000 THEN
    RAISE EXCEPTION USING errcode = '22023', message = 'Description must contain 20 to 1,000 characters';
  END IF;
  SELECT * INTO v_shipment FROM public.krim_shipments WHERE id=p_shipment_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION USING errcode = 'P0002', message = 'Shipment not found'; END IF;
  SELECT pg_catalog.count(DISTINCT a.id)::integer INTO v_candidate_count
  FROM public.krim_shipment_partner_assignments a
  JOIN public.krim_organization_members m ON m.organization_id=a.partner_organization_id AND m.user_id=v_uid AND pg_catalog.lower(m.status)='active'
  WHERE a.shipment_id=p_shipment_id AND a.status IN ('accepted','active','in_progress','assigned')
    AND ((pg_catalog.lower(m.role)='driver' AND EXISTS(SELECT 1 FROM public.krim_driver_assignments da WHERE da.partner_assignment_id=a.id AND da.shipment_id=p_shipment_id AND da.user_id=v_uid AND da.status NOT IN ('delivered','cancelled')))
      OR (pg_catalog.lower(m.role)<>'driver' AND (private.krim_has_permission(v_uid,a.partner_organization_id,'shipment.update') OR private.krim_has_permission(v_uid,a.partner_organization_id,'shipment.dispatch'))));
  IF v_candidate_count=0 THEN RAISE EXCEPTION USING errcode = '42501', message = 'No active partner assignment is available to this user'; END IF;
  IF v_candidate_count>1 THEN RAISE EXCEPTION USING errcode = '22023', message = 'Multiple active assignments are available. No ambiguous exception was recorded'; END IF;
  SELECT a.* INTO v_assignment
  FROM public.krim_shipment_partner_assignments a
  JOIN public.krim_organization_members m ON m.organization_id=a.partner_organization_id AND m.user_id=v_uid AND pg_catalog.lower(m.status)='active'
  WHERE a.shipment_id=p_shipment_id AND a.status IN ('accepted','active','in_progress','assigned')
    AND ((pg_catalog.lower(m.role)='driver' AND EXISTS(SELECT 1 FROM public.krim_driver_assignments da WHERE da.partner_assignment_id=a.id AND da.shipment_id=p_shipment_id AND da.user_id=v_uid AND da.status NOT IN ('delivered','cancelled')))
      OR (pg_catalog.lower(m.role)<>'driver' AND (private.krim_has_permission(v_uid,a.partner_organization_id,'shipment.update') OR private.krim_has_permission(v_uid,a.partner_organization_id,'shipment.dispatch'))))
  ORDER BY a.accepted_at DESC NULLS LAST,a.created_at DESC LIMIT 1 FOR UPDATE OF a;
  SELECT m.role INTO v_member_role FROM public.krim_organization_members m WHERE m.organization_id=v_assignment.partner_organization_id AND m.user_id=v_uid AND pg_catalog.lower(m.status)='active' ORDER BY CASE WHEN pg_catalog.lower(m.role)='driver' THEN 0 ELSE 1 END LIMIT 1;
  v_exception_code:='EXC-'||pg_catalog.to_char(v_now,'YYYYMMDD')||'-'||pg_catalog.upper(pg_catalog.substr(pg_catalog.replace(pg_catalog.gen_random_uuid()::text,'-',''),1,10));
  v_evidence_required:=v_severity IN ('high','critical') OR v_type IN ('cargo_damage_discrepancy','safety_security_concern');
  INSERT INTO public.krim_exceptions(organization_id,shipment_id,exception_code,exception_type,severity,status,detected_at,detected_by,description,metadata,shipment_leg_id,assignment_id,responsible_partner_organization_id,evidence_required)
  VALUES(v_assignment.partner_organization_id,p_shipment_id,v_exception_code,v_type,v_severity,'open',v_now,v_uid,v_description,
    pg_catalog.jsonb_build_object('reported_via','carrier_exception_reporting','member_role',v_member_role,'shipment_number',v_shipment.shipment_number,'evidence_required',v_evidence_required,'notification_channel','in_app'),
    v_assignment.shipment_leg_id,v_assignment.id,v_assignment.partner_organization_id,v_evidence_required)
  RETURNING id INTO v_exception_id;
  INSERT INTO public.krim_audit_events(actor_user_id,organization_id,event_type,entity_type,entity_id,source,metadata,previous_state,new_state,created_at)
  VALUES(v_uid,v_assignment.partner_organization_id,'operational_exception_reported','exception',v_exception_id::text,'carrier_exception_reporting',
    pg_catalog.jsonb_build_object('exception_code',v_exception_code,'shipment_id',p_shipment_id,'assignment_id',v_assignment.id,'exception_type',v_type,'severity',v_severity,'evidence_required',v_evidence_required),
    NULL,pg_catalog.jsonb_build_object('status','open','detected_at',v_now),v_now);
  v_notification_message:='A service exception was recorded for shipment '||coalesce(v_shipment.shipment_number,p_shipment_id::text)||'. Review the authorised KRIM workspace for the latest service update.';
  WITH recipients AS (
    SELECT m.user_id FROM public.krim_organization_members m WHERE m.organization_id=v_assignment.partner_organization_id AND pg_catalog.lower(m.status)='active'
      AND (m.user_id=v_uid OR private.krim_has_permission(m.user_id,v_assignment.partner_organization_id,'shipment.view') OR private.krim_has_permission(m.user_id,v_assignment.partner_organization_id,'shipment.update') OR private.krim_has_permission(m.user_id,v_assignment.partner_organization_id,'shipment.dispatch') OR private.krim_has_permission(m.user_id,v_assignment.partner_organization_id,'compliance.manage'))
    UNION
    SELECT m.user_id FROM public.krim_organization_members m WHERE v_shipment.customer_organization_id IS NOT NULL AND m.organization_id=v_shipment.customer_organization_id AND pg_catalog.lower(m.status)='active' AND private.krim_has_permission(m.user_id,v_shipment.customer_organization_id,'shipment.view')
    UNION
    SELECT m.user_id FROM public.krim_organization_members m JOIN public.krim_organizations o ON o.id=m.organization_id WHERE pg_catalog.lower(m.status)='active' AND pg_catalog.lower(o.status)='active' AND pg_catalog.lower(coalesce(o.organization_type_code,o.organization_type,''))='operations'
      AND (private.krim_has_permission(m.user_id,m.organization_id,'shipment.view') OR private.krim_has_permission(m.user_id,m.organization_id,'compliance.view'))
  )
  INSERT INTO public.notifications(user_id,krim_shipment_id,title,message,notification_type,is_read)
  SELECT DISTINCT r.user_id,p_shipment_id,'Shipment service update',v_notification_message,'alert',false FROM recipients r
  WHERE r.user_id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.notifications n WHERE n.user_id=r.user_id AND n.krim_shipment_id=p_shipment_id AND n.title='Shipment service update' AND n.message=v_notification_message);
  GET DIAGNOSTICS v_notification_count=ROW_COUNT;
  RETURN pg_catalog.jsonb_build_object('ok',true,'exception_id',v_exception_id,'exception_code',v_exception_code,'status','open','severity',v_severity,'evidence_required',v_evidence_required,'notifications_created',v_notification_count,'recorded_at',v_now);
END;
$function$;
REVOKE ALL ON FUNCTION public.krim_report_operational_exception(bigint,text,text,text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.krim_report_operational_exception(bigint,text,text,text) FROM anon;
GRANT EXECUTE ON FUNCTION public.krim_report_operational_exception(bigint,text,text,text) TO authenticated;
