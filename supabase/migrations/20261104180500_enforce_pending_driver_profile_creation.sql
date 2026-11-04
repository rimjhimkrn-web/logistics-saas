create or replace function private.krim_guard_driver_profile_verification()
returns trigger language plpgsql security definer set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_admin boolean := v_user is not null and coalesce(auth.jwt()->>'aal','aal1')='aal2'
    and private.krim_has_permission(v_user,1::bigint,'admin.platform');
begin
  if tg_op='INSERT' then
    if new.verification_status is distinct from 'pending' and not v_admin then
      raise exception using errcode='42501',message='New driver profiles must remain pending until administrator verification';
    end if;
    if (new.user_id is distinct from v_user or new.onboarding_mode not in ('standard','development_test')) and not v_admin then
      raise exception using errcode='42501',message='Driver profile identity and onboarding mode are not authorized';
    end if;
    return new;
  end if;
  if new.verification_status is distinct from old.verification_status and not v_admin then
    raise exception using errcode='42501',message='Driver verification status can only be changed by an AAL2 platform administrator';
  end if;
  if (new.user_id is distinct from old.user_id or new.organization_id is distinct from old.organization_id) and not v_admin then
    raise exception using errcode='42501',message='Driver identity and organization links are immutable outside administrator review';
  end if;
  return new;
end;
$$;
revoke all on function private.krim_guard_driver_profile_verification() from public,anon,authenticated;
drop trigger if exists krim_guard_driver_profile_verification on public.krim_driver_profiles;
create trigger krim_guard_driver_profile_verification before insert or update on public.krim_driver_profiles
for each row execute function private.krim_guard_driver_profile_verification();