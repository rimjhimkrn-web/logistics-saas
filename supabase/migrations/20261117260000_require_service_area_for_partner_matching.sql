-- Require an approved, current partner service-area declaration at both route endpoints.
create or replace function private.krim_partner_has_active_service_area_for_location(
 p_organization_id bigint,p_location_id bigint,p_transport_mode_id bigint
) returns boolean
language sql
stable
security definer
set search_path=''
as $function$
 select coalesce(exists(
  select 1
  from public.krim_locations l
  join public.krim_countries c on c.id=l.country_id and c.is_active is true
  join public.krim_country_operating_packs cp on cp.jurisdiction_code=c.iso2_code
   and cp.status='approved' and (cp.next_review_at is null or cp.next_review_at>pg_catalog.now())
  join public.krim_partner_service_areas sa on sa.organization_id=p_organization_id
   and sa.country_id=l.country_id and sa.status='active'
   and sa.metadata->>'workflow_status'='approved'
   and sa.service_type in ('transport','freight_forwarding','first_mile','last_mile','other')
   and sa.transport_mode_id=p_transport_mode_id
   and sa.effective_from<=pg_catalog.now()
   and (sa.effective_until is null or sa.effective_until>pg_catalog.now())
   and (
    (sa.coverage_type='country' and sa.market_id is null and sa.location_id is null)
    or (sa.coverage_type='market' and sa.market_id=l.market_id and sa.location_id is null
      and exists(select 1 from public.krim_markets m where m.id=sa.market_id and m.country_id=l.country_id and m.is_active is true and lower(coalesce(m.status,'active'))='active'))
    or (sa.coverage_type='location' and sa.location_id=l.id
      and (sa.market_id is null or sa.market_id=l.market_id))
   )
  join public.krim_partner_capabilities pc on pc.organization_id=sa.organization_id
   and pc.service_type=sa.service_type and pc.coverage_country_id=sa.country_id
   and pc.transport_mode_id=p_transport_mode_id and pc.active is true
   and pc.verification_status='verified'
   and (pc.effective_from is null or pc.effective_from<=pg_catalog.now())
   and (pc.effective_until is null or pc.effective_until>pg_catalog.now())
  where l.id=p_location_id and l.is_active is true
 ),false);
$function$;
revoke all on function private.krim_partner_has_active_service_area_for_location(bigint,bigint,bigint) from public,anon,authenticated;

create or replace function private.krim_partner_capability_covers_shipment(
 p_organization_id bigint,p_shipment_id bigint
) returns boolean
language sql stable security definer set search_path=''
as $function$
 select exists(
  select 1 from public.krim_shipments s
  join public.krim_locations origin on origin.id=s.origin_location_id and origin.is_active is true
  join public.krim_locations destination on destination.id=s.destination_location_id and destination.is_active is true
  join public.krim_countries origin_country on origin_country.id=origin.country_id and origin_country.is_active is true
  join public.krim_countries destination_country on destination_country.id=destination.country_id and destination_country.is_active is true
  join public.krim_transport_modes requested_mode on requested_mode.is_active is true
   and upper(requested_mode.code)=upper(s.requested_transport_mode)
  where s.id=p_shipment_id and p_organization_id is not null
   and s.requested_transport_mode is not null
   and exists(select 1 from public.krim_partner_capabilities pc where pc.organization_id=p_organization_id
    and pc.transport_mode_id=requested_mode.id and pc.coverage_country_id=origin.country_id
    and pc.active is true and pc.verification_status='verified'
    and (pc.effective_from is null or pc.effective_from<=pg_catalog.now())
    and (pc.effective_until is null or pc.effective_until>pg_catalog.now())
    and (pc.max_weight_kg is null or pc.max_weight_kg>=coalesce(s.total_weight_kg,0))
    and (nullif(pg_catalog.btrim(pc.coverage_region),'') is null or pg_catalog.lower(pg_catalog.btrim(pc.coverage_region))
      in (pg_catalog.lower(origin_country.name),pg_catalog.lower(coalesce(origin.state_region,'')),pg_catalog.lower(coalesce(origin.region,'')))))
   and exists(select 1 from public.krim_partner_capabilities pc where pc.organization_id=p_organization_id
    and pc.transport_mode_id=requested_mode.id and pc.coverage_country_id=destination.country_id
    and pc.active is true and pc.verification_status='verified'
    and (pc.effective_from is null or pc.effective_from<=pg_catalog.now())
    and (pc.effective_until is null or pc.effective_until>pg_catalog.now())
    and (pc.max_weight_kg is null or pc.max_weight_kg>=coalesce(s.total_weight_kg,0))
    and (nullif(pg_catalog.btrim(pc.coverage_region),'') is null or pg_catalog.lower(pg_catalog.btrim(pc.coverage_region))
      in (pg_catalog.lower(destination_country.name),pg_catalog.lower(coalesce(destination.state_region,'')),pg_catalog.lower(coalesce(destination.region,'')))))
   and private.krim_partner_has_active_service_area_for_location(p_organization_id,origin.id,requested_mode.id)
   and private.krim_partner_has_active_service_area_for_location(p_organization_id,destination.id,requested_mode.id)
 );
$function$;
revoke all on function private.krim_partner_capability_covers_shipment(bigint,bigint) from public,anon,authenticated;

create or replace function private.krim_partner_capability_covers_shipment_leg(
 p_organization_id bigint,p_shipment_leg_id bigint
) returns boolean
language sql stable security definer set search_path=''
as $function$
 select exists(
  select 1 from public.krim_shipment_legs l
  join public.krim_shipments s on s.id=l.shipment_id
  join public.krim_locations origin on origin.id=l.origin_location_id and origin.is_active is true
  join public.krim_locations destination on destination.id=l.destination_location_id and destination.is_active is true
  join public.krim_countries origin_country on origin_country.id=origin.country_id and origin_country.is_active is true
  join public.krim_countries destination_country on destination_country.id=destination.country_id and destination_country.is_active is true
  join public.krim_transport_modes mode on mode.id=l.transport_mode_id and mode.is_active is true
  where l.id=p_shipment_leg_id and p_organization_id is not null
   and s.total_weight_kg is not null and s.total_weight_kg>0
   and exists(select 1 from public.krim_partner_capabilities pc where pc.organization_id=p_organization_id
    and pc.transport_mode_id=mode.id and pc.coverage_country_id=origin.country_id
    and pc.active is true and pc.verification_status='verified'
    and (pc.effective_from is null or pc.effective_from<=pg_catalog.now())
    and (pc.effective_until is null or pc.effective_until>pg_catalog.now())
    and (pc.max_weight_kg is null or pc.max_weight_kg>=s.total_weight_kg)
    and (nullif(pg_catalog.btrim(pc.coverage_region),'') is null or pg_catalog.lower(pg_catalog.btrim(pc.coverage_region))
      in (pg_catalog.lower(origin_country.name),pg_catalog.lower(coalesce(origin.state_region,'')),pg_catalog.lower(coalesce(origin.region,'')))))
   and exists(select 1 from public.krim_partner_capabilities pc where pc.organization_id=p_organization_id
    and pc.transport_mode_id=mode.id and pc.coverage_country_id=destination.country_id
    and pc.active is true and pc.verification_status='verified'
    and (pc.effective_from is null or pc.effective_from<=pg_catalog.now())
    and (pc.effective_until is null or pc.effective_until>pg_catalog.now())
    and (pc.max_weight_kg is null or pc.max_weight_kg>=s.total_weight_kg)
    and (nullif(pg_catalog.btrim(pc.coverage_region),'') is null or pg_catalog.lower(pg_catalog.btrim(pc.coverage_region))
      in (pg_catalog.lower(destination_country.name),pg_catalog.lower(coalesce(destination.state_region,'')),pg_catalog.lower(coalesce(destination.region,'')))))
   and private.krim_partner_has_active_service_area_for_location(p_organization_id,origin.id,mode.id)
   and private.krim_partner_has_active_service_area_for_location(p_organization_id,destination.id,mode.id)
 );
$function$;
revoke all on function private.krim_partner_capability_covers_shipment_leg(bigint,bigint) from public,anon,authenticated;
