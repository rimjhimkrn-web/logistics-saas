CREATE OR REPLACE FUNCTION public.krim_submit_partner_onboarding_global_v2(p_legal_name text, p_country_code text, p_authority_id text, p_operational_category text, p_document_paths text[], p_operating_country_code text, p_registered_address text, p_registered_city text, p_operating_region text DEFAULT NULL::text, p_operating_city text DEFAULT NULL::text, p_postal_code text DEFAULT NULL::text, p_website text DEFAULT NULL::text, p_registered_region text DEFAULT NULL::text, p_registered_postal_code text DEFAULT NULL::text)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_org_id bigint;
  v_case_id bigint;
  v_case_number text;
  v_legal_name text := nullif(btrim(p_legal_name), '');
  v_country_code text := upper(nullif(btrim(p_country_code), ''));
  v_operating_country_code text := upper(nullif(btrim(p_operating_country_code), ''));
  v_authority_id text := nullif(btrim(p_authority_id), '');
  v_metadata jsonb;
  v_iso_codes constant text[] := ARRAY['AD','AE','AF','AG','AI','AL','AM','AO','AQ','AR','AS','AT','AU','AW','AX','AZ','BA','BB','BD','BE','BF','BG','BH','BI','BJ','BL','BM','BN','BO','BQ','BR','BS','BT','BV','BW','BY','BZ','CA','CC','CD','CF','CG','CH','CI','CK','CL','CM','CN','CO','CR','CU','CV','CW','CX','CY','CZ','DE','DJ','DK','DM','DO','DZ','EC','EE','EG','EH','ER','ES','ET','FI','FJ','FK','FM','FO','FR','GA','GB','GD','GE','GF','GG','GH','GI','GL','GM','GN','GP','GQ','GR','GS','GT','GU','GW','GY','HK','HM','HN','HR','HT','HU','ID','IE','IL','IM','IN','IO','IQ','IR','IS','IT','JE','JM','JO','JP','KE','KG','KH','KI','KM','KN','KP','KR','KW','KY','KZ','LA','LB','LC','LI','LK','LR','LS','LT','LU','LV','LY','MA','MC','MD','ME','MF','MG','MH','MK','ML','MM','MN','MO','MP','MQ','MR','MS','MT','MU','MV','MW','MX','MY','MZ','NA','NC','NE','NF','NG','NI','NL','NO','NP','NR','NU','NZ','OM','PA','PE','PF','PG','PH','PK','PL','PM','PN','PR','PS','PT','PW','PY','QA','RE','RO','RS','RU','RW','SA','SB','SC','SD','SE','SG','SH','SI','SJ','SK','SL','SM','SN','SO','SR','SS','ST','SV','SX','SY','SZ','TC','TD','TF','TG','TH','TJ','TK','TL','TM','TN','TO','TR','TT','TV','TW','TZ','UA','UG','UM','US','UY','UZ','VA','VC','VE','VG','VI','VN','VU','WF','WS','YE','YT','ZA','ZM','ZW'];
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION USING errcode='28000', message='Authentication required';
  END IF;

  IF v_legal_name IS NULL OR char_length(v_legal_name) < 2 OR char_length(v_legal_name) > 200 THEN
    RAISE EXCEPTION USING errcode='22023', message='Registered business name must be between 2 and 200 characters';
  END IF;
  IF v_country_code IS NULL OR NOT (v_country_code = ANY(v_iso_codes)) THEN
    RAISE EXCEPTION USING errcode='22023', message='Choose a valid country of incorporation';
  END IF;
  IF v_operating_country_code IS NULL OR NOT (v_operating_country_code = ANY(v_iso_codes)) THEN
    RAISE EXCEPTION USING errcode='22023', message='Choose a valid primary operating country';
  END IF;
  IF v_authority_id IS NULL OR char_length(v_authority_id) < 3 OR char_length(v_authority_id) > 100 THEN
    RAISE EXCEPTION USING errcode='22023', message='Business registration or operating authority ID must be between 3 and 100 characters';
  END IF;
  IF p_operational_category IS NULL OR p_operational_category NOT IN ('ROAD_FTL','OCEAN_NVOCC','AIR_CHARTER','INTERMODAL_RAIL') THEN
    RAISE EXCEPTION USING errcode='22023', message='Unsupported operational category';
  END IF;
  IF nullif(btrim(p_registered_address),'') IS NULL OR char_length(btrim(p_registered_address)) > 240 THEN
    RAISE EXCEPTION USING errcode='22023', message='Registered business address is required and must be at most 240 characters';
  END IF;
  IF nullif(btrim(p_registered_city),'') IS NULL OR char_length(btrim(p_registered_city)) > 120 THEN
    RAISE EXCEPTION USING errcode='22023', message='Registered business city is required and must be at most 120 characters';
  END IF;
  IF char_length(coalesce(p_registered_region,'')) > 120
     OR char_length(coalesce(p_registered_postal_code,'')) > 32
     OR char_length(coalesce(p_operating_region,'')) > 120
     OR char_length(coalesce(p_operating_city,'')) > 120
     OR char_length(coalesce(p_postal_code,'')) > 32
     OR char_length(coalesce(p_website,'')) > 255 THEN
    RAISE EXCEPTION USING errcode='22023', message='A location or website field exceeds its allowed length';
  END IF;
  IF nullif(btrim(p_website),'') IS NOT NULL
     AND btrim(p_website) !~* '^https?://[^[:space:]/]+(\.[^[:space:]/]+)+(:[0-9]+)?(/[^[:space:]]*)?$' THEN
    RAISE EXCEPTION USING errcode='22023', message='Website must be a valid http:// or https:// URL';
  END IF;

  IF p_document_paths IS NULL OR cardinality(p_document_paths) < 1 OR cardinality(p_document_paths) > 2 THEN
    RAISE EXCEPTION USING errcode='22023', message='Upload one required business registration document; an insurance certificate may also be attached';
  END IF;
  IF p_document_paths[1] IS NULL OR p_document_paths[1] !~* ('^[0-9]+/' || v_user_id::text || '/[^/]+\.(pdf|png|jpe?g)$') THEN
    RAISE EXCEPTION USING errcode='22023', message='The business registration document path is invalid';
  END IF;
  v_org_id := split_part(p_document_paths[1], '/', 1)::bigint;
  IF cardinality(p_document_paths) = 2 AND (
       p_document_paths[2] IS NULL
       OR p_document_paths[2] !~* ('^' || v_org_id::text || '/' || v_user_id::text || '/[^/]+\.(pdf|png|jpe?g)$')
       OR p_document_paths[2] = p_document_paths[1]
     ) THEN
    RAISE EXCEPTION USING errcode='22023', message='The optional insurance document path is invalid';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM unnest(p_document_paths) AS submitted_path(path)
    WHERE NOT EXISTS (
      SELECT 1 FROM storage.objects so
      WHERE so.bucket_id='krim-partner-verification'
        AND so.name=submitted_path.path
    )
  ) THEN
    RAISE EXCEPTION USING errcode='22023', message='Each submitted document must exist in the private KRIM verification bucket';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.krim_organization_members m
    JOIN public.krim_organizations o ON o.id=m.organization_id
    WHERE m.user_id=v_user_id AND m.organization_id=v_org_id AND m.status='active'
      AND o.organization_type IN ('partner','carrier','warehouse','forwarder')
      AND o.status='active'
  ) THEN
    RAISE EXCEPTION USING errcode='42501', message='An active transport partner organization is required';
  END IF;

  PERFORM pg_advisory_xact_lock(hashtext('krim-partner-onboarding:' || v_user_id::text)::bigint);
  v_metadata := jsonb_build_object(
    'country_code',v_country_code,
    'authority_id',v_authority_id,
    'operational_category',p_operational_category,
    'document_paths',to_jsonb(p_document_paths),
    'registered_address',btrim(p_registered_address),
    'registered_region',nullif(btrim(coalesce(p_registered_region,'')),''),
    'registered_city',btrim(p_registered_city),
    'registered_postal_code',nullif(btrim(coalesce(p_registered_postal_code,'')),''),
    'operating_country_code',v_operating_country_code,
    'operating_region',nullif(btrim(coalesce(p_operating_region,'')),''),
    'operating_city',nullif(btrim(coalesce(p_operating_city,'')),''),
    'postal_code',nullif(btrim(coalesce(p_postal_code,'')),''),
    'website',nullif(btrim(coalesce(p_website,'')),''),
    'submitted_by',v_user_id,
    'submitted_at',now()
  );

  UPDATE public.krim_organizations
  SET legal_name=v_legal_name,
      display_name=v_legal_name,
      partner_metadata=coalesce(partner_metadata,'{}'::jsonb) || v_metadata,
      partner_lifecycle_status='verification_pending',
      partner_verification_status='pending',
      partner_compliance_status='pending',
      partner_onboarding_status='submitted',
      partner_submitted_at=now(),
      updated_at=now()
  WHERE id=v_org_id;

  SELECT id INTO v_case_id
  FROM public.krim_partner_verification_cases
  WHERE organization_id=v_org_id AND status IN ('open','in_review','pending_information')
  ORDER BY created_at DESC LIMIT 1 FOR UPDATE;

  IF v_case_id IS NULL THEN
    v_case_number := 'KPV-' || upper(substr(replace(gen_random_uuid()::text,'-',''),1,12));
    INSERT INTO public.krim_partner_verification_cases
      (organization_id,case_number,verification_level,status,submitted_by,submitted_at,metadata)
    VALUES (v_org_id,v_case_number,'standard','open',v_user_id,now(),v_metadata)
    RETURNING id INTO v_case_id;
  ELSE
    UPDATE public.krim_partner_verification_cases
    SET submitted_by=v_user_id, submitted_at=now(),
        metadata=coalesce(metadata,'{}'::jsonb) || v_metadata, updated_at=now()
    WHERE id=v_case_id;
  END IF;

  INSERT INTO public.krim_audit_events
    (actor_user_id,organization_id,event_type,entity_type,entity_id,source,metadata)
  VALUES
    (v_user_id,v_org_id,'partner.onboarding.submitted',
     'partner_verification_case',v_case_id::text,'partner_onboarding',v_metadata);

  RETURN v_org_id;
END;
$function$;
REVOKE ALL ON FUNCTION public.krim_submit_partner_onboarding_global_v2(text,text,text,text,text[],text,text,text,text,text,text,text,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.krim_submit_partner_onboarding_global_v2(text,text,text,text,text[],text,text,text,text,text,text,text,text,text) TO authenticated;
REVOKE ALL ON FUNCTION public.krim_submit_partner_onboarding_global(text,text,text,text,text[],text,text,text,text,text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.krim_submit_partner_onboarding(text,text,text,text[]) FROM PUBLIC, anon, authenticated;
