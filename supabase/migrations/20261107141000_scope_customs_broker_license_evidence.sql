drop policy if exists "Customs broker license read own organization" on storage.objects;
create policy "Customs broker license read own organization" on storage.objects for select to authenticated using (
 bucket_id='krim-partner-verification' and split_part(name,'/',1)='customs'
 and exists(select 1 from public.krim_organization_members m join public.krim_organizations o on o.id=m.organization_id
 where m.user_id=(select auth.uid()) and m.status='active' and o.organization_type='customs'
 and name like 'customs/'||m.organization_id::text||'/%'
 and private.krim_has_permission((select auth.uid()),m.organization_id,'compliance.view'))
);