-- Warehouse operations oversight. Applied to project ebltviniygljwwseplph as 20261104111804.
create or replace function public.krim_admin_list_warehouse_operations()
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid();v_tasks jsonb;v_evidence jsonb;
begin
 if v_user is null then raise exception 'Authentication required' using errcode='28000';end if;
 if coalesce(auth.jwt()->>'aal','')<>'aal2' then raise exception 'AAL2 MFA is required' using errcode='42501';end if;
 if not private.krim_has_permission(v_user,1,'admin.platform') then raise exception 'Platform administrator permission required' using errcode='42501';end if;
 select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc),'[]'::jsonb) into v_tasks from (
 select t.id,t.organization_id,o.legal_name organization_name,o.partner_account_mode,o.partner_verification_status,o.partner_compliance_status,t.facility_id,f.facility_code,f.facility_name,t.task_type,t.reference_code,t.sku,t.lot_code,t.quantity,t.unit_code,t.quality_status,t.severity,t.status,t.notes,t.created_at,t.updated_at,t.completed_at from public.krim_warehouse_tasks t join public.krim_organizations o on o.id=t.organization_id join public.krim_warehouse_facilities f on f.id=t.facility_id order by t.created_at desc limit 300) x;
 select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc),'[]'::jsonb) into v_evidence from (
 select e.id,e.task_id,e.organization_id,o.legal_name organization_name,e.facility_id,f.facility_code,e.evidence_type,e.storage_path,e.description,e.captured_at,e.created_at,t.reference_code,t.task_type from public.krim_warehouse_evidence e join public.krim_organizations o on o.id=e.organization_id join public.krim_warehouse_facilities f on f.id=e.facility_id join public.krim_warehouse_tasks t on t.id=e.task_id order by e.created_at desc limit 300) x;
 return jsonb_build_object('tasks',v_tasks,'evidence',v_evidence,'generated_at',now());
end;$$;
revoke all on function public.krim_admin_list_warehouse_operations() from public,anon,authenticated;
grant execute on function public.krim_admin_list_warehouse_operations() to authenticated;
drop policy if exists krim_wh_evidence_read on storage.objects;
create policy krim_wh_evidence_read on storage.objects for select to authenticated using (
 bucket_id='krim-warehouse-evidence' and (
 case when (storage.foldername(name))[1] ~ '^[0-9]+$' then exists(select 1 from public.krim_organizations o join public.krim_organization_members m on m.organization_id=o.id where o.id=((storage.foldername(name))[1])::bigint and m.user_id=(select auth.uid()) and m.status='active' and o.status='active' and o.partner_account_mode='registered_business' and o.partner_verification_status in ('verified','approved') and o.partner_lifecycle_status in ('active','verified') and o.partner_compliance_status in ('clear','compliant','approved','verified','not_required','not_applicable') and (o.organization_type ilike '%warehouse%' or o.organization_type_code ilike '%warehouse%' or o.organization_type ilike '%fulfilment%' or o.organization_type_code ilike '%fulfilment%' or o.organization_type ilike '%fulfillment%' or o.organization_type_code ilike '%fulfillment%') and private.krim_has_permission((select auth.uid()),o.id,'partner.manage')) else false end
 or (coalesce(auth.jwt()->>'aal','')='aal2' and private.krim_has_permission((select auth.uid()),1,'admin.platform'))
 ));