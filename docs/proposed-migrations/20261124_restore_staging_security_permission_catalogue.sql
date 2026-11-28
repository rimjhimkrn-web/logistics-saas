-- PROPOSED STAGING REPAIR ONLY. NOT APPLIED.
-- Source: read-only production reference snapshot, 2026-11-24.
-- Review against canonical role design before use. Never run on production.
-- Uses natural keys; no production IDs, users, or operational records copied.
begin;
create temporary table _krim_permission_seed (
 permission_code text, permission_name text, resource_type text, action text,
 description text, is_system_permission boolean
) on commit drop;
insert into _krim_permission_seed values
('admin.platform', 'Platform Administration', 'platform', 'admin', 'Manage KRIM platform-level administration', true),
('compliance.manage', 'Manage Compliance', 'compliance', 'manage', 'Manage compliance information', true),
('compliance.view', 'View Compliance', 'compliance', 'view', 'View compliance information', true),
('document.manage', 'Manage Documents', 'document', 'manage', 'Manage documents and document status', true),
('document.upload', 'Upload Documents', 'document', 'upload', 'Upload documents', true),
('document.view', 'View Documents', 'document', 'view', 'View shipment and organization documents', true),
('finance.manage', 'Manage Finance', 'finance', 'manage', 'Manage payments and financial transactions', true),
('finance.view', 'View Finance', 'finance', 'view', 'View financial information', true),
('organization.manage', 'Manage Organization', 'organization', 'manage', 'Manage organization settings and members', true),
('organization.view', 'View Organization', 'organization', 'view', 'View organization information', true),
('partner.manage', 'Manage Partners', 'partner', 'manage', 'Manage partner relationships', true),
('partner.view', 'View Partners', 'partner', 'view', 'View logistics partners', true),
('quote.create', 'Create Quotes', 'quote', 'create', 'Create quotations', true),
('quote.update', 'Update Quotes', 'quote', 'update', 'Update quotations', true),
('quote.view', 'View Quotes', 'quote', 'view', 'View shipment quotations', true),
('shipment.assign', 'Assign Shipments', 'shipment', 'assign', 'Assign shipments to operational partners', true),
('shipment.cancel', 'Cancel Shipments', 'shipment', 'cancel', 'Cancel shipments', true),
('shipment.create', 'Create Shipments', 'shipment', 'create', 'Create new shipments', true),
('shipment.dispatch', 'Dispatch Shipments', 'shipment', 'dispatch', 'Dispatch shipments for execution', true),
('shipment.update', 'Update Shipments', 'shipment', 'update', 'Update shipment information', true),
('shipment.view', 'View Shipments', 'shipment', 'view', 'View shipment information', true),
('tracking.update', 'Update Tracking', 'tracking', 'update', 'Create or update tracking events', true),
('tracking.view', 'View Tracking', 'tracking', 'view', 'View shipment tracking information', true);
create temporary table _krim_role_permission_seed (
 role_code text, permission_code text, granted boolean
) on commit drop;
insert into _krim_role_permission_seed values
('compliance_manager', 'compliance.manage', true),
('compliance_manager', 'compliance.view', true),
('compliance_manager', 'document.manage', true),
('compliance_manager', 'document.upload', true),
('compliance_manager', 'document.view', true),
('compliance_manager', 'organization.view', true),
('compliance_manager', 'shipment.view', true),
('compliance_manager', 'tracking.view', true),
('customer_user', 'document.upload', true),
('customer_user', 'document.view', true),
('customer_user', 'finance.view', true),
('customer_user', 'organization.view', true),
('customer_user', 'quote.create', true),
('customer_user', 'quote.view', true),
('customer_user', 'shipment.create', true),
('customer_user', 'shipment.update', true),
('customer_user', 'shipment.view', true),
('customer_user', 'tracking.view', true),
('dispatcher', 'document.upload', true),
('dispatcher', 'document.view', true),
('dispatcher', 'partner.view', true),
('dispatcher', 'shipment.assign', true),
('dispatcher', 'shipment.dispatch', true),
('dispatcher', 'shipment.update', true),
('dispatcher', 'shipment.view', true),
('dispatcher', 'tracking.update', true),
('dispatcher', 'tracking.view', true),
('finance_manager', 'document.manage', true),
('finance_manager', 'document.view', true),
('finance_manager', 'finance.manage', true),
('finance_manager', 'finance.view', true),
('finance_manager', 'organization.view', true),
('finance_manager', 'quote.view', true),
('finance_manager', 'shipment.view', true),
('operations_manager', 'document.upload', true),
('operations_manager', 'document.view', true),
('operations_manager', 'partner.manage', true),
('operations_manager', 'partner.view', true),
('operations_manager', 'quote.create', true),
('operations_manager', 'quote.update', true),
('operations_manager', 'quote.view', true),
('operations_manager', 'shipment.assign', true),
('operations_manager', 'shipment.cancel', true),
('operations_manager', 'shipment.create', true),
('operations_manager', 'shipment.dispatch', true),
('operations_manager', 'shipment.update', true),
('operations_manager', 'shipment.view', true),
('operations_manager', 'tracking.update', true),
('operations_manager', 'tracking.view', true),
('organization_admin', 'compliance.manage', true),
('organization_admin', 'compliance.view', true),
('organization_admin', 'document.manage', true),
('organization_admin', 'document.upload', true),
('organization_admin', 'document.view', true),
('organization_admin', 'finance.view', true),
('organization_admin', 'organization.manage', true),
('organization_admin', 'organization.view', true),
('organization_admin', 'partner.manage', true),
('organization_admin', 'partner.view', true),
('organization_admin', 'quote.create', true),
('organization_admin', 'quote.update', true),
('organization_admin', 'quote.view', true),
('organization_admin', 'shipment.assign', true),
('organization_admin', 'shipment.cancel', true),
('organization_admin', 'shipment.create', true),
('organization_admin', 'shipment.dispatch', true),
('organization_admin', 'shipment.update', true),
('organization_admin', 'shipment.view', true),
('organization_admin', 'tracking.update', true),
('organization_admin', 'tracking.view', true),
('organization_owner', 'compliance.manage', true),
('organization_owner', 'compliance.view', true),
('organization_owner', 'document.manage', true),
('organization_owner', 'document.upload', true),
('organization_owner', 'document.view', true),
('organization_owner', 'finance.manage', true),
('organization_owner', 'finance.view', true),
('organization_owner', 'organization.manage', true),
('organization_owner', 'organization.view', true),
('organization_owner', 'partner.manage', true),
('organization_owner', 'partner.view', true),
('organization_owner', 'quote.create', true),
('organization_owner', 'quote.update', true),
('organization_owner', 'quote.view', true),
('organization_owner', 'shipment.assign', true),
('organization_owner', 'shipment.cancel', true),
('organization_owner', 'shipment.create', true),
('organization_owner', 'shipment.dispatch', true),
('organization_owner', 'shipment.update', true),
('organization_owner', 'shipment.view', true),
('organization_owner', 'tracking.update', true),
('organization_owner', 'tracking.view', true),
('partner_user', 'document.upload', true),
('partner_user', 'document.view', true),
('partner_user', 'organization.view', true),
('partner_user', 'partner.view', true),
('partner_user', 'quote.create', true),
('partner_user', 'shipment.assign', true),
('partner_user', 'shipment.dispatch', true),
('partner_user', 'shipment.update', true),
('partner_user', 'shipment.view', true),
('partner_user', 'tracking.update', true),
('partner_user', 'tracking.view', true),
('platform_admin', 'compliance.manage', true),
('platform_admin', 'compliance.view', true),
('platform_admin', 'document.manage', true),
('platform_admin', 'document.upload', true),
('platform_admin', 'document.view', true),
('platform_admin', 'finance.manage', true),
('platform_admin', 'finance.view', true),
('platform_admin', 'organization.manage', true),
('platform_admin', 'organization.view', true),
('platform_admin', 'partner.manage', true),
('platform_admin', 'partner.view', true),
('platform_admin', 'quote.create', true),
('platform_admin', 'quote.update', true),
('platform_admin', 'quote.view', true),
('platform_admin', 'shipment.assign', true),
('platform_admin', 'shipment.cancel', true),
('platform_admin', 'shipment.create', true),
('platform_admin', 'shipment.dispatch', true),
('platform_admin', 'shipment.update', true),
('platform_admin', 'shipment.view', true),
('platform_admin', 'tracking.update', true),
('platform_admin', 'tracking.view', true),
('platform_superadmin', 'admin.platform', true),
('platform_superadmin', 'compliance.manage', true),
('platform_superadmin', 'compliance.view', true),
('platform_superadmin', 'document.manage', true),
('platform_superadmin', 'document.upload', true),
('platform_superadmin', 'document.view', true),
('platform_superadmin', 'finance.manage', true),
('platform_superadmin', 'finance.view', true),
('platform_superadmin', 'organization.manage', true),
('platform_superadmin', 'organization.view', true),
('platform_superadmin', 'partner.manage', true),
('platform_superadmin', 'partner.view', true),
('platform_superadmin', 'quote.create', true),
('platform_superadmin', 'quote.update', true),
('platform_superadmin', 'quote.view', true),
('platform_superadmin', 'shipment.assign', true),
('platform_superadmin', 'shipment.cancel', true),
('platform_superadmin', 'shipment.create', true),
('platform_superadmin', 'shipment.dispatch', true),
('platform_superadmin', 'shipment.update', true),
('platform_superadmin', 'shipment.view', true),
('platform_superadmin', 'tracking.update', true),
('platform_superadmin', 'tracking.view', true),
('viewer', 'compliance.view', true),
('viewer', 'document.view', true),
('viewer', 'organization.view', true),
('viewer', 'partner.view', true),
('viewer', 'quote.view', true),
('viewer', 'shipment.view', true),
('viewer', 'tracking.view', true);
do $$
begin
 if (select count(*) from _krim_permission_seed) <> 23 then raise exception 'Expected 23 permissions'; end if;
 if (select count(*) from _krim_role_permission_seed) <> 155 then raise exception 'Expected 155 mappings'; end if;
 if exists (select 1 from _krim_role_permission_seed s left join public.krim_security_roles r on r.role_code=s.role_code where r.id is null) then
   raise exception 'Missing staging role_code; reconcile role catalogue first';
 end if;
 if exists (select 1 from public.krim_security_permissions p join _krim_permission_seed s using(permission_code)
   where (p.permission_name,p.resource_type,p.action,p.description,p.is_system_permission)
   is distinct from (s.permission_name,s.resource_type,s.action,s.description,s.is_system_permission)) then
   raise exception 'Existing permission differs; manual review required';
 end if;
 if exists (select 1 from _krim_role_permission_seed s
   join public.krim_security_roles r on r.role_code=s.role_code
   join public.krim_security_permissions p on p.permission_code=s.permission_code
   join public.krim_role_permissions rp on rp.role_id=r.id and rp.permission_id=p.id
   where rp.granted is distinct from s.granted) then
   raise exception 'Existing role grant differs; manual review required';
 end if;
end $$;
insert into public.krim_security_permissions
(permission_code,permission_name,resource_type,action,description,is_system_permission)
select permission_code,permission_name,resource_type,action,description,is_system_permission
from _krim_permission_seed on conflict(permission_code) do nothing;
insert into public.krim_role_permissions(role_id,permission_id,granted)
select r.id,p.id,s.granted from _krim_role_permission_seed s
join public.krim_security_roles r on r.role_code=s.role_code
join public.krim_security_permissions p on p.permission_code=s.permission_code
on conflict(role_id,permission_id) do nothing;
do $$
begin
 if (select count(*) from _krim_permission_seed s join public.krim_security_permissions p using(permission_code)) <> 23 then
   raise exception 'Postcondition failed: permission definitions';
 end if;
 if (select count(*) from _krim_role_permission_seed s join public.krim_security_roles r on r.role_code=s.role_code
   join public.krim_security_permissions p on p.permission_code=s.permission_code
   join public.krim_role_permissions rp on rp.role_id=r.id and rp.permission_id=p.id where rp.granted=s.granted) <> 155 then
   raise exception 'Postcondition failed: role mappings';
 end if;
end $$;
commit;
