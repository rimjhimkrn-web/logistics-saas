-- STAGING ONLY. Run with a trusted database owner connection against isolated
-- Supabase staging. Synthetic users and all fixture records are rolled back.
-- Never run against production.
\set ON_ERROR_STOP on
begin;

do $test$
declare
  v_user_a uuid := gen_random_uuid();
  v_user_b uuid := gen_random_uuid();
  v_org bigint;
  v_shipments bigint;
begin
  insert into auth.users(
    id,aud,role,email,encrypted_password,email_confirmed_at,
    raw_app_meta_data,raw_user_meta_data,created_at,updated_at
  ) values
    (v_user_a,'authenticated','authenticated',
     'krim-customer-a-'||replace(v_user_a::text,'-','')||'@example.invalid',
     '',now(),'{"provider":"email","providers":["email"]}'::jsonb,'{}'::jsonb,now(),now()),
    (v_user_b,'authenticated','authenticated',
     'krim-customer-b-'||replace(v_user_b::text,'-','')||'@example.invalid',
     '',now(),'{"provider":"email","providers":["email"]}'::jsonb,'{}'::jsonb,now(),now());

  perform set_config('request.jwt.claim.sub',v_user_a::text,true);
  v_org := public.krim_provision_customer_organization('KRIM Isolated Customer Tenant A');

  perform set_config('request.jwt.claim.sub',v_user_b::text,true);
  begin
    perform public.krim_create_global_shipment_from_places(
      v_org,
      '{"display_name":"Ranchi","city":"Ranchi","state":"Jharkhand","country_code":"IN","country":"India","latitude":23.3441,"longitude":85.3096}'::jsonb,
      '{"display_name":"Jamshedpur","city":"Jamshedpur","state":"Jharkhand","country_code":"IN","country":"India","latitude":22.8046,"longitude":86.2029}'::jsonb,
      'Synthetic tenant isolation test cargo',100,'road','domestic'
    );
    raise exception 'FAIL: tenant B created shipment under tenant A customer organization';
  exception when insufficient_privilege then
    -- Expected: organization access and shipment.create permission are absent.
    null;
  end;

  select count(*) into v_shipments
  from public.krim_shipments where customer_organization_id=v_org;
  if v_shipments<>0 then
    raise exception 'FAIL: foreign tenant shipment persisted (% rows)',v_shipments;
  end if;
end
$test$;

rollback;
