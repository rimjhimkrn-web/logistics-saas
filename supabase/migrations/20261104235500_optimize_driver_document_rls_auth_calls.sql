-- Cache auth.uid() once per statement in driver document RLS policies.
alter policy krim_driver_docs_read_own on public.krim_driver_verification_documents
 using (user_id = (select auth.uid()));
alter policy krim_driver_docs_insert_own on public.krim_driver_verification_documents
 with check (
  user_id = (select auth.uid())
  and review_status = 'pending'
  and reviewed_by is null
  and reviewed_at is null
  and exists (
   select 1
   from public.krim_driver_profiles p
   where p.id = krim_driver_verification_documents.profile_id
     and p.user_id = (select auth.uid())
     and p.organization_id = krim_driver_verification_documents.organization_id
     and p.verification_status in ('pending','rejected')
  )
 );