do $$
declare v_def text;
begin
 select pg_get_functiondef('public.krim_partner_register_capacity_resource(bigint,text,text,bigint,bigint,numeric,text,text,timestamptz,timestamptz,text[],text)'::regprocedure) into v_def;
 v_def:=replace(v_def,'and o.partner_account_mode=''registered_business''',
  'and o.partner_account_mode=''registered_business'' and o.organization_type in (''partner'',''carrier'',''warehouse'',''forwarder'')');
 if position('o.organization_type in' in v_def)=0 then raise exception 'Failed to restrict capacity registration to logistics partner organization types';end if;
 execute v_def;
 select pg_get_functiondef('public.krim_admin_review_capacity_resource(bigint,text,text)'::regprocedure) into v_def;
 v_def:=replace(v_def,'v_transport_mode_id bigint;v_old_state jsonb;','v_transport_mode_id bigint;v_org_type text;v_old_state jsonb;');
 v_def:=replace(v_def,'r.organization_id,r.transport_mode_id,o.partner_account_mode,o.status,','r.organization_id,r.transport_mode_id,o.organization_type,o.partner_account_mode,o.status,');
 v_def:=replace(v_def,'into v_org_id,v_transport_mode_id,v_org_mode,v_org_status,','into v_org_id,v_transport_mode_id,v_org_type,v_org_mode,v_org_status,');
 v_def:=replace(v_def,'if v_org_mode is distinct from','if coalesce(v_org_type,'''') not in (''partner'',''carrier'',''warehouse'',''forwarder'') or v_org_mode is distinct from');
 if position('coalesce(v_org_type' in v_def)=0 then raise exception 'Failed to add organization-type guard to capacity approval';end if;
 execute v_def;
end $$;