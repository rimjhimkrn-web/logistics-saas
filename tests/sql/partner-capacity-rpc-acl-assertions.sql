-- Run after the proposed capacity RPC ACL migration in an isolated disposable database.
do $$
declare
  v_oid oid := to_regprocedure('public.krim_partner_register_capacity_resource(bigint,text,text,bigint,bigint,numeric,text,text,timestamp with time zone,timestamp with time zone,text[],text)');
begin
  if v_oid is null then raise exception 'Capacity RPC overload missing'; end if;
  if has_function_privilege('anon',v_oid,'EXECUTE') then raise exception 'FAIL: anon EXECUTE unexpectedly granted'; end if;
  if has_function_privilege('authenticated',v_oid,'EXECUTE') is false then raise exception 'FAIL: authenticated EXECUTE missing'; end if;
  if has_function_privilege('service_role',v_oid,'EXECUTE') is false then raise exception 'FAIL: service_role EXECUTE missing'; end if;
  if not (select prosecdef from pg_proc where oid=v_oid) then raise exception 'FAIL: SECURITY DEFINER flag missing'; end if;
  if coalesce((select array_to_string(proconfig, ',') from pg_proc where oid=v_oid),'') not like '%search_path=%' then raise exception 'FAIL: explicit search_path missing'; end if;
end $$;
