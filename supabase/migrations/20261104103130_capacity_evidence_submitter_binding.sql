do $$
declare v_def text;
begin
 select pg_get_functiondef('public.krim_admin_review_capacity_resource(bigint,text,text)'::regprocedure) into v_def;
 v_def:=replace(v_def,
  '''^''||v_org_id::text||''/[0-9a-fA-F-]{36}/capacity-',
  '''^''||v_org_id::text||''/''||(v_old_state#>>''{metadata,submitted_by}'')||''/capacity-');
 if position('v_old_state#>>''{metadata,submitted_by}''' in v_def)=0 then raise exception 'Failed to bind evidence folder to submitting user';end if;
 execute v_def;
end $$;