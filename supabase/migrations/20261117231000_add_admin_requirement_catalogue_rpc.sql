-- Provide a secure, complete requirement catalogue to the regulatory-source console.
create or replace function public.krim_admin_list_market_readiness_requirements()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_user uuid := auth.uid();
  v_requirements jsonb;
begin
  if v_user is null
     or coalesce(auth.jwt()->>'aal','') <> 'aal2'
     or not private.krim_has_permission(v_user,1::bigint,'admin.platform') then
    raise exception using errcode='42501', message='AAL2 platform administrator access required';
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'requirement_id',r.id,
    'requirement_code',r.requirement_code,
    'jurisdiction_code',r.jurisdiction_code,
    'category',r.category,
    'title',r.title,
    'description',r.description,
    'mandatory',r.mandatory,
    'source_review_status',r.source_review_status
  ) order by case when r.jurisdiction_code='*' then 0 else 1 end,
      r.jurisdiction_code,r.category,r.requirement_code),'[]'::jsonb)
  into v_requirements
  from public.krim_market_readiness_requirements r
  where r.source_review_status <> 'retired';

  return jsonb_build_object('requirements',v_requirements,'generated_at',now());
end;
$function$;

revoke all on function public.krim_admin_list_market_readiness_requirements() from public,anon,authenticated;
grant execute on function public.krim_admin_list_market_readiness_requirements() to authenticated;
