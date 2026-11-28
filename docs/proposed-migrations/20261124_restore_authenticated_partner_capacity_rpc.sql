-- Proposed forward-only ACL reconciliation for the exact browser-facing capacity RPC.
-- Do not apply until the staging migration-ledger recovery gate is cleared.
begin;

do $guard$
declare
  v_oid oid;
  v_def text;
begin
  v_oid := to_regprocedure('public.krim_partner_register_capacity_resource(bigint,text,text,bigint,bigint,numeric,text,text,timestamp with time zone,timestamp with time zone,text[],text)');
  if v_oid is null then
    raise exception 'Expected capacity RPC overload is missing';
  end if;

  if not (select prosecdef from pg_proc where oid=v_oid) then
    raise exception 'Capacity RPC must remain SECURITY DEFINER';
  end if;

  if coalesce((select array_to_string(proconfig, ',') from pg_proc where oid=v_oid),'') not like '%search_path=%' then
    raise exception 'Capacity RPC must retain an explicit search_path setting';
  end if;

  v_def := lower(pg_get_functiondef(v_oid));
  if position('auth.uid()' in v_def)=0
     or position('krim_has_permission' in v_def)=0
     or position('krim_partner_compliance_is_current' in v_def)=0
     or position('storage.objects' in v_def)=0
     or position('pending_review' in v_def)=0
     or position('unavailable' in v_def)=0 then
    raise exception 'Capacity RPC authorization/evidence/review guard markers are missing; refusing ACL change';
  end if;
end
$guard$;

revoke all on function public.krim_partner_register_capacity_resource(bigint,text,text,bigint,bigint,numeric,text,text,timestamp with time zone,timestamp with time zone,text[],text) from public;
revoke all on function public.krim_partner_register_capacity_resource(bigint,text,text,bigint,bigint,numeric,text,text,timestamp with time zone,timestamp with time zone,text[],text) from anon;
grant execute on function public.krim_partner_register_capacity_resource(bigint,text,text,bigint,bigint,numeric,text,text,timestamp with time zone,timestamp with time zone,text[],text) to authenticated;
grant execute on function public.krim_partner_register_capacity_resource(bigint,text,text,bigint,bigint,numeric,text,text,timestamp with time zone,timestamp with time zone,text[],text) to service_role;

do $assert$
declare
  v_oid oid := to_regprocedure('public.krim_partner_register_capacity_resource(bigint,text,text,bigint,bigint,numeric,text,text,timestamp with time zone,timestamp with time zone,text[],text)');
begin
  if has_function_privilege('anon',v_oid,'EXECUTE') then raise exception 'anon must not execute capacity RPC'; end if;
  if not has_function_privilege('authenticated',v_oid,'EXECUTE') then raise exception 'authenticated must execute capacity RPC'; end if;
  if not has_function_privilege('service_role',v_oid,'EXECUTE') then raise exception 'service_role must retain capacity RPC execution'; end if;
end
$assert$;

commit;
