-- Recognize a partner's independently approved WAREHOUSE service capability,
-- not only a dedicated warehouse organisation_type. This supports multi-service partners.
create or replace function private.krim_warehouse_org_eligible(p_organization_id bigint)
returns boolean language sql stable security definer set search_path=''
as $$
 select exists(select 1 from public.krim_organizations o where o.id=p_organization_id and o.status='active'
 and o.partner_account_mode='registered_business' and o.partner_verification_status in ('verified','approved')
 and o.partner_lifecycle_status in ('active','verified') and o.partner_compliance_status in ('clear','compliant','approved','verified','not_required','not_applicable')
 and (o.organization_type ilike '%warehouse%' or o.organization_type_code ilike '%warehouse%'
  or o.organization_type ilike '%fulfilment%' or o.organization_type_code ilike '%fulfilment%'
  or o.organization_type ilike '%fulfillment%' or o.organization_type_code ilike '%fulfillment%'
  or exists(select 1 from public.krim_partner_capabilities c join public.krim_transport_modes tm on tm.id=c.transport_mode_id
   where c.organization_id=o.id and c.active=true and c.verification_status='verified' and c.service_type='warehouse' and tm.code='WAREHOUSE' and tm.is_active=true)));
$$;
revoke all on function private.krim_warehouse_org_eligible(bigint) from public,anon,authenticated;
grant execute on function private.krim_warehouse_org_eligible(bigint) to authenticated;
create or replace function private.krim_warehouse_is_operator(p_user_id uuid,p_organization_id bigint,p_facility_id uuid)
returns boolean language sql stable security definer set search_path=''
as $$
 select exists(select 1 from public.krim_organization_members m join public.krim_warehouse_facilities f on f.organization_id=m.organization_id
 where m.organization_id=p_organization_id and m.user_id=p_user_id and m.status='active'
 and f.id=p_facility_id and f.status='active' and f.review_status='approved'
 and private.krim_warehouse_org_eligible(m.organization_id)
 and private.krim_has_permission(p_user_id,p_organization_id,'partner.manage'));
$$;
revoke all on function private.krim_warehouse_is_operator(uuid,bigint,uuid) from public,anon,authenticated;
drop policy if exists krim_wh_facilities_org_member_select on public.krim_warehouse_facilities;
create policy krim_wh_facilities_org_member_select on public.krim_warehouse_facilities for select to authenticated using (
 exists(select 1 from public.krim_organization_members m where m.organization_id=krim_warehouse_facilities.organization_id and m.user_id=(select auth.uid()) and m.status='active' and private.krim_warehouse_org_eligible(m.organization_id)));
drop policy if exists krim_wh_inventory_verified_member_read on public.krim_warehouse_inventory;
create policy krim_wh_inventory_verified_member_read on public.krim_warehouse_inventory for select to authenticated using (
 exists(select 1 from public.krim_organization_members m join public.krim_warehouse_facilities f on f.organization_id=m.organization_id where m.organization_id=krim_warehouse_inventory.organization_id and m.user_id=(select auth.uid()) and m.status='active' and f.id=krim_warehouse_inventory.facility_id and f.status='active' and f.review_status='approved' and private.krim_warehouse_org_eligible(m.organization_id)));
drop policy if exists krim_wh_movements_verified_member_read on public.krim_warehouse_inventory_movements;
create policy krim_wh_movements_verified_member_read on public.krim_warehouse_inventory_movements for select to authenticated using (
 exists(select 1 from public.krim_organization_members m join public.krim_warehouse_facilities f on f.organization_id=m.organization_id where m.organization_id=krim_warehouse_inventory_movements.organization_id and m.user_id=(select auth.uid()) and m.status='active' and f.id=krim_warehouse_inventory_movements.facility_id and f.status='active' and f.review_status='approved' and private.krim_warehouse_org_eligible(m.organization_id)));
drop policy if exists krim_wh_receipts_verified_member_read on public.krim_warehouse_receipts;
create policy krim_wh_receipts_verified_member_read on public.krim_warehouse_receipts for select to authenticated using (
 exists(select 1 from public.krim_organization_members m join public.krim_warehouse_facilities f on f.organization_id=m.organization_id where m.organization_id=krim_warehouse_receipts.organization_id and m.user_id=(select auth.uid()) and m.status='active' and f.id=krim_warehouse_receipts.facility_id and f.status='active' and f.review_status='approved' and private.krim_warehouse_org_eligible(m.organization_id)));
drop policy if exists krim_wh_tasks_member_read on public.krim_warehouse_tasks;
create policy krim_wh_tasks_member_read on public.krim_warehouse_tasks for select to authenticated using (
 exists(select 1 from public.krim_organization_members m join public.krim_warehouse_facilities f on f.organization_id=m.organization_id where m.organization_id=krim_warehouse_tasks.organization_id and m.user_id=(select auth.uid()) and m.status='active' and f.id=krim_warehouse_tasks.facility_id and f.status='active' and f.review_status='approved' and private.krim_warehouse_org_eligible(m.organization_id)));
drop policy if exists krim_wh_task_events_member_read on public.krim_warehouse_task_events;
create policy krim_wh_task_events_member_read on public.krim_warehouse_task_events for select to authenticated using (
 exists(select 1 from public.krim_organization_members m join public.krim_warehouse_facilities f on f.organization_id=m.organization_id where m.organization_id=krim_warehouse_task_events.organization_id and m.user_id=(select auth.uid()) and m.status='active' and f.id=krim_warehouse_task_events.facility_id and f.status='active' and f.review_status='approved' and private.krim_warehouse_org_eligible(m.organization_id)));
drop policy if exists krim_wh_evidence_member_read on public.krim_warehouse_evidence;
create policy krim_wh_evidence_member_read on public.krim_warehouse_evidence for select to authenticated using (
 exists(select 1 from public.krim_organization_members m join public.krim_warehouse_facilities f on f.organization_id=m.organization_id where m.organization_id=krim_warehouse_evidence.organization_id and m.user_id=(select auth.uid()) and m.status='active' and f.id=krim_warehouse_evidence.facility_id and f.status='active' and f.review_status='approved' and private.krim_warehouse_org_eligible(m.organization_id)));
drop policy if exists krim_wh_evidence_upload on storage.objects;
create policy krim_wh_evidence_upload on storage.objects for insert to authenticated with check (
 bucket_id='krim-warehouse-evidence' and (storage.foldername(name))[2]=(select auth.uid())::text and case when (storage.foldername(name))[1] ~ '^[0-9]+$' then private.krim_warehouse_org_eligible(((storage.foldername(name))[1])::bigint) and private.krim_has_permission((select auth.uid()),((storage.foldername(name))[1])::bigint,'partner.manage') and exists(select 1 from public.krim_organization_members m where m.organization_id=((storage.foldername(name))[1])::bigint and m.user_id=(select auth.uid()) and m.status='active') else false end);
drop policy if exists krim_wh_evidence_read on storage.objects;
create policy krim_wh_evidence_read on storage.objects for select to authenticated using (
 bucket_id='krim-warehouse-evidence' and (case when (storage.foldername(name))[1] ~ '^[0-9]+$' then private.krim_warehouse_org_eligible(((storage.foldername(name))[1])::bigint) and private.krim_has_permission((select auth.uid()),((storage.foldername(name))[1])::bigint,'partner.manage') and exists(select 1 from public.krim_organization_members m where m.organization_id=((storage.foldername(name))[1])::bigint and m.user_id=(select auth.uid()) and m.status='active') else false end or (coalesce(auth.jwt()->>'aal','')='aal2' and private.krim_has_permission((select auth.uid()),1,'admin.platform')));
