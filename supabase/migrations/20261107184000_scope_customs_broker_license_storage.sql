-- Scope customs broker licence evidence upload and orphan cleanup.
drop policy if exists "Customs broker license upload own organization" on storage.objects;
create policy "Customs broker license upload own organization"
on storage.objects for insert to authenticated
with check (
 bucket_id='krim-partner-verification'
 and name like 'customs/%/'||(select auth.uid())::text||'/%'
 and exists(select 1 from public.krim_organization_members m join public.krim_organizations o on o.id=m.organization_id
  where m.user_id=(select auth.uid()) and m.status='active' and o.organization_type='customs' and o.status='active'
   and name like 'customs/'||m.organization_id::text||'/'||(select auth.uid())::text||'/%'
   and private.krim_has_permission((select auth.uid()),m.organization_id,'compliance.manage'))
);
drop policy if exists "Customs broker license cleanup unregistered upload" on storage.objects;
create policy "Customs broker license cleanup unregistered upload"
on storage.objects for delete to authenticated
using (
 bucket_id='krim-partner-verification' and split_part(name,'/',1)='customs'
 and owner=(select auth.uid())
 and exists(select 1 from public.krim_organization_members m
  where m.user_id=(select auth.uid()) and m.status='active'
   and name like 'customs/'||m.organization_id::text||'/'||(select auth.uid())::text||'/%'
   and private.krim_has_permission((select auth.uid()),m.organization_id,'compliance.manage'))
 and not exists(select 1 from public.krim_customs_broker_licenses l where l.evidence_path=objects.name)
);
