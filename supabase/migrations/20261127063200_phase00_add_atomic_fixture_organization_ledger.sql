-- Atomic, server-only ledger and organisation provisioning for Phase 00 fixtures.
create table if not exists private.krim_phase00_fixture_organizations (
  run_id uuid not null,
  fixture_role text not null check (fixture_role in ('customer_a','customer_b','partner_a','partner_b')),
  user_id uuid not null references auth.users(id) on delete cascade,
  organization_id bigint not null references public.krim_organizations(id) on delete cascade,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  primary key (run_id, fixture_role),
  unique (run_id, user_id),
  unique (organization_id)
);
alter table private.krim_phase00_fixture_organizations enable row level security;
revoke all on table private.krim_phase00_fixture_organizations from public, anon, authenticated, service_role;

create or replace function public.krim_phase00_provision_fixture_organization(
  p_run_id uuid,
  p_fixture_role text,
  p_user_id uuid,
  p_actor_user_id uuid
)
returns bigint
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_role_id bigint;
  v_org_id bigint;
  v_existing private.krim_phase00_fixture_organizations%rowtype;
  v_user auth.users%rowtype;
  v_is_partner boolean;
  v_legal_name text;
begin
  if coalesce(auth.role(), '') <> 'service_role' then
    raise exception using errcode='42501', message='Service role required';
  end if;
  if p_run_id is null or p_user_id is null or p_actor_user_id is null
     or p_fixture_role not in ('customer_a','customer_b','partner_a','partner_b') then
    raise exception using errcode='22023', message='Invalid fixture provisioning input';
  end if;

  select id into v_role_id
  from public.krim_security_roles
  where role_code='platform_superadmin';
  if v_role_id is null or not exists (
    select 1 from public.krim_user_role_assignments
    where user_id=p_actor_user_id and role_id=v_role_id and is_active=true
  ) then
    raise exception using errcode='42501', message='Designated owner authorization required';
  end if;

  select * into v_user from auth.users where id=p_user_id;
  if not found or v_user.email_confirmed_at is null
     or v_user.raw_app_meta_data->>'krim_phase00_fixture' <> 'true'
     or v_user.raw_app_meta_data->>'krim_fixture_run_id' <> p_run_id::text
     or v_user.raw_app_meta_data->>'krim_fixture_role' <> p_fixture_role then
    raise exception using errcode='42501', message='Confirmed fixture identity does not match this run';
  end if;

  perform pg_catalog.set_config('request.jwt.claim.sub', p_actor_user_id::text, true);
  perform pg_catalog.set_config('request.jwt.claim.role', 'authenticated', true);

  select * into v_existing
  from private.krim_phase00_fixture_organizations
  where run_id=p_run_id and fixture_role=p_fixture_role;
  if found then
    if v_existing.user_id <> p_user_id or v_existing.created_by <> p_actor_user_id then
      raise exception using errcode='23505', message='Fixture ledger identity conflict';
    end if;
    return v_existing.organization_id;
  end if;

  v_is_partner := p_fixture_role like 'partner_%';
  v_legal_name := 'KRIM TEST ONLY | ' || upper(replace(p_fixture_role, '_', ' ')) || ' | ' || p_run_id::text;

  insert into public.krim_organizations (
    organization_type, organization_type_code, legal_name, display_name, status,
    partner_account_mode, partner_lifecycle_status, partner_verification_status,
    partner_compliance_status, partner_onboarding_status, partner_metadata
  ) values (
    case when v_is_partner then 'partner' else 'customer' end,
    case when v_is_partner then 'partner' else 'customer' end,
    v_legal_name,
    'KRIM TEST ONLY — ' || upper(replace(p_fixture_role, '_', ' ')),
    'active',
    case when v_is_partner then 'development_test' else null end,
    case when v_is_partner then 'registered' else 'not_applicable' end,
    'not_started',
    'not_started',
    'not_started',
    case when v_is_partner then pg_catalog.jsonb_build_object(
      'krim_phase00_fixture', true, 'krim_fixture_run_id', p_run_id::text, 'krim_fixture_role', p_fixture_role
    ) else '{}'::jsonb end
  ) returning id into v_org_id;

  insert into public.krim_organization_members (organization_id,user_id,role,status)
  values (v_org_id,p_user_id,'owner','active');

  insert into private.krim_phase00_fixture_organizations(run_id,fixture_role,user_id,organization_id,created_by)
  values (p_run_id,p_fixture_role,p_user_id,v_org_id,p_actor_user_id);

  return v_org_id;
end;
$function$;

revoke all on function public.krim_phase00_provision_fixture_organization(uuid,text,uuid,uuid) from public, anon, authenticated;
grant execute on function public.krim_phase00_provision_fixture_organization(uuid,text,uuid,uuid) to service_role;
