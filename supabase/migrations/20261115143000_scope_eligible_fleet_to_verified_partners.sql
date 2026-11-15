create or replace function public.krim_vehicle_driver_eligible_vehicles(p_organization_id bigint)
returns table(vehicle_id uuid,registration_number text,registration_country_code text,vehicle_category text,vehicle_type text,payload_capacity numeric,payload_unit text)
language plpgsql security definer set search_path to '' as $function$
declare
 v_user uuid:=auth.uid();
 v_org public.krim_organizations%rowtype;
begin
 if v_user is null or not public.krim_has_permission(v_user,p_organization_id,'shipment.dispatch') then
  raise exception using errcode='42501',message='Dispatch permission required';
 end if;
 select * into v_org from public.krim_organizations where id=p_organization_id;
 if not found or coalesce(v_org.status,'')<>'active' or coalesce(v_org.partner_account_mode,'')<>'registered_business'
  or coalesce(v_org.partner_verification_status,'')<>'verified' or coalesce(v_org.partner_lifecycle_status,'')<>'active'
  or coalesce(v_org.partner_compliance_status,'')<>'compliant' then return; end if;
 if not exists(select 1 from public.krim_partner_capabilities c where c.organization_id=p_organization_id and c.service_type='transport'
  and c.active=true and c.verification_status='verified' and (c.effective_from is null or c.effective_from<=current_date)
  and (c.effective_until is null or c.effective_until>=current_date)) then return; end if;
 return query
 select v.id,v.registration_number,v.registration_country_code,v.vehicle_category,v.vehicle_type,v.payload_capacity,v.payload_unit
 from public.krim_vehicles v
 where v.organization_id=p_organization_id and v.verification_status='verified' and v.operational_status='active'
  and v.payload_capacity is not null and v.payload_capacity>0
  and lower(btrim(coalesce(v.payload_unit,''))) in('kg','kilogram','kilograms','t','ton','tonne','tonnes','mt')
  and exists(select 1 from public.krim_vehicle_document_requirements r where r.registration_country_code=v.registration_country_code and lower(r.vehicle_category)=lower(v.vehicle_category) and r.is_required=true)
  and not exists(select 1 from public.krim_vehicle_document_requirements r where r.registration_country_code=v.registration_country_code and lower(r.vehicle_category)=lower(v.vehicle_category) and r.is_required=true
   and not exists(select 1 from public.krim_vehicle_documents d where d.vehicle_id=v.id and d.document_type=r.document_type and d.review_status='approved' and (d.expires_at is null or d.expires_at>=current_date)))
  and not exists(select 1 from public.krim_vehicle_driver_bindings b where b.vehicle_id=v.id and b.status='active')
 order by v.registration_number;
end;$function$;
revoke all on function public.krim_vehicle_driver_eligible_vehicles(bigint) from public,anon;
grant execute on function public.krim_vehicle_driver_eligible_vehicles(bigint) to authenticated,service_role;