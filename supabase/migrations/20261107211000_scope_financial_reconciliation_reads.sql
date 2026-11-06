-- Financial reconciliation data is visible only to finance.view users and platform administrators.
drop policy if exists org_isolation_all on public.krim_financial_reconciliation_exceptions;
drop policy if exists recon_exception_org_all on public.krim_financial_reconciliation_exception_events;
drop policy if exists "KRIM financial reconciliations organization access" on public.krim_financial_reconciliations;
create policy "KRIM reconciliation exceptions finance read" on public.krim_financial_reconciliation_exceptions
 for select to authenticated using (
  (organization_id is not null and private.krim_has_permission((select auth.uid()),organization_id,'finance.view'))
  or exists (
   select 1 from public.krim_organization_members m join public.krim_organizations o on o.id=m.organization_id
   where m.user_id=(select auth.uid()) and m.status='active' and o.status='active'
    and o.organization_type in ('platform','operations')
    and private.krim_has_permission((select auth.uid()),m.organization_id,'admin.platform')
  )
 );
create policy "KRIM reconciliation exception events finance read" on public.krim_financial_reconciliation_exception_events
 for select to authenticated using (
  exists(select 1 from public.krim_financial_reconciliation_exceptions e
   where e.id=exception_id and (
    (e.organization_id is not null and private.krim_has_permission((select auth.uid()),e.organization_id,'finance.view'))
    or exists(select 1 from public.krim_organization_members m join public.krim_organizations o on o.id=m.organization_id
     where m.user_id=(select auth.uid()) and m.status='active' and o.status='active'
      and o.organization_type in ('platform','operations')
      and private.krim_has_permission((select auth.uid()),m.organization_id,'admin.platform'))
   ))
 );
create policy "KRIM financial reconciliations finance read" on public.krim_financial_reconciliations
 for select to authenticated using (
  private.krim_has_permission((select auth.uid()),organization_id,'finance.view')
  or exists(select 1 from public.krim_organization_members m join public.krim_organizations o on o.id=m.organization_id
   where m.user_id=(select auth.uid()) and m.status='active' and o.status='active'
    and o.organization_type in ('platform','operations')
    and private.krim_has_permission((select auth.uid()),m.organization_id,'admin.platform'))
 );
revoke insert,update,delete,truncate,references,trigger on table public.krim_financial_reconciliation_exception_events from public,anon,authenticated;
grant select on table public.krim_financial_reconciliation_exception_events to authenticated;
