drop policy if exists krim_driver_verification_cleanup_unregistered_upload on storage.objects;
create policy krim_driver_verification_cleanup_unregistered_upload on storage.objects for delete to authenticated using(
 bucket_id='krim-driver-verification'
 and (storage.foldername(name))[1]=auth.uid()::text
 and exists(select 1 from public.krim_driver_profiles p where p.user_id=auth.uid() and p.id::text=(storage.foldername(objects.name))[2])
 and not exists(select 1 from public.krim_driver_verification_documents d where d.storage_path=storage.objects.name)
);