create or replace function public.krim_partner_register_capacity_resource(
 p_organization_id bigint,p_resource_type text,p_resource_name text,p_transport_mode_id bigint,p_location_id bigint,
 p_capacity_value numeric,p_capacity_unit text,p_availability_type text,p_available_from timestamptz,p_available_until timestamptz,
 p_document_paths text[],p_notes text default ''
) returns jsonb language plpgsql security definer set search_path = '' as $function$
declare
 v_user_id uuid:=auth.uid();v_resource_id bigint;v_availability_id bigint;
 v_resource_type text:=lower(btrim(coalesce(p_resource_type,'')));
 v_availability_type text:=lower(btrim(coalesce(p_availability_type,'')));
 v_name text:=left(btrim(coalesce(p_resource_name,'')),180);
 v_unit text:=left(btrim(coalesce(p_capacity_unit,'')),32);
 v_notes text:=left(btrim(coalesce(p_notes,'')),500);
begin
 if v_user_id is null then raise exception using errcode='28000',message='Authentication required';end if;
 if p_organization_id is null
  or not exists(select 1 from public.krim_organization_members m where m.user_id=v_user_id and m.organization_id=p_organization_id and lower(m.status)='active')
  or not private.krim_has_permission(v_user_id,p_organization_id,'partner.manage') then
  raise exception using errcode='42501',message='An active organization membership and partner capacity management permission are required';
 end if;
 if not exists(select 1 from public.krim_organizations o where o.id=p_organization_id and lower(o.status)='active'
  and o.partner_account_mode='registered_business' and o.organization_type in ('partner','carrier','forwarder','logistics_provider','warehouse','warehouse_operator')
  and lower(coalesce(o.partner_verification_status,'')) in ('verified','approved')
  and lower(coalesce(o.partner_lifecycle_status,'')) in ('active','verified')
  and lower(coalesce(o.partner_compliance_status,'')) in ('clear','compliant','approved','verified','not_required','not_applicable')) then
  raise exception using errcode='42501',message='Only an active, verified and compliant registered business partner can register operational capacity';
 end if;
 if v_resource_type not in ('vehicle','equipment','warehouse','handling','container','other') then raise exception using errcode='22023',message='Unsupported resource type';end if;
 if v_availability_type not in ('vehicle','equipment','weight','volume','container','slot','service') then raise exception using errcode='22023',message='Unsupported availability type';end if;
 if v_name='' or v_unit='' or p_capacity_value is null or p_capacity_value<=0 or p_capacity_value::text in ('NaN','Infinity','-Infinity') then
  raise exception using errcode='22023',message='Resource name, finite positive capacity and capacity unit are required';end if;
 if p_available_from is null or p_available_until is null or not isfinite(p_available_from) or not isfinite(p_available_until)
  or p_available_from<now() or p_available_until<=p_available_from then
  raise exception using errcode='22023',message='Provide a finite future availability window with an end after its start';end if;
 if not exists(select 1 from public.krim_transport_modes m where m.id=p_transport_mode_id and m.is_active=true) then
  raise exception using errcode='22023',message='Select an active KRIM transport mode';end if;
 if not exists(select 1 from public.krim_locations l where l.id=p_location_id and coalesce(l.is_active,true)=true) then
  raise exception using errcode='22023',message='Select an active KRIM location';end if;
 if not exists(select 1 from public.krim_partner_capabilities pc join public.krim_locations l on l.id=p_location_id
  where pc.organization_id=p_organization_id and pc.transport_mode_id=p_transport_mode_id and pc.coverage_country_id=l.country_id
   and pc.active is true and pc.verification_status='verified'
   and (pc.effective_from is null or pc.effective_from<=now()) and (pc.effective_until is null or pc.effective_until>now())) then
  raise exception using errcode='42501',message='Capacity can only be registered for a transport mode and country covered by an active, individually verified partner capability';end if;
 if p_document_paths is null or cardinality(p_document_paths)<1 or cardinality(p_document_paths)>5
  or cardinality(p_document_paths)<>(select count(distinct x) from unnest(p_document_paths) x) then
  raise exception using errcode='22023',message='Upload 1–5 unique supporting resource documents';end if;
 if exists(select 1 from unnest(p_document_paths) as submitted(path)
  where submitted.path !~ ('^'||p_organization_id::text||'/'||v_user_id::text||'/capacity-[0-9a-fA-F-]{36}\.(pdf|png|jpe?g)$')
   or not exists(select 1 from storage.objects so where so.bucket_id='krim-partner-verification' and so.name=submitted.path)) then
  raise exception using errcode='23514',message='A supporting document is missing, invalid or outside your private organization folder';end if;
 insert into public.krim_capacity_resources(organization_id,resource_type,resource_name,transport_mode_id,location_id,capacity_value,capacity_unit,available_from,available_until,status,metadata)
 values(p_organization_id,v_resource_type,v_name,p_transport_mode_id,p_location_id,p_capacity_value,v_unit,p_available_from,p_available_until,'pending_review',
  jsonb_build_object('source_type','partner_reported','submitted_by',v_user_id,'notes',v_notes,'verification_state','pending_review','document_paths',to_jsonb(p_document_paths),'evidence_count',cardinality(p_document_paths)))
 returning id into v_resource_id;
 insert into public.krim_partner_capacity_availability(organization_id,capacity_resource_id,transport_mode_id,availability_type,available_from,available_until,capacity_value,capacity_unit,status,source_type,metadata)
 values(p_organization_id,v_resource_id,p_transport_mode_id,v_availability_type,p_available_from,p_available_until,p_capacity_value,v_unit,'unavailable','partner_reported',
  jsonb_build_object('submitted_by',v_user_id,'notes',v_notes,'verification_state','pending_review'))
 returning id into v_availability_id;
 return jsonb_build_object('resource_id',v_resource_id,'availability_id',v_availability_id,'organization_id',p_organization_id,
  'resource_status','pending_review','availability_status','unavailable','source_type','partner_reported','verification_state','pending_review','evidence_count',cardinality(p_document_paths));
end;$function$;