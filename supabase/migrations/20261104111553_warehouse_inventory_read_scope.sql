-- Scope all warehouse inventory, movement and receipt reads to verified businesses
-- operating administrator-approved facilities. Write paths remain RPC-only.
drop policy if exists krim_wh_inventory_org_member on public.krim_warehouse_inventory;
create policy krim_wh_inventory_verified_member_read on public.krim_warehouse_inventory for select to authenticated using (
 exists(select 1 from public.krim_organization_members m join public.krim_organizations o on o.id=m.organization_id join public.krim_warehouse_facilities f on f.id=krim_warehouse_inventory.facility_id and f.organization_id=o.id
 where m.organization_id=krim_warehouse_inventory.organization_id and m.user_id=(select auth.uid()) and m.status='active' and o.status='active' and o.partner_account_mode='registered_business'
 and o.partner_verification_status in ('verified','approved') and o.partner_lifecycle_status in ('active','verified') and o.partner_compliance_status in ('clear','compliant','approved','verified','not_required','not_applicable')
 and (o.organization_type ilike '%warehouse%' or o.organization_type_code ilike '%warehouse%' or o.organization_type ilike '%fulfilment%' or o.organization_type_code ilike '%fulfilment%' or o.organization_type ilike '%fulfillment%' or o.organization_type_code ilike '%fulfillment%')
 and f.status='active' and f.review_status='approved'));
drop policy if exists krim_wh_movements_select_member on public.krim_warehouse_inventory_movements;
create policy krim_wh_movements_verified_member_read on public.krim_warehouse_inventory_movements for select to authenticated using (
 exists(select 1 from public.krim_organization_members m join public.krim_organizations o on o.id=m.organization_id join public.krim_warehouse_facilities f on f.id=krim_warehouse_inventory_movements.facility_id and f.organization_id=o.id
 where m.organization_id=krim_warehouse_inventory_movements.organization_id and m.user_id=(select auth.uid()) and m.status='active' and o.status='active' and o.partner_account_mode='registered_business'
 and o.partner_verification_status in ('verified','approved') and o.partner_lifecycle_status in ('active','verified') and o.partner_compliance_status in ('clear','compliant','approved','verified','not_required','not_applicable')
 and f.status='active' and f.review_status='approved'));
drop policy if exists krim_wh_receipts_org_member on public.krim_warehouse_receipts;
create policy krim_wh_receipts_verified_member_read on public.krim_warehouse_receipts for select to authenticated using (
 exists(select 1 from public.krim_organization_members m join public.krim_organizations o on o.id=m.organization_id join public.krim_warehouse_facilities f on f.id=krim_warehouse_receipts.facility_id and f.organization_id=o.id
 where m.organization_id=krim_warehouse_receipts.organization_id and m.user_id=(select auth.uid()) and m.status='active' and o.status='active' and o.partner_account_mode='registered_business'
 and o.partner_verification_status in ('verified','approved') and o.partner_lifecycle_status in ('active','verified') and o.partner_compliance_status in ('clear','compliant','approved','verified','not_required','not_applicable')
 and f.status='active' and f.review_status='approved'));