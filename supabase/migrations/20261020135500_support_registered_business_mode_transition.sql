create or replace function public.krim_set_partner_account_mode(
  p_mode text,
  p_profile jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
declare
  v_user_id uuid := auth.uid();
  v_org_id bigint;
  v_verification text;
  v_lifecycle text;
  v_profile jsonb := coalesce(p_profile, '{}'::jsonb);
  v_display_name text;
  v_country_code text;
  v_city text;
  v_service_category text;
  v_metadata_patch jsonb;
begin
  if v_user_id is null then
    raise exception using errcode = '28000', message = 'Authentication required';
  end if;
  if p_mode is null or p_mode not in ('development_test', 'individual_interest', 'registered_business') then
    raise exception using errcode = '22023', message = 'Unsupported account mode';
  end if;
  if jsonb_typeof(v_profile) <> 'object' then
    raise exception using errcode = '22023', message = 'Profile must be a JSON object';
  end if;

  select o.id,
         coalesce(o.partner_verification_status, 'not_started'),
         coalesce(o.partner_lifecycle_status, 'registered')
    into v_org_id, v_verification, v_lifecycle
  from public.krim_organization_members m
  join public.krim_organizations o on o.id = m.organization_id
  where m.user_id = v_user_id
    and m.status = 'active'
    and lower(coalesce(o.organization_type_code, o.organization_type)) in ('partner','carrier','warehouse','forwarder')
  order by m.created_at asc
  limit 1;

  if v_org_id is null then
    raise exception using errcode = '42501', message = 'An active partner organization is required';
  end if;
  if v_verification in ('verified','approved') or v_lifecycle in ('approved','active') then
    raise exception using errcode = '42501', message = 'An approved partner organization cannot be switched into a non-commercial mode';
  end if;

  if p_mode = 'individual_interest' then
    v_display_name := nullif(btrim(v_profile->>'display_name'), '');
    v_country_code := upper(nullif(btrim(v_profile->>'country_code'), ''));
    v_city := nullif(btrim(v_profile->>'city'), '');
    v_service_category := nullif(btrim(v_profile->>'service_category'), '');

    if v_display_name is null or char_length(v_display_name) < 2 or char_length(v_display_name) > 120 then
      raise exception using errcode = '22023', message = 'Enter your name (2–120 characters)';
    end if;
    if v_country_code is null or v_country_code !~ '^[A-Z]{2}$' then
      raise exception using errcode = '22023', message = 'Choose a valid two-letter country code';
    end if;
    if v_city is null or char_length(v_city) < 2 or char_length(v_city) > 120 then
      raise exception using errcode = '22023', message = 'Enter your operating city (2–120 characters)';
    end if;
    if v_service_category is null or v_service_category not in ('road_transport','freight_forwarding','warehouse','customs_support','other') then
      raise exception using errcode = '22023', message = 'Choose a supported independent-partner service category';
    end if;

    v_metadata_patch := jsonb_build_object(
      'account_mode', p_mode,
      'account_mode_updated_at', now(),
      'individual_profile', jsonb_build_object(
        'display_name', v_display_name,
        'country_code', v_country_code,
        'city', v_city,
        'service_category', v_service_category,
        'submitted_at', now(),
        'review_status', 'interest_recorded'
      )
    );
  elsif p_mode = 'development_test' then
    v_metadata_patch := jsonb_build_object(
      'account_mode', p_mode,
      'account_mode_updated_at', now(),
      'development_test', jsonb_build_object(
        'enabled', true,
        'commercial_access', false,
        'sample_data_only', true,
        'enabled_at', now()
      )
    );
  else
    v_metadata_patch := jsonb_build_object(
      'account_mode', p_mode,
      'account_mode_updated_at', now()
    );
  end if;

  update public.krim_organizations
  set partner_metadata = (coalesce(partner_metadata, '{}'::jsonb) - 'individual_profile' - 'development_test') || v_metadata_patch,
      updated_at = now()
  where id = v_org_id;

  insert into public.krim_audit_events (
    actor_user_id, organization_id, event_type, entity_type, entity_id, source, metadata, new_state
  ) values (
    v_user_id, v_org_id, 'partner.account_mode.selected', 'organization', v_org_id::text,
    'partner_onboarding',
    jsonb_build_object('account_mode', p_mode, 'commercial_access', false),
    jsonb_build_object('account_mode', p_mode, 'commercial_access', false)
  );

  return jsonb_build_object(
    'organization_id', v_org_id,
    'account_mode', p_mode,
    'commercial_access', false,
    'message', case
      when p_mode = 'development_test' then 'Development/test mode enabled. Live commercial operations remain locked.'
      when p_mode = 'individual_interest' then 'Independent partner interest saved. Identity and applicable operating requirements remain pending.'
      else 'Registered business pathway selected. Verification remains pending until genuine documents are submitted and reviewed.'
    end
  );
end;
$function$;

revoke all on function public.krim_set_partner_account_mode(text, jsonb) from public;
revoke all on function public.krim_set_partner_account_mode(text, jsonb) from anon;
grant execute on function public.krim_set_partner_account_mode(text, jsonb) to authenticated;