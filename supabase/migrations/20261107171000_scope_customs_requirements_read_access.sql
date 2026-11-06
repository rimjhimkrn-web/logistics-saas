drop policy if exists "Customs requirements visible to shipment stakeholders" on public.krim_customs_jurisdiction_requirements;
create policy "Customs requirements visible to shipment stakeholders" on public.krim_customs_jurisdiction_requirements for select to authenticated using (
 exists(select 1 from public.krim_shipment_customs c join public.krim_shipments s on s.id=c.shipment_id
 where c.country_id=krim_customs_jurisdiction_requirements.country_id
 and (private.krim_has_permission((select auth.uid()),s.customer_organization_id,'shipment.view')
  or exists(select 1 from public.krim_customs_broker_assignments a where a.customs_record_id=c.id and a.shipment_id=c.shipment_id and a.assignment_status='accepted' and private.krim_has_permission((select auth.uid()),a.broker_organization_id,'compliance.view'))))
 or exists(select 1 from public.krim_organization_members m join public.krim_organizations o on o.id=m.organization_id
  where m.user_id=(select auth.uid()) and m.status='active' and o.organization_type='customs' and o.status='active'
  and private.krim_has_permission((select auth.uid()),m.organization_id,'compliance.view'))
 or (coalesce(auth.jwt()->>'aal','aal1')='aal2' and private.krim_has_permission((select auth.uid()),1,'admin.platform'))
);