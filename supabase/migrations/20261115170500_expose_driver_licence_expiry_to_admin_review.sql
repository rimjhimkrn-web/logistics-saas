create or replace function public.krim_admin_list_driver_verification_with_expiry()
returns table(
  profile_id uuid,
  user_id uuid,
  organization_id bigint,
  full_name text,
  country_code text,
  phone text,
  company_name text,
  licence_number text,
  licence_expiry_date date,
  verification_status text,
  document_id uuid,
  document_type text,
  original_file_name text,
  storage_path text,
  content_type text,
  file_size bigint,
  review_status text,
  review_reason text,
  document_created_at timestamptz
)
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_user uuid := auth.uid();
begin
  if v_user is null then
    raise exception using errcode='28000', message='Authentication required';
  end if;
  if coalesce(auth.jwt()->>'aal','aal1') <> 'aal2' then
    raise exception using errcode='42501', message='Multi-factor authentication required';
  end if;
  if not private.krim_has_permission(v_user,1::bigint,'admin.platform') then
    raise exception using errcode='42501', message='Platform administrator permission required';
  end if;
  return query
  select p.id,p.user_id,p.organization_id,p.full_name,p.country_code,p.phone,
         p.company_name,p.licence_number,p.licence_expiry_date,p.verification_status,
         d.id,d.document_type,d.original_file_name,d.storage_path,d.content_type,
         d.file_size,d.review_status,d.review_reason,d.created_at
  from public.krim_driver_profiles p
  left join public.krim_driver_verification_documents d on d.profile_id=p.id
  order by case when p.verification_status in ('pending','in_review') then 0 else 1 end,
           p.created_at desc,d.created_at desc;
end;
$function$;

revoke all on function public.krim_admin_list_driver_verification_with_expiry() from public, anon;
grant execute on function public.krim_admin_list_driver_verification_with_expiry() to authenticated;
