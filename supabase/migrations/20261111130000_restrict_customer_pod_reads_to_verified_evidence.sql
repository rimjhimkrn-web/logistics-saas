-- Customers may only read independently verified delivery POD records.
-- Partner organizations retain access to their own submitted/reviewable records.
drop policy if exists "KRIM POD organization access" on public.krim_pod_records;

create policy "KRIM partner organization POD access"
on public.krim_pod_records
for select
to authenticated
using (
  private.krim_has_organization_access((select auth.uid()), partner_organization_id)
);

create policy "KRIM customer verified POD access"
on public.krim_pod_records
for select
to authenticated
using (
  status = 'verified'
  and verified_at is not null
  and exists (
    select 1
    from public.krim_shipments s
    where s.id = krim_pod_records.shipment_id
      and s.customer_organization_id is not null
      and private.krim_has_organization_access((select auth.uid()), s.customer_organization_id)
  )
);
