DROP POLICY IF EXISTS "KRIM assigned partners can view shipment alerts" ON public.krim_shipment_alerts;
DROP POLICY IF EXISTS "KRIM shipment alerts customer permission access" ON public.krim_shipment_alerts;
CREATE POLICY "KRIM shipment alerts scoped read"
ON public.krim_shipment_alerts FOR SELECT TO authenticated
USING (
  private.krim_user_has_active_partner_assignment(shipment_id)
  OR EXISTS (
    SELECT 1 FROM public.krim_shipments s
    WHERE s.id = krim_shipment_alerts.shipment_id
      AND private.krim_has_permission((SELECT auth.uid()), s.customer_organization_id, 'shipment.view')
  )
);

DROP POLICY IF EXISTS "KRIM assigned partners can view shipment milestones" ON public.krim_shipment_milestones;
DROP POLICY IF EXISTS "KRIM shipment milestones customer permission access" ON public.krim_shipment_milestones;
CREATE POLICY "KRIM shipment milestones scoped read"
ON public.krim_shipment_milestones FOR SELECT TO authenticated
USING (
  private.krim_user_has_active_partner_assignment(shipment_id)
  OR EXISTS (
    SELECT 1 FROM public.krim_shipments s
    WHERE s.id = krim_shipment_milestones.shipment_id
      AND private.krim_has_permission((SELECT auth.uid()), s.customer_organization_id, 'shipment.view')
  )
);

DROP POLICY IF EXISTS "KRIM assigned partners can view shipment risks" ON public.krim_shipment_risks;
DROP POLICY IF EXISTS "KRIM shipment risks organization access" ON public.krim_shipment_risks;
CREATE POLICY "KRIM shipment risks scoped read"
ON public.krim_shipment_risks FOR SELECT TO authenticated
USING (
  private.krim_user_has_active_partner_assignment(shipment_id)
  OR EXISTS (
    SELECT 1 FROM public.krim_shipments s
    WHERE s.id = krim_shipment_risks.shipment_id
      AND private.krim_has_organization_access((SELECT auth.uid()), s.customer_organization_id)
  )
);

DROP POLICY IF EXISTS "KRIM assigned partners can view shipment status history" ON public.krim_shipment_status_history;
DROP POLICY IF EXISTS "KRIM shipment status history organization access" ON public.krim_shipment_status_history;
CREATE POLICY "KRIM shipment status history scoped read"
ON public.krim_shipment_status_history FOR SELECT TO authenticated
USING (
  private.krim_user_has_active_partner_assignment(shipment_id)
  OR EXISTS (
    SELECT 1 FROM public.krim_shipments s
    WHERE s.id = krim_shipment_status_history.shipment_id
      AND private.krim_has_organization_access((SELECT auth.uid()), s.customer_organization_id)
  )
);

DROP POLICY IF EXISTS "KRIM assigned partners can view shipment tracking events" ON public.krim_tracking_events;
DROP POLICY IF EXISTS "KRIM operations managers can view tracking events" ON public.krim_tracking_events;
DROP POLICY IF EXISTS "KRIM tracking events organization access" ON public.krim_tracking_events;
CREATE POLICY "KRIM tracking events scoped read"
ON public.krim_tracking_events FOR SELECT TO authenticated
USING (
  private.krim_user_has_active_partner_assignment(shipment_id)
  OR EXISTS (
    SELECT 1 FROM public.krim_shipments s
    WHERE s.id = krim_tracking_events.shipment_id
      AND s.customer_organization_id IS NOT NULL
      AND private.krim_has_organization_access((SELECT auth.uid()), s.customer_organization_id)
  )
  OR EXISTS (
    SELECT 1
    FROM public.krim_organization_members m
    JOIN public.krim_organizations o ON o.id = m.organization_id
    WHERE m.user_id = (SELECT auth.uid())
      AND m.status = 'active'
      AND o.status = 'active'
      AND lower(coalesce(o.organization_type,'')) = 'operations'
      AND public.krim_has_permission((SELECT auth.uid()), m.organization_id, 'tracking.view')
  )
);
