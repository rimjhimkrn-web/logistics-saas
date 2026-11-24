-- Isolated fixture test for the proposed resolver. Never connects to KRIM production.
create role anon nologin;
create role authenticated nologin;
create role service_role nologin;

create schema krim_internal;
grant usage on schema krim_internal to service_role;
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


-- Negative-path fixtures: inactive/suspended members and cancelled assignments.
insert into public.krim_shipments values (101,10);
insert into public.krim_customer_acquisition_profiles values
  (31,10,'en','active'),
  (32,10,'en','active');
insert into public.krim_customer_identity_links values
  (41,31,10,'00000000-0000-0000-0000-000000000065','verified',now()),
  (42,32,10,'00000000-0000-0000-0000-000000000063','verified',now());
insert into public.krim_customer_workspace_profiles values
  (51,31,10,'en','Asia/Kolkata','active','active'),
  (52,32,10,'en','Asia/Kolkata','active','active');
insert into public.krim_organization_members values
  (63,10,'00000000-0000-0000-0000-000000000063','finance','suspended'),
  (64,20,'00000000-0000-0000-0000-000000000064','manager','suspended'),
  (65,10,'00000000-0000-0000-0000-000000000065','finance','active'),
  (66,20,'00000000-0000-0000-0000-000000000066','finance','active'),
  (67,20,'00000000-0000-0000-0000-000000000067','member','active');
insert into public.krim_shipment_partner_assignments values
  (72,101,20,'cancelled');
