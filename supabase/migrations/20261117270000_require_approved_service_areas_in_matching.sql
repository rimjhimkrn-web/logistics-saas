-- Matching candidates must have approved active service areas at both endpoints.
create or replace function public.krim_internal_partner_location_coverage_score(
 p_partner_organization_id bigint,p_location_id bigint,p_transport_mode_id bigint,p_service_type text default 'transport'
) returns numeric
language sql stable security definer set search_path=''
as $function$
 select max(case sa.coverage_type
   when 'location' then 100::numeric
   when 'market' then 90::numeric
   when 'region' then 80::numeric
   when 'country' then 70::numeric
   else null::numeric end)
 from public.krim_partner_service_areas sa
 join public.krim_locations l on l.id=p_location_id and l.is_active is true
 join public.krim_countries c on c.id=l.country_id and c.is_active is true
 join public.krim_country_operating_packs cp on cp.jurisdiction_code=c.iso2_code
  and cp.pack_status='approved' and (cp.next_review_at is null or cp.next_review_at>pg_catalog.now())
 where sa.organization_id=p_partner_organization_id
  and sa.status='active' and sa.metadata->>'workflow_status'='approved'
  and sa.service_type=p_service_type
  and (sa.transport_mode_id is null or sa.transport_mode_id=p_transport_mode_id)
  and sa.effective_from<=pg_catalog.now()
  and (sa.effective_until is null or sa.effective_until>=pg_catalog.now())
  and (
   (sa.coverage_type='location' and sa.location_id=l.id)
   or (sa.coverage_type='market' and sa.market_id=l.market_id
     and exists(select 1 from public.krim_markets m where m.id=sa.market_id and m.country_id=l.country_id and m.is_active is true and lower(coalesce(m.status,'active'))='active'))
   or (sa.coverage_type='country' and sa.country_id=l.country_id)
   or (sa.coverage_type='region' and sa.country_id=l.country_id
     and lower(coalesce(sa.metadata->>'region_code',sa.metadata->>'region',''))=
         lower(coalesce(l.state_region,l.region,'')))
  );
$function$;
revoke all on function public.krim_internal_partner_location_coverage_score(bigint,bigint,bigint,text) from public,anon,authenticated;

-- Harden the matching-run candidate filter at the source, not only at later quote acceptance.
do $block$
declare v_definition text;
begin
 select pg_catalog.pg_get_functiondef('public.krim_internal_create_partner_matching_run(bigint,bigint)'::regprocedure)
 into v_definition;
 if position('krim_partner_has_active_service_area_for_location' in v_definition)=0 then
  v_definition:=replace(v_definition,
   '      and o.partner_lifecycle_status = ''active''',
   '      and o.status = ''active'''||
   '      and o.partner_account_mode = ''registered_business'''||
   '      and private.krim_partner_compliance_is_current(o.id)'||
   '      and private.krim_partner_has_active_service_area_for_location(pc.organization_id, v_req.origin_location_id, v_mode_id)'||
   '      and private.krim_partner_has_active_service_area_for_location(pc.organization_id, v_req.destination_location_id, v_mode_id)'||
   '      and o.partner_lifecycle_status = ''active''');
  if position('krim_partner_has_active_service_area_for_location' in v_definition)=0 then
   raise exception 'Could not safely locate matching-run candidate filter';
  end if;
  execute v_definition;
 end if;
end
$block$;
