-- Isolated fixture test for the proposed resolver. Never connects to KRIM production.
create role anon nologin;
create role authenticated nologin;
create role service_role nologin;

create schema krim_internal;
create table public.krim_shipments (
  id bigint primary key,
  customer_organization_id bigint
);
create table public.krim_organizations (
  id bigint primary key,
  organization_type text not null,
  status text not null,
  timezone text,
  partner_lifecycle_status text,
  partner_verification_status text,
  partner_compliance_status text
);
create table public.krim_customer_identity_links (
  id bigint primary key,
  customer_profile_id bigint not null,
  organization_id bigint not null,
  user_id uuid not null,
  identity_status text not null,
  verified_at timestamptz
);
create table public.krim_customer_acquisition_profiles (
  id bigint primary key,
  organization_id bigint,
  language_code text,
  status text not null
);
create table public.krim_customer_workspace_profiles (
  id bigint primary key,
  customer_profile_id bigint not null,
  organization_id bigint,
  preferred_language_code text,
  preferred_timezone text,
  workspace_status text not null,
  account_status text not null
);
create table public.krim_organization_members (
  id bigint primary key,
  organization_id bigint not null,
  user_id uuid not null,
  role text not null,
  status text not null
);
create table public.krim_shipment_partner_assignments (
  id bigint primary key,
  shipment_id bigint not null,
  partner_organization_id bigint not null,
  status text not null
);

-- Function file is applied by the workflow after fixture schema setup.
insert into public.krim_shipments values (100,10);
insert into public.krim_organizations
  (id,organization_type,status,timezone,partner_lifecycle_status,partner_verification_status,partner_compliance_status)
values
  (10,'customer','active','Asia/Kolkata',null,null,null),
  (20,'carrier','active','Asia/Kolkata','active','verified','compliant');
insert into public.krim_customer_acquisition_profiles values (30,10,'en','active');
insert into public.krim_customer_identity_links values
  (40,30,10,'00000000-0000-0000-0000-000000000040','verified',now());
insert into public.krim_customer_workspace_profiles values
  (50,30,10,'en','Asia/Kolkata','active','active');
insert into public.krim_organization_members values
  (60,10,'00000000-0000-0000-0000-000000000040','owner','active'),
  (61,20,'00000000-0000-0000-0000-000000000061','dispatcher','active'),
  (62,20,'00000000-0000-0000-0000-000000000062','driver','active');
insert into public.krim_shipment_partner_assignments values
  (70,100,20,'accepted'),
  (71,100,20,'active');

do $$
declare c integer; p integer; d integer;
begin
  select count(*) into c from krim_internal.resolve_shipment_notification_recipients(100,'customer');
  if c <> 1 then raise exception 'customer expected 1 recipient, got %',c; end if;
  select count(*) into p from krim_internal.resolve_shipment_notification_recipients(100,'partner');
  if p <> 1 then raise exception 'partner expected 1 non-driver recipient despite duplicate assignments, got %',p; end if;
  select count(*) into d from krim_internal.resolve_shipment_notification_recipients(100,'partner') where member_role='driver';
  if d <> 0 then raise exception 'driver unexpectedly returned'; end if;
  if has_function_privilege('anon','krim_internal.resolve_shipment_notification_recipients(bigint,text)','EXECUTE') then
    raise exception 'anon unexpectedly has execute';
  end if;
  if has_function_privilege('authenticated','krim_internal.resolve_shipment_notification_recipients(bigint,text)','EXECUTE') then
    raise exception 'authenticated unexpectedly has execute';
  end if;
  if not has_function_privilege('service_role','krim_internal.resolve_shipment_notification_recipients(bigint,text)','EXECUTE') then
    raise exception 'service_role is missing execute';
  end if;
  begin
    perform * from krim_internal.resolve_shipment_notification_recipients(100,null);
    raise exception 'null recipient type should fail';
  exception when sqlstate '22023' then null;
  end;
  begin
    perform * from krim_internal.resolve_shipment_notification_recipients(999,'customer');
    raise exception 'unknown shipment should fail';
  exception when sqlstate 'P0002' then null;
  end;
end $$;
