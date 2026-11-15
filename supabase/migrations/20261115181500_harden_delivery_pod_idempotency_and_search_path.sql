-- Hardens delivery POD retries and removes mutable search_path from internal POD RPCs.
-- Internal functions remain callable only by postgres/service_role; authenticated drivers
-- enter through krim_driver_submit_delivery_pod.

CREATE OR REPLACE FUNCTION public.krim_internal_submit_delivery_pod(
  p_assignment_id bigint,
  p_received_by_name text DEFAULT NULL,
  p_received_by_role text DEFAULT NULL,
  p_signature_reference text DEFAULT NULL,
  p_evidence_metadata jsonb DEFAULT '{}'::jsonb
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_assignment public.krim_shipment_partner_assignments%ROWTYPE;
  v_shipment public.krim_shipments%ROWTYPE;
  v_leg public.krim_shipment_legs%ROWTYPE;
  v_pod public.krim_pod_records%ROWTYPE;
BEGIN
  IF p_assignment_id IS NULL OR NULLIF(pg_catalog.btrim(p_received_by_name),'') IS NULL THEN
    RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='Assignment and recipient name are required';
  END IF;
  IF pg_catalog.length(pg_catalog.btrim(p_received_by_name))>200
     OR pg_catalog.length(coalesce(p_received_by_role,''))>120
     OR pg_catalog.length(coalesce(p_signature_reference,''))>240 THEN
    RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='POD recipient fields exceed permitted lengths';
  END IF;
  IF p_evidence_metadata IS NULL OR pg_catalog.jsonb_typeof(p_evidence_metadata)<>'object' THEN
    RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='POD evidence metadata must be a JSON object';
  END IF;

  SELECT * INTO v_assignment FROM public.krim_shipment_partner_assignments
  WHERE id=p_assignment_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Assignment % not found',p_assignment_id; END IF;

  SELECT * INTO v_shipment FROM public.krim_shipments
  WHERE id=v_assignment.shipment_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Shipment % not found',v_assignment.shipment_id; END IF;

  IF v_assignment.shipment_leg_id IS NULL THEN
    RAISE EXCEPTION 'Partner assignment % has no shipment leg',v_assignment.id;
  END IF;
  SELECT * INTO v_leg FROM public.krim_shipment_legs
  WHERE id=v_assignment.shipment_leg_id
    AND shipment_id=v_shipment.id
    AND partner_organization_id=v_assignment.partner_organization_id
  FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Assigned shipment leg does not match shipment and partner'; END IF;

  -- Locking the assignment serializes duplicate submissions for this leg.
  SELECT * INTO v_pod FROM public.krim_pod_records
  WHERE assignment_id=v_assignment.id AND shipment_id=v_shipment.id
    AND shipment_leg_id=v_leg.id AND pod_type='delivery'
    AND status IN ('submitted','under_review','verified')
  ORDER BY id DESC LIMIT 1 FOR UPDATE;

  IF FOUND THEN
    IF v_pod.received_by_name IS DISTINCT FROM pg_catalog.btrim(p_received_by_name)
       OR v_pod.received_by_role IS DISTINCT FROM NULLIF(pg_catalog.btrim(p_received_by_role),'')
       OR v_pod.signature_reference IS DISTINCT FROM NULLIF(pg_catalog.btrim(p_signature_reference),'')
       OR v_pod.evidence_metadata IS DISTINCT FROM p_evidence_metadata THEN
      RAISE EXCEPTION USING ERRCODE='23505',
        MESSAGE='A delivery POD already exists for this assignment and leg with a different payload; conflicting retry rejected';
    END IF;
    RETURN pg_catalog.jsonb_build_object(
      'submitted',true,'idempotent',true,'pod_id',v_pod.id,'shipment_id',v_shipment.id,
      'shipment_leg_id',v_leg.id,'status',v_pod.status,
      'next_step',CASE WHEN v_pod.status='verified' THEN 'delivery_authorization' ELSE 'verification' END
    );
  END IF;

  IF v_shipment.status<>'in_transit' THEN
    RAISE EXCEPTION 'Shipment % must be in_transit for delivery POD; current status %',v_shipment.id,v_shipment.status;
  END IF;
  IF v_assignment.status NOT IN ('active','accepted') THEN
    RAISE EXCEPTION 'Assignment % is not active/accepted',v_assignment.id;
  END IF;
  IF p_evidence_metadata->>'driver_assignment_id' IS NULL
     OR pg_catalog.jsonb_typeof(p_evidence_metadata->'driver_evidence')<>'array'
     OR pg_catalog.jsonb_array_length(p_evidence_metadata->'driver_evidence')<1 THEN
    RAISE EXCEPTION USING ERRCODE='55000', MESSAGE='Assigned-driver delivery evidence is required';
  END IF;

  INSERT INTO public.krim_pod_records
    (assignment_id,shipment_id,shipment_leg_id,partner_organization_id,pod_type,status,
     delivered_at,received_by_name,received_by_role,signature_reference,evidence_metadata,
     submitted_at,created_at,updated_at)
  VALUES
    (v_assignment.id,v_shipment.id,v_leg.id,v_assignment.partner_organization_id,'delivery','submitted',
     pg_catalog.now(),pg_catalog.btrim(p_received_by_name),
     NULLIF(pg_catalog.btrim(p_received_by_role),''),NULLIF(pg_catalog.btrim(p_signature_reference),''),
     p_evidence_metadata,pg_catalog.now(),pg_catalog.now(),pg_catalog.now())
  RETURNING * INTO v_pod;

  INSERT INTO public.krim_partner_execution_events
    (shipment_id,shipment_leg_id,event_type,event_time,location_id,source_type,source_reference,
     metadata,partner_organization_id,assignment_id,created_at)
  VALUES
    (v_shipment.id,v_leg.id,'pod_submitted',pg_catalog.now(),v_leg.destination_location_id,'system',
     'krim_pod_submission',pg_catalog.jsonb_build_object('pod_id',v_pod.id),
     v_assignment.partner_organization_id,v_assignment.id,pg_catalog.now());

  INSERT INTO public.krim_tracking_events
    (shipment_id,shipment_leg_id,event_type,event_time,location_id,source_type,source_reference,metadata,created_at)
  VALUES
    (v_shipment.id,v_leg.id,'pod_submitted',pg_catalog.now(),v_leg.destination_location_id,'system',
     'krim_pod_submission',pg_catalog.jsonb_build_object('pod_id',v_pod.id,'pending_verification',true),pg_catalog.now());

  INSERT INTO public.krim_audit_events
    (actor_user_id,organization_id,event_type,entity_type,entity_id,source,metadata,previous_state,new_state,created_at)
  VALUES
    (NULL,v_shipment.customer_organization_id,'shipment.pod_submitted','shipment',v_shipment.id::text,'operations',
     pg_catalog.jsonb_build_object('assignment_id',v_assignment.id,'shipment_leg_id',v_leg.id,'pod_id',v_pod.id),
     pg_catalog.jsonb_build_object('status',v_shipment.status),
     pg_catalog.jsonb_build_object('status','pod_submitted'),pg_catalog.now());

  RETURN pg_catalog.jsonb_build_object(
    'submitted',true,'idempotent',false,'pod_id',v_pod.id,'shipment_id',v_shipment.id,
    'shipment_leg_id',v_leg.id,'status','submitted','next_step','verification'
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.krim_internal_verify_delivery_pod(
  p_pod_id bigint,p_verifier_user_id uuid,p_decision text DEFAULT 'verify',p_reason text DEFAULT NULL
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE v_pod public.krim_pod_records%ROWTYPE;
BEGIN
  IF p_decision NOT IN ('verify','reject') THEN
    RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='Invalid POD decision';
  END IF;
  SELECT * INTO v_pod FROM public.krim_pod_records WHERE id=p_pod_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'POD % not found',p_pod_id; END IF;
  IF v_pod.status NOT IN ('submitted','under_review') THEN
    IF v_pod.status='verified' AND p_decision='verify' THEN
      RETURN pg_catalog.jsonb_build_object('verified',true,'idempotent',true,'pod_id',v_pod.id,
        'shipment_id',v_pod.shipment_id,'next_step','delivery_authorization');
    END IF;
    RAISE EXCEPTION 'POD % is not awaiting verification; current status %',p_pod_id,v_pod.status;
  END IF;
  IF p_verifier_user_id IS NULL THEN
    RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='Verifier identity is required';
  END IF;

  IF p_decision='reject' THEN
    IF pg_catalog.length(pg_catalog.btrim(coalesce(p_reason,'')))<5 THEN
      RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='A meaningful rejection reason is required';
    END IF;
    UPDATE public.krim_pod_records SET status='rejected',verified_at=pg_catalog.now(),
      verified_by=p_verifier_user_id,rejection_reason=pg_catalog.btrim(p_reason),updated_at=pg_catalog.now()
    WHERE id=v_pod.id;
    INSERT INTO public.krim_partner_execution_events
      (shipment_id,shipment_leg_id,event_type,event_time,source_type,source_reference,metadata,
       partner_organization_id,assignment_id,created_at)
    VALUES
      (v_pod.shipment_id,v_pod.shipment_leg_id,'exception_reported',pg_catalog.now(),'system',
       'krim_pod_verification',pg_catalog.jsonb_build_object('pod_id',v_pod.id,'decision','reject'),
       v_pod.partner_organization_id,v_pod.assignment_id,pg_catalog.now());
    RETURN pg_catalog.jsonb_build_object('verified',false,'pod_id',v_pod.id,'status','rejected','next_step','pod_resubmission');
  END IF;

  UPDATE public.krim_pod_records SET status='verified',verified_at=pg_catalog.now(),
    verified_by=p_verifier_user_id,updated_at=pg_catalog.now() WHERE id=v_pod.id;
  INSERT INTO public.krim_partner_execution_events
    (shipment_id,shipment_leg_id,event_type,event_time,source_type,source_reference,metadata,
     partner_organization_id,assignment_id,created_at)
  VALUES
    (v_pod.shipment_id,v_pod.shipment_leg_id,'pod_verified',pg_catalog.now(),'system',
     'krim_pod_verification',pg_catalog.jsonb_build_object('pod_id',v_pod.id,'verifier_user_id',p_verifier_user_id),
     v_pod.partner_organization_id,v_pod.assignment_id,pg_catalog.now());
  INSERT INTO public.krim_audit_events
    (actor_user_id,organization_id,event_type,entity_type,entity_id,source,metadata,previous_state,new_state,created_at)
  SELECT p_verifier_user_id,s.customer_organization_id,'shipment.pod_verified','shipment',s.id::text,'operations',
    pg_catalog.jsonb_build_object('pod_id',v_pod.id,'assignment_id',v_pod.assignment_id),
    pg_catalog.jsonb_build_object('pod_status','submitted'),
    pg_catalog.jsonb_build_object('pod_status','verified'),pg_catalog.now()
  FROM public.krim_shipments s WHERE s.id=v_pod.shipment_id;
  RETURN pg_catalog.jsonb_build_object('verified',true,'idempotent',false,'pod_id',v_pod.id,
    'shipment_id',v_pod.shipment_id,'status','verified','next_step','delivery_authorization');
END;
$function$;
