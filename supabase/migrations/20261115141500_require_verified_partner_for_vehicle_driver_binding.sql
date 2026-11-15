create or replace function public.krim_vehicle_driver_bind(p_organization_id bigint,p_vehicle_id uuid,p_driver_user_id uuid)
returns uuid language plpgsql security definer set search_path to '' as $function$
declare
 v_user uuid:=auth.uid();
 v_profile public.krim_driver_profiles%rowtype;
 v_vehicle public.krim_vehicles%rowtype;
 v_org public.krim_organizations%rowtype;
 v_binding uuid;
begin
 if v_user is null or not public.krim_has_permission(v_user,p_organization_id,'shipment.dispatch') then
  raise exception using errcode='42501',message='Dispatch permission required';
 end if;
 select * into v_org from public.krim_organizations where id=p_organization_id for share;
 if not found or coalesce(v_org.status,'')<>'active' or coalesce(v_org.partner_account_mode,'')<>'registered_business'
  or coalesce(v_org.partner_verification_status,'')<>'verified' or coalesce(v_org.partner_lifecycle_status,'')<>'active'
  or coalesce(v_org.partner_compliance_status,'')<>'compliant' then
  raise exception using errcode='42501',message='Only an active, verified, compliant registered-business partner can bind fleet resources';
 end if;
 if not exists(select 1 from public.krim_partner_capabilities c where c.organization_id=p_organization_id and c.service_type='transport'
  and c.active=true and c.verification_status='verified' and (c.effective_from is null or c.effective_from<=current_date)
  and (c.effective_until is null or c.effective_until>=current_date)) then
  raise exception using errcode='42501',message='A current independently verified transport capability is required';
 end if;
 select * into v_vehicle from public.krim_vehicles where id=p_vehicle_id and organization_id=p_organization_id for update;
 if not found or v_vehicle.verification_status<>'verified' or v_vehicle.operational_status<>'active' then
  raise exception using errcode='42501',message='Vehicle must be verified, active and owned by this partner organisation';
 end if;
 if v_vehicle.payload_capacity is null or v_vehicle.payload_capacity<=0 or lower(btrim(coalesce(v_vehicle.payload_unit,''))) not in('kg','kilogram','kilograms','t','ton','tonne','tonnes','mt') then
  raise exception using errcode='55000',message='A positive vehicle payload and recognised kg/tonne unit are required';
 end if;
 if not exists(select 1 from public.krim_vehicle_document_requirements r where r.registration_country_code=v_vehicle.registration_country_code and lower(r.vehicle_category)=lower(v_vehicle.vehicle_category) and r.is_required=true)
  or exists(select 1 from public.krim_vehicle_document_requirements r where r.registration_country_code=v_vehicle.registration_country_code and lower(r.vehicle_category)=lower(v_vehicle.vehicle_category) and r.is_required=true
   and not exists(select 1 from public.krim_vehicle_documents d where d.vehicle_id=v_vehicle.id and d.document_type=r.document_type and d.review_status='approved' and (d.expires_at is null or d.expires_at>=current_date))) then
  raise exception using errcode='55000',message='Vehicle mandatory documents are missing, unapproved or expired';
 end if;
 select dp.* into v_profile from public.krim_driver_profiles dp join public.krim_organization_members m on m.user_id=dp.user_id and m.organization_id=dp.organization_id
 where dp.user_id=p_driver_user_id and dp.organization_id=p_organization_id and dp.verification_status='verified'
  and nullif(btrim(dp.licence_number),'') is not null and lower(m.role)='driver' and lower(m.status)='active' for update of dp;
 if not found then raise exception using errcode='42501',message='Driver must have a verified profile and active driver membership in this organisation';end if;
 if not exists(select 1 from public.krim_driver_verification_documents d where d.profile_id=v_profile.id and d.document_type='licence_front' and d.review_status='accepted')
  or not exists(select 1 from public.krim_driver_verification_documents d where d.profile_id=v_profile.id and d.document_type='licence_back' and d.review_status='accepted')
  or not exists(select 1 from public.krim_driver_verification_documents d where d.profile_id=v_profile.id and d.document_type='identity_document' and d.review_status='accepted') then
  raise exception using errcode='42501',message='Front and back driving licence evidence and identity evidence must all be independently accepted';
 end if;
 if exists(select 1 from public.krim_vehicle_driver_bindings where status='active' and (vehicle_id=p_vehicle_id or driver_user_id=p_driver_user_id)) then
  raise exception using errcode='23505',message='Vehicle or driver already has an active binding; revoke the existing binding first';
 end if;
 insert into public.krim_vehicle_driver_bindings(organization_id,vehicle_id,driver_profile_id,driver_user_id,status,created_by)
 values(p_organization_id,p_vehicle_id,v_profile.id,p_driver_user_id,'active',v_user) returning id into v_binding;
 insert into public.krim_audit_events(actor_user_id,organization_id,event_type,entity_type,entity_id,source,metadata,new_state)
 values(v_user,p_organization_id,'vehicle.driver.bound','vehicle_driver_binding',v_binding::text,'fleet-compatibility',
  jsonb_build_object('vehicle_id',p_vehicle_id,'driver_user_id',p_driver_user_id,'partner_verified',true,'transport_capability_verified',true),
  jsonb_build_object('status','active'));
 return v_binding;
end;$function$;
revoke all on function public.krim_vehicle_driver_bind(bigint,uuid,uuid) from public,anon;
grant execute on function public.krim_vehicle_driver_bind(bigint,uuid,uuid) to authenticated,service_role;