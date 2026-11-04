-- Allow profile organization transfer only inside the verified, email-bound driver invitation acceptance RPC.
create or replace function private.krim_guard_driver_profile_verification()
returns trigger language plpgsql security definer set search_path=''
as $$
declare
 v_user uuid:=auth.uid();
 v_admin boolean:=v_user is not null and coalesce(auth.jwt()->>'aal','aal1')='aal2'
   and private.krim_has_permission(v_user,1::bigint,'admin.platform');
 v_invitation_rehome boolean:=current_setting('krim.driver_invitation_accept',true)='yes'
   and v_user is not null
   and exists(select 1 from public.krim_organization_members m where m.organization_id=new.organization_id
     and m.user_id=v_user and m.role='driver' and m.status='active');
begin
 if tg_op='INSERT' then
  if new.verification_status is distinct from 'pending' and not v_admin then raise exception using errcode='42501',message='New driver profiles must remain pending until administrator verification';end if;
  if (new.user_id is distinct from v_user or new.onboarding_mode not in ('standard','development_test')) and not v_admin then raise exception using errcode='42501',message='Driver profile identity and onboarding mode are not authorized';end if;
  return new;
 end if;
 if new.verification_status is distinct from old.verification_status and not v_admin then raise exception using errcode='42501',message='Driver verification status can only be changed by an AAL2 platform administrator';end if;
 if new.user_id is distinct from old.user_id and not v_admin then raise exception using errcode='42501',message='Driver identity is immutable outside administrator review';end if;
 if new.organization_id is distinct from old.organization_id and not (v_admin or v_invitation_rehome) then raise exception using errcode='42501',message='Driver organization can only change through an accepted carrier invitation';end if;
 return new;
end;$$;
revoke all on function private.krim_guard_driver_profile_verification() from public,anon,authenticated;

create or replace function public.krim_accept_driver_invitation(p_token text)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare v_uid uuid:=auth.uid();v_email text:=lower(coalesce(auth.jwt()->>'email',''));v_inv public.krim_organization_invitations%rowtype;v_org public.krim_organizations%rowtype;
begin
 if v_uid is null then raise exception using errcode='28000',message='Authentication required';end if;
 if p_token is null or length(p_token)<50 or length(p_token)>100 then raise exception using errcode='22023',message='Invalid driver invitation token';end if;
 select * into v_inv from public.krim_organization_invitations i where i.invitation_token_hash=md5(p_token) for update;
 if not found or v_inv.role_code<>'driver' or v_inv.status<>'pending' or v_inv.expires_at<=now() then raise exception using errcode='P0002',message='Driver invitation is invalid, expired or already used';end if;
 if v_email='' or v_email<>lower(v_inv.email) then raise exception using errcode='42501',message='Sign in with the email address that received this invitation';end if;
 select * into v_org from public.krim_organizations o where o.id=v_inv.organization_id for share;
 if v_org.status<>'active' or v_org.partner_account_mode<>'registered_business' or v_org.partner_verification_status<>'verified' or v_org.partner_lifecycle_status<>'active' or v_org.partner_compliance_status<>'compliant' then raise exception using errcode='42501',message='Inviting carrier organization is no longer eligible';end if;
 perform pg_advisory_xact_lock(hashtext('krim-driver-membership:'||v_inv.organization_id::text||':'||v_uid::text)::bigint);
 if exists(select 1 from public.krim_organization_members m where m.organization_id=v_inv.organization_id and m.user_id=v_uid and (m.role<>'driver' or m.status<>'active')) then raise exception using errcode='23514',message='This account already has a different membership in the carrier organization. Ask the organization administrator to resolve it.';end if;
 if not exists(select 1 from public.krim_organization_members m where m.organization_id=v_inv.organization_id and m.user_id=v_uid) then insert into public.krim_organization_members(organization_id,user_id,role,status) values(v_inv.organization_id,v_uid,'driver','active');end if;
 perform set_config('krim.driver_invitation_accept','yes',true);
 update public.krim_driver_profiles set organization_id=v_inv.organization_id,updated_at=now() where user_id=v_uid and organization_id<>v_inv.organization_id;
 perform set_config('krim.driver_invitation_accept','',true);
 update public.krim_organization_invitations set status='accepted',accepted_at=now() where id=v_inv.id;
 insert into public.krim_audit_events(actor_user_id,organization_id,event_type,entity_type,entity_id,source,metadata)
 values(v_uid,v_inv.organization_id,'partner.driver_invitation.accepted','organization_invitation',v_inv.id::text,'driver_invitation',jsonb_build_object('email',v_email,'role','driver'));
 return jsonb_build_object('organization_id',v_inv.organization_id,'role','driver','status','active');
end;$$;
revoke all on function public.krim_accept_driver_invitation(text) from public,anon,authenticated;
grant execute on function public.krim_accept_driver_invitation(text) to authenticated;
