do $migration$
declare
  v_def text;
  v_old text;
  v_new text;
begin
  v_def := pg_get_functiondef('private.krim_guard_driver_profile_verification()'::regprocedure);
  v_old := $old$(new.licence_number is distinct from old.licence_number or new.full_name is distinct from old.full_name or new.country_code is distinct from old.country_code)$old$;
  v_new := $new$(new.licence_number is distinct from old.licence_number or new.licence_expiry_date is distinct from old.licence_expiry_date or new.full_name is distinct from old.full_name or new.country_code is distinct from old.country_code)$new$;
  if position(v_old in v_def)=0 then
    raise exception 'Existing driver profile verification guard changed; aborting consolidation';
  end if;
  execute replace(v_def,v_old,v_new);
end;
$migration$;

drop trigger if exists trg_krim_guard_driver_profile_verification_updates on public.krim_driver_profiles;
drop function if exists public.krim_guard_driver_profile_verification_updates();
