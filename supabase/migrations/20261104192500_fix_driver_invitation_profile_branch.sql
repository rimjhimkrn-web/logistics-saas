create or replace function public.krim_accept_driver_invitation(p_token text)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare v_uid uuid:=auth.uid();v_email text;v_email_confirmed boolean;v_inv private.krim_driver_invitations%rowtype;
 v_orgrow public.krim_organizations%rowtype;v_meta jsonb;v_profile public.krim_driver_profiles%rowtype;
 v_name text;v_country text;v_phone text;v_licence text;v_mode text;v_has_profile boolean:=false;
begin
 if v_uid is null then raise exception using errcode='28000',message='Authentication required';end if;
 if coalesce(p_token,'') !~ '^[a-f0-9]{64}$' then raise exception using errcode='22023',message='Invalid driver invitation token';end if;
 select lower(email),email_confirmed_at is not null,raw_user_meta_data into v_email,v_email_confirmed,v_meta from auth.users where id=v_uid;
 if not coalesce(v_email_confirmed,false) then raise exception using errcode='42501',message='Confirm the invited email address before accepting this carrier invitation';end if;
 select * into v_inv from private.krim_driver_invitations where token_hash=encode(extensions.digest(convert_to(p_token,'UTF8'),'sha256'),'hex') for update;
 if not found or v_inv.revoked_at is not null or v_inv.accepted_at is not null or v_inv.expires_at<=now() then raise exception using errcode='55000',message='Invitation is invalid, expired, revoked or already used';end if;
 if v_email is null or v_email<>v_inv.invited_email then raise exception using errcode='42501',message='Sign in using the confirmed email address to which this invitation was issued';end if;
 select * into v_orgrow from public.krim_organizations where id=v_inv.organization_id for share;
 if coalesce(v_orgrow.partner_account_mode,'')<>'registered_business' or coalesce(v_orgrow.status,'')<>'active'
  or coalesce(v_orgrow.partner_verification_status,'')<>'verified' or coalesce(v_orgrow.partner_lifecycle_status,'')<>'active'
  or coalesce(v_orgrow.partner_compliance_status,'')<>'compliant'
  or not exists(select 1 from public.krim_partner_capabilities c where c.organization_id=v_inv.organization_id and c.service_type='transport' and c.active=true and c.verification_status='verified') then
  raise exception using errcode='23514',message='Carrier eligibility changed; ask the carrier to contact KRIM support';
 end if;
 v_name:=left(nullif(btrim(coalesce(v_meta->>'full_name','')),''),180);if v_name is null or char_length(v_name)<2 then v_name:='Driver '||substr(v_uid::text,1,8);end if;
 v_country:=upper(coalesce(v_meta->>'country_code','IN'));if v_country !~ '^[A-Z]{2}$' then v_country:='IN';end if;
 v_phone:=left(coalesce(v_meta->>'phone',''),40);v_licence:=left(coalesce(v_meta->>'driver_licence_number',''),120);
 select * into v_profile from public.krim_driver_profiles where user_id=v_uid for update;
 v_has_profile:=found;
 if v_has_profile then
  if v_profile.onboarding_mode='development_test' then raise exception using errcode='42501',message='Development/test driver profiles cannot join commercial carrier operations';end if;
 else
  v_mode:=case when coalesce(v_meta->>'driver_onboarding_mode','standard')='development_test' then 'development_test' else 'standard' end;
  if v_mode='development_test' then raise exception using errcode='42501',message='Development/test driver profiles cannot join commercial carrier operations';end if;
 end if;
 insert into public.krim_organization_members(organization_id,user_id,role,status) values(v_inv.organization_id,v_uid,'driver','active')
 on conflict(organization_id,user_id) do update set role='driver',status='active';
 perform set_config('krim.driver_invitation_accept','on',true);
 if v_has_profile then
  update public.krim_driver_profiles set organization_id=v_inv.organization_id,verification_status='pending',
   company_name=left(coalesce(v_orgrow.display_name,v_orgrow.legal_name,''),180),updated_at=now() where id=v_profile.id;
  update public.krim_driver_verification_documents set organization_id=v_inv.organization_id where profile_id=v_profile.id and user_id=v_uid;
 else
  insert into public.krim_driver_profiles(user_id,organization_id,full_name,country_code,phone,company_name,licence_number,verification_status,onboarding_mode)
  values(v_uid,v_inv.organization_id,v_name,v_country,v_phone,left(coalesce(v_orgrow.display_name,v_orgrow.legal_name,''),180),v_licence,'pending','standard');
 end if;
 update private.krim_driver_invitations set accepted_by=v_uid,accepted_at=now() where id=v_inv.id;
 insert into public.krim_audit_events(actor_user_id,organization_id,event_type,entity_type,entity_id,source,metadata)
 values(v_uid,v_inv.organization_id,'driver.invitation.accepted','driver_invitation',v_inv.id::text,'driver_invitation',jsonb_build_object('driver_user_id',v_uid,'profile_verification','pending'));
 return jsonb_build_object('accepted',true,'organization_id',v_inv.organization_id,'verification_status','pending');
end;$$;
revoke all on function public.krim_accept_driver_invitation(text) from public,anon;
grant execute on function public.krim_accept_driver_invitation(text) to authenticated;