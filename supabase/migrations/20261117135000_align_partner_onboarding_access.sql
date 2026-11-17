-- Align partner self-service verification access across KRIM environments.
-- The bucket remains private; commercial access is not granted by document submission.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'krim-partner-verification',
  'krim-partner-verification',
  false,
  10485760,
  array['application/pdf','image/jpeg','image/png']::text[]
)
on conflict (id) do update
set name = excluded.name,
    public = false,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname='storage' and tablename='objects'
      and policyname='krim_partner_verification_read_own_org'
  ) then
    execute $policy$
      create policy "krim_partner_verification_read_own_org"
      on storage.objects for select to authenticated
      using (
        bucket_id='krim-partner-verification'
        and case
          when split_part(name,'/',1) ~ '^[0-9]+$' then exists (
            select 1
            from public.krim_organization_members m
            join public.krim_organizations o on o.id=m.organization_id
            where m.user_id=auth.uid()
              and m.status='active'
              and o.status='active'
              and m.organization_id=split_part(storage.objects.name,'/',1)::bigint
              and coalesce(o.organization_type_code,o.organization_type)
                = any(array['partner','carrier','warehouse','forwarder','logistics_provider','warehouse_operator']::text[])
          )
          else false
        end
      )
    $policy$;
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname='storage' and tablename='objects'
      and policyname='krim_partner_verification_upload_own_org'
  ) then
    execute $policy$
      create policy "krim_partner_verification_upload_own_org"
      on storage.objects for insert to authenticated
      with check (
        bucket_id='krim-partner-verification'
        and split_part(name,'/',2)=auth.uid()::text
        and case
          when split_part(name,'/',1) ~ '^[0-9]+$' then exists (
            select 1
            from public.krim_organization_members m
            join public.krim_organizations o on o.id=m.organization_id
            where m.user_id=auth.uid()
              and m.status='active'
              and o.status='active'
              and m.organization_id=split_part(storage.objects.name,'/',1)::bigint
              and coalesce(o.organization_type_code,o.organization_type)
                = any(array['partner','carrier','warehouse','forwarder','logistics_provider','warehouse_operator']::text[])
          )
          else false
        end
      )
    $policy$;
  end if;
end
$$;

grant execute on function public.krim_provision_partner_organization(text) to authenticated;
grant execute on function public.krim_set_partner_account_mode(text,jsonb) to authenticated;
grant execute on function public.krim_submit_partner_onboarding_global_multi_v1(
  text,text,text,text[],text[],text,text,text,text,text,text,text,text,text,jsonb
) to authenticated;
grant execute on function public.krim_admin_review_partner_verification(bigint,text,text) to authenticated;
grant execute on function public.krim_admin_review_partner_capability(bigint,text,text) to authenticated;
