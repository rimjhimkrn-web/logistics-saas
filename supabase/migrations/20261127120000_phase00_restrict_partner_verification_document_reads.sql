drop policy if exists krim_partner_verification_read_own_org on storage.objects;

create policy krim_partner_verification_read_authorized_owner_manager_or_admin
on storage.objects
for select
to authenticated
using (
  bucket_id = 'krim-partner-verification'
  and (
    (
      owner = (select auth.uid())
      and split_part(name, '/', 2) = (select auth.uid())::text
      and case
        when split_part(name, '/', 1) ~ '^[0-9]+$' then exists (
          select 1
          from public.krim_organization_members m
          join public.krim_organizations o on o.id = m.organization_id
          where m.user_id = (select auth.uid())
            and m.status = 'active'
            and o.status = 'active'
            and m.organization_id = split_part(storage.objects.name, '/', 1)::bigint
            and coalesce(o.organization_type_code, o.organization_type) in
              ('partner','carrier','warehouse','forwarder','logistics_provider','warehouse_operator')
        )
        else false
      end
    )
    or (
      case
        when split_part(name, '/', 1) ~ '^[0-9]+$' then exists (
          select 1
          from public.krim_organization_members m
          join public.krim_organizations o on o.id = m.organization_id
          where m.user_id = (select auth.uid())
            and m.status = 'active'
            and o.status = 'active'
            and m.organization_id = split_part(storage.objects.name, '/', 1)::bigint
            and coalesce(o.organization_type_code, o.organization_type) in
              ('partner','carrier','warehouse','forwarder','logistics_provider','warehouse_operator')
            and private.krim_has_permission((select auth.uid()), m.organization_id, 'partner.manage')
        )
        else false
      end
    )
    or (
      coalesce((auth.jwt() ->> 'aal'), 'aal1') = 'aal2'
      and private.krim_has_permission((select auth.uid()), 1::bigint, 'admin.platform')
    )
  )
);