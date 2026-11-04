-- Require partner.manage for every inventory stock mutation and pin the function search_path.
do $patch$
declare v_def text;v_old text;v_new text;
begin
 select pg_get_functiondef('public.krim_warehouse_record_movement(bigint,uuid,text,numeric,text,uuid,text,text,text,text,text,text,text,text)'::regprocedure) into v_def;
 v_old:='if v_org_type is null or not exists(select 1 from public.krim_organizations o where o.id=p_organization_id and o.partner_account_mode=''registered_business'' and o.partner_verification_status in (''verified'',''approved'') and o.partner_lifecycle_status in (''active'',''verified'') and o.partner_compliance_status in (''clear'',''compliant'',''approved'',''verified'',''not_required'',''not_applicable'')) then';
 v_new:='if v_org_type is null or not exists(select 1 from public.krim_organizations o where o.id=p_organization_id and o.partner_account_mode=''registered_business'' and o.partner_verification_status in (''verified'',''approved'') and o.partner_lifecycle_status in (''active'',''verified'') and o.partner_compliance_status in (''clear'',''compliant'',''approved'',''verified'',''not_required'',''not_applicable'')) or not private.krim_has_permission(v_user_id,p_organization_id,''partner.manage'') then';
 if position('private.krim_has_permission(v_user_id,p_organization_id,''partner.manage'')' in v_def)=0 then
  if position(v_old in v_def)=0 then raise exception 'Could not locate warehouse movement authorization block';end if;
  v_def:=replace(v_def,v_old,v_new);
 end if;
 v_def:=replace(v_def,'SET search_path TO ''public'', ''pg_temp''','SET search_path TO ''''');
 execute v_def;
end;$patch$;