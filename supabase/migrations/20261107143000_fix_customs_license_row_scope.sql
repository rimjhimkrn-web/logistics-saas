drop policy if exists "Customs broker licenses scoped read" on public.krim_customs_broker_licenses;
create policy "Customs broker licenses scoped read" on public.krim_customs_broker_licenses for select to authenticated using (
 private.krim_has_permission((select auth.uid()),public.krim_customs_broker_licenses.organization_id,'compliance.view')
 or (coalesce(auth.jwt()->>'aal','aal1')='aal2' and private.krim_has_permission((select auth.uid()),1,'admin.platform'))
);