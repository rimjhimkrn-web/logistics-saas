do $migration$
declare
 v_def text;
begin
 select pg_get_functiondef(p.oid) into v_def
 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 where n.nspname='public' and p.proname='krim_partner_submit_service_capability'
 and pg_get_function_identity_arguments(p.oid)='p_organization_id bigint, p_transport_mode_id bigint, p_service_type text, p_coverage_country_id bigint, p_coverage_region text, p_max_weight_kg numeric, p_refrigerated boolean, p_hazardous_goods_capable boolean, p_evidence_paths text[]';
 if v_def is null or position('AND so.name=p' in v_def)=0 then raise exception 'Capability submission source did not match expected evidence check'; end if;
 v_def:=replace(v_def,'AND so.name=p','AND so.name=p AND so.owner_id=v_uid::text');
 execute v_def;

 select pg_get_functiondef(p.oid) into v_def
 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 where n.nspname='public' and p.proname='krim_partner_register_capacity_resource'
 and pg_get_function_identity_arguments(p.oid)='p_organization_id bigint, p_resource_type text, p_resource_name text, p_transport_mode_id bigint, p_location_id bigint, p_capacity_value numeric, p_capacity_unit text, p_availability_type text, p_available_from timestamp with time zone, p_available_until timestamp with time zone, p_document_paths text[], p_notes text';
 if v_def is null or position('and so.name=submitted.path' in v_def)=0 then raise exception 'Capacity registration source did not match expected evidence check'; end if;
 v_def:=replace(v_def,'and so.name=submitted.path','and so.name=submitted.path and so.owner_id=v_user_id::text');
 execute v_def;

 select pg_get_functiondef(p.oid) into v_def
 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 where n.nspname='public' and p.proname='krim_admin_review_capacity_resource'
 and pg_get_function_identity_arguments(p.oid)='p_resource_id bigint, p_decision text, p_reason text';
 if v_def is null or position('and so.name=d.path' in v_def)=0 then raise exception 'Capacity review source did not match expected evidence check'; end if;
 v_def:=replace(v_def,'and so.name=d.path','and so.name=d.path and so.owner_id=(v_old_state#>>''{metadata,submitted_by}'')');
 if position('if v_decision=''approved'' then' in v_def)=0 then raise exception 'Capacity review approval block did not match expected source'; end if;
 v_def:=replace(v_def,
  'if v_decision=''approved'' then',
  'if v_decision=''approved'' then
  if nullif(v_old_state#>>''{metadata,submitted_by}'','''') is null or (v_old_state#>>''{metadata,submitted_by}'')::uuid=v_user_id then
   raise exception using errcode=''42501'',message=''Capacity submitter cannot approve their own resource evidence'';
  end if;');
 execute v_def;
end;
$migration$;