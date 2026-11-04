do $$
declare v_def text;
begin
 select pg_get_functiondef('public.krim_internal_check_network_capability(bigint)'::regprocedure) into v_def;
 v_def:=replace(v_def,'set stage=''matching'',status=''queued''','set stage=''qualification'',status=''queued''');
 if position('stage=''matching''' in v_def)>0 or position('stage=''qualification''' in v_def)=0 then
  raise exception 'Failed to align unavailable quote stage with allowed orchestration stages';
 end if;
 execute v_def;
end $$;
revoke all on function public.krim_internal_check_network_capability(bigint) from public,anon,authenticated;
grant execute on function public.krim_internal_check_network_capability(bigint) to service_role;