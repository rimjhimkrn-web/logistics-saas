-- Partner capacity correction and resubmission: preserve the rejected resource record and full review history.
create or replace function public.krim_partner_resubmit_rejected_capacity_resource(
 p_resource_id bigint,
 p_resource_type text,
 p_resource_name text,
 p_transport_mode_id bigint,
 p_location_id bigint,
 p_capacity_value numeric,
 p_capacity_unit text,
 p_availability_type text,
 p_available_from timestamptz,
 p_available_until timestamptz,
 p_document_paths text[],
 p_notes text default ''
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
 v_user_id uuid := auth.uid();
 v_resource public.krim_capacity_resources%rowtype;
 v_availability public.krim_partner_capacity_availability%rowtype;
 v_resource_type text := lower(btrim(coalesce(p_resource_type,'')));
 v_availability_type text := lower(btrim(coalesce(p_availability_type,'')));
 v_name text := left(btrim(coalesce(p_resource_name,'')),180);
 v_unit text := left(btrim(coalesce(p_capacity_unit,'')),32);
 v_notes text := left(btrim(coalesce(p_notes,'')),500);
 v_history jsonb;
begin
 if v_user_id is null then raise exception using errcode='28000',message='Authentication required'; end if;
 if p_resource_id is null then raise exception using errcode='22023',message='A rejected resource is required'; end if;
 select * into v_resource from public.krim_capacity_resources where id=p_resource_id for update;
 if not found then raise exception using errcode='P0002',message='Capacity resource not found'; end if;
 if v_resource.status <> 'rejected' or v_resource.metadata->>'verification_state' <> 'rejected'
  or nullif(v_resource.metadata->>'submitted_by','') is distinct from v_user_id::text then
  raise exception using errcode='42501',message='Only the original submitter can correct and resubmit their own rejected resource';
 end if;
 if not exists(select 1 from public.krim_organization_members m where m.user_id=v_user_id and m.organization_id=v_resource.organization_id and lower(m.status)='active')
  or not private.krim_has_permission(v_user_id,v_resource.organization_id,'partner.manage') then
  raise exception using errcode='42501',message='Active organisation membership and partner capacity management permission are required';
 end if;
 if not exists(select 1 from public.krim_organizations o where o.id=v_resource.organization_id
  and o.organization_type in ('partner','carrier','forwarder','logistics_provider','warehouse','warehouse_operator')
  and private.krim_partner_compliance_is_current(o.id)) then
  raise exception using errcode='42501',message='Partner organisation must remain active, verified and compliant';
 end if;
 if v_resource_type not in ('vehicle','equipment','warehouse','handling','container','other')
  or v_availability_type not in ('vehicle','equipment','weight','volume','container','slot','service') then
  raise exception using errcode='22023',message='Unsupported resource or availability type';
 end if;
 if v_name='' or v_unit='' or p_capacity_value is null or p_capacity_value<=0 or p_capacity_value::text in ('NaN','Infinity','-Infinity') then
  raise exception using errcode='22023',message='Resource name, finite positive capacity and unit are required';
 end if;
 if p_available_from is null or p_available_until is null or not isfinite(p_available_from) or not isfinite(p_available_until)
  or p_available_from<now() or p_available_until<=p_available_from then
  raise exception using errcode='22023',message='Provide a finite future availability window';
 end if;
 if not exists(select 1 from public.krim_transport_modes m where m.id=p_transport_mode_id and m.is_active=true)
  or not exists(select 1 from public.krim_locations l where l.id=p_location_id and coalesce(l.is_active,true)=true) then
  raise exception using errcode='22023',message='Select an active KRIM transport mode and location';
 end if;
 if not exists(select 1 from public.krim_partner_capabilities pc join public.krim_locations l on l.id=p_location_id
  where pc.organization_id=v_resource.organization_id and pc.transport_mode_id=p_transport_mode_id and pc.coverage_country_id=l.country_id
  and pc.active is true and pc.verification_status='verified' and (pc.effective_from is null or pc.effective_from<=now())
  and (pc.effective_until is null or pc.effective_until>now())) then
  raise exception using errcode='42501',message='An active verified partner capability is required for this mode and location';
 end if;
 if p_document_paths is null or cardinality(p_document_paths)<1 or cardinality(p_document_paths)>5
  or cardinality(p_document_paths)<>(select count(distinct x) from unnest(p_document_paths) x) then
  raise exception using errcode='22023',message='Upload 1–5 unique replacement evidence documents';
 end if;
 if exists(select 1 from unnest(p_document_paths) submitted(path)
  where submitted.path !~ ('^'||v_resource.organization_id::text||'/'||v_user_id::text||'/capacity-[0-9a-fA-F-]{36}\.(pdf|png|jpe?g)$')
  or not exists(select 1 from storage.objects so where so.bucket_id='krim-partner-verification' and so.name=submitted.path and so.owner_id=v_user_id::text)) then
  raise exception using errcode='23514',message='Replacement evidence is missing, invalid or outside your private organisation folder';
 end if;
 select * into v_availability from public.krim_partner_capacity_availability
  where capacity_resource_id=p_resource_id and organization_id=v_resource.organization_id for update;
 if not found then raise exception using errcode='23514',message='The original resource availability record is missing'; end if;
 if v_availability.lane_id is null or not exists(select 1 from public.krim_network_lanes l
  where l.id=v_availability.lane_id and l.status='active' and l.origin_location_id=p_location_id and l.transport_mode_id=p_transport_mode_id) then
  raise exception using errcode='23514',message='The original operating lane is no longer active or does not match the corrected origin and mode';
 end if;
 v_history:=coalesce(v_resource.metadata->'resubmission_history','[]'::jsonb)||jsonb_build_array(jsonb_build_object(
  'previous_review_decision',v_resource.metadata->>'review_decision','previous_review_reason',v_resource.metadata->>'review_reason',
  'previous_reviewed_at',v_resource.metadata->>'reviewed_at','previous_reviewed_by',v_resource.metadata->>'reviewed_by',
  'resubmitted_at',now(),'resubmitted_by',v_user_id));
 update public.krim_capacity_resources set resource_type=v_resource_type,resource_name=v_name,transport_mode_id=p_transport_mode_id,
  location_id=p_location_id,capacity_value=p_capacity_value,capacity_unit=v_unit,available_from=p_available_from,available_until=p_available_until,
  status='pending_review',metadata=coalesce(metadata,'{}'::jsonb)||jsonb_build_object('source_type','partner_reported','submitted_by',v_user_id,
  'notes',v_notes,'verification_state','pending_review','document_paths',to_jsonb(p_document_paths),'evidence_count',cardinality(p_document_paths),
  'review_decision',null,'review_reason',null,'reviewed_at',null,'reviewed_by',null,'resubmission_history',v_history,'resubmitted_at',now()),
  updated_at=now() where id=p_resource_id;
 update public.krim_partner_capacity_availability set transport_mode_id=p_transport_mode_id,availability_type=v_availability_type,
  available_from=p_available_from,available_until=p_available_until,capacity_value=p_capacity_value,capacity_unit=v_unit,status='unavailable',
  source_type='partner_reported',metadata=coalesce(metadata,'{}'::jsonb)||jsonb_build_object('submitted_by',v_user_id,'notes',v_notes,
  'verification_state','pending_review','review_decision',null,'review_reason',null,'reviewed_at',null,'reviewed_by',null,'resubmitted_at',now()),
  updated_at=now() where id=v_availability.id and capacity_resource_id=p_resource_id;
 insert into public.krim_audit_events(actor_user_id,organization_id,event_type,entity_type,entity_id,source,metadata,previous_state,new_state)
 values(v_user_id,v_resource.organization_id,'partner.capacity_resource.resubmitted','capacity_resource',p_resource_id::text,
  'partner_capacity_resubmission',jsonb_build_object('evidence_count',cardinality(p_document_paths)),
  jsonb_build_object('status','rejected','review_reason',v_resource.metadata->>'review_reason'),
  jsonb_build_object('status','pending_review','verification_state','pending_review','availability_id',v_availability.id));
 return jsonb_build_object('resource_id',p_resource_id,'availability_id',v_availability.id,'organization_id',v_resource.organization_id,
  'resource_status','pending_review','availability_status','unavailable','verification_state','pending_review','evidence_count',cardinality(p_document_paths));
end;
$function$;
revoke all on function public.krim_partner_resubmit_rejected_capacity_resource(bigint,text,text,bigint,bigint,numeric,text,text,timestamptz,timestamptz,text[],text) from public, anon;
grant execute on function public.krim_partner_resubmit_rejected_capacity_resource(bigint,text,text,bigint,bigint,numeric,text,text,timestamptz,timestamptz,text[],text) to authenticated;
