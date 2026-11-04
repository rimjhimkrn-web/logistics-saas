create table if not exists private.krim_driver_invitations (
  id uuid primary key default gen_random_uuid(),
  organization_id bigint not null references public.krim_organizations(id) on delete cascade,
  invited_email text not null check (invited_email = lower(btrim(invited_email))),
  token_hash text not null unique,
  invited_by uuid not null references auth.users(id),
  expires_at timestamptz not null,
  accepted_by uuid references auth.users(id),
  accepted_at timestamptz,
  revoked_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists krim_driver_invitations_org_created_idx on private.krim_driver_invitations(organization_id,created_at desc);
revoke all on private.krim_driver_invitations from public,anon,authenticated;

create or replace function public.krim_create_driver_invitation(p_organization_id bigint,p_email text)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare v_uid uuid:=auth.uid();v_email text:=lower(btrim(coalesce(p_email,'')));v_token text;v_id uuid;v_org public.krim_organizations%rowtype;
begin
 if v_uid is null then raise exception using errcode='28000',message='Authentication required';end if;
 if not private.krim_has_permission(v_uid,p_organization_id,'partner.manage') then raise exception using errcode='42501',message='Partner management permission required';end if;
 if v_email !~* '^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$' then raise exception using errcode='22023',message='Enter a valid driver email address';end if;
 select * into v_org from public.krim_organizations where id=p_organization_id for share;
 if not found or coalesce(v_org.partner_account_mode,'')<>'registered_business' or coalesce(v_org.status,'')<>'active'
  or coalesce(v_org.partner_verification_status,'')<>'verified' or coalesce(v_org.partner_lifecycle_status,'')<>'active'
  or coalesce(v_org.partner_compliance_status,'')<>'compliant'
  or not exists(select 1 from public.krim_partner_capabilities c where c.organization_id=p_organization_id and c.service_type='transport' and c.active=true and c.verification_status='verified') then
  raise exception using errcode='23514',message='Only an eligible verified transport carrier can invite drivers';
 end if;
 v_token:=encode(extensions.gen_random_bytes(32),'hex');
 update private.krim_driver_invitations set revoked_at=now() where organization_id=p_organization_id and invited_email=v_email and accepted_at is null and revoked_at is null;
 insert into private.krim_driver_invitations(organization_id,invited_email,token_hash,invited_by,expires_at)
 values(p_organization_id,v_email,encode(extensions.digest(convert_to(v_token,'UTF8'),'sha256'),'hex'),v_uid,now()+interval '7 days') returning id into v_id;
 insert into public.krim_audit_events(actor_user_id,organization_id,event_type,entity_type,entity_id,source,metadata,new_state)
 values(v_uid,p_organization_id,'driver.invitation.created','driver_invitation',v_id::text,'driver_invitation',jsonb_build_object('email',v_email),jsonb_build_object('expires_at',now()+interval '7 days'));
 return jsonb_build_object('invitation_id',v_id,'email',v_email,'expires_at',now()+interval '7 days','invite_url','https://rimjhimkrn-web.github.io/logistics-saas/auth/driver-signup.html?invite='||v_token);
end;$$;

create or replace function public.krim_list_driver_invitations(p_organization_id bigint)
returns table(id uuid,invited_email text,expires_at timestamptz,accepted_at timestamptz,revoked_at timestamptz,created_at timestamptz)
language plpgsql security definer set search_path=''
as $$
declare v_uid uuid:=auth.uid();
begin
 if v_uid is null then raise exception using errcode='28000',message='Authentication required';end if;
 if not private.krim_has_permission(v_uid,p_organization_id,'partner.manage') then raise exception using errcode='42501',message='Partner management permission required';end if;
 return query select i.id,i.invited_email,i.expires_at,i.accepted_at,i.revoked_at,i.created_at from private.krim_driver_invitations i where i.organization_id=p_organization_id order by i.created_at desc limit 100;
end;$$;

create or replace function public.krim_revoke_driver_invitation(p_invitation_id uuid)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare v_uid uuid:=auth.uid();v_org bigint;
begin
 if v_uid is null then raise exception using errcode='28000',message='Authentication required';end if;
 select organization_id into v_org from private.krim_driver_invitations where id=p_invitation_id;
 if v_org is null then raise exception using errcode='P0002',message='Invitation not found';end if;
 if not private.krim_has_permission(v_uid,v_org,'partner.manage') then raise exception using errcode='42501',message='Partner management permission required';end if;
 update private.krim_driver_invitations set revoked_at=now() where id=p_invitation_id and accepted_at is null and revoked_at is null;
 if not found then raise exception using errcode='55000',message='Invitation is already accepted, revoked or expired';end if;
 insert into public.krim_audit_events(actor_user_id,organization_id,event_type,entity_type,entity_id,source,metadata)
 values(v_uid,v_org,'driver.invitation.revoked','driver_invitation',p_invitation_id::text,'driver_invitation','{}'::jsonb);
 return jsonb_build_object('invitation_id',p_invitation_id,'revoked',true);
end;$$;

create or replace function public.krim_accept_driver_invitation(p_token text)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare v_uid uuid:=auth.uid();v_email text;v_org bigint;v_inv private.krim_driver_invitations%rowtype;v_orgrow public.krim_organizations%rowtype;
 v_meta jsonb;v_profile public.krim_driver_profiles%rowtype;v_name text;v_country text;v_phone text;v_licence text;
begin
 if v_uid is null then raise exception using errcode='28000',message='Authentication required';end if;
 if coalesce(p_token,'') !~ '^[a-f0-9]{64}$' then raise exception using errcode='22023',message='Invalid driver invitation token';end if;
 select lower(email),raw_user_meta_data into v_email,v_meta from auth.users where id=v_uid;
 if coalesce(v_meta->>'driver_onboarding_mode','standard')='development_test' then raise exception using errcode='42501',message='Development/test driver accounts cannot join commercial carrier operations';end if;
 select * into v_inv from private.krim_driver_invitations where token_hash=encode(extensions.digest(convert_to(p_token,'UTF8'),'sha256'),'hex') for update;
 if not found or v_inv.revoked_at is not null or v_inv.accepted_at is not null or v_inv.expires_at<=now() then raise exception using errcode='55000',message='Invitation is invalid, expired, revoked or already used';end if;
 if v_email is null or v_email<>v_inv.invited_email then raise exception using errcode='42501',message='Sign in using the email address to which this invitation was issued';end if;
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
 insert into public.krim_organization_members(organization_id,user_id,role,status) values(v_inv.organization_id,v_uid,'driver','active')
 on conflict(organization_id,user_id) do update set role='driver',status='active';
 perform set_config('krim.driver_invitation_accept','on',true);
 select * into v_profile from public.krim_driver_profiles where user_id=v_uid for update;
 if found then
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

revoke all on function public.krim_create_driver_invitation(bigint,text) from public,anon;
revoke all on function public.krim_list_driver_invitations(bigint) from public,anon;
revoke all on function public.krim_revoke_driver_invitation(uuid) from public,anon;
revoke all on function public.krim_accept_driver_invitation(text) from public,anon;
grant execute on function public.krim_create_driver_invitation(bigint,text) to authenticated;
grant execute on function public.krim_list_driver_invitations(bigint) to authenticated;
grant execute on function public.krim_revoke_driver_invitation(uuid) to authenticated;
grant execute on function public.krim_accept_driver_invitation(text) to authenticated;

create or replace function private.krim_guard_driver_profile_verification()
returns trigger language plpgsql security definer set search_path=''
as $$
declare v_user uuid:=auth.uid();v_admin boolean:=v_user is not null and coalesce(auth.jwt()->>'aal','aal1')='aal2' and private.krim_has_permission(v_user,1::bigint,'admin.platform');
 v_invite_accept boolean:=coalesce(current_setting('krim.driver_invitation_accept',true),'')='on';
begin
 if tg_op='INSERT' then
  if new.verification_status is distinct from 'pending' and not v_admin then raise exception using errcode='42501',message='New driver profiles must remain pending until administrator verification';end if;
  if (new.user_id is distinct from v_user or new.onboarding_mode not in ('standard','development_test')) and not v_admin then raise exception using errcode='42501',message='Driver profile identity and onboarding mode are not authorized';end if;
  return new;
 end if;
 if new.verification_status is distinct from old.verification_status and not v_admin and not (v_invite_accept and new.verification_status='pending') then raise exception using errcode='42501',message='Driver verification status can only be changed by an AAL2 platform administrator or reset to pending on a valid carrier invitation';end if;
 if new.user_id is distinct from old.user_id and not v_admin then raise exception using errcode='42501',message='Driver identity cannot be changed';end if;
 if new.organization_id is distinct from old.organization_id and not v_admin and not v_invite_accept then raise exception using errcode='42501',message='Driver organization can only change through an accepted carrier invitation';end if;
 return new;
end;$$;
revoke all on function private.krim_guard_driver_profile_verification() from public,anon,authenticated;
drop trigger if exists krim_guard_driver_profile_verification on public.krim_driver_profiles;
create trigger krim_guard_driver_profile_verification before insert or update on public.krim_driver_profiles for each row execute function private.krim_guard_driver_profile_verification();