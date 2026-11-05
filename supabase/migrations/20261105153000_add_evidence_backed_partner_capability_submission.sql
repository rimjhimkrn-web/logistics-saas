CREATE OR REPLACE FUNCTION public.krim_partner_submit_service_capability(
  p_organization_id bigint,p_transport_mode_id bigint,p_service_type text,p_coverage_country_id bigint,
  p_coverage_region text,p_max_weight_kg numeric,p_refrigerated boolean,p_hazardous_goods_capable boolean,p_evidence_paths text[]
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $function$
DECLARE
 v_uid uuid:=auth.uid();v_org public.krim_organizations%ROWTYPE;v_mode public.krim_transport_modes%ROWTYPE;
 v_paths text[];v_capability_id bigint;
BEGIN
 IF v_uid IS NULL THEN RAISE EXCEPTION USING errcode='28000',message='Authentication required';END IF;
 IF p_organization_id IS NULL OR NOT private.krim_has_permission(v_uid,p_organization_id,'partner.manage') THEN
  RAISE EXCEPTION USING errcode='42501',message='Active partner manager permission required';END IF;
 SELECT * INTO v_org FROM public.krim_organizations WHERE id=p_organization_id FOR SHARE;
 IF NOT FOUND OR lower(coalesce(v_org.organization_type_code,v_org.organization_type,'')) NOT IN
 ('partner','carrier','forwarder','logistics_provider','warehouse','warehouse_operator')
 OR lower(coalesce(v_org.partner_account_mode,''))<>'registered_business' OR lower(coalesce(v_org.status,''))<>'active'
 THEN RAISE EXCEPTION USING errcode='42501',message='Only an active registered-business partner organization may submit service capabilities';END IF;
 IF lower(coalesce(v_org.partner_verification_status,'')) NOT IN ('verified','approved')
 OR lower(coalesce(v_org.partner_lifecycle_status,'')) NOT IN ('active','verified')
 OR lower(coalesce(v_org.partner_compliance_status,'')) NOT IN ('clear','compliant','approved','verified','not_required','not_applicable')
 THEN RAISE EXCEPTION USING errcode='23514',message='Complete organization verification and compliance before submitting service capabilities';END IF;
 SELECT * INTO v_mode FROM public.krim_transport_modes WHERE id=p_transport_mode_id AND is_active=true;
 IF NOT FOUND THEN RAISE EXCEPTION USING errcode='22023',message='Select an active KRIM transport mode';END IF;
 IF p_service_type IS NULL OR p_service_type NOT IN ('transport','warehouse','freight_forwarding','last_mile','first_mile','customs','other')
 THEN RAISE EXCEPTION USING errcode='22023',message='Unsupported service type';END IF;
 IF p_coverage_country_id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.krim_countries WHERE id=p_coverage_country_id)
 THEN RAISE EXCEPTION USING errcode='22023',message='Coverage country is not recognized';END IF;
 IF p_max_weight_kg IS NOT NULL AND (p_max_weight_kg<=0 OR p_max_weight_kg>100000000)
 THEN RAISE EXCEPTION USING errcode='22023',message='Maximum weight must be a positive value in kilograms';END IF;
 IF char_length(coalesce(p_coverage_region,''))>160 THEN RAISE EXCEPTION USING errcode='22023',message='Coverage region must be 160 characters or fewer';END IF;
 SELECT coalesce(array_agg(DISTINCT btrim(x)),'{}'::text[]) INTO v_paths
 FROM unnest(coalesce(p_evidence_paths,'{}'::text[])) x WHERE btrim(x)<>'';
 IF cardinality(v_paths)<1 OR cardinality(v_paths)>5 THEN RAISE EXCEPTION USING errcode='22023',message='Upload between one and five supporting evidence files';END IF;
 IF EXISTS(SELECT 1 FROM unnest(v_paths) p WHERE p !~ ('^'||p_organization_id::text||'/'||v_uid::text||'/capability/[A-Za-z0-9._-]{1,120}$'))
 THEN RAISE EXCEPTION USING errcode='42501',message='Evidence files must be in your own organization capability folder';END IF;
 IF EXISTS(SELECT 1 FROM unnest(v_paths) p WHERE NOT EXISTS(
  SELECT 1 FROM storage.objects so WHERE so.bucket_id='krim-partner-verification' AND so.name=p))
 THEN RAISE EXCEPTION USING errcode='22023',message='One or more evidence files are missing from private partner storage';END IF;
 IF EXISTS(SELECT 1 FROM public.krim_partner_capabilities c WHERE c.organization_id=p_organization_id
  AND c.transport_mode_id=p_transport_mode_id AND c.service_type=p_service_type
  AND c.coverage_country_id IS NOT DISTINCT FROM p_coverage_country_id
  AND coalesce(lower(c.coverage_region),'')=coalesce(lower(nullif(btrim(p_coverage_region),'')),'')
  AND c.verification_status='pending')
 THEN RAISE EXCEPTION USING errcode='23505',message='A matching capability request is already awaiting review';END IF;
 INSERT INTO public.krim_partner_capabilities(organization_id,transport_mode_id,service_type,coverage_country_id,coverage_region,
  max_weight_kg,refrigerated,hazardous_goods_capable,active,verification_status,effective_from,metadata)
 VALUES(p_organization_id,p_transport_mode_id,p_service_type,p_coverage_country_id,nullif(btrim(p_coverage_region),''),
  p_max_weight_kg,coalesce(p_refrigerated,false),coalesce(p_hazardous_goods_capable,false),false,'pending',now(),
  jsonb_build_object('evidence_paths',to_jsonb(v_paths),'submitted_by',v_uid,'submitted_at',now(),'submission_source','partner_workspace'))
 RETURNING id INTO v_capability_id;
 INSERT INTO public.krim_audit_events(actor_user_id,organization_id,event_type,entity_type,entity_id,source,metadata,new_state)
 VALUES(v_uid,p_organization_id,'partner.capability.submitted','partner_capability',v_capability_id::text,'partner_workspace',
  jsonb_build_object('transport_mode_id',p_transport_mode_id,'service_type',p_service_type,'coverage_country_id',p_coverage_country_id),
  jsonb_build_object('capability_id',v_capability_id,'verification_status','pending','active',false,'evidence_count',cardinality(v_paths)));
 RETURN jsonb_build_object('capability_id',v_capability_id,'verification_status','pending','active',false,'evidence_count',cardinality(v_paths));
END;$function$;
REVOKE ALL ON FUNCTION public.krim_partner_submit_service_capability(bigint,bigint,text,bigint,text,numeric,boolean,boolean,text[]) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.krim_partner_submit_service_capability(bigint,bigint,text,bigint,text,numeric,boolean,boolean,text[]) TO authenticated;