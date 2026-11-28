-- STAGING ONLY. Run with a trusted database owner connection against isolated
-- Supabase staging. This test creates synthetic auth users and partner data inside
-- one transaction and rolls all of it back. Never run against production.
\set ON_ERROR_STOP on
begin;

do $test$
declare
  v_user_a uuid := gen_random_uuid();
  v_user_b uuid := gen_random_uuid();
  v_org bigint;
  v_vehicle_count bigint;
begin
  insert into auth.users(
    id,aud,role,email,encrypted_password,email_confirmed_at,
    raw_app_meta_data,raw_user_meta_data,created_at,updated_at
  ) values
    (v_user_a,'authenticated','authenticated',
     'krim-tenant-a-'||replace(v_user_a::text,'-','')||'@example.invalid',
     '',now(),'{"provider":"email","providers":["email"]}'::jsonb,'{}'::jsonb,now(),now()),
    (v_user_b,'authenticated','authenticated',
     'krim-tenant-b-'||replace(v_user_b::text,'-','')||'@example.invalid',
     '',now(),'{"provider":"email","providers":["email"]}'::jsonb,'{}'::jsonb,now(),now());

  perform set_config('request.jwt.claim.sub',v_user_a::text,true);
  v_org := public.krim_provision_partner_organization('KRIM Isolated Tenant A Test');

  perform set_config('request.jwt.claim.sub',v_user_b::text,true);
  begin
    perform public.krim_vehicle_register(
      v_org,'IN','Jharkhand','TEST-TENANT-B','truck','heavy_vehicle',
      'Test','Isolation',2024,1000,'kg','partner_owned',null
    );
    raise exception 'FAIL: tenant B registered a vehicle under tenant A organization';
  exception when insufficient_privilege then
    -- Expected: tenant B is not an active owner/manager of tenant A.
    null;
  end;

  select count(*) into v_vehicle_count
  from public.krim_vehicles where organization_id=v_org;
  if v_vehicle_count<>0 then
    raise exception 'FAIL: foreign tenant vehicle row persisted (% rows)',v_vehicle_count;
  end if;
end
$test$;

rollback;
