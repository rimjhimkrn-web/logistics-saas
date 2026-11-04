-- Include the server-side warehouse capability gate in the private administrator queue.
create or replace function public.krim_admin_list_warehouse_facilities()
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid();v_items jsonb;
begin
 if v_user is null then raise exception 'Authentication required' using errcode='28000';end if;
 if coalesce(auth.jwt()->>'aal','')<>'aal2' then raise exception 'AAL2 MFA is required' using errcode='42501';end if;
 if not private.krim_has_permission(v_user,1,'admin.platform') then raise exception 'Platform administrator permission required' using errcode='42501';end if;
 select coalesce(jsonb_agg(jsonb_build_object('facility_id',f.id,'organization_id',f.organization_id,'organization_name',o.legal_name,
 'organization_type',o.organization_type,'organization_type_code',o.organization_type_code,'organization_status',o.status,
 'warehouse_capability_verified',private.krim_warehouse_org_eligible(o.id),
 'partner_account_mode',o.partner_account_mode,'partner_verification_status',o.partner_verification_status,
 'partner_lifecycle_status',o.partner_lifecycle_status,'partner_compliance_status',o.partner_compliance_status,
 'facility_code',f.facility_code,'facility_name',f.facility_name,'country_code',f.country_code,'address_text',f.address_text,
 'timezone',f.timezone,'status',f.status,'review_status',f.review_status,'metadata',f.metadata,'created_at',f.created_at)
 order by f.created_at),'[]'::jsonb) into v_items from public.krim_warehouse_facilities f join public.krim_organizations o on o.id=f.organization_id where f.review_status='pending_review';
 return jsonb_build_object('items',v_items);
end;$$;