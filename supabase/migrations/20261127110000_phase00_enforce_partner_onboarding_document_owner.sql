-- Enforce ownership again at the organization metadata persistence boundary.
-- The onboarding RPC runs SECURITY DEFINER; this trigger independently binds
-- every submitted registration/insurance object to the authenticated caller.
create or replace function private.krim_assert_partner_onboarding_document_ownership()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_user_id uuid := auth.uid();
  v_paths jsonb;
  v_path text;
begin
  if new.partner_onboarding_status is distinct from 'submitted' then
    return new;
  end if;

  v_paths := new.partner_metadata -> 'document_paths';
  if v_paths is null or jsonb_typeof(v_paths) <> 'array'
     or jsonb_array_length(v_paths) < 1 or jsonb_array_length(v_paths) > 2 then
    raise exception using errcode = '22023',
      message = 'Submitted partner documents are missing or invalid';
  end if;

  if v_user_id is null then
    raise exception using errcode = '28000',
      message = 'Authenticated document ownership is required';
  end if;

  for v_path in select jsonb_array_elements_text(v_paths)
  loop
    if not exists (
      select 1
      from storage.objects so
      where so.bucket_id = 'krim-partner-verification'
        and so.name = v_path
        and so.owner = v_user_id
    ) then
      raise exception using errcode = '42501',
        message = 'Every submitted partner document must be owned by the authenticated submitter';
    end if;
  end loop;

  return new;
end;
$function$;

drop trigger if exists trg_krim_partner_onboarding_document_owner
  on public.krim_organizations;

create trigger trg_krim_partner_onboarding_document_owner
before update of partner_metadata, partner_onboarding_status
on public.krim_organizations
for each row
when (new.partner_onboarding_status = 'submitted')
execute function private.krim_assert_partner_onboarding_document_ownership();

revoke all on function private.krim_assert_partner_onboarding_document_ownership() from public, anon, authenticated;
