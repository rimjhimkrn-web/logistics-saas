create or replace function private.krim_guard_driver_profile_verification()
returns trigger language plpgsql security definer set search_path = ''
as $$
declare v_user uuid := auth.uid();
begin
  if new.verification_status is distinct from old.verification_status then
    if v_user is null or coalesce(auth.jwt()->>'aal','aal1') <> 'aal2'
       or not private.krim_has_permission(v_user,1::bigint,'admin.platform') then
      raise exception using errcode='42501',message='Driver verification status can only be changed by an AAL2 platform administrator';
    end if;
  end if;
  if new.user_id is distinct from old.user_id or new.organization_id is distinct from old.organization_id then
    if v_user is null or coalesce(auth.jwt()->>'aal','aal1') <> 'aal2'
       or not private.krim_has_permission(v_user,1::bigint,'admin.platform') then
      raise exception using errcode='42501',message='Driver identity and organization links are immutable outside administrator review';
    end if;
  end if;
  return new;
end;
$$;
revoke all on function private.krim_guard_driver_profile_verification() from public,anon,authenticated;
drop trigger if exists krim_guard_driver_profile_verification on public.krim_driver_profiles;
create trigger krim_guard_driver_profile_verification before update on public.krim_driver_profiles
for each row execute function private.krim_guard_driver_profile_verification();