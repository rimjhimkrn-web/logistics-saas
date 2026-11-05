-- Restrict driver POD metadata registration to an uploaded, owned evidence object.
-- The storage bucket remains private; this does not grant update/delete access.
grant select, insert on table public.krim_driver_delivery_evidence to authenticated;

drop policy if exists "Drivers submit evidence for own assignments"
  on public.krim_driver_delivery_evidence;

create policy "Drivers submit verified object evidence for own assignments"
on public.krim_driver_delivery_evidence
for insert
to authenticated
with check (
  user_id = (select auth.uid())
  and length(btrim(recipient_name)) between 1 and 200
  and length(coalesce(notes, '')) <= 1000
  and file_size between 1 and 10485760
  and content_type in ('image/jpeg', 'image/png', 'image/webp', 'application/pdf')
  and storage_path like ((select auth.uid())::text || '/' || assignment_id::text || '/%')
  and cardinality(string_to_array(storage_path, '/')) = 3
  and exists (
    select 1
    from storage.objects o
    where o.bucket_id = 'krim-driver-evidence'
      and o.name = krim_driver_delivery_evidence.storage_path
      and o.owner = (select auth.uid())
  )
  and exists (
    select 1
    from public.krim_driver_assignments a
    join public.krim_organization_members m
      on m.organization_id = a.organization_id
     and m.user_id = (select auth.uid())
     and lower(m.role) = 'driver'
     and lower(m.status) = 'active'
    where a.id = krim_driver_delivery_evidence.assignment_id
      and a.user_id = (select auth.uid())
      and a.status not in ('delivered', 'cancelled')
  )
);
