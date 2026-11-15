DROP POLICY IF EXISTS "KRIM claim events organization access" ON public.krim_claim_events;
DROP POLICY IF EXISTS "KRIM claim events platform admin read" ON public.krim_claim_events;
CREATE POLICY "KRIM claim events scoped read" ON public.krim_claim_events
FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.krim_claims c
    WHERE c.id=krim_claim_events.claim_id
      AND (private.krim_has_organization_access((SELECT auth.uid()),c.organization_id)
        OR (c.respondent_organization_id IS NOT NULL AND private.krim_has_organization_access((SELECT auth.uid()),c.respondent_organization_id)))
  )
  OR EXISTS (
    SELECT 1 FROM public.krim_organization_members m
    JOIN public.krim_organizations o ON o.id=m.organization_id
    WHERE m.user_id=(SELECT auth.uid()) AND m.status='active' AND o.status='active'
      AND o.organization_type=ANY(ARRAY['platform','operations']::text[])
      AND private.krim_has_permission((SELECT auth.uid()),m.organization_id,'admin.platform')
  )
);

DROP POLICY IF EXISTS "KRIM claim evidence organization access" ON public.krim_claim_evidence;
DROP POLICY IF EXISTS "KRIM claim evidence platform admin read" ON public.krim_claim_evidence;
CREATE POLICY "KRIM claim evidence scoped read" ON public.krim_claim_evidence
FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.krim_claims c
    WHERE c.id=krim_claim_evidence.claim_id
      AND (private.krim_has_organization_access((SELECT auth.uid()),c.organization_id)
        OR (c.respondent_organization_id IS NOT NULL AND private.krim_has_organization_access((SELECT auth.uid()),c.respondent_organization_id)))
  )
  OR EXISTS (
    SELECT 1 FROM public.krim_organization_members m
    JOIN public.krim_organizations o ON o.id=m.organization_id
    WHERE m.user_id=(SELECT auth.uid()) AND m.status='active' AND o.status='active'
      AND o.organization_type=ANY(ARRAY['platform','operations']::text[])
      AND private.krim_has_permission((SELECT auth.uid()),m.organization_id,'admin.platform')
  )
);

DROP POLICY IF EXISTS "KRIM claims organization access" ON public.krim_claims;
DROP POLICY IF EXISTS "KRIM claims platform admin read" ON public.krim_claims;
CREATE POLICY "KRIM claims scoped read" ON public.krim_claims
FOR SELECT TO authenticated
USING (
  private.krim_has_organization_access((SELECT auth.uid()),organization_id)
  OR (respondent_organization_id IS NOT NULL AND private.krim_has_organization_access((SELECT auth.uid()),respondent_organization_id))
  OR EXISTS (
    SELECT 1 FROM public.krim_organization_members m
    JOIN public.krim_organizations o ON o.id=m.organization_id
    WHERE m.user_id=(SELECT auth.uid()) AND m.status='active' AND o.status='active'
      AND o.organization_type=ANY(ARRAY['platform','operations']::text[])
      AND private.krim_has_permission((SELECT auth.uid()),m.organization_id,'admin.platform')
  )
);

DROP POLICY IF EXISTS "KRIM organizations member access" ON public.krim_organizations;
DROP POLICY IF EXISTS "KRIM organizations platform admin read" ON public.krim_organizations;
CREATE POLICY "KRIM organizations scoped read" ON public.krim_organizations
FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.krim_organization_members m
    WHERE m.organization_id=krim_organizations.id
      AND m.user_id=(SELECT auth.uid()) AND m.status='active'
  )
  OR (
    COALESCE((SELECT auth.jwt())->>'aal','aal1')='aal2'
    AND private.krim_has_permission((SELECT auth.uid()),1::bigint,'admin.platform')
  )
);

DROP POLICY IF EXISTS "KRIM customer verified POD access" ON public.krim_pod_records;
DROP POLICY IF EXISTS "KRIM partner organization POD access" ON public.krim_pod_records;
CREATE POLICY "KRIM POD stakeholder read" ON public.krim_pod_records
FOR SELECT TO authenticated
USING (
  (
    status='verified' AND verified_at IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM public.krim_shipments s
      WHERE s.id=krim_pod_records.shipment_id
        AND s.customer_organization_id IS NOT NULL
        AND private.krim_has_organization_access((SELECT auth.uid()),s.customer_organization_id)
    )
  )
  OR private.krim_has_organization_access((SELECT auth.uid()),partner_organization_id)
);

DROP POLICY IF EXISTS "KRIM customs records platform admin read" ON public.krim_shipment_customs;
DROP POLICY IF EXISTS "KRIM shipment customs customer and accepted broker read" ON public.krim_shipment_customs;
CREATE POLICY "KRIM shipment customs stakeholder read" ON public.krim_shipment_customs
FOR SELECT TO authenticated
USING (
  (
    COALESCE((SELECT auth.jwt())->>'aal','aal1')='aal2'
    AND private.krim_has_permission((SELECT auth.uid()),1::bigint,'admin.platform')
  )
  OR EXISTS (
    SELECT 1 FROM public.krim_shipments s
    WHERE s.id=krim_shipment_customs.shipment_id
      AND private.krim_has_permission((SELECT auth.uid()),s.customer_organization_id,'shipment.view')
  )
  OR EXISTS (
    SELECT 1 FROM public.krim_customs_broker_assignments a
    WHERE a.customs_record_id=krim_shipment_customs.id
      AND a.shipment_id=krim_shipment_customs.shipment_id
      AND a.assignment_status='accepted'
      AND private.krim_has_permission((SELECT auth.uid()),a.broker_organization_id,'compliance.view')
  )
);
