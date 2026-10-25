-- Require verifiable onboarding evidence before an administrator can approve a logistics partner.
-- Rejections remain possible without documents so incomplete/invalid applications can be closed safely.

CREATE OR REPLACE FUNCTION public.krim_admin_review_partner_verification(
  p_case_id bigint,
  p_decision text,
  p_reason text DEFAULT NULL::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_org_id bigint;
  v_case_status text;
  v_org_type text;
  v_org_status text;
  v_partner_metadata jsonb;
  v_decision text := lower(nullif(btrim(p_decision),''));
  v_reason text := nullif(btrim(coalesce(p_reason,'')),'');
  v_old_state jsonb;
  v_new_state jsonb;
  v_document_paths text[];
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION USING errcode='28000', message='Authentication required';
  END IF;
  IF NOT private.krim_has_permission(v_user_id, 1::bigint, 'admin.platform') THEN
    RAISE EXCEPTION USING errcode='42501', message='Platform administrator permission required';
  END IF;
  IF p_case_id IS NULL OR v_decision IS NULL OR v_decision NOT IN ('approved','rejected') THEN
    RAISE EXCEPTION USING errcode='22023', message='Choose an existing case and an approved or rejected decision';
  END IF;
  IF v_decision='rejected' AND (v_reason IS NULL OR char_length(v_reason)<5) THEN
    RAISE EXCEPTION USING errcode='22023', message='A rejection reason of at least 5 characters is required';
  END IF;
  IF char_length(coalesce(v_reason,''))>1000 THEN
    RAISE EXCEPTION USING errcode='22023', message='Review notes must be 1000 characters or fewer';
  END IF;

  SELECT c.organization_id,c.status,
         jsonb_build_object(
           'case_status',c.status,
           'decision',c.decision,
           'verification_status',o.partner_verification_status,
           'lifecycle_status',o.partner_lifecycle_status
         ),
         o.organization_type,o.status,o.partner_metadata
    INTO v_org_id,v_case_status,v_old_state,v_org_type,v_org_status,v_partner_metadata
  FROM public.krim_partner_verification_cases c
  JOIN public.krim_organizations o ON o.id=c.organization_id
  WHERE c.id=p_case_id
  FOR UPDATE OF c;

  IF v_org_id IS NULL THEN
    RAISE EXCEPTION USING errcode='P0002', message='Verification case not found';
  END IF;
  IF v_case_status NOT IN ('open','in_review','pending_information') THEN
    RAISE EXCEPTION USING errcode='55000', message='This verification case has already been decided or closed';
  END IF;

  IF v_decision='approved' THEN
    IF v_org_type NOT IN ('partner','carrier','warehouse','forwarder') OR v_org_status <> 'active' THEN
      RAISE EXCEPTION USING errcode='23514', message='Only an active logistics organization can be approved';
    END IF;
    IF nullif(btrim(v_partner_metadata->>'authority_id'),'') IS NULL
       OR nullif(btrim(v_partner_metadata->>'country_code'),'') IS NULL
       OR nullif(btrim(v_partner_metadata->>'operating_country_code'),'') IS NULL
       OR nullif(btrim(v_partner_metadata->>'operational_category'),'') IS NULL
       OR nullif(btrim(v_partner_metadata->>'registered_address'),'') IS NULL
       OR nullif(btrim(v_partner_metadata->>'registered_city'),'') IS NULL THEN
      RAISE EXCEPTION USING errcode='23514', message='Cannot approve: required business registration and location details are incomplete';
    END IF;

    IF jsonb_typeof(v_partner_metadata->'document_paths') IS DISTINCT FROM 'array'
       OR jsonb_array_length(v_partner_metadata->'document_paths') < 1 THEN
      RAISE EXCEPTION USING errcode='23514', message='Cannot approve: a business registration document has not been submitted';
    END IF;

    SELECT array_agg(value)
      INTO v_document_paths
    FROM jsonb_array_elements_text(v_partner_metadata->'document_paths') AS docs(value);

    IF v_document_paths IS NULL OR cardinality(v_document_paths) < 1
       OR EXISTS (
         SELECT 1
         FROM unnest(v_document_paths) AS submitted(path)
         WHERE submitted.path !~ ('^' || v_org_id::text || '/[0-9a-fA-F-]{36}/[^/]+\.(pdf|png|jpe?g)$')
            OR NOT EXISTS (
              SELECT 1 FROM storage.objects so
              WHERE so.bucket_id='krim-partner-verification'
                AND so.name=submitted.path
            )
       ) THEN
      RAISE EXCEPTION USING errcode='23514', message='Cannot approve: submitted verification documents are missing or invalid in private storage';
    END IF;
  END IF;

  UPDATE public.krim_partner_verification_cases
  SET status=CASE WHEN v_decision='approved' THEN 'approved' ELSE 'rejected' END,
      decision=v_decision,
      decision_reason=v_reason,
      assigned_to=coalesce(assigned_to,v_user_id),
      started_at=coalesce(started_at,now()),
      completed_at=now(),
      updated_at=now()
  WHERE id=p_case_id;

  IF v_decision='approved' THEN
    UPDATE public.krim_organizations
    SET partner_lifecycle_status='active',
        partner_verification_status='verified',
        partner_compliance_status='compliant',
        partner_onboarding_status='completed',
        partner_onboarding_completed_at=now(),
        partner_verified_at=now(),
        partner_approved_at=now(),
        partner_activated_at=now(),
        partner_reviewed_at=now(),
        partner_reviewed_by=v_user_id,
        partner_review_notes=v_reason,
        updated_at=now()
    WHERE id=v_org_id;
  ELSE
    UPDATE public.krim_organizations
    SET partner_lifecycle_status='restricted',
        partner_verification_status='rejected',
        partner_compliance_status='non_compliant',
        partner_onboarding_status='blocked',
        partner_restricted_at=now(),
        partner_reviewed_at=now(),
        partner_reviewed_by=v_user_id,
        partner_review_notes=v_reason,
        updated_at=now()
    WHERE id=v_org_id;
  END IF;

  v_new_state := jsonb_build_object(
    'case_status',CASE WHEN v_decision='approved' THEN 'approved' ELSE 'rejected' END,
    'decision',v_decision,
    'organization_id',v_org_id
  );
  INSERT INTO public.krim_audit_events
    (actor_user_id,organization_id,event_type,entity_type,entity_id,source,metadata,previous_state,new_state)
  VALUES
    (v_user_id,v_org_id,'partner.onboarding.reviewed','partner_verification_case',p_case_id::text,'partner_onboarding',
     jsonb_build_object('decision',v_decision,'reason',v_reason),v_old_state,v_new_state);

  RETURN jsonb_build_object('case_id',p_case_id,'organization_id',v_org_id,'decision',v_decision,'status',v_new_state->>'case_status');
END;
$function$;

REVOKE ALL ON FUNCTION public.krim_admin_review_partner_verification(bigint,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.krim_admin_review_partner_verification(bigint,text,text) TO authenticated;
