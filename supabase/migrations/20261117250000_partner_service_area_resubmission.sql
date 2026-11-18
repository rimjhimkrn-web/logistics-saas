-- Secure same-record correction and resubmission for rejected partner service-area requests.
create or replace function public.krim_partner_resubmit_service_area(
 p_service_area_id bigint,
 p_organization_id bigint,
 p_coverage_type text,
 p_scope_id bigint,
 p_service_type text,
 p_transport_mode_id bigint,
 p_evidence_paths text[],
 p_notes text,
 p_effective_from timestamptz,
 p_effective_until timestamptz
) returns jsonb
language plpgsql
security definer
set search_path=''
as $function$
declare
 v_uid uuid:=auth.uid();
 v_area public.krim_partner_service_areas%rowtype;
 v_org public.krim_organizations%rowtype;
 v_country_id bigint;
 v_market_id bigint;
 v_location_id bigint;
 v_paths text[];
 v_history jsonb;
begin
 if v_uid is null then raise exception using errcode='28000',message='Authentication required'; end if;
 if p_service_area_id is null or p_organization_id is null then raise exception using errcode='22023',message='A rejected service-area request is required'; end if;
 select * into v_area from public.krim_partner_service_areas where id=p_service_area_id and organization_id=p_organization_id for update;
 if not found then raise exception using errcode='P0002',message='Service-area request not found'; end if;
 if v_area.status<>'closed' or v_area.metadata->>'workflow_status'<>'rejected'
  or nullif(v_area.metadata->>'submitted_by','') is distinct from v_uid::text then
  raise exception using errcode='42501',message='Only the original submitter can correct their own rejected service-area request';
 end if;
 if not private.krim_has_permission(v_uid,p_organization_id,'partner.manage') then
  raise exception using errcode='42501',message='Active partner manager permission is required';
 end if;
 select * into v_org from public.krim_organizations where id=p_organization_id for share;
 if not found or lower(coalesce(v_org.organization_type_code,v_org.organization_type,'')) not in ('partner','carrier','forwarder','logistics_provider','warehouse','warehouse_operator')
  or lower(coalesce(v_org.partner_account_mode,''))<>'registered_business' or lower(coalesce(v_org.status,''))<>'active'
  or not private.krim_partner_compliance_is_current(p_organization_id) then
  raise exception using errcode='42501',message='Only an active, compliant registered-business partner may resubmit service areas';
 end if;
 if p_coverage_type not in ('country','market','location') or p_scope_id is null then
  raise exception using errcode='22023',message='Choose a supported country, market or location scope';
 end if;
 if p_service_type not in ('transport','warehouse','freight_forwarding','last_mile','first_mile','customs','other') then
  raise exception using errcode='22023',message='Unsupported service type';
 end if;
 if p_transport_mode_id is not null and not exists(select 1 from public.krim_transport_modes where id=p_transport_mode_id and is_active=true) then
  raise exception using errcode='22023',message='Select an active KRIM transport mode';
 end if;
 if p_effective_from is null or p_effective_from<now()-interval '5 minutes' or (p_effective_until is not null and p_effective_until<p_effective_from) then
  raise exception using errcode='22023',message='Invalid or backdated service-area effective dates';
 end if;
 if char_length(coalesce(p_notes,''))<1 or char_length(p_notes)>2000 then raise exception using errcode='22023',message='Operational notes are required and must be 2,000 characters or fewer'; end if;
 if p_coverage_type='country' then
  select id into v_country_id from public.krim_countries where id=p_scope_id and is_active=true;
 elsif p_coverage_type='market' then
  select m.country_id,m.id into v_country_id,v_market_id from public.krim_markets m join public.krim_countries c on c.id=m.country_id and c.is_active=true
  where m.id=p_scope_id and m.is_active=true and lower(coalesce(m.status,'active'))='active';
 else
  select l.country_id,l.market_id,l.id into v_country_id,v_market_id,v_location_id from public.krim_locations l join public.krim_countries c on c.id=l.country_id and c.is_active=true where l.id=p_scope_id and l.is_active=true;
 end if;
 if v_country_id is null then raise exception using errcode='22023',message='Selected coverage scope is missing, inactive or inconsistent'; end if;
 select coalesce(array_agg(distinct btrim(x)),'{}'::text[]) into v_paths from unnest(coalesce(p_evidence_paths,'{}'::text[])) x where btrim(x)<>'';
 if cardinality(v_paths)<1 or cardinality(v_paths)>5 then raise exception using errcode='22023',message='Upload one to five replacement evidence files'; end if;
 if exists(select 1 from unnest(v_paths) p where p !~ ('^'||p_organization_id::text||'/'||v_uid::text||'/service-area/[A-Za-z0-9._-]{1,120}$')
  or not exists(select 1 from storage.objects so where so.bucket_id='krim-partner-verification' and so.name=p and so.owner=v_uid)) then
  raise exception using errcode='42501',message='Replacement evidence must exist in your private organisation folder and belong to your account';
 end if;
 if exists(select 1 from public.krim_partner_service_areas a where a.id<>p_service_area_id and a.organization_id=p_organization_id
  and a.coverage_type=p_coverage_type and a.country_id=v_country_id and a.market_id is not distinct from v_market_id
  and a.location_id is not distinct from v_location_id and a.service_type=p_service_type
  and a.transport_mode_id is not distinct from p_transport_mode_id and a.status='draft' and a.metadata->>'workflow_status'='pending_review') then
  raise exception using errcode='23505',message='A matching service-area request is already awaiting review';
 end if;
 v_history:=coalesce(v_area.metadata->'resubmission_history','[]'::jsonb)||jsonb_build_array(jsonb_build_object(
  'previous_review_decision',v_area.metadata->>'review_decision','previous_review_reason',v_area.metadata->>'review_reason',
  'previous_reviewed_by',v_area.metadata->>'reviewed_by','previous_reviewed_at',v_area.metadata->>'reviewed_at',
  'resubmitted_by',v_uid,'resubmitted_at',now()));
 update public.krim_partner_service_areas set country_id=v_country_id,market_id=v_market_id,location_id=v_location_id,
  coverage_type=p_coverage_type,service_type=p_service_type,transport_mode_id=p_transport_mode_id,
  status='draft',effective_from=p_effective_from,effective_until=p_effective_until,
  metadata=coalesce(metadata,'{}'::jsonb)||jsonb_build_object('workflow_status','pending_review','submitted_by',v_uid,'submitted_at',now(),
  'submission_source','partner_workspace_resubmission','evidence_paths',to_jsonb(v_paths),'notes',nullif(btrim(p_notes),''),
  'review_decision',null,'review_reason',null,'reviewed_by',null,'reviewed_at',null,'resubmission_history',v_history),
  updated_at=now() where id=p_service_area_id;
 insert into public.krim_audit_events(actor_user_id,organization_id,event_type,entity_type,entity_id,source,metadata,
  previous_state,new_state) values(v_uid,p_organization_id,'partner.service_area.resubmitted','partner_service_area',
  p_service_area_id::text,'partner_workspace_resubmission',jsonb_build_object('evidence_count',cardinality(v_paths)),
  jsonb_build_object('status','closed','workflow_status','rejected','review_reason',v_area.metadata->>'review_reason'),
  jsonb_build_object('status','draft','workflow_status','pending_review','evidence_count',cardinality(v_paths)));
 return jsonb_build_object('service_area_id',p_service_area_id,'organization_id',p_organization_id,'status','draft',
  'workflow_status','pending_review','evidence_count',cardinality(v_paths));
end;
$function$;
revoke all on function public.krim_partner_resubmit_service_area(bigint,bigint,text,bigint,text,bigint,text[],text,timestamptz,timestamptz) from public,anon;
grant execute on function public.krim_partner_resubmit_service_area(bigint,bigint,text,bigint,text,bigint,text[],text,timestamptz,timestamptz) to authenticated;
