drop policy if exists "KRIM shipment customs customer scoped read" on public.krim_shipment_customs;
create policy "KRIM shipment customs customer and accepted broker read" on public.krim_shipment_customs for select to authenticated using (
 exists(select 1 from public.krim_shipments s where s.id=krim_shipment_customs.shipment_id and private.krim_has_permission((select auth.uid()),s.customer_organization_id,'shipment.view'))
 or exists(select 1 from public.krim_customs_broker_assignments a where a.customs_record_id=krim_shipment_customs.id and a.shipment_id=krim_shipment_customs.shipment_id and a.assignment_status='accepted' and private.krim_has_permission((select auth.uid()),a.broker_organization_id,'compliance.view'))
);
create policy "Customs shipment document upload scoped" on storage.objects for insert to authenticated with check (
 bucket_id='krim-partner-verification' and split_part(name,'/',1)='customs-docs'
 and exists(select 1 from public.krim_organization_members m where m.user_id=(select auth.uid()) and m.status='active'
 and name like 'customs-docs/%/'||m.organization_id::text||'/'||(select auth.uid())::text||'/%'
 and (private.krim_has_permission((select auth.uid()),m.organization_id,'shipment.update') or private.krim_has_permission((select auth.uid()),m.organization_id,'compliance.view')))
);
create policy "Customs shipment document read scoped" on storage.objects for select to authenticated using (
 bucket_id='krim-partner-verification' and split_part(name,'/',1)='customs-docs'
 and exists(select 1 from public.krim_customs_document_submissions d where d.storage_path=name and (
 exists(select 1 from public.krim_shipments s where s.id=d.shipment_id and private.krim_has_permission((select auth.uid()),s.customer_organization_id,'shipment.view'))
 or exists(select 1 from public.krim_customs_broker_assignments a where a.customs_record_id=d.customs_record_id and a.shipment_id=d.shipment_id and a.assignment_status='accepted' and private.krim_has_permission((select auth.uid()),a.broker_organization_id,'compliance.view'))
 or (coalesce(auth.jwt()->>'aal','aal1')='aal2' and private.krim_has_permission((select auth.uid()),1,'admin.platform'))
 ))
);