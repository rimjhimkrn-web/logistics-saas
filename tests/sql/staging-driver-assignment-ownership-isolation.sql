-- STAGING ONLY. Run with a trusted database-owner connection against isolated
-- Supabase staging. All synthetic users, organization and assignment are rolled back.
-- Never run against production.
\set ON_ERROR_STOP on
begin;

do $test$
declare
  v_user_a uuid := gen_random_uuid();
  v_user_b uuid := gen_random_uuid();
  v_org bigint;
  v_assignment uuid := gen_random_uuid();
  v_status text;
begin
  insert into auth.users(
    id,aud,role,email,encrypted_password,email_confirmed_at,
    raw_app_meta_data,raw_user_meta_data,created_at,updated_at
  ) values
    (v_user_a,'authenticated','authenticated',
     'krim-driver-a-'||replace(v_user_a::text,'-','')||'@example.invalid',
     '',now(),'{"provider":"email","providers":["email"]}'::jsonb,'{}'::jsonb,now(),now()),
    (v_user_b,'authenticated','authenticated',
     'krim-driver-b-'||replace(v_user_b::text,'-','')||'@example.invalid',
     '',now(),'{"provider":"email","providers":["email"]}'::jsonb,'{}'::jsonb,now(),now());

  perform set_config('request.jwt.claim.sub',v_user_a::text,true);
  v_org := public.krim_provision_partner_organization('KRIM Isolated Driver Tenant A');

  update public.krim_organization_members
  set role='driver',status='active'
  where organization_id=v_org and user_id=v_user_a;
  if not found then raise exception 'FAIL: provisioned driver membership missing'; end if;

  insert into public.krim_driver_assignments(
    id,user_id,organization_id,status,created_by
  ) values(v_assignment,v_user_a,v_org,'assigned',v_user_a);

  perform set_config('request.jwt.claim.sub',v_user_b::text,true);
  begin
    perform public.krim_driver_accept_assignment(v_assignment);
    raise exception 'FAIL: tenant B accepted tenant A driver assignment';
  exception when insufficient_privilege then
    -- Expected: the assignment is not owned by the authenticated driver.
    null;
  end;

  select status into v_status
  from public.krim_driver_assignments where id=v_assignment;
  if v_status is distinct from 'assigned' then
    raise exception 'FAIL: foreign assignment state changed (%).',v_status;
  end if;
end
$test$;

rollback;
