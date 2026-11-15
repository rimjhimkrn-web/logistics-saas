ALTER POLICY "Customs broker assignment event scoped read" ON public."krim_customs_broker_assignment_events" USING ((EXISTS ( SELECT 1
   FROM ((krim_customs_broker_assignments a
     JOIN krim_shipment_customs c ON ((c.id = a.customs_record_id)))
     JOIN krim_shipments s ON ((s.id = c.shipment_id)))
  WHERE ((a.id = krim_customs_broker_assignment_events.assignment_id) AND (private.krim_has_permission(( SELECT auth.uid() AS uid), s.customer_organization_id, 'shipment.view'::text) OR private.krim_has_permission(( SELECT auth.uid() AS uid), a.broker_organization_id, 'compliance.view'::text))))) OR ((COALESCE(((SELECT auth.jwt()) ->> 'aal'::text), 'aal1'::text) = 'aal2'::text) AND private.krim_has_permission(( SELECT auth.uid() AS uid), (1)::bigint, 'admin.platform'::text)));

ALTER POLICY "Customs broker assignment scoped read" ON public."krim_customs_broker_assignments" USING ((EXISTS ( SELECT 1
   FROM (krim_shipment_customs c
     JOIN krim_shipments s ON ((s.id = c.shipment_id)))
  WHERE ((c.id = krim_customs_broker_assignments.customs_record_id) AND (private.krim_has_permission(( SELECT auth.uid() AS uid), s.customer_organization_id, 'shipment.view'::text) OR private.krim_has_permission(( SELECT auth.uid() AS uid), krim_customs_broker_assignments.broker_organization_id, 'compliance.view'::text))))) OR ((COALESCE(((SELECT auth.jwt()) ->> 'aal'::text), 'aal1'::text) = 'aal2'::text) AND private.krim_has_permission(( SELECT auth.uid() AS uid), (1)::bigint, 'admin.platform'::text)));

ALTER POLICY "Customs broker license events scoped read" ON public."krim_customs_broker_license_events" USING ((EXISTS ( SELECT 1
   FROM krim_customs_broker_licenses l
  WHERE ((l.id = krim_customs_broker_license_events.license_id) AND private.krim_has_permission(( SELECT auth.uid() AS uid), l.organization_id, 'compliance.view'::text)))) OR ((COALESCE(((SELECT auth.jwt()) ->> 'aal'::text), 'aal1'::text) = 'aal2'::text) AND private.krim_has_permission(( SELECT auth.uid() AS uid), (1)::bigint, 'admin.platform'::text)));

ALTER POLICY "Customs broker licenses scoped read" ON public."krim_customs_broker_licenses" USING (private.krim_has_permission(( SELECT auth.uid() AS uid), organization_id, 'compliance.view'::text) OR ((COALESCE(((SELECT auth.jwt()) ->> 'aal'::text), 'aal1'::text) = 'aal2'::text) AND private.krim_has_permission(( SELECT auth.uid() AS uid), (1)::bigint, 'admin.platform'::text)));

ALTER POLICY "Customs document event scoped read" ON public."krim_customs_document_events" USING ((EXISTS ( SELECT 1
   FROM (krim_customs_document_submissions d
     JOIN krim_shipments s ON ((s.id = d.shipment_id)))
  WHERE ((d.id = krim_customs_document_events.submission_id) AND (private.krim_has_permission(( SELECT auth.uid() AS uid), s.customer_organization_id, 'shipment.view'::text) OR (EXISTS ( SELECT 1
           FROM krim_customs_broker_assignments a
          WHERE ((a.customs_record_id = d.customs_record_id) AND (a.shipment_id = d.shipment_id) AND (a.assignment_status = 'accepted'::text) AND private.krim_has_permission(( SELECT auth.uid() AS uid), a.broker_organization_id, 'compliance.view'::text)))))))) OR ((COALESCE(((SELECT auth.jwt()) ->> 'aal'::text), 'aal1'::text) = 'aal2'::text) AND private.krim_has_permission(( SELECT auth.uid() AS uid), (1)::bigint, 'admin.platform'::text)));

ALTER POLICY "Customs shipment document scoped read" ON public."krim_customs_document_submissions" USING ((EXISTS ( SELECT 1
   FROM krim_shipments s
  WHERE ((s.id = krim_customs_document_submissions.shipment_id) AND private.krim_has_permission(( SELECT auth.uid() AS uid), s.customer_organization_id, 'shipment.view'::text)))) OR (EXISTS ( SELECT 1
   FROM krim_customs_broker_assignments a
  WHERE ((a.customs_record_id = krim_customs_document_submissions.customs_record_id) AND (a.shipment_id = krim_customs_document_submissions.shipment_id) AND (a.assignment_status = 'accepted'::text) AND private.krim_has_permission(( SELECT auth.uid() AS uid), a.broker_organization_id, 'compliance.view'::text)))) OR ((COALESCE(((SELECT auth.jwt()) ->> 'aal'::text), 'aal1'::text) = 'aal2'::text) AND private.krim_has_permission(( SELECT auth.uid() AS uid), (1)::bigint, 'admin.platform'::text)));

ALTER POLICY "Customs requirements visible to shipment stakeholders" ON public."krim_customs_jurisdiction_requirements" USING ((EXISTS ( SELECT 1
   FROM (krim_shipment_customs c
     JOIN krim_shipments s ON ((s.id = c.shipment_id)))
  WHERE ((c.country_id = krim_customs_jurisdiction_requirements.country_id) AND (private.krim_has_permission(( SELECT auth.uid() AS uid), s.customer_organization_id, 'shipment.view'::text) OR (EXISTS ( SELECT 1
           FROM krim_customs_broker_assignments a
          WHERE ((a.customs_record_id = c.id) AND (a.shipment_id = c.shipment_id) AND (a.assignment_status = 'accepted'::text) AND private.krim_has_permission(( SELECT auth.uid() AS uid), a.broker_organization_id, 'compliance.view'::text)))))))) OR (EXISTS ( SELECT 1
   FROM (krim_organization_members m
     JOIN krim_organizations o ON ((o.id = m.organization_id)))
  WHERE ((m.user_id = ( SELECT auth.uid() AS uid)) AND (m.status = 'active'::text) AND (o.organization_type = 'customs'::text) AND (o.status = 'active'::text) AND private.krim_has_permission(( SELECT auth.uid() AS uid), m.organization_id, 'compliance.view'::text)))) OR ((COALESCE(((SELECT auth.jwt()) ->> 'aal'::text), 'aal1'::text) = 'aal2'::text) AND private.krim_has_permission(( SELECT auth.uid() AS uid), (1)::bigint, 'admin.platform'::text)));

ALTER POLICY "KRIM exceptions scoped read" ON public."krim_exceptions" USING (private.krim_has_permission((SELECT auth.uid()), organization_id, 'shipment.view'::text) OR private.krim_has_permission((SELECT auth.uid()), organization_id, 'compliance.view'::text) OR (EXISTS ( SELECT 1
   FROM (krim_organization_members m
     JOIN krim_organizations o ON ((o.id = m.organization_id)))
  WHERE ((m.user_id = (SELECT auth.uid())) AND (m.status = 'active'::text) AND (o.status = 'active'::text) AND (lower(COALESCE(o.organization_type, ''::text)) = 'operations'::text) AND krim_has_permission((SELECT auth.uid()), m.organization_id, 'shipment.view'::text)))));
