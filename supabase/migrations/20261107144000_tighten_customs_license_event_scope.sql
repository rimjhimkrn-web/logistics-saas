drop policy if exists "Customs broker license events scoped read" on public.krim_customs_broker_license_events;
create policy "Customs broker license events scoped read" on public.krim_customs_broker_license_events for select to authenticated using (
 exists(select 1 from public.krim_customs_broker_licenses l where l.id=public.krim_customs_broker_license_events.license_id
  and private.krim_has_permission((select auth.uid()),l.organization_id,'compliance.view'))
 or (coalesce(auth.jwt()->>'aal','aal1')='aal2' and private.krim_has_permission((select auth.uid()),1,'admin.platform'))
);