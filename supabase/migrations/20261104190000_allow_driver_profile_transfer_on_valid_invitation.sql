create or replace function private.krim_guard_driver_profile_verification()
returns trigger language plpgsql security definer set search_path = ''
as $$
declare v_user uuid:=auth.uid();v_admin boolean:=v_user is not null and coalesce(auth.jwt()->>'aal','aal1')='aal2' and private.krim_has_permission(v_user,1::bigint,'admin.platform');v_invitation_accept boolean:=current_setting('krim.driver_invitation_accept',true)='on';
begin
 if tg_op='INSERT' then
  if new.verification_status is distinct from 'pending' and not v_admin then raise exception using errcode='42501',message='New driver profiles must remain pending until administrator verification';end if;
  if (new.user_id is distinct from v_user or new.onboarding_mode not in ('standard','development_test')) and not v_admin then raise exception using errcode='42501',message='Driver profile identity and onboarding mode are not authorized';end if;
  return new;
 end if;
 if new.verification_status is distinct from old.verification_status and not v_admin then raise exception using errcode='42501',message='Driver verification status can only be changed by an AAL2 platform administrator';end if;
 if new.user_id is distinct from old.user_id and not v_admin then raise exception using errcode='42501',message='Driver identity cannot be changed';end if;
 if new.organization_id is distinct from old.organization_id and not v_admin then
  if not (v_invitation_accept and v_user=new.user_id
   and exists(select 1 from public.krim_organization_members m where m.organization_id=new.organization_id and m.user_id=v_user and m.role='driver' and m.status='active')
   and exists(select 1 from private.krim_driver_invitations i join auth.users u on lower(u.email)=i.invited_email where i.organization_id=new.organization_id and u.id=v_user and i.accepted_at is null and i.revoked_at is null and i.expires_at>now())) then
   raise exception using errcode='42501',message='Driver organization changes require a valid accepted carrier invitation';
  end if;
 end if;
 return new;
end;
$$;
revoke all on function private.krim_guard_driver_profile_verification() from public,anon,authenticated;