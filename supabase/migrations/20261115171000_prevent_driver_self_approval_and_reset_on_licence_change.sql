create or replace function public.krim_guard_driver_profile_verification_updates()
returns trigger
language plpgsql
set search_path to ''
as $function$
begin
  if auth.uid() = old.user_id then
    if old.licence_number is distinct from new.licence_number
       or old.licence_expiry_date is distinct from new.licence_expiry_date then
      new.verification_status := 'pending';
    elsif old.verification_status is distinct from new.verification_status then
      new.verification_status := old.verification_status;
    end if;
  end if;
  return new;
end;
$function$;

revoke all on function public.krim_guard_driver_profile_verification_updates() from public, anon, authenticated;

drop trigger if exists trg_krim_guard_driver_profile_verification_updates on public.krim_driver_profiles;
create trigger trg_krim_guard_driver_profile_verification_updates
before update on public.krim_driver_profiles
for each row execute function public.krim_guard_driver_profile_verification_updates();
