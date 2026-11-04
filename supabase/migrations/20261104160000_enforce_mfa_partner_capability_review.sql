-- Require AAL2 for capability queue access and review decisions.
-- Both functions independently enforce MFA and platform permission.
CREATE OR REPLACE FUNCTION public.krim_admin_list_partner_capabilities()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $function$
DECLARE v_user_id uuid := auth.uid(); v_items jsonb;
BEGIN
  IF v_user_id IS NULL THEN RAISE EXCEPTION USING errcode='28000',message='Authentication required'; END IF;
  IF coalesce(auth.jwt()->>'aal','aal1') <> 'aal2' THEN RAISE EXCEPTION USING errcode='42501',message='Multi-factor authentication required'; END IF;
  IF NOT private.krim_has_permission(v_user_id,1::bigint,'admin.platform') THEN RAISE EXCEPTION USING errcode='42501',message='Platform administrator permission required'; END IF;
  SELECT coalesce(jsonb_agg(jsonb_build_object(
    'id',c.id,'organization_id',c.organization_id,'organization_name',coalesce(o.display_name,o.legal_name),
    'organization_status',o.status,'partner_account_mode',o.partner_account_mode,
    'partner_lifecycle_status',o.partner_lifecycle_status,'partner_verification_status',o.partner_verification_status,
    'partner_compliance_status',o.partner_compliance_status,'transport_mode_id',c.transport_mode_id,
    'service_type',c.service_type,'coverage_country_id',c.coverage_country_id,'coverage_region',c.coverage_region,
    'max_weight_kg',c.max_weight_kg,'refrigerated',c.refrigerated,'hazardous_goods_capable',c.hazardous_goods_capable,
    'active',c.active,'verification_status',c.verification_status,'created_at',c.created_at,
    'effective_from',c.effective_from,'effective_until',c.effective_until,'metadata',c.metadata
  ) ORDER BY c.created_at,c.id),'[]'::jsonb) INTO v_items
  FROM public.krim_partner_capabilities c JOIN public.krim_organizations o ON o.id=c.organization_id
  WHERE c.verification_status='pending';
  RETURN jsonb_build_object('items',v_items,'count',jsonb_array_length(v_items));
END;
$function$;
CREATE OR REPLACE FUNCTION public.krim_admin_review_partner_capability(p_capability_id bigint,p_decision text,p_reason text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $function$
DECLARE
  v_user_id uuid:=auth.uid(); v_decision text:=lower(nullif(btrim(p_decision),'')); v_reason text:=nullif(btrim(coalesce(p_reason,'')),'');
  v_org_id bigint; v_org_mode text; v_org_status text; v_org_lifecycle text; v_org_verification text; v_org_compliance text;
  v_cap_status text; v_old_state jsonb; v_new_state jsonb;
BEGIN
  IF v_user_id IS NULL THEN RAISE EXCEPTION USING errcode='28000',message='Authentication required'; END IF;
  IF coalesce(auth.jwt()->>'aal','aal1') <> 'aal2' THEN RAISE EXCEPTION USING errcode='42501',message='Multi-factor authentication required'; END IF;
  IF NOT private.krim_has_permission(v_user_id,1::bigint,'admin.platform') THEN RAISE EXCEPTION USING errcode='42501',message='Platform administrator permission required'; END IF;
  IF p_capability_id IS NULL OR v_decision IS NULL OR v_decision NOT IN ('approved','rejected') THEN RAISE EXCEPTION USING errcode='22023',message='Choose a capability and an approved or rejected decision'; END IF;
  IF v_decision='rejected' AND (v_reason IS NULL OR char_length(v_reason)<5) THEN RAISE EXCEPTION USING errcode='22023',message='A rejection reason of at least 5 characters is required'; END IF;
  IF char_length(coalesce(v_reason,''))>1000 THEN RAISE EXCEPTION USING errcode='22023',message='Review notes must be 1000 characters or fewer'; END IF;
  SELECT c.organization_id,c.verification_status,o.partner_account_mode,o.status,o.partner_lifecycle_status,o.partner_verification_status,o.partner_compliance_status,
    jsonb_build_object('capability_id',c.id,'active',c.active,'verification_status',c.verification_status,'metadata',c.metadata)
  INTO v_org_id,v_cap_status,v_org_mode,v_org_status,v_org_lifecycle,v_org_verification,v_org_compliance,v_old_state
  FROM public.krim_partner_capabilities c JOIN public.krim_organizations o ON o.id=c.organization_id WHERE c.id=p_capability_id FOR UPDATE OF c,o;
  IF v_org_id IS NULL THEN RAISE EXCEPTION USING errcode='P0002',message='Partner capability not found'; END IF;
  IF v_cap_status<>'pending' THEN RAISE EXCEPTION USING errcode='55000',message='Only pending capabilities can be reviewed'; END IF;
  IF v_decision='approved' AND (v_org_mode<>'registered_business' OR v_org_status<>'active' OR v_org_lifecycle<>'active' OR v_org_verification<>'verified' OR v_org_compliance<>'compliant') THEN
    RAISE EXCEPTION USING errcode='23514',message='The partner organisation must be an approved, verified and compliant registered business before a capability can be activated';
  END IF;
  UPDATE public.krim_partner_capabilities SET verification_status=CASE WHEN v_decision='approved' THEN 'verified' ELSE 'rejected' END,
    active=(v_decision='approved'),metadata=coalesce(metadata,'{}'::jsonb)||jsonb_build_object('reviewed_at',now(),'reviewed_by',v_user_id,'review_decision',v_decision,'review_reason',v_reason)
  WHERE id=p_capability_id;
  v_new_state:=jsonb_build_object('capability_id',p_capability_id,'active',(v_decision='approved'),
    'verification_status',CASE WHEN v_decision='approved' THEN 'verified' ELSE 'rejected' END,'decision',v_decision,'reason',v_reason);
  INSERT INTO public.krim_audit_events(actor_user_id,organization_id,event_type,entity_type,entity_id,source,metadata,previous_state,new_state)
  VALUES(v_user_id,v_org_id,'partner.capability.reviewed','partner_capability',p_capability_id::text,'partner_capability_review',
    jsonb_build_object('decision',v_decision,'reason',v_reason),v_old_state,v_new_state);
  RETURN jsonb_build_object('capability_id',p_capability_id,'organization_id',v_org_id,'decision',v_decision,'active',(v_decision='approved'),
    'verification_status',CASE WHEN v_decision='approved' THEN 'verified' ELSE 'rejected' END);
END;
$function$;
REVOKE ALL ON FUNCTION public.krim_admin_list_partner_capabilities() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.krim_admin_list_partner_capabilities() TO authenticated;
REVOKE ALL ON FUNCTION public.krim_admin_review_partner_capability(bigint,text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.krim_admin_review_partner_capability(bigint,text,text) TO authenticated;
