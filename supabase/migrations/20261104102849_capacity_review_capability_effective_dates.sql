do $$
declare v_def text;
begin
 select pg_get_functiondef('public.krim_admin_list_capacity_resources()'::regprocedure) into v_def;
 v_def:=replace(v_def,'and c.active=true and c.verification_status=''verified''',
  'and c.active=true and c.verification_status=''verified'' and (c.effective_from is null or c.effective_from<=now()) and (c.effective_until is null or c.effective_until>now())');
 if position('c.effective_until>now()' in v_def)=0 then raise exception 'Failed to add effective-date guard to capacity queue';end if;
 execute v_def;
 select pg_get_functiondef('public.krim_admin_review_capacity_resource(bigint,text,text)'::regprocedure) into v_def;
 v_def:=replace(v_def,'and c.active=true and c.verification_status=''verified'') then',
  'and c.active=true and c.verification_status=''verified'' and (c.effective_from is null or c.effective_from<=now()) and (c.effective_until is null or c.effective_until>now())) then');
 if position('c.effective_until>now()' in v_def)=0 then raise exception 'Failed to add effective-date guard to resource approval';end if;
 execute v_def;
end $$;