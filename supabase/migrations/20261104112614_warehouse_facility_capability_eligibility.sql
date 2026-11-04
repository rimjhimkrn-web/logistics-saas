-- Allow verified WAREHOUSE capabilities to pass facility registration, facility approval,
-- inventory movement and dashboard checks even when the legal organisation is a multi-service partner.
do $patch$
declare v_def text;v_start int;v_end int;
begin
 select pg_get_functiondef('public.krim_warehouse_register_facility(bigint,text,text,text,text,text,text)'::regprocedure) into v_def;
 if position('private.krim_warehouse_org_eligible(o.id)' in v_def)=0 then
  v_start:=strpos(v_def,'and (o.organization_type ilike');
  v_end:=strpos(v_def,'then raise exception ''An active, verified registered-business warehouse organisation membership is required''');
  if v_start=0 or v_end<=v_start then raise exception 'Facility registration guard not located';end if;
  v_def:=substring(v_def from 1 for v_start-1)||'and private.krim_warehouse_org_eligible(o.id))'||E'\n '||substring(v_def from v_end);execute v_def;
 end if;
 select pg_get_functiondef('public.krim_warehouse_record_movement(bigint,uuid,text,numeric,text,uuid,text,text,text,text,text,text,text,text)'::regprocedure) into v_def;
 if position('private.krim_warehouse_org_eligible(o.id)' in v_def)=0 then
  v_start:=strpos(v_def,'and (o.organization_type ilike');v_end:=strpos(v_def,'limit 1;');
  if v_start=0 or v_end<=v_start then raise exception 'Movement eligibility guard not located';end if;
  v_def:=substring(v_def from 1 for v_start-1)||'and private.krim_warehouse_org_eligible(o.id)'||E'\n '||substring(v_def from v_end);execute v_def;
 end if;
 select pg_get_functiondef('public.krim_admin_review_warehouse_facility(uuid,text,text)'::regprocedure) into v_def;
 if position('private.krim_warehouse_org_eligible(v_org.id)' in v_def)=0 then
  v_start:=strpos(v_def,'and (v_org.organization_type ilike');v_end:=strpos(v_def,'then raise exception ''Organisation is not eligible for facility approval''');
  if v_start=0 or v_end<=v_start then raise exception 'Facility approval eligibility guard not located';end if;
  v_def:=substring(v_def from 1 for v_start-1)||'and private.krim_warehouse_org_eligible(v_org.id))'||E'\n '||substring(v_def from v_end);execute v_def;
 end if;
end;$patch$;
create or replace function public.krim_warehouse_dashboard()
returns jsonb language plpgsql security definer set search_path=''
as $$
declare v_user uuid:=auth.uid();v_orgs bigint[];v_result jsonb;
begin
 if v_user is null then raise exception 'Authentication required' using errcode='28000';end if;
 select coalesce(array_agg(distinct o.id),'{}'::bigint[]) into v_orgs from public.krim_organizations o join public.krim_organization_members m on m.organization_id=o.id
 where m.user_id=v_user and m.status='active' and private.krim_warehouse_org_eligible(o.id) and private.krim_has_permission(v_user,o.id,'partner.manage');
 select jsonb_build_object('open_tasks',(select count(*) from public.krim_warehouse_tasks t where t.organization_id=any(v_orgs) and t.status in ('open','in_progress','on_hold')),
 'completed_today',(select count(*) from public.krim_warehouse_tasks t where t.organization_id=any(v_orgs) and t.status='completed' and t.completed_at>=date_trunc('day',now())),
 'active_facilities',(select count(*) from public.krim_warehouse_facilities f where f.organization_id=any(v_orgs) and f.status='active' and f.review_status='approved'),
 'inventory_skus',(select count(*) from public.krim_warehouse_inventory i where i.organization_id=any(v_orgs)),
 'inventory_units',(select coalesce(sum(i.quantity),0) from public.krim_warehouse_inventory i where i.organization_id=any(v_orgs)),
 'pending_quality',(select count(*) from public.krim_warehouse_inventory i where i.organization_id=any(v_orgs) and i.quality_status in ('pending','hold')),
 'recent_tasks',(select count(*) from public.krim_warehouse_tasks t where t.organization_id=any(v_orgs) and t.created_at>=now()-interval '7 days')) into v_result;
 return coalesce(v_result,'{}'::jsonb);
end;$$;