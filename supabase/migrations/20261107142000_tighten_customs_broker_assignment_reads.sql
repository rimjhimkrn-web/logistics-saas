drop policy if exists "Customs broker assignment scoped read" on public.krim_customs_broker_assignments;
create policy "Customs broker assignment scoped read" on public.krim_customs_broker_assignments for select to authenticated using (
 exists(select 1 from public.krim_shipment_customs c join public.krim_shipments s on s.id=c.shipment_id where c.id=customs_record_id and (
 private.krim_has_permission((select auth.uid()),s.customer_organization_id,'shipment.view')
 or private.krim_has_permission((select auth.uid()),broker_organization_id,'compliance.view')))
 or (coalesce(auth.jwt()->>'aal','aal1')='aal2' and private.krim_has_permission((select auth.uid()),1,'admin.platform')));
drop policy if exists "Customs broker assignment event scoped read" on public.krim_customs_broker_assignment_events;
create policy "Customs broker assignment event scoped read" on public.krim_customs_broker_assignment_events for select to authenticated using (
 exists(select 1 from public.krim_customs_broker_assignments a join public.krim_shipment_customs c on c.id=a.customs_record_id join public.krim_shipments s on s.id=c.shipment_id
 where a.id=assignment_id and (private.krim_has_permission((select auth.uid()),s.customer_organization_id,'shipment.view')
 or private.krim_has_permission((select auth.uid()),a.broker_organization_id,'compliance.view')))
 or (coalesce(auth.jwt()->>'aal','aal1')='aal2' and private.krim_has_permission((select auth.uid()),1,'admin.platform')));
