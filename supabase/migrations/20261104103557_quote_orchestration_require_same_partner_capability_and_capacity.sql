create or replace function public.krim_internal_check_network_capability(p_orchestration_run_id bigint)
returns jsonb language plpgsql security definer set search_path = ''
as $function$
declare
 v_run public.krim_quote_orchestration_runs%rowtype;v_origin_country bigint;v_destination_country bigint;
 v_origin_location bigint;v_destination_location bigint;v_mode_id bigint;v_weight numeric;v_requested_at timestamptz;
 v_partner_count integer;v_capacity_count integer;
begin
 select * into v_run from public.krim_quote_orchestration_runs where id=p_orchestration_run_id for update;
 if not found then raise exception 'Quote orchestration run not found';end if;
 v_weight:=nullif((v_run.input_snapshot->>'cargo_weight')::numeric,0);
 v_origin_location:=nullif(v_run.input_snapshot->>'origin_location_id','')::bigint;
 v_destination_location:=nullif(v_run.input_snapshot->>'destination_location_id','')::bigint;
 v_requested_at:=coalesce(nullif(v_run.input_snapshot->>'requested_service_date','')::timestamptz,now());
 select l.country_id into v_origin_country from public.krim_locations l where l.id=v_origin_location and l.is_active=true;
 select l.country_id into v_destination_country from public.krim_locations l where l.id=v_destination_location and l.is_active=true;
 select m.id into v_mode_id from public.krim_transport_modes m where m.code=upper(v_run.input_snapshot->>'transport_mode_code') and m.is_active=true limit 1;
 if v_mode_id is null then return jsonb_build_object('status','blocked','reason','transport_mode_unavailable');end if;
 with eligible_partners as (
  select o.id organization_id from public.krim_organizations o
  where o.status='active' and o.partner_account_mode='registered_business' and o.partner_lifecycle_status='active'
   and o.partner_verification_status='verified' and o.partner_compliance_status='compliant'
   and exists(select 1 from public.krim_partner_capabilities pc where pc.organization_id=o.id and pc.transport_mode_id=v_mode_id
    and pc.service_type='transport' and pc.active=true and pc.verification_status='verified'
    and (pc.effective_from is null or pc.effective_from<=v_requested_at) and (pc.effective_until is null or pc.effective_until>v_requested_at)
    and (pc.max_weight_kg is null or v_weight is null or pc.max_weight_kg>=v_weight))
   and (exists(select 1 from public.krim_partner_capabilities g where g.organization_id=o.id and g.transport_mode_id=v_mode_id
      and g.service_type='transport' and g.active=true and g.verification_status='verified' and g.coverage_country_id is null
      and (g.effective_from is null or g.effective_from<=v_requested_at) and (g.effective_until is null or g.effective_until>v_requested_at))
    or (exists(select 1 from public.krim_partner_capabilities oc where oc.organization_id=o.id and oc.transport_mode_id=v_mode_id
      and oc.service_type='transport' and oc.active=true and oc.verification_status='verified' and oc.coverage_country_id=v_origin_country
      and (oc.effective_from is null or oc.effective_from<=v_requested_at) and (oc.effective_until is null or oc.effective_until>v_requested_at))
     and exists(select 1 from public.krim_partner_capabilities dc where dc.organization_id=o.id and dc.transport_mode_id=v_mode_id
      and dc.service_type='transport' and dc.active=true and dc.verification_status='verified' and dc.coverage_country_id=v_destination_country
      and (dc.effective_from is null or dc.effective_from<=v_requested_at) and (dc.effective_until is null or dc.effective_until>v_requested_at))))
 ),
 capacity_partners as (
  select nc.organization_id from public.krim_network_capacity nc join eligible_partners ep on ep.organization_id=nc.organization_id
  where nc.transport_mode_id=v_mode_id and nc.status='available'
   and (nc.available_from is null or nc.available_from<=v_requested_at) and (nc.available_until is null or nc.available_until>v_requested_at)
   and (nc.capacity_value is null or v_weight is null or nc.capacity_value>=v_weight)
   and (nc.origin_location_id is null or nc.origin_location_id=v_origin_location)
   and (nc.destination_location_id is null or nc.destination_location_id=v_destination_location)
  union
  select a.organization_id from public.krim_partner_capacity_availability a
  join public.krim_capacity_resources r on r.id=a.capacity_resource_id
  join eligible_partners ep on ep.organization_id=a.organization_id
  where a.transport_mode_id=v_mode_id and a.status='available' and a.metadata->>'verification_state'='verified'
   and a.available_from<=v_requested_at and a.available_until>v_requested_at
   and (a.booking_window_start is null or a.booking_window_start<=v_requested_at)
   and (a.booking_window_end is null or a.booking_window_end>v_requested_at)
   and a.availability_type in ('vehicle','weight') and r.resource_type='vehicle' and r.transport_mode_id=v_mode_id
   and r.status='available' and r.metadata->>'verification_state'='verified' and r.location_id=v_origin_location
   and r.available_from<=v_requested_at and r.available_until>v_requested_at and lower(a.capacity_unit)=lower(r.capacity_unit)
   and ((a.availability_type='vehicle' and a.capacity_value>=1 and r.capacity_value>=1)
    or (a.availability_type='weight' and v_weight is not null and v_weight>0 and case lower(btrim(a.capacity_unit))
     when 'kg' then least(a.capacity_value,r.capacity_value)>=v_weight when 'kgs' then least(a.capacity_value,r.capacity_value)>=v_weight
     when 'kilogram' then least(a.capacity_value,r.capacity_value)>=v_weight when 'kilograms' then least(a.capacity_value,r.capacity_value)>=v_weight
     when 't' then least(a.capacity_value,r.capacity_value)>=v_weight/1000 when 'tonne' then least(a.capacity_value,r.capacity_value)>=v_weight/1000
     when 'tonnes' then least(a.capacity_value,r.capacity_value)>=v_weight/1000 when 'metric ton' then least(a.capacity_value,r.capacity_value)>=v_weight/1000
     when 'metric tons' then least(a.capacity_value,r.capacity_value)>=v_weight/1000 else false end))
 )
 select (select count(*) from eligible_partners),(select count(distinct organization_id) from capacity_partners)
 into v_partner_count,v_capacity_count;
 if v_partner_count=0 or v_capacity_count=0 then
  update public.krim_quote_orchestration_runs set stage='matching',status='queued',
   result_summary=result_summary||jsonb_build_object('network_capability','unavailable','partner_capability_count',v_partner_count,'network_capacity_count',v_capacity_count)
  where id=p_orchestration_run_id;
  return jsonb_build_object('status','unavailable','partner_capability_count',v_partner_count,'network_capacity_count',v_capacity_count);
 end if;
 update public.krim_quote_orchestration_runs set stage='pricing',status='queued',
  result_summary=result_summary||jsonb_build_object('network_capability','available','partner_capability_count',v_partner_count,'network_capacity_count',v_capacity_count)
 where id=p_orchestration_run_id;
 return jsonb_build_object('status','available','partner_capability_count',v_partner_count,'network_capacity_count',v_capacity_count);
end;
$function$;
revoke all on function public.krim_internal_check_network_capability(bigint) from public,anon,authenticated;
grant execute on function public.krim_internal_check_network_capability(bigint) to service_role;