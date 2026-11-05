DO $$
DECLARE
 v_def text;
 v_old text;
 v_new text;
BEGIN
 SELECT pg_get_functiondef('public.krim_admin_review_partner_capability(bigint,text,text)'::regprocedure) INTO v_def;

 v_old := 'v_cap_status text;v_old_state jsonb;v_new_state jsonb;';
 v_new := 'v_cap_status text;v_country_id bigint;v_mode_id bigint;v_evidence jsonb;v_submitter uuid;v_old_state jsonb;v_new_state jsonb;';
 IF position(v_old in v_def)=0 THEN RAISE EXCEPTION 'Capability review declaration anchor missing'; END IF;
 v_def := replace(v_def,v_old,v_new);

 v_old := 'if v_decision=''rejected'' and (v_reason is null or char_length(v_reason)<5) then raise exception using errcode=''22023'',message=''A rejection reason of at least 5 characters is required'';end if;';
 v_new := 'if v_decision=''rejected'' and (v_reason is null or char_length(v_reason)<5) then raise exception using errcode=''22023'',message=''A rejection reason of at least 5 characters is required'';end if;
 if v_decision=''approved'' and (v_reason is null or char_length(v_reason)<10) then raise exception using errcode=''22023'',message=''An approval evidence-review note of at least 10 characters is required'';end if;';
 IF position(v_old in v_def)=0 THEN RAISE EXCEPTION 'Capability review reason anchor missing'; END IF;
 v_def := replace(v_def,v_old,v_new);

 v_old := 'select c.organization_id,c.verification_status,o.partner_account_mode,o.status,o.partner_lifecycle_status,o.partner_verification_status,o.partner_compliance_status,
  jsonb_build_object(''capability_id'',c.id,''active'',c.active,''verification_status'',c.verification_status,''metadata'',c.metadata)
 into v_org_id,v_cap_status,v_org_mode,v_org_status,v_org_lifecycle,v_org_verification,v_org_compliance,v_old_state';
 v_new := 'select c.organization_id,c.verification_status,o.partner_account_mode,o.status,o.partner_lifecycle_status,o.partner_verification_status,o.partner_compliance_status,
  c.coverage_country_id,c.transport_mode_id,c.metadata->''evidence_paths'',nullif(c.metadata->>''submitted_by'','''')::uuid,
  jsonb_build_object(''capability_id'',c.id,''active'',c.active,''verification_status'',c.verification_status,''metadata'',c.metadata)
 into v_org_id,v_cap_status,v_org_mode,v_org_status,v_org_lifecycle,v_org_verification,v_org_compliance,v_country_id,v_mode_id,v_evidence,v_submitter,v_old_state';
 IF position(v_old in v_def)=0 THEN RAISE EXCEPTION 'Capability review select anchor missing'; END IF;
 v_def := replace(v_def,v_old,v_new);

 v_old := ' ) then raise exception using errcode=''23514'',message=''The partner organisation must be an approved, verified and compliant registered business before a capability can be activated'';end if;';
 v_new := ' ) then raise exception using errcode=''23514'',message=''The partner organisation must be an approved, verified and compliant registered business before a capability can be activated'';end if;
 if v_decision=''approved'' and (v_country_id is null or not exists(select 1 from public.krim_countries where id=v_country_id and is_active=true)) then
  raise exception using errcode=''23514'',message=''Capability approval requires a recognized active country coverage record'';end if;
 if v_decision=''approved'' and not exists(select 1 from public.krim_transport_modes where id=v_mode_id and is_active=true) then
  raise exception using errcode=''23514'',message=''Capability approval requires an active KRIM transport mode'';end if;
 if v_decision=''approved'' and (coalesce(jsonb_typeof(v_evidence),''null'')<>''array'' or jsonb_array_length(coalesce(v_evidence,''[]''::jsonb)) not between 1 and 5 or v_submitter is null) then
  raise exception using errcode=''23514'',message=''Capability approval requires one to five submitted private evidence files'';end if;
 if v_decision=''approved'' and exists(
  select 1 from jsonb_array_elements_text(coalesce(v_evidence,''[]''::jsonb)) e(path)
  where e.path !~ (''^''||v_org_id::text||''/''||v_submitter::text||''/capability/[A-Za-z0-9._-]{1,120}$'')
     or not exists(select 1 from storage.objects so where so.bucket_id=''krim-partner-verification'' and so.name=e.path)
 ) then raise exception using errcode=''23514'',message=''One or more required private capability evidence files are missing or outside the submitter folder'';end if;';
 IF position(v_old in v_def)=0 THEN RAISE EXCEPTION 'Capability review approval guard anchor missing'; END IF;
 v_def := replace(v_def,v_old,v_new);

 EXECUTE v_def;
END $$;