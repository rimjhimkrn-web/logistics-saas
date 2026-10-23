-- Phase 2: make the existing customer service-request RPC safely available to signed-in customers.
-- General inquiries (including location coverage review) must not be recorded as quote requests.
CREATE OR REPLACE FUNCTION public.krim_submit_customer_service_request(
  p_request_type text,
  p_origin_location_id bigint DEFAULT NULL::bigint,
  p_destination_location_id bigint DEFAULT NULL::bigint,
  p_transport_mode_code text DEFAULT NULL::text,
  p_cargo_weight numeric DEFAULT NULL::numeric,
  p_cargo_weight_unit text DEFAULT NULL::text,
  p_requested_service_date date DEFAULT NULL::date,
  p_notes text DEFAULT NULL::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth', 'pg_temp'
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_profile_id bigint;
  v_workspace_status text;
  v_account_status text;
  v_request_id bigint;
  v_reference text;
  v_qualification jsonb;
  v_request_type text := lower(trim(coalesce(p_request_type, '')));
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION USING errcode='28000', message='Authentication required';
  END IF;

  IF v_request_type NOT IN ('quote','shipment','general') THEN
    RAISE EXCEPTION USING errcode='22023', message='Unsupported request type';
  END IF;

  SELECT cil.customer_profile_id INTO v_profile_id
  FROM public.krim_customer_identity_links cil
  WHERE cil.user_id=v_user_id AND cil.identity_status='verified'
  LIMIT 1;

  IF v_profile_id IS NULL THEN
    RAISE EXCEPTION USING errcode='42501', message='Active customer identity not found';
  END IF;

  SELECT cwp.workspace_status,cwp.account_status
  INTO v_workspace_status,v_account_status
  FROM public.krim_customer_workspace_profiles cwp
  WHERE cwp.customer_profile_id=v_profile_id;

  IF v_workspace_status IS DISTINCT FROM 'active'
     OR v_account_status IS DISTINCT FROM 'active' THEN
    RAISE EXCEPTION USING errcode='42501', message='Customer workspace is not active';
  END IF;

  IF p_cargo_weight IS NOT NULL AND p_cargo_weight <= 0 THEN
    RAISE EXCEPTION USING errcode='22023', message='Cargo weight must be greater than zero';
  END IF;

  IF p_requested_service_date IS NOT NULL AND p_requested_service_date < current_date THEN
    RAISE EXCEPTION USING errcode='22023', message='Requested service date cannot be in the past';
  END IF;

  IF length(coalesce(p_notes,'')) > 2000 THEN
    RAISE EXCEPTION USING errcode='22023', message='Notes must be 2000 characters or fewer';
  END IF;

  IF p_origin_location_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.krim_locations l WHERE l.id=p_origin_location_id AND coalesce(l.is_active,true)
  ) THEN
    RAISE EXCEPTION USING errcode='22023', message='Origin location is not active or does not exist';
  END IF;

  IF p_destination_location_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.krim_locations l WHERE l.id=p_destination_location_id AND coalesce(l.is_active,true)
  ) THEN
    RAISE EXCEPTION USING errcode='22023', message='Destination location is not active or does not exist';
  END IF;

  v_reference := 'SR-' || to_char(clock_timestamp(),'YYYYMMDDHH24MISSMS') || '-' ||
    upper(substr(md5(v_user_id::text || clock_timestamp()::text),1,8));

  INSERT INTO public.krim_customer_service_requests(
    customer_profile_id,request_type,request_reference,status,
    origin_location_id,destination_location_id,transport_mode_code,
    cargo_weight,cargo_weight_unit,requested_service_date,notes,metadata,
    created_at,updated_at
  )
  VALUES(
    v_profile_id,v_request_type,v_reference,'qualifying',
    p_origin_location_id,p_destination_location_id,
    nullif(upper(trim(p_transport_mode_code)),''),
    p_cargo_weight,nullif(lower(trim(p_cargo_weight_unit)),''),
    p_requested_service_date,nullif(trim(p_notes),''),
    jsonb_build_object('submitted_by_user_id',v_user_id,'request_channel','customer_workspace'),
    now(),now()
  )
  RETURNING id INTO v_request_id;

  v_qualification := public.krim_internal_qualify_customer_request(v_profile_id,v_request_id);

  -- Record acquisition events only for their matching event type; a general coverage inquiry
  -- must never inflate quote or shipment-request metrics.
  IF v_request_type='quote' THEN
    INSERT INTO public.krim_customer_acquisition_events(
      customer_profile_id,event_type,source_type,source_reference,occurred_at,metadata
    ) VALUES(
      v_profile_id,'quote_requested','direct',v_reference,now(),
      jsonb_build_object('request_id',v_request_id,'request_type',v_request_type)
    );
  ELSIF v_request_type='shipment' THEN
    INSERT INTO public.krim_customer_acquisition_events(
      customer_profile_id,event_type,source_type,source_reference,occurred_at,metadata
    ) VALUES(
      v_profile_id,'shipment_requested','direct',v_reference,now(),
      jsonb_build_object('request_id',v_request_id,'request_type',v_request_type)
    );
  END IF;

  INSERT INTO public.krim_audit_events(
    actor_user_id,organization_id,event_type,entity_type,entity_id,source,metadata,created_at
  )
  SELECT v_user_id,cwp.organization_id,'customer.service_request.submitted',
    'customer_service_request',v_request_id,'customer_workspace',
    jsonb_build_object('request_reference',v_reference,'request_type',v_request_type,'qualification',v_qualification),
    now()
  FROM public.krim_customer_workspace_profiles cwp
  WHERE cwp.customer_profile_id=v_profile_id;

  RETURN jsonb_build_object(
    'status','submitted','request_id',v_request_id,
    'request_reference',v_reference,'qualification',v_qualification
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.krim_submit_customer_service_request(text,bigint,bigint,text,numeric,text,date,text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.krim_submit_customer_service_request(text,bigint,bigint,text,numeric,text,date,text) FROM anon;
GRANT EXECUTE ON FUNCTION public.krim_submit_customer_service_request(text,bigint,bigint,text,numeric,text,date,text) TO authenticated;
