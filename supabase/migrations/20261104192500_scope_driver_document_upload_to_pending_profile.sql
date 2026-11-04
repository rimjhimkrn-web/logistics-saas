drop policy if exists krim_driver_docs_insert_own on public.krim_driver_verification_documents;
create policy krim_driver_docs_insert_own on public.krim_driver_verification_documents
for insert to authenticated
with check (
 user_id=auth.uid() and review_status='pending' and reviewed_by is null and reviewed_at is null
 and exists(select 1 from public.krim_driver_profiles p
  where p.id=krim_driver_verification_documents.profile_id
   and p.user_id=auth.uid()
   and p.organization_id=krim_driver_verification_documents.organization_id
   and p.verification_status in ('pending','rejected'))
);