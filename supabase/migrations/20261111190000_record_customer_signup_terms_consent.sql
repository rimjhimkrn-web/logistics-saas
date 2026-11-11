-- Persist required Terms and Privacy acceptance for customer registrations.
-- The auth.users trigger records consent atomically with customer profile creation.

begin;

alter table public.krim_user_consent_events
  drop constraint if exists krim_user_consent_events_consent_type_check;

alter table public.krim_user_consent_events
  add constraint krim_user_consent_events_consent_type_check
  check (consent_type = any (array[
    'marketing_email'::text,
    'product_analytics'::text,
    'personalization'::text,
    'terms_and_privacy'::text
  ]));

create or replace function public.handle_new_customer()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
begin
  insert into public.customer_profiles (
    id, full_name, company_name, phone
  )
  values (
    new.id,
    new.raw_user_meta_data->>'full_name',
    new.raw_user_meta_data->>'company_name',
    new.raw_user_meta_data->>'phone'
  );

  if coalesce(new.raw_user_meta_data->>'terms_accepted', 'false') = 'true' then
    insert into public.krim_user_consent_events (
      user_id, consent_type, granted, policy_version
    )
    values (
      new.id,
      'terms_and_privacy',
      true,
      coalesce(nullif(new.raw_user_meta_data->>'terms_version', ''), '2026-11-11')
    );
  end if;

  return new;
end;
$function$;

commit;
