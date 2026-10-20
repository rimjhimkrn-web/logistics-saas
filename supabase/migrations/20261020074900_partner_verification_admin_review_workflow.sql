CREATE OR REPLACE FUNCTION public.krim_admin_list_partner_verification_cases()
 RETURNS TABLE(case_id bigint, case_number text, verification_level text, case_status text, decision text, decision_reason text, submitted_at timestamp with time zone, updated_at timestamp with time zone, organization_id bigint, legal_name text, organization_type text, organization_status text, case_metadata jsonb, organization_metadata jsonb)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION USING errcode='28000', message='Authentication required';
  END IF;
  IF NOT private.krim_has_permission(auth.uid(), 1::bigint, 'admin.platform') THEN
    RAISE EXCEPTION USING errcode='42501', message='Platform administrator permission required';
  END IF;

  RETURN QUERY
  SELECT c.id, c.case_number, c.verification_level, c.status, c.decision,
         c.decision_reason, c.submitted_at, c.updated_at,
         o.id, o.legal_name, o.organization_type, o.status,
         c.metadata, o.partner_metadata
  FROM public.krim_partner_verification_cases c
  JOIN public.krim_organizations o ON o.id=c.organization_id
  ORDER BY CASE WHEN c.status IN ('open','in_review','pending_information') THEN 0 ELSE 1 END,
           c.submitted_at DESC NULLS LAST
  LIMIT 50;
END;
$function$;

CREATE OR REPLACE FUNCTION public.krim_admin_review_partner_verification(p_case_id bigint, p_decision text, p_reason text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_org_id bigint;
  v_case_status text;
  v_decision text := lower(nullif(btrim(p_decision),''));
  v_reason text := nullif(btrim(coalesce(p_reason,'')),'');
  v_old_state jsonb;
  v_new_state jsonb;
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
         jsonb_build_object('case_status',c.status,'decision',c.decision,'verification_status',o.partner_verification_status,'lifecycle_status',o.partner_lifecycle_status)
    INTO v_org_id,v_case_status,v_old_state
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

  v_new_state := jsonb_build_object('case_status',CASE WHEN v_decision='approved' THEN 'approved' ELSE 'rejected' END,'decision',v_decision,'organization_id',v_org_id);
  INSERT INTO public.krim_audit_events
    (actor_user_id,organization_id,event_type,entity_type,entity_id,source,metadata,previous_state,new_state)
  VALUES
    (v_user_id,v_org_id,'partner.onboarding.reviewed','partner_verification_case',p_case_id::text,'partner_onboarding',
     jsonb_build_object('decision',v_decision,'reason',v_reason),v_old_state,v_new_state);

  RETURN jsonb_build_object('case_id',p_case_id,'organization_id',v_org_id,'decision',v_decision,'status',v_new_state->>'case_status');
END;
$function$;
REVOKE ALL ON FUNCTION public.krim_admin_list_partner_verification_cases() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.krim_admin_list_partner_verification_cases() TO authenticated;
REVOKE ALL ON FUNCTION public.krim_admin_review_partner_verification(bigint,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.krim_admin_review_partner_verification(bigint,text,text) TO authenticated;
DROP POLICY IF EXISTS krim_partner_verification_admin_read ON storage.objects;
CREATE POLICY krim_partner_verification_admin_read
ON storage.objects FOR SELECT TO authenticated
USING (bucket_id='krim-partner-verification' AND private.krim_has_permission((SELECT auth.uid()), 1::bigint, 'admin.platform'));
